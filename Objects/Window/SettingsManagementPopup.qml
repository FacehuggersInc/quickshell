import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland

import qs.Objects.Design
import Qt5Compat.GraphicalEffects
import qs.Objects.Window
import qs.Objects.Widgets
import qs.Objects.Widgets.Internal

PopupWindow {
    id: generalSettingsPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth: 460
    property int panelHeight: Math.min(Screen.height - mainWindow.height - 20, 740)

    implicitWidth: panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    property bool isClosing: false

    // ── Brightness (ddcutil) ─────────────────────────────────────
    property var displayNames: []        // populated from ddcdetect on open
    property var brightnessValues: []    // one entry per detected display
    property bool brightnessBeingDragged: false  // prevents poll overwriting mid-drag

    // Global brightness debounce — sets all displays at once
    Timer {
        id: globalBrightnessDebounce
        interval: 350
        repeat: false
        property int pendingValue: 50
        onTriggered: {
            // Fire one ddcsetbrightness per display in parallel via separate procs
            for (var i = 0; i < generalSettingsPopup.brightnessValues.length; i++) {
                root.execute(root.newUtill(["--ddcsetbrightness", i + 1, pendingValue]))
            }
        }
    }

    // Per-display debounce — ddcutil is slow (~0.5s/display), don't call on every tick
    Timer {
        id: brightnessDebounce
        interval: 350
        repeat: false
        property int pendingDisplay: 1
        property int pendingValue: 50
        onTriggered: {
            root.execute(root.newUtill(["--ddcsetbrightness", pendingDisplay, pendingValue]))
        }
    }

    Process {
        id: detectProc
        command: root.newUtill(["--ddcdetect"])
        stdout: StdioCollector {
            onStreamFinished: {
                // Format: 1:ModelName|2:ModelName|3:ModelName
                var parts = this.text.trim().split("|")
                var names = []
                for (var i = 0; i < parts.length; i++) {
                    var kv = parts[i].split(":")
                    if (kv.length >= 2) names.push(kv.slice(1).join(":").trim())
                }
                generalSettingsPopup.displayNames = names
            }
        }
    }

    Process {
        id: brightnessGetProc
        command: root.newUtill(["--ddcgetbrightness"])
        stdout: StdioCollector {
            onStreamFinished: {
                // Format: 1:75:100|2:50:100|3:80:100
                var displays = this.text.trim().split("|")
                var vals = []
                for (var i = 0; i < displays.length; i++) {
                    var parts = displays[i].split(":")
                    if (parts.length < 3) { vals.push(50); continue }
                    var current = parseInt(parts[1])
                    var max     = parseInt(parts[2])
                    vals.push(max > 0 ? Math.round((current / max) * 100) : 50)
                }
                // Don't overwrite while user is dragging a slider
                if (!generalSettingsPopup.brightnessBeingDragged)
                    generalSettingsPopup.brightnessValues = vals
            }
        }
    }

    // ── Color Picker ─────────────────────────────────────────────────────────
    Process {
        id: colorPickerProc
        command: ["hyprpicker"]
        stdout: StdioCollector {
            onStreamFinished: {
                var color = this.text.trim()
                if (!color.match(/^#[0-9a-fA-F]{6}$/i)) return
                Quickshell.clipboardText = color
                addColorFromSettingsProc.command = root.newUtill(["--addcolor", color])
                addColorFromSettingsProc.running = true
            }
        }
    }

    Process {
        id: addColorFromSettingsProc
        stdout: StdioCollector {
            onStreamFinished: {
                var list = this.text.trim().split(",").filter(function(c) { return c !== "" })
                root.settings.colorHistory = list
                root.saveSettings()
            }
        }
    }

    function fetchBrightness() {
        if (!detectProc.running)        detectProc.running = true
        if (!brightnessGetProc.running) brightnessGetProc.running = true
    }

    function setBrightness(displayNum, value) {
        // Update local state immediately for responsive UI
        var newVals = brightnessValues.slice()
        newVals[displayNum - 1] = value
        brightnessValues = newVals
        // Debounce the actual ddcutil call
        brightnessDebounce.pendingDisplay = displayNum
        brightnessDebounce.pendingValue   = value
        brightnessDebounce.restart()
    }


    // ── USB Drives ───────────────────────────────────────────────
    property var usbDrives: []   // [{label, mountpoint}]

    Process {
        id: usbDetectProc
        command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT,HOTPLUG,TYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim())
                    var drives = []
                    var devices = data["blockdevices"] || []
                    for (var i = 0; i < devices.length; i++) {
                        var dev = devices[i]
                        // hotplug can be true, "1", or 1 depending on lsblk version
                        var isHotplug = dev.hotplug === true
                            || dev.hotplug === "1"
                            || dev.hotplug === 1
                        if (!isHotplug) continue
                        var check = [dev].concat(dev.children || [])
                        for (var j = 0; j < check.length; j++) {
                            var part = check[j]
                            if (part.mountpoint && part.mountpoint !== ""
                                    && part.mountpoint !== null) {
                                drives.push({
                                    label: part.label && part.label !== ""
                                        ? part.label
                                        : part.name || "USB Drive",
                                    mountpoint: part.mountpoint
                                })
                            }
                        }
                    }
                    generalSettingsPopup.usbDrives = drives
                } catch(e) {
                    console.log("USB detect error: " + e)
                    generalSettingsPopup.usbDrives = []
                }
            }
        }
    }

    // Refresh USB list every 3s while popup is open
    Timer {
        id: usbRefreshTimer
        interval: 3000
        repeat: true
        running: false
        onTriggered: fetchUSB()
    }

    function fetchUSB() {
        if (!usbDetectProc.running) usbDetectProc.running = true
    }

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (generalSettingsPopup.isClosing) {
                generalSettingsPopup.visible = false
                generalSettingsPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ generalSettingsPopup ]
        onCleared: generalSettingsPopup.forceClose()
    }

    // ── Reusable full-width action row ────────────────────────────
    component ActionRow: RoundButton {
        property string iconName: "settings"
        property string label: ""
        property string description: ""

        Layout.fillWidth: true
        padding: 0
        horizontalPadding: 8
        implicitHeight: 42

        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

        background: Rectangle {
            radius: 8
            color: hov.hovered ? root.settings.theme.primary : "transparent"
            opacity: hov.hovered ? 0.18 : 1
        }

        contentItem: RowLayout {
            spacing: 10

            IconButton {
                iconName: parent.parent.iconName
                iconSize: 20
                color: root.settings.theme.primary
                tooltipText: ""
                MouseArea {
                    anchors.fill: parent
                    onClicked: parent.parent.parent.clicked()
                }
            }

            Text {
                text: parent.parent.label
                color: root.settings.theme.text
                font.family: root.settings.fontFamily
                font.weight: 500
                font.pixelSize: 14
                Layout.fillWidth: true
            }

            Text {
                text: parent.parent.description
                color: root.settings.theme.text
                opacity: 0.45
                font.family: root.settings.fontFamily
                font.pixelSize: 12
                visible: text !== ""
            }
        }
    }

    // ── Background block ──────────────────────────────────────────
    Rectangle {
        id: background
        width: panelWidth
        height: panelHeight
        radius: 15
        color: root.settings.theme.background
        opacity: 0
        clip: true

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 1
            radius: 25
            samples: 100
            color: "#80000000"
            source: background
        }

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.margins: 12
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            contentWidth: panelWidth - 24
            contentHeight: settingsColumn.implicitHeight

            ColumnLayout {
                id: settingsColumn
                width: panelWidth - 24
                spacing: 2

                // ── WALLPAPER ─────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                TextDivider {
                    dividerText: "Wallpaper"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }

                // Wallpaper interval
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: 0.7
                        tooltipText: "Wallpaper change interval"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Wallpaper Interval"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                        }

                        Text {
                            text: "e.g. 30s · 5m · 1h 30m · 2h · 90000ms"
                            color: root.settings.theme.text
                            opacity: 0.35
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // Editable field — accepts readable (30s, 5m, 1h 30m) or raw ms
                    Rectangle {
                        width: 150
                        height: 36
                        radius: 6
                        color: root.settings.theme.surface

                        // Border flashes red on bad input
                        border.color: intervalField.hasError
                            ? "#e05555"
                            : intervalField.activeFocus
                                ? root.settings.theme.primary
                                : "transparent"
                        border.width: 1

                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        TextField {
                            id: intervalField
                            anchors.fill: parent
                            anchors.margins: 6
                            font.family: root.settings.fontFamily
                            font.pixelSize: 13
                            color: root.settings.theme.text
                            background: Item {}
                            horizontalAlignment: Text.AlignHCenter
                            selectByMouse: true

                            property bool hasError: false
                            property bool userEditing: false

                            // Convert ms to readable on load / when not editing
                            function msToReadable(ms) {
                                var secs = Math.round(ms / 1000)
                                if (secs < 60) return secs + "s"
                                var m = Math.floor(secs / 60)
                                var s = secs % 60
                                if (m < 60) return s > 0 ? m + "m " + s + "s" : m + "m"
                                var h = Math.floor(m / 60)
                                var rem = m % 60
                                return rem > 0 ? h + "h " + rem + "m" : h + "h"
                            }

                            // Parse readable or raw ms → milliseconds
                            // Returns -1 on invalid input
                            function parseToMs(input) {
                                input = input.trim().toLowerCase()
                                if (!input) return -1

                                // Raw ms number
                                if (/^\d+ms$/.test(input)) return parseInt(input)
                                if (/^\d+$/.test(input))   return parseInt(input)  // bare number = ms

                                // Compound: 1h 30m 10s (any combination)
                                var total = 0
                                var matched = false
                                var hoursMatch  = input.match(/(\d+(?:\.\d+)?)\s*h/)
                                var minsMatch   = input.match(/(\d+(?:\.\d+)?)\s*m(?!s)/)
                                var secsMatch   = input.match(/(\d+(?:\.\d+)?)\s*s/)
                                if (hoursMatch) { total += parseFloat(hoursMatch[1])  * 3600000; matched = true }
                                if (minsMatch)  { total += parseFloat(minsMatch[1])   * 60000;   matched = true }
                                if (secsMatch)  { total += parseFloat(secsMatch[1])   * 1000;    matched = true }
                                if (matched && total > 0) return Math.round(total)

                                return -1
                            }

                            Component.onCompleted: {
                                text = msToReadable(root.settings.wallpapers.interval || 300000)
                            }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    userEditing = true
                                } else {
                                    // Commit on focus loss
                                    commitValue()
                                }
                            }

                            onAccepted: commitValue()

                            function commitValue() {
                                var ms = parseToMs(text)
                                var maxMs = 43200000  // 12 hours
                                var minMs = 5000      // 5 seconds

                                if (ms < 0 || ms < minMs || ms > maxMs) {
                                    hasError = true
                                    errorResetTimer.restart()
                                    // Restore current value
                                    text = msToReadable(root.settings.wallpapers.interval || 300000)
                                    return
                                }

                                hasError = false
                                // setWallpaperInterval saves AND updates the live timer
                                root.setWallpaperInterval(ms)
                                // Reformat to canonical readable form
                                text = msToReadable(ms)
                                userEditing = false
                            }

                            Timer {
                                id: errorResetTimer
                                interval: 1500
                                onTriggered: intervalField.hasError = false
                            }
                        }
                    }
                }

                // Smart crop for vertical monitors
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: (root.settings.wallpapers.smartCrop || false) ? 1.0 : 0.45
                        tooltipText: "Smart crop for vertical monitors"
                        onClicked: {
                            root.settings.wallpapers.smartCrop = !(root.settings.wallpapers.smartCrop || false)
                            root.saveSettings()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Smart Crop (Vertical Monitors)"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (root.settings.wallpapers.smartCrop || false)
                                ? "Cropping to subject center on portrait displays"
                                : "Using wallpapers as-is on all displays"
                            color: root.settings.theme.text
                            opacity: 0.45
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 24
                        radius: 12
                        color: (root.settings.wallpapers.smartCrop || false)
                            ? root.settings.theme.primary
                            : Qt.rgba(1, 1, 1, 0.15)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            color: root.settings.theme.text
                            anchors.verticalCenter: parent.verticalCenter
                            x: (root.settings.wallpapers.smartCrop || false)
                                ? parent.width - width - 3 : 3
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.settings.wallpapers.smartCrop = !(root.settings.wallpapers.smartCrop || false)
                                root.saveSettings()
                            }
                        }
                    }
                }

                // Wallpaper mode — 3-state toggle: day / auto / night
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: root.wallpaperMode === 1 ? "light_mode"
                            : root.wallpaperMode === 2 ? "dark_mode"
                            : "wallpaper"
                        iconSize: 20
                        color: root.settings.theme.primary
                        opacity: root.wallpaperMode === 0 ? 0.45 : 1.0
                        tooltipText: root.wallpaperMode === 1 ? "Force Day Mode"
                            : root.wallpaperMode === 2 ? "Force Night Mode"
                            : "Auto (following schedule)"
                        onClicked: {
                            root.wallpaperMode = (root.wallpaperMode + 1) % 3
                            root.settings.wallpaperMode = root.wallpaperMode
                            root.saveSettings()
                            root.nextWallpaper()
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Wallpaper Mode"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.wallpaperMode === 1 ? "Always day wallpapers"
                                : root.wallpaperMode === 2 ? "Always night wallpapers"
                                : "Following dark hour schedule"
                            color: root.settings.theme.text
                            opacity: 0.45
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    // 3-state toggle track
                    // Position: left=day(1), center=auto(0), right=night(2)
                    Rectangle {
                        id: threeStateTrack
                        width: 66
                        height: 24
                        radius: 12
                        color: root.wallpaperMode === 1
                            ? "#f5a623"                       // amber for day
                            : root.wallpaperMode === 2
                                ? root.settings.theme.primary // themed for night
                                : Qt.rgba(1, 1, 1, 0.15)      // neutral for auto

                        Behavior on color { ColorAnimation { duration: 150 } }

                        // Three position dots (day · auto · night)
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Repeater {
                                model: 3
                                Rectangle {
                                    width: 4; height: 4; radius: 2
                                    color: root.settings.theme.text
                                    opacity: 0.3
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                }
                            }
                        }

                        // Sliding thumb
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            color: root.settings.theme.text
                            anchors.verticalCenter: parent.verticalCenter
                            // day=left(1), auto=center(0), night=right(2)
                            x: root.wallpaperMode === 1 ? 3
                             : root.wallpaperMode === 2 ? threeStateTrack.width - width - 3
                             : (threeStateTrack.width - width) / 2

                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.wallpaperMode = (root.wallpaperMode + 1) % 3
                                root.settings.wallpaperMode = root.wallpaperMode
                                root.saveSettings()
                                root.nextWallpaper()
                            }
                        }
                    }
                }

                // Dark mode hours
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: "dark_mode"
                        iconSize: 20
                        color: root.settings.theme.primary
                        tooltipText: "Dark mode hours"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "Dark Mode Hours"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                        }

                        // "From" hour
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "From"
                                color: root.settings.theme.text
                                opacity: 0.55
                                font.family: root.settings.fontFamily
                                font.pixelSize: 12
                                Layout.preferredWidth: 36
                            }

                            CustomSlider {
                                id: darkHourAtSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 23
                                stepSize: 1
                                handleBorderWidth: 0

                                Binding {
                                    target: darkHourAtSlider
                                    property: "value"
                                    value: root.settings.wallpapers.darkModeHours.at || 20
                                    when: !darkHourAtSlider.pressed
                                }

                                onMoved: {
                                    root.settings.wallpapers.darkModeHours.at = Math.round(this.value)
                                    root.saveSettings()
                                }
                            }

                            Text {
                                text: {
                                    var h = Math.round(darkHourAtSlider.value)
                                    var suffix = h >= 12 ? "pm" : "am"
                                    var display = h > 12 ? h - 12 : (h === 0 ? 12 : h)
                                    return display + suffix
                                }
                                color: root.settings.theme.text
                                font.family: root.settings.fontFamily
                                font.pixelSize: 13
                                font.weight: 500
                                Layout.preferredWidth: 38
                            }
                        }

                        // "Until" hour
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Until"
                                color: root.settings.theme.text
                                opacity: 0.55
                                font.family: root.settings.fontFamily
                                font.pixelSize: 12
                                Layout.preferredWidth: 36
                            }

                            CustomSlider {
                                id: darkHourBeforeSlider
                                Layout.fillWidth: true
                                from: 0
                                to: 23
                                stepSize: 1
                                handleBorderWidth: 0

                                Binding {
                                    target: darkHourBeforeSlider
                                    property: "value"
                                    value: root.settings.wallpapers.darkModeHours.before || 7
                                    when: !darkHourBeforeSlider.pressed
                                }

                                onMoved: {
                                    root.settings.wallpapers.darkModeHours.before = Math.round(this.value)
                                    root.saveSettings()
                                }
                            }

                            Text {
                                text: {
                                    var h = Math.round(darkHourBeforeSlider.value)
                                    var suffix = h >= 12 ? "pm" : "am"
                                    var display = h > 12 ? h - 12 : (h === 0 ? 12 : h)
                                    return display + suffix
                                }
                                color: root.settings.theme.text
                                font.family: root.settings.fontFamily
                                font.pixelSize: 13
                                font.weight: 500
                                Layout.preferredWidth: 38
                            }
                        }

                        // Preview of the schedule
                        Text {
                            text: {
                                var at = Math.round(darkHourAtSlider.value)
                                var before = Math.round(darkHourBeforeSlider.value)
                                var toStr = function(h) {
                                    var s = h >= 12 ? "pm" : "am"
                                    var d = h > 12 ? h - 12 : (h === 0 ? 12 : h)
                                    return d + s
                                }
                                return "Night wallpapers " + toStr(at) + " → " + toStr(before)
                            }
                            color: root.settings.theme.primary
                            opacity: 0.7
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }

                // ── DISPLAY ───────────────────────────────────────
                TextDivider {
                    dividerText: "Display"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }

                // Global brightness — controls all displays at once
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    IconButton {
                        iconName: generalSettingsPopup.brightnessValues.length > 0
                            ? (generalSettingsPopup.brightnessValues.reduce(function(a,b){return a+b},0)
                               / generalSettingsPopup.brightnessValues.length) > 60
                                ? "backlight_high"
                                : (generalSettingsPopup.brightnessValues.reduce(function(a,b){return a+b},0)
                                   / generalSettingsPopup.brightnessValues.length) > 20
                                    ? "backlight_low"
                                    : "backlight_off"
                            : "backlight_high"
                        iconSize: 20
                        color: root.settings.theme.primary
                        tooltipText: "All Displays"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "All Displays"
                            color: root.settings.theme.text
                            opacity: 0.55
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }

                        CustomSlider {
                            id: globalBrightnessSlider
                            Layout.fillWidth: true
                            from: 1
                            to: 100
                            handleBorderWidth: 0
                            onPressedChanged: generalSettingsPopup.brightnessBeingDragged = pressed

                            Binding {
                                target: globalBrightnessSlider
                                property: "value"
                                value: generalSettingsPopup.brightnessValues.length > 0
                                    ? Math.round(generalSettingsPopup.brightnessValues.reduce(
                                        function(a,b){return a+b}, 0)
                                        / generalSettingsPopup.brightnessValues.length)
                                    : 50
                                when: !globalBrightnessSlider.pressed
                            }
                            onMoved: {
                                var v = Math.round(this.value)
                                var newVals = []
                                for (var i = 0; i < generalSettingsPopup.brightnessValues.length; i++) {
                                    newVals.push(v)
                                }
                                generalSettingsPopup.brightnessValues = newVals
                                globalBrightnessDebounce.pendingValue = v
                                globalBrightnessDebounce.restart()
                            }
                        }
                    }

                    Text {
                        text: generalSettingsPopup.brightnessValues.length > 0
                            ? Math.round(generalSettingsPopup.brightnessValues.reduce(
                                function(a,b){return a+b},0)
                                / generalSettingsPopup.brightnessValues.length) + "%"
                            : "?%"
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 500
                        font.pixelSize: 14
                        Layout.preferredWidth: 38
                    }
                }

                // Divider between global and per-display
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: root.settings.theme.text
                    opacity: 0.08
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                // Per-display brightness sliders
                Repeater {
                    model: generalSettingsPopup.displayNames.length
                    delegate: RowLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        IconButton {
                            iconName: {
                                var v = generalSettingsPopup.brightnessValues[index] || 50
                                if (v > 60) return "backlight_high"
                                if (v > 20) return "backlight_low"
                                return "backlight_off"
                            }
                            iconSize: 20
                            color: root.settings.theme.primary
                            tooltipText: generalSettingsPopup.displayNames[index] || ""
                        }

                        Text {
                            text: generalSettingsPopup.displayNames[index] || "Display " + (index + 1)
                            color: root.settings.theme.text
                            opacity: 0.55
                            font.family: root.settings.fontFamily
                            font.pixelSize: 12
                            Layout.preferredWidth: 115
                            elide: Text.ElideRight
                        }

                        CustomSlider {
                            Layout.fillWidth: true
                            from: 1
                            to: 100
                            handleBorderWidth: 0
                            id: perDisplaySlider
                            onPressedChanged: generalSettingsPopup.brightnessBeingDragged = pressed
                            onMoved: generalSettingsPopup.setBrightness(index + 1, Math.round(this.value))

                            Binding {
                                target: perDisplaySlider
                                property: "value"
                                value: generalSettingsPopup.brightnessValues[index] || 50
                                when: !perDisplaySlider.pressed
                            }
                        }

                        Text {
                            text: (generalSettingsPopup.brightnessValues[index] || 50) + "%"
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 500
                            font.pixelSize: 14
                            Layout.preferredWidth: 38
                        }
                    }
                }

                }  // end Wallpaper/Display ColumnLayout

                // ── QUICK ACCESS ──────────────────────────────────
                TextDivider {
                    dividerText: "Quick Access"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "wallpaper"
                    label: "Next Wallpaper"
                    onClicked: root.nextWallpaper()
                }
                ActionRow {
                    iconName: "open_folder"
                    label: "File Manager"
                    description: "nautilus"
                    onClicked: root.execute(["nautilus"])
                }
                ActionRow {
                    iconName: "terminal"
                    label: "Terminal"
                    description: "ghostty"
                    onClicked: root.execute(["ghostty"])
                }
                ActionRow {
                    iconName: "copy_content"
                    label: "Color Picker"
                    description: colorPickerProc.running ? "picking..." : "hyprpicker"
                    onClicked: {
                        if (!colorPickerProc.running) colorPickerProc.running = true
                    }
                }
                ActionRow {
                    iconName: "screenshot"
                    label: "Screenshot"
                    description: "flameshot gui"
                    onClicked: root.execute(["flameshot", "gui"])
                }

                // USB drives — only visible when drives are mounted
                Repeater {
                    model: generalSettingsPopup.usbDrives
                    delegate: ActionRow {
                        required property var modelData
                        iconName: "open_folder"
                        label: modelData.label
                        description: modelData.mountpoint
                        onClicked: root.execute(["nautilus", modelData.mountpoint])
                    }
                }


                // ── CONFIGURATIONS ────────────────────────────────
                TextDivider {
                    dividerText: "Configurations"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "settings"
                    label: "Hyprland Config"
                    description: "~/.config/hypr/"
                    onClicked: root.execute(["code", "/home/fach/.config/hypr/"])
                }
                ActionRow {
                    iconName: "settings"
                    label: "Quickshell Config"
                    description: "~/.config/quickshell/"
                    onClicked: root.execute(["code", "/home/fach/.config/quickshell/"])
                }
                ActionRow {
                    iconName: "open_folder"
                    label: "All Dotfiles"
                    description: "~/.config/"
                    onClicked: root.execute(["code", "/home/fach/.config/"])
                }
                ActionRow {
                    iconName: "refresh"
                    label: "Reload Hyprland Config"
                    description: "hyprctl reload"
                    onClicked: root.execute(["hyprctl", "reload"])
                }

                // ── HYPRLAND ──────────────────────────────────────
                TextDivider {
                    dividerText: "Hyprland"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    id: animToggle
                    property bool on: true
                    iconName: "settings"
                    label: "Toggle Animations"
                    description: on ? "currently on" : "currently off"
                    onClicked: {
                        on = !on
                        root.execute(["hyprctl", "keyword", "animations:enabled", on ? "true" : "false"])
                    }
                }
                ActionRow {
                    id: blurToggle
                    property bool on: true
                    iconName: "settings"
                    label: "Toggle Blur"
                    description: on ? "currently on" : "currently off"
                    onClicked: {
                        on = !on
                        root.execute(["hyprctl", "keyword", "decoration:blur:enabled", on ? "true" : "false"])
                    }
                }


                // ── POWER ─────────────────────────────────────────
                TextDivider {
                    dividerText: "Power"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "lock"
                    label: "Lock Screen"
                    description: "hyprshutdown, hyprctl dispatch exit"
                    onClicked: root.execute(["bash", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit"])
                }
                ActionRow {
                    iconName: "hide"
                    label: "Suspend"
                    description: "systemctl suspend"
                    onClicked: root.execute(["systemctl", "suspend"])
                }
                ActionRow {
                    iconName: "restart"
                    label: "Reboot"
                    description: "systemctl reboot"
                    onClicked: root.execute(["systemctl", "reboot"])
                }
                ActionRow {
                    iconName: "stop"
                    label: "Shutdown"
                    description: "systemctl poweroff"
                    onClicked: root.execute(["systemctl", "poweroff"])
                }

                // ── DEBUG ─────────────────────────────────────────
                TextDivider {
                    dividerText: "Debug"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "restart"
                    label: "Restart Quickshell"
                    description: "detached"
                    onClicked: root.execute(["/home/fach/.config/quickshell/Scripts/restart.sh"])
                }

                // bottom breathing room
                Item { implicitHeight: 8 }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        generalSettingsPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) {
            alphaAnim.stop()
            isClosing = false
        }
        updatePosition(widget)
        background.opacity = 0
        generalSettingsPopup.visible = true
        alphaAnim.from = 0
        alphaAnim.to = 1.0
        alphaAnim.start()
        focusGrab.active = true
        fetchBrightness()
        fetchUSB()
        usbRefreshTimer.start()
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
        usbRefreshTimer.stop()
    }

    function toggle(widget) {
        if (!generalSettingsPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}