import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: media

    property string status

    property string title
    property string artist
    property string album
    property string time
    property string image
    property string url
    property string source

    Timer {
        id: getTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (!getMetadataProc.running){
                getMetadataProc.running = true
            } 
        }
    }

    Process{
        id: getMetadataProc
        command: root.newUtill(["--getcurrentplaying"])
        stdout: StdioCollector{
            onStreamFinished:{
                if (this.text.trim()){
                    var data = this.text.trim().split("  ?  ")
                    media.title = data[0]
                    media.artist = data[1]
                    media.album = data[2]
                    media.time = data[3]
                    media.image = data[4]
                    media.url = data[5]
                    media.source = data[6]
                    media.status = data[7] ? data[7] : ""

                } else {
                    media.title = ""
                    media.artist = ""
                    media.album = ""
                    media.time = ""
                    media.image = ""
                    media.url = ""
                    media.source = ""
                    media.status = ""
                } 
            }
        }
    }

}