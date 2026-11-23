/*
 * gsd-power's ambient path anchors on the first lux sample and then swings
 * the panel for a small change in light. Drop only that call. The Settings
 * switch stays, and lapis-autobright follows it with the Android curve.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>

typedef void (*proxy_call_fn)(void *proxy, const char *method, void *params,
			      int flags, int timeout, void *cancellable,
			      void *callback, void *user_data);
typedef void *(*proxy_call_sync_fn)(void *proxy, const char *method, void *params,
				    int flags, int timeout, void *cancellable,
				    void **error);

static int drop_auto_target(const char *method)
{
	return method && strcmp(method, "SetAutoBrightnessTarget") == 0;
}

static void release_params(void *params)
{
	static void *(*sink)(void *);
	static void (*unref)(void *);

	if (!params)
		return;
	if (!sink) {
		sink = dlsym(RTLD_NEXT, "g_variant_ref_sink");
		unref = dlsym(RTLD_NEXT, "g_variant_unref");
	}
	if (sink && unref)
		unref(sink(params));
}

void g_dbus_proxy_call(void *proxy, const char *method, void *params,
		       int flags, int timeout, void *cancellable,
		       void *callback, void *user_data)
{
	static proxy_call_fn real;

	if (!real)
		real = dlsym(RTLD_NEXT, "g_dbus_proxy_call");
	if (drop_auto_target(method)) {
		release_params(params);
		return;
	}
	real(proxy, method, params, flags, timeout, cancellable, callback, user_data);
}

void *g_dbus_proxy_call_sync(void *proxy, const char *method, void *params,
			     int flags, int timeout, void *cancellable,
			     void **error)
{
	static proxy_call_sync_fn real;

	if (!real)
		real = dlsym(RTLD_NEXT, "g_dbus_proxy_call_sync");
	if (drop_auto_target(method)) {
		release_params(params);
		if (error)
			*error = NULL;
		return NULL;
	}
	return real(proxy, method, params, flags, timeout, cancellable, error);
}
