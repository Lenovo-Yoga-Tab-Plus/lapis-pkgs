/* Keep automatic brightness steady.
 *
 * iio-sensor-proxy 3.9 publishes the TCS3701 light level. Two things in that
 * stream make the screen pulse. A single sample of about 1.2 lux shows up
 * between real readings, and the real reading itself wanders (16 lux to 26
 * lux in a steady room). GNOME treats the first reading as the baseline and
 * then moves the backlight in proportion, so that wander swung this panel
 * from 31% to 69%.
 *
 * This replaces only the LightLevel value inside the proxy. The published
 * reading stays put until a new level, about twice as bright or half as
 * bright, has shown up several times in a row. Compass heading uses the same
 * glib call and is left alone.
 *
 * The checked instruction is the LightLevel store in iio-sensor-proxy 3.9-1
 * (build-id 0711a2b80fb4e6b9c9f9baa957116bab8228af77). Any other build is
 * left alone.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define LIGHT_CALL_RETURN 0x5244u
#define LIGHT_LEVEL_INSN 0xfd4076a0u
#define LIGHT_LEVEL_INSN_AT 0x523cu
#define STARTUP 5
#define CONFIRM 4
#define BAND 2.0

typedef void *(*new_double_fn) (double);

static new_double_fn real_new_double;
static int enabled;
static double startup[STARTUP];
static unsigned startup_count;
static int holding;
static double held;
static double pending;
static double pending_sum;
static unsigned pending_count;
static unsigned notes;

static int
is_light_emit (void *caller)
{
	Dl_info info;
	const uint32_t *insn;
	uintptr_t offset;

	if (!dladdr (caller, &info) || !info.dli_fbase || !info.dli_fname)
		return 0;
	if (!strstr (info.dli_fname, "iio-sensor-proxy"))
		return 0;
	offset = (uintptr_t) caller - (uintptr_t) info.dli_fbase;
	if (offset != LIGHT_CALL_RETURN)
		return 0;
	insn = (const uint32_t *) ((uintptr_t) info.dli_fbase + LIGHT_LEVEL_INSN_AT);
	if (*insn != LIGHT_LEVEL_INSN)
		return 0;
	if (!enabled) {
		enabled = 1;
		fprintf (stderr, "lapis-light-filter: smoothing ambient light\n");
	}
	return 1;
}

static double
median_of (double *values, unsigned count)
{
	double ordered[STARTUP];
	unsigned i, j;

	for (i = 0; i < count; i++)
		ordered[i] = values[i];
	for (i = 1; i < count; i++) {
		double value = ordered[i];
		j = i;
		while (j > 0 && ordered[j - 1] > value) {
			ordered[j] = ordered[j - 1];
			j--;
		}
		ordered[j] = value;
	}
	return ordered[count / 2];
}

static double
smooth_lux (double value)
{
	if (!(value >= 0.0) || value > 200000.0)
		return value;

	if (!holding) {
		startup[startup_count++] = value;
		if (startup_count < STARTUP)
			return median_of (startup, startup_count);
		held = median_of (startup, STARTUP);
		holding = 1;
		fprintf (stderr, "lapis-light-filter: holding %.2f lux\n", held);
		return held;
	}

	if (value >= held / BAND && value <= held * BAND) {
		pending_count = 0;
		pending_sum = 0.0;
		return held;
	}

	if (pending_count > 0 && value >= pending / 1.4 && value <= pending * 1.4) {
		pending_count++;
		pending_sum += value;
	} else {
		pending = value;
		pending_count = 1;
		pending_sum = value;
	}
	/* Glitch bursts sit near 1.4 lux. A real dark reading has to stay. */
	if (pending_count < (value < 4.0 ? 16 : CONFIRM)) {
		if (notes < 6) {
			fprintf (stderr, "lapis-light-filter: holding %.2f, skipped %.2f\n",
				 held, value);
			notes++;
		}
		return held;
	}

	held = pending_sum / pending_count;
	pending_count = 0;
	pending_sum = 0.0;
	fprintf (stderr, "lapis-light-filter: light changed to %.2f lux\n", held);
	return held;
}

void *
g_variant_new_double (double value)
{
	void *caller;

	if (!real_new_double)
		real_new_double = (new_double_fn) dlsym (RTLD_NEXT, "g_variant_new_double");

	caller = __builtin_return_address (0);
	if (is_light_emit (caller))
		value = smooth_lux (value);
	return real_new_double (value);
}
