# Quickshell — Arch Linux / Hyprland

A Hyprland desktop shell built with Quickshell.

---

## Dependencies

```bash
sudo pacman -S quickshell hyprland hyprpicker awww \
    xdg-desktop-portal-hyprland \
    pipewire wireplumber alsa-utils playerctl \
    bluez bluez-utils bluez-plugins \
    ddcutil udisks2 networkmanager \
    libnotify nautilus ghostty flameshot \
    qt6-base qt6-declarative qt6-wayland \
    qt6-tools python
```

```bash
pip install rapidfuzz colormath pillow numpy --break-system-packages
```

Then open `~/.config/quickshell/Scripts/utill.py` and set your username at the top of the file:

```python
# ── USER CONFIGURATION ────────────────────────────
USERNAME = "youruser"   # change this to your Linux username
```

This controls where the script looks for your config, icon cache, and icon directories. Everything else derives from it automatically.

---

> **Install order matters:**
> 1. Install system packages via `pacman` first
> 2. Enable services before adding user to groups
> 3. Add user to groups and **log out/in** before running anything that needs them (DDC, bluetooth, USB)
> 4. Install Python packages after Python is installed
> 5. `awww` daemon must be running before Quickshell starts — add `exec-once = awww-daemon` to your Hyprland config
> 6. Reboot after adding `i2c-dev` to modules — `modprobe` is a temporary fix until reboot

---

## User Groups

```bash
sudo usermod -aG video storage i2c bluetooth $USER
```

Log out and back in after.

---

## Services

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

## Installation

```bash
git clone https://github.com/FacehuggersInc/quickshell.git ~/.config/quickshell
```

---

## Configuration

Create `~/.config/quickshell/config.json`. Required keys are marked, all others are optional.

```json
{
    "wallpapers": {
        "displays":   ["DP-1", "HDMI-A-1"],        // required — connector names left to right
        "day":        "/path/to/wallpapers/day/",   // required
        "night":      "/path/to/wallpapers/night/", // required
        "interval":   600000,                        // ms between wallpaper changes
        "primaryDisplayIndex": 0,                    // index into displays array
        "randomWallpaperPerDisplay": true,           // different wallpaper per display
        "smartCrop":  false,                         // auto-crop for vertical monitors
        "darkModeHours": {
            "at":     21,                            // hour to switch to night (24h)
            "before": 6                              // hour to switch to day (24h)
        }
    },
    "commands": {
        "terminal":          "ghostty",              // required
        "terminal_run":      "ghostty -e bash -c",   // required
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
```

> **`{placeholder}` substitution** — any command containing `{placeholder}` has that token replaced at runtime before the command is executed:
> - `{display}` — replaced with the connector name e.g. `DP-1`
> - `{wallpaper}` — replaced with the full path to the wallpaper file
> - `{path}` — replaced with a file or folder path (used by `files_open`)
>
> You can use these in any command value. Custom placeholders are also supported — add `{anything}` to a command string and pass the value when calling `root.cmd("key", {"anything": "value"})` from QML.

```json
    "iconsPath":  "/path/to/icons/",                 // required
    "fontFamily": "JetBrainsMono",                   // required
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

---

## Python Utility (`utill.py`)

The shell depends heavily on `Scripts/utill.py`. Almost every background operation — from fetching active windows to setting brightness to picking wallpapers — calls this file via a subprocess. It is **not optional**.

The file is called by Quickshell like this:

```bash
python3 ~/.config/quickshell/Scripts/utill.py --functionname arg1 arg2
```

Most of these calls happen invisibly in the background. The following functions are in active use by the shell:

| Function | Purpose |
|---|---|
| `--getcurrentplaying` | Current media metadata via MPRIS (title, artist, album, art, source, status) |
| `--getactiveapplications` | Fetch running windows and their metadata from Hyprland |
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

```bash
pip install rapidfuzz colormath pillow numpy --break-system-packages
```

Then open `~/.config/quickshell/Scripts/utill.py` and set your username at the top of the file:

```python
# ── USER CONFIGURATION ────────────────────────────
USERNAME = "youruser"   # change this to your Linux username
```

This controls where the script looks for your config, icon cache, and icon directories. Everything else derives from it automatically.

- `rapidfuzz` — fuzzy icon matching
- `pillow` + `numpy` — smart crop saliency detection
- `colormath` — theme generation

If any package is missing the affected features will silently fail or return empty results.

---

## Launchers & Options

Launchers are pinned apps in the app bar. Each launcher maps a window class name to a launch command.

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

**Optional launcher fields:**

| Field | Description |
|---|---|
| `nickname` | Display name shown in the bar instead of `name` |
| `options` | List of argument sets for the right-click jump list |
| `masque` | Makes another app's windows appear under this pin — `{ "classIncludes": "Electron" }` or `{ "cmdIncludes": "some-process" }` |

**`launcherflags` controls per-launcher behaviour:**

| Flag | Description |
|---|---|
| `lockOptions` | Class names whose options are never auto-updated from running process args |
| `ignoreOptions` | Class names that never show or save options at all |
| `filters` | Args to strip when capturing options — e.g. `{ "org.gnome.Nautilus": ["--gapplication-service"] }` |
| `maxOptions` | Max number of options stored per launcher |


---

## Icons

Place all icons in the directory set as `iconsPath`. Required names:

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

## Run

```bash
quickshell
```

Or add to `~/.config/hypr/hyprland.conf`:
```
exec-once = quickshell
```