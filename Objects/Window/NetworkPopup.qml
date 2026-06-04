import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

PopupWindow {
    id: networkPopup

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height + 5

    property int panelWidth:  320
    property int panelHeight: 220

    implicitWidth:  panelWidth
    implicitHeight: panelHeight
    color: "transparent"
    visible: false

    mask: Region { item: background }

    MouseArea { anchors.fill: parent; z: -1; onClicked: networkPopup.forceClose() }

    property bool isClosing: false

    // Parsed network state
    property string netInterface: "..."
    property string netType:      "unknown"
    property string netVpn:       "no"
    property int    netRxSpeed:   0
    property int    netTxSpeed:   0

    PropertyAnimation {
        id: alphaAnim
        target: background
        property: "opacity"
        duration: 150
        onFinished: {
            if (networkPopup.isClosing) {
                networkPopup.visible = false
                networkPopup.isClosing = false
                background.opacity = 0
            }
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [ networkPopup ]
        onCleared: networkPopup.forceClose()
    }

    Process {
        id: netInfoProc
        command: root.newUtill(["--getnetworkinfo"])
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length < 7) return
                networkPopup.netInterface = parts[0]
                networkPopup.netType      = parts[1]
                networkPopup.netVpn       = parts[2]
                networkPopup.netRxSpeed   = parseInt(parts[5]) || 0
                networkPopup.netTxSpeed   = parseInt(parts[6]) || 0
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 1500
        repeat: true
        running: false
        onTriggered: { if (!netInfoProc.running) netInfoProc.running = true }
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)        return bytesPerSec + " B/s"
        if (bytesPerSec < 1048576)     return (bytesPerSec / 1024).toFixed(1) + " KB/s"
        if (bytesPerSec < 1073741824)  return (bytesPerSec / 1048576).toFixed(1) + " MB/s"
        return (bytesPerSec / 1073741824).toFixed(2) + " GB/s"
    }

    Rectangle {
        id: background
        width: panelWidth
        height: panelHeight
        radius: 15
        color: root.settings.theme.background
        opacity: 0
        clip: true

        MouseArea { anchors.fill: parent; onClicked: {} }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 1
            radius: 20
            samples: 40
            color: "#80000000"
            source: background
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── Connection type + interface ───────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                IconButton {
                    iconName: networkPopup.netType === "wired"    ? "wired"
                            : networkPopup.netType === "wireless" ? "wifi_max"
                            : "wired"
                    iconSize: 32
                    color: root.settings.theme.primary
                    tooltipText: networkPopup.netType
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: networkPopup.netInterface
                        color: root.settings.theme.text
                        font.family: root.settings.fontFamily
                        font.weight: 700
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: networkPopup.netType === "wired"    ? "Wired connection"
                            : networkPopup.netType === "wireless" ? "Wireless connection"
                            : "Network connection"
                        color: root.settings.theme.text
                        opacity: 0.5
                        font.family: root.settings.fontFamily
                        font.pixelSize: 12
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.settings.theme.text
                opacity: 0.08
            }

            // ── VPN ───────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                IconButton {
                    iconName: "vpn"
                    iconSize: 20
                    color: networkPopup.netVpn !== "no"
                        ? root.settings.theme.primary
                        : root.settings.theme.text
                    opacity: networkPopup.netVpn !== "no" ? 1.0 : 0.3
                    tooltipText: "VPN"
                }

                Text {
                    text: networkPopup.netVpn !== "no"
                        ? "VPN: " + networkPopup.netVpn
                        : "No VPN"
                    color: root.settings.theme.text
                    opacity: networkPopup.netVpn !== "no" ? 1.0 : 0.4
                    font.family: root.settings.fontFamily
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }
            }

            // ── Download / Upload speeds ──────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                // Download
                RowLayout {
                    spacing: 6
                    Image {
                        source: root.iconSource("download")
                        width: 16; height: 16
                        sourceSize.width: 16; sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.6
                    }
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Download"
                            color: root.settings.theme.text
                            opacity: 0.5
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: networkPopup.formatSpeed(networkPopup.netRxSpeed)
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 600
                            font.pixelSize: 14
                        }
                    }
                }

                Rectangle { width: 1; height: 30; color: root.settings.theme.text; opacity: 0.1 }

                // Upload
                RowLayout {
                    spacing: 6
                    Image {
                        source: root.iconSource("upload")
                        width: 16; height: 16
                        sourceSize.width: 16; sourceSize.height: 16
                        fillMode: Image.PreserveAspectFit
                        opacity: 0.6
                    }
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "Upload"
                            color: root.settings.theme.text
                            opacity: 0.5
                            font.family: root.settings.fontFamily
                            font.pixelSize: 11
                        }
                        Text {
                            text: networkPopup.formatSpeed(networkPopup.netTxSpeed)
                            color: root.settings.theme.text
                            font.family: root.settings.fontFamily
                            font.weight: 600
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }

    function updatePosition(widget) {
        let pos = mainWindow.itemPosition(widget)
        networkPopup.anchor.rect.x = (pos.x + widget.width / 2) - panelWidth / 2
    }

    function forceOpen(widget) {
        if (isClosing) { alphaAnim.stop(); isClosing = false }
        updatePosition(widget)
        background.opacity = 0
        networkPopup.visible = true
        alphaAnim.from = 0; alphaAnim.to = 1.0; alphaAnim.start()
        focusGrab.active = true
        if (!netInfoProc.running) netInfoProc.running = true
        refreshTimer.start()
    }

    function forceClose() {
        if (isClosing) return
        isClosing = true
        alphaAnim.from = background.opacity; alphaAnim.to = 0; alphaAnim.start()
        focusGrab.active = false
        refreshTimer.stop()
    }

    function toggle(widget) {
        if (!networkPopup.visible || isClosing) forceOpen(widget)
        else forceClose()
    }
}