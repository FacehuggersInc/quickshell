//@ pragma UseQApplication
//@ pragma IconTheme material-symbols

import QtQuick
import Quickshell
import Quickshell.Io

import Quickshell.Services.Notifications

import qs.Objects.Window
import qs.Objects.Systems

ShellRoot {
    // INIT
    id: root

    FileView {
        id: configFile
        preload: true
        blockLoading: true
        path: Qt.resolvedUrl("./config.json")
        watchChanges: true
        onFileChanged: this.reload()
        onAdapterUpdated: this.writeAdapter()
    }
    property var settings: JSON.parse(configFile.text()) 
    property var utill: ["python3", "/home/fach/.config/quickshell/Scripts/utill.py"]
    property bool initialDarkHourCheck: false
    property var monitorResolutions: ({})  // name -> {w, h}

    // Fetch monitor resolutions once on startup
    Process {
        id: monitorResProc
        command: root.newUtill(["--getmonitorres"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (!text) return
                var res = {}
                text.split("|").forEach(function(entry) {
                    var parts = entry.split(":")
                    if (parts.length >= 3) {
                        res[parts[0]] = { w: parseInt(parts[1]), h: parseInt(parts[2]) }
                    }
                })
                root.monitorResolutions = res
            }
        }
    }
    // wallpaperMode: 0=auto (follow dark hours), 1=force day, 2=force night
    property int wallpaperMode: root.settings.wallpaperMode || 0


    // FUNCTIONS
    function notify(title, body, icon){
        if (icon){
            notifyServer.iconName = icon
        } else {
            notifyServer.iconName = "notify"
        }
        
        root.execute(["notify-send", title, body])
    }

    function saveSettings(){
        configFile.setText( JSON.stringify( settings, null, 4 ) )
    }

    // cmd() — look up a command by key and split into args array
    // Supports {placeholder} substitution: root.cmd("files_open", {path: "/foo"})
    function cmd(key, replacements) {
        var command = settings.commands[key]
        if (!command) {
            console.log("cmd: unknown key '" + key + "'")
            return []
        }
        if (replacements) {
            for (var k in replacements) {
                command = command.replace("{" + k + "}", replacements[k])
            }
        }
        return command.split(" ")
    }

    // cmdExec() — look up and immediately execute
    function cmdExec(key, replacements) {
        var args = root.cmd(key, replacements)
        if (args.length > 0) execute(args)
    }

    function copy(text){
        Quickshell.clipboardText = text
    }

    function execute(args){
        var commandArgs = args
        // Only split if a single string was passed (legacy convenience)
        // Never split if multiple args given — paths can contain spaces
        if (commandArgs.length === 1 && typeof commandArgs[0] === "string") {
            if (!commandArgs[0].startsWith("/") && commandArgs[0].includes(" ")){
                commandArgs = args[0].split(" ")
            }
        }
        console.log("Executing -> " + commandArgs)
        Quickshell.execDetached({ command: commandArgs })
    }

    function copyArray(array){
        var newArray = [];
        for (var i = 0; i < array.length; i++){
            newArray.push(array[i]);
        }
        return newArray;
    }

    function combine(listA, listB){
        var newList = copyArray(listA);
        for (var i = 0; i < listB.length; i++){
            newList.push(listB[i]);
        }
        return newList;
    }

    function newUtill(args){
        return combine(root.utill, args);
    }

    function iconSource(name){
        return settings.iconsPath + name + ".png"
    }

    function setWallpaperInterval(ms) {
        root.settings.wallpapers.interval = ms
        wallpaperSwitchTimer.interval = ms
        root.saveSettings()
    }

    function nextWallpaper(){
        wallpaperSwitchTimer.restart()
        checkDarkHour()
    }

    function checkDarkHour(){ 
        if (!initialDarkHourCheck) {
            wallpaperSwitchTimer.interval = settings.wallpapers.interval
            initialDarkHourCheck = true 
        }

        // wallpaperMode overrides the hour check
        if (root.wallpaperMode === 1) {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.day
            wallpaperRandomChoice.running = true
            return
        }
        if (root.wallpaperMode === 2) {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.night
            wallpaperRandomChoice.running = true
            return
        }

        var hour = new Date().getHours()
        if (hour >= settings.wallpapers.darkModeHours.at || hour < settings.wallpapers.darkModeHours.before){
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.night
        } else {
            wallpaperRandomChoice.wallpaperFolder = settings.wallpapers.day
        }
        wallpaperRandomChoice.running = true
    }

    function wallColors(){
        return wallpaperColors.colors
    }

    function wallColorsLen(){
        return wallpaperColors.colors.length
    }


    // GLOBAL OBJECTS

    // -- NOTIFICATIONS
    property NotificationServer notifyServer: NotificationServer {
        id: notifyServer
        keepOnReload: true 
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        property string iconName: "notify"
    }

    // -- USB HOTPLUG WATCHER
    property string usbLastMountpoint: ""
    property string usbLastLabel: ""

    // Python handles the full check: finds mountpoint, label, sends notification
    // Returns: "mountpoint|label" on success, "none" if not mounted yet
    Process {
        id: usbMountCheckProc
        property string pendingDevice: ""
        property int retryCount: 0

        function checkDevice(devName) {
            pendingDevice = devName
            retryCount    = 0
            command = root.newUtill(["--usbmountcheck", devName])
            running = true
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim()
                console.log("USB mount check result: " + result)

                if (result === "none" || result === "") {
                    // Not mounted yet — retry up to 3 times
                    if (usbMountCheckProc.retryCount < 3) {
                        usbMountCheckProc.retryCount++
                        usbRetryTimer.restart()
                    }
                    return
                }

                var parts = result.split("|")
                var mountpoint = parts[0]
                var label      = parts.length > 1 ? parts[1] : "USB Drive"

                root.usbLastMountpoint = mountpoint
                root.usbLastLabel      = label

                root.execute([
                    "notify-send",
                    "--app-name=USB",
                    "--action=open=Open in Files",
                    "--urgency=normal",
                    "USB Drive Connected",
                    label + " mounted at " + mountpoint
                ])
            }
        }
    }

    Timer {
        id: usbRetryTimer
        interval: 1500
        repeat: false
        onTriggered: {
            var dev = usbMountCheckProc.pendingDevice
            if (dev !== "") {
                usbMountCheckProc.command = root.newUtill(["--usbmountcheck", dev])
                usbMountCheckProc.running = true
            }
        }
    }

    // Permanent udevadm monitor — SplitParser fires onRead per line instantly
    Process {
        id: usbWatcher
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block"]
        running: true
        onRunningChanged: if (!running) running = true

        stdout: SplitParser {
            onRead: function(line) {
                line = line.trim()
                console.log("udevadm: " + line)

                if (!line.includes(" add ")) return

                var match = line.match(/add\s+(\S+)\s+\(block\)/)
                if (!match) return

                var devName = match[1].split("/").pop()
                console.log("USB device detected: " + devName)

                if (devName.startsWith("loop")) return
                if (devName.startsWith("dm-"))  return
                if (!/\d$/.test(devName)) return

                console.log("USB partition detected: " + devName)
                usbMountInitTimer.devName = devName
                usbMountInitTimer.restart()
            }
        }
    }

    Timer {
        id: usbMountInitTimer
        interval: 1500
        repeat: false
        property string devName: ""
        onTriggered: {
            console.log("Checking mount for: " + devName)
            if (devName !== "") usbMountCheckProc.checkDevice(devName)
        }
    }

    // USB action handled directly in Notification.qml via root.usbLastMountpoint
    
    // -- MEDIA
    property MediaSystem media: MediaSystem{
        id: mediaSystem
    }

    // Smart crop process — handles vertical monitor wallpapers
    Process {
        id: smartCropProc
        property string wallpaper: ""
        property int    monW: 0
        property int    monH: 0
        property string displayName: ""
        property string rawCommand: ""
        property string lastTempFile: ""

        command: root.newUtill(["--smartcrop", wallpaper, monW, monH])

        stdout: StdioCollector {
            onStreamFinished: {
                var result = this.text.trim()
                if (!result) return

                // Clean up previous temp file
                if (smartCropProc.lastTempFile !== ""
                        && smartCropProc.lastTempFile !== smartCropProc.wallpaper) {
                    root.execute(["rm", "-f", smartCropProc.lastTempFile])
                }

                smartCropProc.lastTempFile = result

                // Set the wallpaper with cropped (or original) path
                var cmd = smartCropProc.rawCommand
                    .replace("{wallpaper}", result)
                root.execute(cmd.split(" "))
                // Clean up temp file after a short delay
                if (result !== smartCropProc.wallpaper) {
                    cleanupTimer.tempFile = result
                    cleanupTimer.restart()
                }
            }
        }
    }

    // -- THEME
    Timer{
        id: themeCheckTimer
        interval: 100
        running: false
        repeat: true
        onTriggered:{
            if (colorQuan.colors.length > 0){
                var themeCommand = combine( newUtill(["--generatetheme", "dark"]), root.wallpaperColors.colors )
                themeGenerator.command = themeCommand
                themeGenerator.running = true
                themeCheckTimer.repeat = false
                themeCheckTimer.running = false
            } 
        }
    }
    Process{
        id:themeGenerator
        command: newUtill(["--generatetheme", "dark"])
        stdout : StdioCollector {
            onStreamFinished: {
                var theme = {"mode":"dark"}
                var obj = this.text.trim()
                if (!obj) { return }
                var pairs = obj.split(",")
                for (var i = 0; i < pairs.length; i++){
                    var pair = pairs[i].split(":")
                    theme[pair[0]] = pair[1]
                }

                settings.theme = theme

                saveSettings()
            }
        }
    }

    // -- WALLPAPERS
    property ColorQuantizer wallpaperColors: ColorQuantizer{
        id: colorQuan
        depth: 3
        rescaleSize: 256
    }
    Timer{
        id: wallpaperSwitchTimer
        interval: 100 //Gets Altered in checkDarkHour
        running: true
        repeat: true
        onTriggered: checkDarkHour()
    }
    Process{
        id: wallpaperRandomChoice
        property string wallpaperFolder: settings.wallpapers.day; 
        property int wallpapersToGet: settings.wallpapers.randomWallpaperPerDisplay ? settings.wallpapers.displays.length : 1
        command: newUtill( ["--randomfile", wallpaperRandomChoice.wallpaperFolder, wallpaperRandomChoice.wallpapersToGet] )
        stdout : StdioCollector {
            onStreamFinished: {
                
                var wallpapers = this.text.split(",")
                var rawCommand = (settings.commands && settings.commands.wallpaper_set)
                    || settings.wallpapers.setWallpaperCommand
                    || "swww img -o {display} {wallpaper}"
                var setWallpaperCommand = rawCommand
                for (var i = 0; i < settings.wallpapers.displays.length; i++) {
                    setWallpaperCommand = rawCommand
                    
                    setWallpaperCommand = setWallpaperCommand.replace( "{display}", settings.wallpapers.displays[i] )

                    var wallpaper = null
                    if (settings.wallpapers.randomWallpaperPerDisplay) {
                        wallpaper = wallpapers[i].trim()
                    } else {
                        wallpaper = wallpapers[0].trim()
                    }

                    // Smart crop for vertical monitors if setting enabled
                    var finalWallpaper = wallpaper
                    if (settings.wallpapers.smartCrop) {
                        var displayName = settings.wallpapers.displays[i]
                        var monRes = root.monitorResolutions[displayName]
                        if (monRes && monRes.h > monRes.w) {
                            // Vertical monitor — run smartcrop synchronously via proc
                            // We use a blocking call pattern here by launching the command
                            // and substituting inline. Since execDetached is async we
                            // store the crop path and use it in a separate proc.
                            smartCropProc.wallpaper   = wallpaper
                            smartCropProc.monW        = monRes.w
                            smartCropProc.monH        = monRes.h
                            smartCropProc.displayName = displayName
                            smartCropProc.rawCommand  = setWallpaperCommand
                                .replace("{display}", settings.wallpapers.displays[i])
                            smartCropProc.running     = true
                            continue  // handled by smartCropProc
                        }
                    }

                    var wallpaperCmd = setWallpaperCommand
                        .replace("{display}", settings.wallpapers.displays[i])
                        .replace("{wallpaper}", finalWallpaper)
                    execute( wallpaperCmd.split(" ") )
                }
                
                root.wallpaperColors.source = Qt.resolvedUrl(wallpapers[settings.wallpapers.primaryDisplayIndex].trim())
                themeCheckTimer.repeat = true
                themeCheckTimer.running = true
            }
        }
    }

    // -- UI OBJECTS
    property MainWindow main: MainWindow {}
}