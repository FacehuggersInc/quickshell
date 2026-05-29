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

    // Debounce — ddcutil is slow (~0.5s/display), don't call on every tick
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
                generalSettingsPopup.brightnessValues = vals
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
                        // Only hotplug devices (USB)
                        if (!dev.hotplug) continue
                        // Check top-level and children for mounted partitions
                        var check = [dev].concat(dev.children || [])
                        for (var j = 0; j < check.length; j++) {
                            var part = check[j]
                            if (part.mountpoint && part.mountpoint !== "") {
                                drives.push({
                                    label: part.label || part.name || "USB Drive",
                                    mountpoint: part.mountpoint
                                })
                            }
                        }
                    }
                    generalSettingsPopup.usbDrives = drives
                } catch(e) {
                    generalSettingsPopup.usbDrives = []
                }
            }
        }
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

                // ── MANAGE ───────────────────────────────────────
                TextDivider {
                    dividerText: "Manage"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }

                // Brightness — one row per detected display
                Repeater {
                    model: generalSettingsPopup.displayNames.length
                    delegate: RowLayout {
                        required property int index
                        Layout.fillWidth: true
                        spacing: 10

                        IconButton {
                            iconName: "show"
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
                            value: generalSettingsPopup.brightnessValues[index] || 50
                            onMoved: generalSettingsPopup.setBrightness(index + 1, Math.round(this.value))
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
                    description: "hyprpicker -a"
                    onClicked: root.execute(["hyprpicker", "-a"])
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

                // ── POWER ─────────────────────────────────────────
                TextDivider {
                    dividerText: "Power"
                    dividerHeight: 2
                    Layout.fillWidth: true
                }
                ActionRow {
                    iconName: "lock"
                    label: "Lock Screen"
                    description: "loginctl lock-session"
                    onClicked: root.execute(["loginctl", "lock-session"])
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
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity
        alphaAnim.to = 0
        alphaAnim.start()
        focusGrab.active = false
    }

    function toggle(widget) {
        if (!generalSettingsPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}