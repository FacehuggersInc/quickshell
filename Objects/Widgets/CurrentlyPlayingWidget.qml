import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Widgets.Internal

RoundedBlock{
    id: widget
    leftPadding: 15
    rightPadding: 15
    topPadding: 5
    bottomPadding: 5

    
    property bool considerReset: true

    Timer {
        id: getPlayingTimer
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            updateMetadata()
            if (!internal.lastTitle){
                widget.visible = false
            } else {
                internal.setControlsVisibleState(true)
                internal.setPlaying(internal.lastTitle)
                internal.setInfo(internal.lastInfo)
            }
        }
    }

    function updateMetadata(){
        if (root.media.status == "Playing" || root.media.status == "Paused"){
            var info = ""
            if (root.media.album){  info += root.media.album }
            if (root.media.artist){  info += info ? " • " + root.media.artist : root.media.artist }
            var source = root.media.source ? root.media.source : "Audio"
            info += info ? " • " + source : source

            var title = root.media.title
            internal.updatePlayPauseState()

            internal.lastTitle = title.trim()
            internal.lastInfo = info.trim()
            internal.setPlaying(title.trim())
            internal.setInfo(info.trim())

            widget.visible = true
        } else {
            if (considerReset){
                internal.lastTitle = ''
                internal.lastInfo = ''
                internal.setPlaying('')
                internal.setInfo('')
                internal.setControlsVisibleState(false)
                internal.updatePlayPauseState()
            }
        } 
    }

    CurrentlyPlayingInternal{
        id: internal
    }

}


