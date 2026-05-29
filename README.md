# Quickshell Setup — Arch Linux / Hyprland

Everything required to run this Quickshell configuration.

---

## System Dependencies

### Core Shell
```bash
sudo pacman -S quickshell qt6-base qt6-declarative qt6-wayland
```

### Hyprland & Wayland
```bash
sudo pacman -S hyprland xdg-desktop-portal-hyprland
```

### Wallpaper — swww
```bash
sudo pacman -S swww
```
Start the daemon before Quickshell launches:
```bash
swww-daemon &
```
Your `config.json` `setWallpaperCommand` should look something like:
```
swww img {wallpaper} --outputs {display} --transition-type fade
```

### Notifications
```bash
sudo pacman -S libnotify
```

### Audio
```bash
sudo pacman -S pipewire wireplumber
sudo pacman -S alsa-utils        # provides amixer for volume control
sudo pacman -S playerctl         # media play/pause/skip controls
```

### Bluetooth
```bash
sudo pacman -S bluez bluez-utils bluez-plugins
sudo systemctl enable --now bluetooth
```
Enable battery level reporting — add to `/etc/bluetooth/main.conf` under `[General]`:
```ini
Experimental=true
```
Then restart:
```bash
sudo systemctl restart bluetooth
```

### Display Brightness (DDC/CI over I2C)
```bash
sudo pacman -S ddcutil
sudo usermod -aG i2c $USER
```
Create `/etc/modules-load.d/i2c.conf` with:
```
i2c-dev
```
Then reboot or run:
```bash
sudo modprobe i2c-dev
```
Verify your monitors are detected:
```bash
ddcutil detect
```

### USB Automounting
```bash
sudo pacman -S udisks2
sudo systemctl enable --now udisks2
```

### Network
```bash
sudo pacman -S networkmanager
sudo systemctl enable --now NetworkManager
```

### File Manager
```bash
sudo pacman -S nautilus
```

### Terminal
```bash
sudo pacman -S ghostty
```

### Screenshot
```bash
sudo pacman -S flameshot
```

### Color Picker
```bash
sudo pacman -S hyprpicker
```

### Media / MPRIS
```bash
sudo pacman -S qt6-tools   # provides qdbus for MPRIS metadata
```

### VS Code (for opening configs from the settings panel)
```bash
sudo pacman -S code
# or from AUR if you want the proprietary version:
# yay -S visual-studio-code-bin
```

---

## Python & Script Dependencies

```bash
sudo pacman -S python
pip install rapidfuzz colormath --break-system-packages
```

The `utill.py` script lives at:
```
~/.config/quickshell/Scripts/utill.py
```

---

## User Groups

Your user needs to be in these groups. Run this once then **log out and back in**:
```bash
sudo usermod -aG video storage i2c bluetooth $USER
```

Verify:
```bash
groups $USER
```
You should see `video`, `storage`, `i2c`, and `bluetooth` in the output.

---

## Post-Install Verification

Run these after a fresh login to confirm everything is working:

```bash
bluetoothctl --version     # Bluetooth
ddcutil detect             # Display brightness
playerctl --version        # Media controls
amixer info                # Audio
udisksctl status           # USB automounting
udevadm --version          # USB hotplug (part of systemd, always present)
swww --version             # Wallpaper daemon
hyprpicker --version       # Color picker
flameshot --version        # Screenshot
ghostty --version          # Terminal
```

---

## Quick Reference — Settings Panel Features

| Feature | Command Used |
|---|---|
| Wallpaper | `swww img` |
| Lock screen | `loginctl lock-session` |
| Suspend | `systemctl suspend` |
| Reboot | `systemctl reboot` |
| Shutdown | `systemctl poweroff` |
| Hyprland reload | `hyprctl reload` |
| Color picker | `hyprpicker -a` |
| Screenshot | `flameshot gui` |
| File manager | `nautilus` |
| Terminal | `ghostty` |
| Brightness | `ddcutil setvcp 10 <value>` |
| Bluetooth | `bluetoothctl` |
| Audio | `wpctl` + `amixer` |
| USB mount | `udisksctl mount` |