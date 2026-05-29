import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import qs.Objects.Design

IconButton {
    id: sIBO
    iconName: "ethernet"
    iconSize: 25
    tooltipText: "Internet Conn"
    color: '#fa930e'

    font.family: root.settings.fontFamily
    font.weight: 500
    font.pixelSize: 18

    Process {
        id: clockProc
        command: root.newUtill( ["--getinterface", "wired"] )
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.split(",")
                var name = parts[0]
                var type = parts[1]
                if (type.includes("wired")){
                    sIBO.setIcon("ethernet")
                } else if (type.includes("external")){
                    sIBO.setIcon("vpn")
                }
                sIBO.text = name
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockProc.running = true
    }

}


