# Quickshell — Arch Linux / Hyprland

A Hyprland desktop shell built with Quickshell. Requires a **Wayland session** — does not work under X11.

---

## 1. Dependencies

Install only what applies to your setup — you do not need to run all of these.

**Core — required to run the shell:**
```bash
sudo pacman -S quickshell python \
    qt6-base qt6-declarative qt6-wayland qt6-tools
```

**Wallpaper — required for wallpaper cycling:**
```bash
sudo pacman -S awww
```

**Audio — required for volume, media controls, and the audio popup:**
```bash
sudo pacman -S pipewire wireplumber alsa-utils playerctl
```

**Bluetooth — required for the bluetooth popup:**
```bash
sudo pacman -S bluez bluez-utils bluez-plugins
```

**Display brightness — required for DDC brightness sliders:**
```bash
sudo pacman -S ddcutil
```

**USB automounting — required for USB quick access:**
```bash
sudo pacman -S udisks2
```

**Network — required for the network widget:**
```bash
sudo pacman -S networkmanager
```

**Notifications — required for toast popups:**
```bash
sudo pacman -S libnotify
```

**Apps used by default commands** — these match the defaults in `config.json` but can be swapped for alternatives:
```bash
sudo pacman -S nautilus ghostty flameshot hyprpicker
```

**Wayland/Hyprland integration:**
```bash
sudo pacman -S hyprland xdg-desktop-portal-hyprland
```

**Python packages — required for background operations:**
```bash
pip install rapidfuzz colormath pillow numpy --break-system-packages
```

> **Install order matters:**
> 1. Install system packages via `pacman` first
> 2. Enable services before adding user to groups
> 3. Add user to groups and **log out/in** before running anything that needs them (DDC, bluetooth, USB)
> 4. Install Python packages after Python is installed
> 5. `awww` daemon must be running before Quickshell starts — add `exec-once = awww-daemon` to your Hyprland config. Without this wallpapers will silently do nothing
> 6. Reboot after adding `i2c-dev` to modules — `modprobe` is a temporary fix until reboot

---

## 2. User Groups

```bash
sudo usermod -aG video storage i2c bluetooth $USER
```

Log out and back in after.

---

## 3. Services

```bash
sudo systemctl enable --now bluetooth NetworkManager udisks2
```

**Bluetooth battery** — add to `/etc/bluetooth/main.conf` under `[General]`:
```ini
Experimental=true
```

**DDC brightness** — create `/etc/modules-load.d/i2c.conf`:
```
i2c-dev
```
Then reboot or `sudo modprobe i2c-dev`.

---

## 4. Installation

```bash
git clone https://github.com/FacehuggersInc/quickshell.git ~/.config/quickshell
```

**Set your username in `utill.py`** — open `~/.config/quickshell/Scripts/utill.py` and update the user configuration block at the top:

```python
# ── USER CONFIGURATION ────────────────────────────────────────
USERNAME = "youruser"   # change this to your Linux username
```

This controls where the script looks for your config, icon cache, and icon directories. Everything else derives from it automatically.

> **`theme.py` must also be present** in `~/.config/quickshell/Scripts/` alongside `utill.py`. It is imported directly — if it is missing every `utill.py` call will crash and the shell will not function.

---

## 5. Icons

