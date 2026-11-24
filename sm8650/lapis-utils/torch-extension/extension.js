import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';

const LED = '/sys/class/leds/white:flash/brightness';
const FLASHLIGHT = '/usr/bin/lapis-flashlight';

const TorchIndicator = GObject.registerClass(
class TorchIndicator extends QuickSettings.SystemIndicator {
    _init() {
        super._init();

        this._lit = false;
        this._busy = false;
        this._toggle = new QuickSettings.QuickToggle({
            title: 'Torch',
            icon_name: 'flashlight-off',
            toggle_mode: true,
        });
        this._toggle.connect('clicked', () => this._onClicked());
        this.quickSettingsItems.push(this._toggle);

        this._icon = this._addIndicator();
        this._icon.icon_name = 'flashlight-on';

        this._sync();
        this._timer = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._sync();
            return GLib.SOURCE_CONTINUE;
        });

        Main.panel.statusArea.quickSettings.addExternalIndicator(this);
    }

    _brightness() {
        try {
            const [, bytes] = Gio.File.new_for_path(LED).load_contents(null);
            return parseInt(new TextDecoder().decode(bytes).trim(), 10) || 0;
        } catch (e) {
            return 0;
        }
    }

    _sync() {
        if (this._busy)
            return;
        const lit = this._brightness() > 0;
        this._lit = lit;
        this._icon.visible = lit;
        this._toggle.icon_name = lit ? 'flashlight-on' : 'flashlight-off';
        if (this._toggle.checked !== lit)
            this._toggle.checked = lit;
    }

    _onClicked() {
        if (this._busy)
            return;
        this._busy = true;
        this._run(this._lit ? 'off' : 'on');
    }

    _run(command) {
        try {
            const proc = Gio.Subprocess.new(
                ['pkexec', FLASHLIGHT, command],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE);
            proc.communicate_utf8_async(null, null, (source, result) => {
                try {
                    const [, stderr] = source.communicate_utf8_finish(result);
                    if (!source.get_successful())
                        log(`torch: ${stderr}`);
                } catch (e) {
                    log(`torch: ${e}`);
                }
                this._busy = false;
                this._sync();
            });
        } catch (e) {
            log(`torch: ${e}`);
            this._busy = false;
            this._sync();
        }
    }

    destroy() {
        if (this._timer) {
            GLib.source_remove(this._timer);
            this._timer = 0;
        }
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

export default class TorchExtension extends Extension {
    enable() {
        this._indicator = new TorchIndicator();
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
