import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import qs.Objects.Design
import qs.Objects.Window
import qs.Objects.Widgets

Item {
    id: interfaceWidget
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property string netInterface: "..."
    property string netType:      "unknown"
    property string netVpn:       "no"

    Process {
        id: netProc
        command: root.newUtill(["--getnetworkinfo"])
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split("|")
                if (parts.length < 3) return
                interfaceWidget.netInterface = parts[0]
                interfaceWidget.netType      = parts[1]
                interfaceWidget.netVpn       = parts[2]
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: { if (!netProc.running) netProc.running = true }
    }

    NetworkPopup { id: networkPopup }

    RowLayout {
        id: row
        spacing: 5

        IconButton {
            id: netIcon
            iconName: interfaceWidget.netVpn !== "no" ? "vpn"
                    : interfaceWidget.netType === "wired"    ? "wired"
                    : interfaceWidget.netType === "wireless" ? "wifi_max"
                    : "wired"
            iconSize: 22
            color: interfaceWidget.netVpn !== "no" ? "#7be376" : "#fa930e"
            tooltipText: interfaceWidget.netVpn !== "no"
                ? "VPN: " + interfaceWidget.netVpn
                : interfaceWidget.netType === "wired" ? "Wired"
                : interfaceWidget.netType === "wireless" ? "Wireless"
                : "Network"
            onClicked: networkPopup.toggle(interfaceWidget)
        }

        Text {
            text: interfaceWidget.netInterface
            color: interfaceWidget.netVpn !== "no" ? "#7be376" : "#fa930e"
            font.family: root.settings.fontFamily
            font.weight: 500
            font.pixelSize: 18
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: networkPopup.toggle(interfaceWidget)
            }
        }
    }
}