Icons are hand-picked from [Google Material Icons](https://fonts.google.com/icons) and saved as PNG. They are not always named to match their Material name — some are renamed to fit the context they're used in based on personal preference.

Place all icons in the directory set as `iconsPath`. The path must end with a trailing `/`. Required names:

```
add                 alarm               apps
audio_adjust        backlight_high      backlight_low
backlight_off       bluetooth           bluetooth_connected
bluetooth_disabled  bluetooth_searching brightness
calendar_add        calendar_edit       calendar_event
calendar_month      calendar_today      check
close               copy_content        dark_mode
delete              download            ethernet
filter              filter_off          hide
history             home                light_mode
lock                masked              masked_add
media_input         media_output        microphone
microphone_alert    microphone_mute     music_add
music_album         music_artist        music_note
music_note_single   music_off           music_pause
music_play          music_prev          music_queue
music_resume        music_skip          notify
notify_unread       open_app            open_folder
pin                 refresh             restart
screenshot          search              settings
show                stop                sync
terminal            unpin               upload
volume_max          volume_med          volume_min
volume_mute         vpn                 wallpaper
wifi_max            wifi_med            wifi_min
wifi_off            wired
```

All icons are `.png`.

---

## 6. Python Utility (`utill.py`)

The shell depends heavily on `Scripts/utill.py`. Almost every background operation — from fetching active windows to setting brightness to picking wallpapers — calls this file via a subprocess. It is **not optional**.

The file is called by Quickshell like this:

```bash
python3 ~/.config/quickshell/Scripts/utill.py --functionname arg1 arg2
```

Most of these calls happen invisibly in the background. The following functions are in active use by the shell:

| Function | Purpose |
|---|---|
| `--getcurrentplaying` | Current media metadata via MPRIS (title, artist, album, art, source, status) |
| `--getactiveapplications` | Fetch running windows and their metadata |
| `--getappicons` | Fuzzy-match app class names to icon files |
| `--getdesktopapps` | Parse `.desktop` files for the Add App window |
| `--getnetworkinfo` | Network interface, type, VPN and speed |
| `--getaudiodevices` | List audio input/output devices via wpctl |
| `--getcommandhistory` | Read shell history (bash/zsh/fish), filtered |
| `--randomfile` | Pick random wallpaper(s) from a folder |
| `--smartcrop` | Saliency-crop wallpapers for vertical monitors |
| `--getmonitorres` | Get monitor resolutions with transform awareness |
| `--ddcdetect` | Detect DDC-capable displays |
| `--ddcgetbrightness` | Read current brightness from each display |
| `--ddcsetbrightness` | Set brightness on a specific display |
| `--btstate` | Bluetooth adapter state |
| `--btdevices` | List paired devices with battery and connection status |
| `--btscan` | Start/stop scanning for nearby devices |
| `--btscanresults` | List unpaired discovered devices |
| `--btconnect` | Connect to a device by MAC |
| `--btdisconnect` | Disconnect a device |
| `--btpair` | Pair and trust a new device |
| `--btforget` | Remove a paired device |
| `--btpower` | Toggle or set adapter power |
| `--addcolor` | Save a picked color to history in config.json |
| `--getcolors` | Read color history |
| `--clearcolors` | Clear color history |
| `--usbmountcheck` | Check if a USB device is mounted, mount if not |
| `--generatetheme` | Build a color theme from a set of seed colors |

**Python packages required** by this file:

- `rapidfuzz` — fuzzy icon matching
- `pillow` + `numpy` — smart crop saliency detection
- `colormath` — theme generation

If any package is missing the affected features will silently fail or return empty results.

---

## 7. Configuration

`config.json` does not exist by default — create it at `~/.config/quickshell/config.json`. Required keys are marked, all others are optional.

```json
{
    "wallpapers": {
        "displays":   ["DP-1", "HDMI-A-1"],        // required — connector names, left to right
        "day":        "/path/to/wallpapers/day/",   // required — trailing slash needed
        "night":      "/path/to/wallpapers/night/", // required — trailing slash needed
        "interval":   600000,                        // ms between wallpaper changes
        "primaryDisplayIndex": 0,                    // index into displays array — the wallpaper on this display is treated as the "current wallpaper" for theme generation and color sampling
        "randomWallpaperPerDisplay": true,           // different wallpaper per display
        "smartCrop":  false,                         // auto-crop for vertical monitors
        "cycling":    true,                          // set to false to disable wallpaper cycling entirely
        "autoTheme":  false,                         // generate theme colors from current wallpaper
        "darkModeHours": {
            "at":     21,                            // hour to switch to night (24h)
            "before": 6                              // hour to switch to day (24h)
        }
    },
    "commands": {
        "terminal":          "ghostty",              // required
        "terminal_run":      "ghostty -e bash -c",   // required — the command to run is appended as an arg
        "wallpaper_set":     "awww img -o {display} {wallpaper}", // required
        "screenshot":        "flameshot gui",
        "files":             "nautilus",
        "files_open":        "nautilus {path}",
        "colorpicker":       "hyprpicker",
        "editor":            "code",
        "config_main":       "code /home/USER/.config/",
        "config_hypr":       "code /home/USER/.config/hypr/",
        "config_quickshell": "code /home/USER/.config/quickshell/",
        "suspend":           "systemctl suspend",
        "reboot":            "systemctl reboot",
        "poweroff":          "systemctl poweroff",
        "logout":            "bash -c command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit",
        "restart_shell":     "/home/USER/.config/quickshell/Scripts/restart.sh",
        "hypr_reload":       "hyprctl reload"
    },
    "iconsPath":  "/path/to/icons/",                 // required — trailing slash needed
    "fontFamily": "JetBrainsMono",                   // required — must be installed on your system
    "theme": {
        "background": "#19090e",                     // required
        "surface":    "#2b1e22",                     // required
        "primary":    "#6b5d62",                     // required
        "secondary":  "#55474c",
        "text":       "#e7d9df"                      // required
    },
    "wallpaperMode":          0,    // 0=auto, 1=force day, 2=force night
    "volumePercentageOffset": 0,
    "colorHistory":           [],
    "launcherflags": {
        "maxOptions":    3,
        "filters":       {},   // class: [args to strip]
        "setOptions":    {},
        "lockOptions":   [],   // class names — never update options
        "ignoreOptions": []    // class names — never show options
    },
    "launchers": []
}
```

Replace `USER` with your username and all paths with your actual locations.

> **`{placeholder}` substitution** — any command containing `{placeholder}` has that token replaced at runtime before the command is executed:
> - `{display}` — replaced with the connector name e.g. `DP-1`
> - `{wallpaper}` — replaced with the full path to the wallpaper file
> - `{path}` — replaced with a file or folder path (used by `files_open`)
>
> You can use these in any command value. Custom placeholders are also supported — add `{anything}` to a command string and pass the value when calling `root.cmd("key", {"anything": "value"})` from QML.

> **Other commands used internally** — the following are called directly in QML without going through the `commands` map and cannot be overridden from config:
> - `hyprctl dispatch workspace {n}` — workspace switching
> - `hyprctl dispatch movetoworkspacesilent` — sending windows between workspaces
> - `hyprctl keyword` — toggling animations and blur
> - `wpctl set-volume` / `wpctl set-default` — audio control
> - `playerctl previous/play-pause/next` — media controls
> - `bluetoothctl` — all bluetooth operations (via `utill.py`)
> - `ddcutil` — all brightness operations (via `utill.py`)
> - `udisksctl mount` — USB mounting (via `utill.py`)
> - `notify-send` — desktop notifications
> - `kill {pid}` — force-closing apps
> - `rm -f` — cleaning up smart crop temp files

---

## 8. Theme

Theme colors are set manually in `config.json` under the `theme` key. If you want to generate a theme from seed colors, `utill.py` includes a `--generatetheme` function that builds a full theme from a set of hex colors:

```bash
python3 ~/.config/quickshell/Scripts/utill.py --generatetheme dark #19090e #6b5d62
```

Setting `"autoTheme": true` in `wallpapers` enables automatic theme generation — every time the wallpaper changes, colors are sampled from it and the theme is updated and saved to `config.json` automatically. Disable this if you want to keep a fixed theme.

---

## 9. Launchers & Options

Launchers are pinned apps in the app bar. Each launcher maps a window class name to a launch command. All launcher management — window matching, active state, instance tracking, options, masques — is handled entirely by `AppBarWidget`.

> **`name` is the app or package class name** — this is the class name the application registers with the window system (e.g. `code`, `brave-browser`, `org.gnome.Nautilus`). Without a `nickname`, `name` is also what gets displayed in the bar.

```json
"launchers": [
    {
        "name":     "code",
        "nickname": "VS Code",
        "icon":     "/usr/share/icons/Papirus/64x64/apps/code.svg",
        "command":  "/opt/visual-studio-code/code",
        "options":  [
            ["/home/user/project-a"],
            ["/home/user/project-b"],
            ["--new-window"]
        ]
    }
]
```

**Options** are like a Windows Jump List — right-clicking a pinned app shows a menu of launch variants. Each entry in `options` is a list of arguments appended to the launch command when that variant is chosen.

In the example above, right-clicking VS Code shows three entries:
- `code /home/user/project-a`
- `code /home/user/project-b`
- `code --new-window`

**Launcher fields:**

| Field | Required | Description |
|---|---|---|
| `name` | ✔ | App or package class name. `AppBarWidget` uses this to match running windows, track instances, and manage state. Doubles as display name if no `nickname` is set |
| `command` | ✔ | Launch command |
| `icon` | ✔ | Path to icon file |
| `nickname` | — | Display name shown in the bar. Defaults to `name` if omitted |
| `options` | — | List of argument sets for the right-click jump list |
| `masque` | — | Makes another app's windows appear under this pin — `{ "classIncludes": "Electron" }` or `{ "cmdIncludes": "some-process" }` |

**`launcherflags` controls per-launcher behaviour:**

| Flag | Description |
|---|---|
| `lockOptions` | Class names whose options are never auto-updated from running process args |
| `ignoreOptions` | Class names that never show or save options at all |
| `filters` | Args to strip when capturing options — e.g. `{ "org.gnome.Nautilus": ["--gapplication-service"] }` |
| `maxOptions` | Max number of options stored per launcher |

> **Finding the class name** — most native apps use their binary name (e.g. `code`, `ghostty`). Flatpak apps use their full app ID (e.g. `com.discordapp.Discord`). You can confirm it by running `hyprctl clients` while the app is open and checking the `class:` field, or by checking the app's `.desktop` file for `StartupWMClass`.

---

## 10. Pinning Apps

The easiest way to pin an app is to simply open it, then **right-click its icon in the app bar** and select **Pin**. The shell will capture the app's class name, command, and any launch arguments automatically.

> **This is not always accurate.** Some apps launch under a different class name than their executable, spawn child processes with different names, or use wrapper scripts. If a pinned app doesn't launch anything when clicked, or opens under the wrong icon, you may need to manually set the correct `command` in `config.json` or use the **Custom App** form in the Add App menu.

For full control, use the **Add App** button (apps icon, far right of the app bar) which gives you two options:
- **From Installed Apps** — picks from all `.desktop` files on your system
- **Custom App** — manually set the class name, command, icon, and options

---

## 11. Masquing

Masquing lets you make one app's windows appear under a different pinned app's icon. This is useful when an app spawns windows under a class name that doesn't match its launcher — for example a game launcher that opens the actual game under a completely different class, or an Electron app that reports a generic class name.

**How to set a masque:**
1. The app you want to masque **under** must already be pinned
2. Open the app you want to masque
3. Right-click its icon in the app bar
4. Select **Add as Masque...** and choose the pinned app to masque under

From that point on, any window matching that class name will appear under the chosen pin as if it were that app.

To remove a masque, right-click the pinned app and select **Manage Masques** — this lists all masques assigned to that pin and lets you remove them individually.

You can also set a masque upfront when adding a custom app via the **Custom App** form using the **Masque Under** field.

---

## 12. Timers & Reactivity

Most polling uses `Timer` components with fixed intervals. These control how quickly the UI reacts to changes — lower means faster updates but more subprocess calls. **If the default intervals feel too slow or too aggressive for your system, change them directly in the file listed.**

| Feature | Default | File | What it polls |
|---|---|---|---|
| Wallpaper switching | set via config (`interval` key in ms) | `shell.qml` | Cycles to the next wallpaper — controlled by `setWallpaperInterval()` |
| USB hotplug retry | 1500ms | `shell.qml` | Delay before retrying a USB mount check after a hotplug event |
| Active applications (initial) | 10ms | `Objects/Widgets/AppBarWidget.qml` | Fires immediately on startup to build the static app list, then slows down |
| Active applications (polling) | 650ms | `Objects/Widgets/AppBarWidget.qml` | Running windows, active state, instance counts |
| Media metadata | 1000ms | `Objects/Systems/MediaSystem.qml` | Currently playing track, artist, album, status — always polling |
| Media display refresh | 300ms | `Objects/Window/AudioManagementPopup.qml` | Updates the now-playing display in the audio popup (only while popup is open) |
| Notification popup auto-dismiss | 6000ms | `Objects/Window/NotificationPopup.qml` | Auto-closes toast after this time |
| Notifications badge | 500ms | `Objects/Widgets/NotificationsWidget.qml` | Unread count fallback |
| Workspace list | 2000ms | `Objects/Widgets/WorkspaceSwitcherWidget.qml` | All workspaces and window counts |
| Active workspace | 200ms | `Objects/Widgets/WorkspaceSwitcherWidget.qml` | Current workspace highlight |
| Network info | 1500ms | `Objects/Window/NetworkPopup.qml` | Interface, VPN, upload/download (only while popup is open) |
| Bluetooth device list | 3000ms | `Objects/Window/BluetoothPopup.qml` | Paired devices and connection state |
| Bluetooth scan timeout | 12000ms | `Objects/Window/BluetoothPopup.qml` | Stops scanning after this duration |
| USB drives in settings | 3000ms | `Objects/Window/SettingsManagementPopup.qml` | Mounted USB devices (only while popup is open) |
| Brightness debounce | 350ms | `Objects/Window/SettingsManagementPopup.qml` | Delay before sending DDC command after slider release |

---

## 13. First Run

On the first launch the icon cache does not exist yet. `AppBarWidget` will call `--getappicons` which walks your entire icon theme directory to build it — this is a one-time operation and may take a few seconds. Subsequent launches read from the cache and are fast.

The cache is stored at `~/.config/quickshell/.icon-cache`.

---

## 14. Run

```bash
quickshell
```

Add to `~/.config/hypr/hyprland.conf` to start automatically:
```
exec-once = awww-daemon
exec-once = quickshell
```

> `awww-daemon` must be listed **before** `quickshell` so the wallpaper daemon is ready when the shell starts.