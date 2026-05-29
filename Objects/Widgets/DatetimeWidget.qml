import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import qs.Objects.Design

import QtQuick.Layouts

Text {
    id: sTO
    required property string format
    required property string textColor
    property var cmd: root.newUtill( ["--format", format] )

    color: textColor
    font.family: root.settings.fontFamily
    font.weight: 500
    font.pixelSize: 18

    verticalAlignment: Text.AlignVCenter

    Process {
        id: clockProc
        command: cmd
        running: true
        stdout: StdioCollector {
            onStreamFinished: sTO.text = this.text
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockProc.running = true
    }

}
