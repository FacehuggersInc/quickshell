import os, sys, subprocess, time, random, re, json, glob, select, configparser
from pathlib import Path
from datetime import datetime
from urllib.parse import urlparse
from rapidfuzz import fuzz, process

from theme import build_theme

INVALID = [(" &", ",")]
PLAYERS = ["Youtube Music", "Spotify", 'Youtube']
ICON_ROOTS = ["/usr/share/icons", "/home/fach/.local/share/icons"]
VALID_EXTS = (".png", ".svg", ".xpm")


def post(txt: str):
    print(str(txt))
    sys.stdout.flush()


class Utill():

    def get_now(self):
        return datetime.now()

    def blank(self, *args):
        print(f"Whoops this '{args[0]}' function does not exist")

    def call(self, function: str, *args):
        func = getattr(
            self,
            function,
            lambda *xtra, f=function: self.blank(f, *xtra)
        )
        if func.__callable:
            return func(*args)
        else:
            return "NO"

    def argfunc(func):
        def wrapper(*args, **kwargs):
            return func(*args, **kwargs)
        wrapper.__callable = True
        return wrapper

    # ── DATE / TIME ──────────────────────────────────────────────────────────

    @argfunc
    def format(self, format_txt: str, *args):
        return self.get_now().strftime(format_txt)

    # ── AUDIO ────────────────────────────────────────────────────────────────

    @argfunc
    def togglemic(self, *args):
        result = subprocess.run(['amixer', "set", "Capture", "toggle"], capture_output=True, text=True)
        mic_mute = "off"
        found_block = False
        for line in result.stdout.split('\n'):
            if "Capture" in line: found_block = True
            if found_block and '%' in line:
                mic_mute = line.split('[')[-1].split("]")[0].strip()
                break
        return mic_mute

    @argfunc
    def togglevol(self, *args):
        result = subprocess.run(['amixer', "set", "Master", "toggle"], capture_output=True, text=True)
        vol_mute = "off"
        found_block = False
        for line in result.stdout.split('\n'):
            if "Master" in line: found_block = True
            if found_block and '%' in line:
                vol_mute = line.split('[')[-1].split("]")[0].strip()
                break
        return vol_mute

    @argfunc
    def getaudio(self, *args):
        result = subprocess.run(['amixer'], capture_output=True, text=True)
        lines = result.stdout.split('\n')
        found_vol = found_mic = False
        found_vol_block = found_mic_block = False
        volume = volume_mute = mic_volume = mic_mute = ""
        for line in lines:
            if "Master" in line: found_vol_block = True
            if found_vol_block and '%' in line and not found_vol:
                volume = line.split('[', 1)[-1].split("]")[0].strip()
                volume_mute = line.split('[')[-1].split("]")[0].strip()
                found_vol = True
            if "Capture" in line: found_mic_block = True
            if found_mic_block and '%' in line and not found_mic:
                mic_mute = line.split('[')[-1].split("]")[0].strip()
                mic_volume = line.split('[', 1)[-1].split("]")[0].strip()
                found_mic = True
        return volume, volume_mute, mic_volume, mic_mute

    @argfunc
    def getaudiodevices(self, *args):
        result = subprocess.run(['wpctl', 'status'], capture_output=True, text=True)
        BAR = "│"
        in_audio = in_capture = False
        devices = ''
        dev_type = None

        def get_data(raw):
            raw = raw.replace(BAR, "").strip()
            if not raw: return None
            default = raw.startswith("*")
            parts = (raw[1:].strip() if default else raw).split(".", 1)
            if len(parts) < 2: return None
            return [parts[0].strip(), default, parts[1].split("[", 1)[0].strip()]

        for line in result.stdout.split("\n"):
            if "Audio" == line.strip(): in_audio = True; continue
            if in_audio:
                if "Sinks:" in line:   dev_type = "output"; in_capture = True; continue
                if "Sources:" in line: dev_type = "input";  in_capture = True; continue
                if in_capture:
                    data = get_data(line)
                    if data:
                        data.insert(1, dev_type)
                        devices += ','.join([str(v) for v in data]) + "|"
                    else:
                        in_capture = False

        return devices.rstrip("|")

    @argfunc
    def setaudiodevice(self, *args):
        return subprocess.run(['wpctl', 'set-default', args[0]], capture_output=True, text=True).stdout.strip()

    # ── NETWORK ──────────────────────────────────────────────────────────────

    @argfunc
    def getinterface(self, *args):
        match args[0]:
            case "ssid": return "Unknown",
            case "wired" | "interface":
                result = subprocess.run(['nmcli'], capture_output=True, text=True)
                connections = []
                for line in result.stdout.split('\n'):
                    if len(line.split(":")) <= 2 and "connected" in line:
                        if any(inv in line for inv in ["unavailable", "configuration"]): continue
                        connections.append((line.split(":")[0], "wired" if "Wired" in line else "external"))
                externals = [c for c in connections if c[1] == "external"]
                return externals[-1] if len(externals) > 1 else connections[0] if connections else ("unknown", "wired")

    # ── FILESYSTEM UTILS ─────────────────────────────────────────────────────

    @argfunc
    def run(self, *args):
        return subprocess.run(list(args), capture_output=True, text=True).stdout

    @argfunc
    def findin(self, *args):
        func = args[0]
        lines, targets = [], []
        if func == "cmd":
            command, args = [], args[1:]
            for i, arg in enumerate(args):
                if arg == "/": targets = args[i+1:]; break
                command.append(arg)
            lines = subprocess.run(command, capture_output=True, text=True).stdout.split("\n")
        elif func == "file":
            targets = args[2:]
            with open(Path(args[1]), "r") as f: lines = f.readlines()
        for line in lines:
            if all(t in line for t in targets): return line

    @argfunc
    def replacein(self, *args):
        path = Path(args[0])
        data = ' '.join(args[1:]).split(" / ")
        filters, replacement = data[0].split(","), data[1]
        with open(path, "r") as f: lines = f.readlines()
        for i, line in enumerate(lines):
            if all(flt in line for flt in filters) and replacement != line:
                lines[i] = replacement
        with open(path, "w") as f:
            for line in lines: f.write(f"{line.strip()}\n")
        return ""

    @argfunc
    def randomfile(self, *args):
        files = list(Path(args[0]).iterdir())
        count = 1 if len(args) == 1 else int(args[1])
        choices = []
        while len(choices) < count:
            c = str(random.choice(files))
            if c not in choices: choices.append(c)
        return choices

    # ── MEDIA / MPRIS ────────────────────────────────────────────────────────

    def get_app_name(self, service):
        return service.replace("org.mpris.MediaPlayer2.", "").split(".instance")[0]

    def get_identity(self, service):
        try:
            return subprocess.check_output(
                ["qdbus", service, "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Identity"],
                text=True
            ).strip()
        except subprocess.CalledProcessError:
            return ""

    def get_site_name(self, url):
        try: return urlparse(url).netloc.replace("www.", "")
        except: return ""

    @argfunc
    def getcurrentplaying(self, *args):
        try:
            services = [l.strip() for l in subprocess.check_output(["qdbus"], text=True).splitlines()
                        if "org.mpris.MediaPlayer2" in l]
        except subprocess.CalledProcessError:
            return "  ?    ?    ?    ?    ?    ?    ?  Nothing"

        for service in services:
            try:
                status = subprocess.check_output(
                    ["qdbus", service, "/org/mpris/MediaPlayer2",
                     "org.mpris.MediaPlayer2.Player.PlaybackStatus"], text=True
                ).strip()
                if status not in ["Playing", "Paused"]: continue

                metadata = subprocess.check_output(
                    ["qdbus", service, "/org/mpris/MediaPlayer2",
                     "org.mpris.MediaPlayer2.Player.Metadata"], text=True
                )
                data = {"title": "", "artist": "", "album": "", "length": "", "art": "", "url": ""}
                for line in metadata.splitlines():
                    line = line.strip()
                    if "xesam:title" in line:   data["title"]  = line.split(":", 2)[-1].strip()
                    elif "xesam:artist" in line: data["artist"] = line.split(":")[-1].strip()
                    elif "xesam:album" in line:  data["album"]  = line.split(":")[-1].strip()
                    elif "mpris:length" in line: data["length"] = line.split(":")[-1].strip()
                    elif "mpris:artUrl" in line: data["art"]    = line.split(":")[-1].strip()
                    elif "xesam:url" in line or "mpris:url" in line:
                        data["url"] = line.split("url:", 1)[-1].strip()

                app  = self.get_identity(service) or self.get_app_name(service)
                site = self.get_site_name(data.get("url", ""))
                app_display = site if site else (f"Browser ({app})" if app.lower() in ["chromium", "brave", "firefox"] else app)
                return f"{data['title']}  ?  {data['artist']}  ?  {data['album']}  ?  {data['length']}  ?  {data['art']}  ?  {data['url']}  ?  {app_display}  ?  {status}"
            except subprocess.CalledProcessError:
                continue

        return "  ?    ?    ?    ?    ?    ?    ?  Nothing"

    @argfunc
    def getcurrentplayingstatus(self, *args):
        try:
            services = [l.strip() for l in subprocess.check_output(["qdbus"], text=True).splitlines()
                        if "org.mpris.MediaPlayer2" in l]
        except subprocess.CalledProcessError:
            return "Nothing"
        for service in services:
            try:
                status = subprocess.check_output(
                    ["qdbus", service, "/org/mpris/MediaPlayer2",
                     "org.mpris.MediaPlayer2.Player.PlaybackStatus"], text=True
                ).strip()
                if status in ["Playing", "Paused", "Stopped"]: return status
            except subprocess.CalledProcessError:
                continue
        return "Nothing"

    # ── THEME ────────────────────────────────────────────────────────────────

    @argfunc
    def generatetheme(self, *args):
        return build_theme(args[1:], args[0])

    # ── HYPRLAND / WINDOWS ───────────────────────────────────────────────────

    @argfunc
    def gethyprwindows(self, *args):
        result = subprocess.run(['hyprctl', 'clients', '-j'], stdout=subprocess.PIPE, text=True)
        return json.loads(result.stdout.strip())

    @argfunc
    def getactiveapplications(self, *args):
        processes = subprocess.run(['ps', '-eo', 'pid,args'],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        windows = self.gethyprwindows()
        proc_map = {}
        if processes.returncode == 0:
            for line in processes.stdout.splitlines()[1:]:
                parts = line.strip().split(None, 1)
                if len(parts) == 2: proc_map[parts[0]] = parts[1]

        final = []
        for win in windows:
            pid = str(win.get('pid'))
            if not pid: continue
            win['command'] = proc_map.get(pid, "")
            final.append((pid, win))

        classes = [p[1]['class'] for p in final]
        icons   = self.getappicons(*classes).split(",")

        return_str = ""
        for pid, proc in final:
            match = [i for i in icons if proc['class'] in i]
            if not match: continue
            clazz, icon = match[0].split(":", 1)
            return_str += f"{proc['pid']},{proc['class']},{icon},{proc['command']},{proc['workspace']['name']},{proc['title']}|"

        return return_str.rstrip("|").strip()

    @argfunc
    def closehyprwindow(self, *args):
        full_arg_str = ' '.join(args)
        clients = json.loads(subprocess.run(['hyprctl', 'clients', '-j'],
                                            capture_output=True, text=True).stdout)
        results = ""
        for i, target_title in enumerate(full_arg_str.split(",")):
            target_title = target_title.strip()
            if not target_title: continue
            found = False
            for client in clients:
                matches = process.extract(client['title'], [target_title], scorer=fuzz.WRatio, limit=20)
                for n, score, _ in matches:
                    if score >= 92:
                        subprocess.run(['hyprctl', 'dispatch', 'closewindow', f"address:{client['address']}"])
                        results += f"{i}:ok|"
                        found = True
            if not found: results += f"{i}:no|"
        return results.rstrip("|")

    # ── ICON LOOKUP ──────────────────────────────────────────────────────────

    def extract_size(self, path):
        match = re.search(r"/(\d+)x\d+/", path)
        if match: return int(match.group(1))
        return 9999 if "scalable" in path else 0

    def build_icon_index(self):
        index = []
        for ROOT in ICON_ROOTS:
            for root, _, files in os.walk(ROOT):
                for file in files:
                    if not file.endswith(VALID_EXTS): continue
                    name = os.path.splitext(file)[0].lower()
                    index.append((name, os.path.join(root, file), self.extract_size(os.path.join(root, file))))
        return index

    @argfunc
    def getappicons(self, *args):
        # Optional first arg: "--clearcache" removes cached entries for
        # the requested class names so they get re-looked up fresh.
        # Useful when a newly pinned app returned a wrong or missing icon.
        args = list(args)
        clear_cache = False
        if args and args[0] == "--clearcache":
            clear_cache = True
            args = args[1:]

        classnames = args
        results    = []
        cache      = {"apps": {}, "index": []}
        save_cache = False
        cachepath  = Path("/home/fach/.config/quickshell/.icon-cache")

        if cachepath.exists():
            with open(cachepath, "r") as f: cache = json.load(f)

            # Remove requested classes from cache so they get re-resolved
            if clear_cache:
                for cls in classnames:
                    if cls in cache['apps']:
                        del cache['apps'][cls]
                        save_cache = True

            for key in list(cache['apps'].keys()):
                if key in classnames:
                    classnames.remove(key)
                    results.append(f"{key}:{cache['apps'][key]}")
        else:
            save_cache = True
            cache['index'] = self.build_icon_index()

        # Rebuild index if empty (e.g. cache existed but index was cleared)
        if not cache['index']:
            cache['index'] = self.build_icon_index()
            save_cache = True

        names = [e[0] for e in cache['index']]
        for cls in classnames:
            matches    = process.extract(cls.lower(), names, scorer=fuzz.WRatio, limit=20)
            candidates = [cache['index'][idx] for _, score, idx in matches if score >= 70]
            if not candidates: continue
            best = next((c for c in candidates if c[2] >= 90), None) or max(candidates, key=lambda x: x[2])
            cache['apps'][cls] = best[1]
            save_cache = True
            results.append(f"{cls}:{best[1]}")

        if save_cache:
            with open(cachepath, "w") as f: json.dump(cache, f, indent=4)
        return ",".join(results)

    # ── DESKTOP APP PARSER ───────────────────────────────────────────────────

    @argfunc
    def getdesktopapps(self, *args):
        """Parse .desktop files. Returns newline-separated: name|exec|icon|className|comment"""
        search_paths = [
            "/usr/share/applications/*.desktop",
            "/usr/local/share/applications/*.desktop",
            os.path.expanduser("~/.local/share/applications/*.desktop"),
        ]
        results, seen = [], set()

        for pattern in search_paths:
            for path in sorted(glob.glob(pattern)):
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        raw = f.read()
                    config = configparser.RawConfigParser()
                    config.read_string(raw)
                    if not config.has_section("Desktop Entry"): continue
                    entry = config["Desktop Entry"]
                    if entry.get("NoDisplay", "false").lower() == "true": continue
                    if entry.get("Hidden",    "false").lower() == "true": continue
                    if entry.get("Terminal",  "false").lower() == "true": continue
                    name = entry.get("Name", "").strip()
                    if not name or name in seen: continue
                    seen.add(name)
                    exec_raw   = entry.get("Exec", "").strip()
                    exec_clean = re.sub(r'%[fFuUdDnNickvm]', '', exec_raw).strip()
                    exec_clean = re.sub(r'^env\s+\S+=\S+\s+', '', exec_clean).strip()
                    icon       = entry.get("Icon",       "").strip()
                    comment    = entry.get("Comment",    "").strip().replace("|", "-").replace("\n", " ")
                    binary     = exec_clean.split()[0] if exec_clean.split() else ""
                    class_name = os.path.basename(binary).lower() if binary else name.lower()
                    results.append(f"{name}|{exec_clean}|{icon}|{class_name}|{comment}")
                except Exception:
                    continue

        results.sort(key=lambda x: x.split("|")[0].lower())
        return "\n".join(results) if results else "none"

    # ── BLUETOOTH ────────────────────────────────────────────────────────────

    @argfunc
    def btpower(self, *args):
        action = args[0] if args else 'toggle'
        if action == 'toggle':
            result  = subprocess.run(['bluetoothctl', 'show'], capture_output=True, text=True)
            action  = 'off' if 'Powered: yes' in result.stdout else 'on'
        subprocess.run(['bluetoothctl', 'power', action], capture_output=True)
        return action

    @argfunc
    def btstate(self, *args):
        result = subprocess.run(['bluetoothctl', 'show'], capture_output=True, text=True)
        powered      = 'yes' if 'Powered: yes'     in result.stdout else 'no'
        scanning     = 'yes' if 'Discovering: yes'  in result.stdout else 'no'
        discoverable = 'yes' if 'Discoverable: yes' in result.stdout else 'no'
        name = ''
        for line in result.stdout.splitlines():
            if 'Name:' in line: name = line.split('Name:', 1)[1].strip(); break
        return f"powered:{powered},scanning:{scanning},discoverable:{discoverable},name:{name}"

    @argfunc
    def btdevices(self, *args):
        paired_out    = subprocess.run(['bluetoothctl', 'devices', 'Paired'],    capture_output=True, text=True).stdout.strip()
        connected_out = subprocess.run(['bluetoothctl', 'devices', 'Connected'], capture_output=True, text=True).stdout.strip()
        connected_macs = {l.strip().split(' ', 2)[1] for l in connected_out.splitlines() if len(l.strip().split(' ', 2)) >= 2}
        devices = []
        for line in paired_out.splitlines():
            parts = line.strip().split(' ', 2)
            if len(parts) < 3: continue
            mac, name = parts[1], parts[2]
            info = subprocess.run(['bluetoothctl', 'info', mac], capture_output=True, text=True).stdout
            battery = alias = icon = ''
            alias = name
            for l in info.splitlines():
                l = l.strip()
                if l.startswith('Battery Percentage:'):
                    try: battery = l.split('(')[1].split(')')[0].strip()
                    except: pass
                elif l.startswith('Icon:'):   icon  = l.split(':', 1)[1].strip()
                elif l.startswith('Alias:'):  alias = l.split(':', 1)[1].strip()
            devices.append(f"{mac}|{name}|{alias}|{'yes' if mac in connected_macs else 'no'}|{battery}|{icon}")
        return '\n'.join(devices) if devices else 'none'

    @argfunc
    def btscan(self, *args):
        action = args[0] if args else 'on'
        if action == 'on':
            subprocess.Popen(['bluetoothctl', '--timeout', '10', 'scan', 'on'],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return 'scanning'
        subprocess.run(['bluetoothctl', 'scan', 'off'], capture_output=True)
        return 'stopped'

    @argfunc
    def btscanresults(self, *args):
        all_devs   = subprocess.run(['bluetoothctl', 'devices'],        capture_output=True, text=True).stdout.strip()
        paired_out = subprocess.run(['bluetoothctl', 'devices', 'Paired'], capture_output=True, text=True).stdout.strip()
        paired_macs = {l.strip().split(' ', 2)[1] for l in paired_out.splitlines() if len(l.strip().split(' ', 2)) >= 2}
        results = []
        for line in all_devs.splitlines():
            parts = line.strip().split(' ', 2)
            if len(parts) < 3: continue
            if parts[1] not in paired_macs:
                results.append(f"{parts[1]}|{parts[2]}")
        return '\n'.join(results) if results else 'none'

    @argfunc
    def btconnect(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        result  = subprocess.run(['bluetoothctl', 'connect', mac], capture_output=True, text=True, timeout=15)
        success = 'Connection successful' in result.stdout or 'Connected: yes' in result.stdout
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth',
                        f'Connected to {name}' if success else f'Failed to connect to {name}'])
        return 'ok' if success else 'fail'

    @argfunc
    def btdisconnect(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        subprocess.run(['bluetoothctl', 'disconnect', mac], capture_output=True)
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth', f'Disconnected {name}'])
        return 'ok'

    @argfunc
    def btforget(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        subprocess.run(['bluetoothctl', 'remove', mac], capture_output=True)
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth', f'Forgot {name}'])
        return 'ok'

    @argfunc
    def btpair(self, *args):
        mac, name = args[0], (args[1] if len(args) > 1 else args[0])
        subprocess.run(['bluetoothctl', 'trust', mac], capture_output=True)
        result  = subprocess.run(['bluetoothctl', 'pair', mac], capture_output=True, text=True, timeout=30)
        success = 'Pairing successful' in result.stdout or 'Failed' not in result.stdout
        if success: subprocess.run(['bluetoothctl', 'connect', mac], capture_output=True)
        subprocess.run(['notify-send', '-i', 'bluetooth', 'Bluetooth',
                        f'Paired with {name}' if success else f'Failed to pair with {name}'])
        return 'ok' if success else 'fail'

    # ── DDC / DISPLAY BRIGHTNESS ─────────────────────────────────────────────

    @argfunc
    def ddcdetect(self, *args):
        result = subprocess.run(["ddcutil", "detect"], capture_output=True, text=True, timeout=10)
        displays, current_num, current_name = [], None, None
        for line in result.stdout.splitlines():
            ls = line.strip()
            if ls.startswith("Display "):
                if current_num is not None and current_name is not None:
                    displays.append(f"{current_num}:{current_name}")
                try:    current_num  = int(ls.split()[1])
                except: current_num  = None
                current_name = None
            elif ls.startswith("Model:") and current_num is not None:
                current_name = ls.split(":", 1)[1].strip()
        if current_num is not None and current_name is not None:
            displays.append(f"{current_num}:{current_name}")
        return "|".join(displays) if displays else "none"

    @argfunc
    def ddcgetbrightness(self, *args):
        detect   = subprocess.run(["ddcutil", "detect", "--brief"], capture_output=True, text=True, timeout=10)
        displays = [l.strip().split()[1] for l in detect.stdout.splitlines()
                    if l.strip().startswith("Display ")]
        results  = []
        for d in displays:
            try:
                out  = subprocess.run(["ddcutil", "--display", d, "getvcp", "10"],
                                       capture_output=True, text=True, timeout=5).stdout.strip()
                cur  = next((int(p.split("=")[-1].strip()) for p in out.split(",") if "current value" in p), 0)
                mx   = next((int(p.split("=")[-1].strip()) for p in out.split(",") if "max value"     in p), 100)
                results.append(f"{d}:{cur}:{mx}")
            except Exception:
                results.append(f"{d}:0:100")
        return "|".join(results)

    @argfunc
    def ddcsetbrightness(self, *args):
        if len(args) < 2: return "fail"
        display, value = str(args[0]), max(0, min(100, int(float(args[1]))))
        try:
            subprocess.run(["ddcutil", "--display", display, "setvcp", "10", str(value)],
                           capture_output=True, timeout=5)
            return "ok"
        except Exception:
            return "fail"

    # ── USB ──────────────────────────────────────────────────────────────────

    @argfunc
    def usbmountcheck(self, *args):
        """Check if device is mounted; mount via udisksctl if not.
        Returns: mountpoint|label  or  none
        """
        if not args: return "none"
        devName = args[0].strip()
        devPath = "/dev/" + devName

        def get_mountpoint(dev):
            result = subprocess.run(["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT", dev],
                                    capture_output=True, text=True)
            try:
                data = json.loads(result.stdout.strip())
                for d in data.get("blockdevices", []):
                    for c in [d] + d.get("children", []):
                        mp = c.get("mountpoint") or ""
                        lb = c.get("label") or devName
                        if mp.startswith("/"): return mp, lb
            except Exception: pass
            return "", devName

        mp, lb = get_mountpoint(devPath)
        if mp: return f"{mp}|{lb}"

        mount = subprocess.run(["udisksctl", "mount", "-b", devPath, "--no-user-interaction"],
                               capture_output=True, text=True, timeout=10)
        if "Mounted" in mount.stdout or mount.returncode == 0:
            mp, lb = get_mountpoint(devPath)
            if mp: return f"{mp}|{lb}"
            for line in mount.stdout.splitlines():
                if " at " in line:
                    mp = line.split(" at ", 1)[-1].strip().rstrip(".")
                    if mp.startswith("/"): return f"{mp}|{devName}"
        return "none"

    # ── MISC ─────────────────────────────────────────────────────────────────

    @argfunc
    def getinterface(self, *args):
        match args[0]:
            case "ssid": return "Unknown",
            case "wired" | "interface":
                result = subprocess.run(['nmcli'], capture_output=True, text=True)
                connections = []
                for line in result.stdout.split('\n'):
                    if len(line.split(":")) <= 2 and "connected" in line:
                        if any(inv in line for inv in ["unavailable", "configuration"]): continue
                        connections.append((line.split(":")[0], "wired" if "Wired" in line else "external"))
                externals = [c for c in connections if c[1] == "external"]
                return externals[-1] if len(externals) > 1 else (connections[0] if connections else ("unknown", "wired"))

    @argfunc
    def generatetheme(self, *args):
        return build_theme(args[1:], args[0])


if __name__ == "__main__":
    args = sys.argv[1:]
    cmd  = args[0]
    if cmd:
        raw = False
        newline = None
        if cmd.startswith("--"):
            cmd = cmd.replace("--", "").strip()
            if cmd.endswith(':raw'):
                cmd = cmd[0:-4]
                raw = True
            elif cmd.endswith(":newline"):
                cmd        = cmd[0:-8]
                newline    = True, args[1]
                args       = args[1:]
            result = Utill().call(cmd, *args[1:])
            if result:
                if not raw and newline is None:
                    if isinstance(result, (list, tuple)):
                        post(','.join([str(v) for v in result]))
                    elif isinstance(result, dict):
                        post(','.join([f"{k}:{v}" for k, v in result.items()]))
                    else:
                        post(result)
                elif raw:
                    post(result)
                elif newline:
                    post(result.replace(newline[1], "\n"))
        else:
            post(f"Error: lacking --cmd <args>")