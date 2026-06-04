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
        "lock":              "loginctl lock-session",
        "suspend":           "systemctl suspend",
        "reboot":            "systemctl reboot",
        "poweroff":          "systemctl poweroff",
        "logout":            "bash -c command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit",
        "restart_shell":     "/home/USER/.config/quickshell/Scripts/restart.sh",
        "hypr_reload":       "hyprctl reload"
    },
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
    "forceDarkMode":          false,
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