import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets

RowLayout {
    id: playingInternal

    property bool textWordWrap: false
    property bool controlsInitialState: false
    property string textColor: "white"
    property string lastTitle: ""
    property string lastInfo: ""

    function setLastTitle(title){
        lastTitle = title
    }
    function setPlaying(text){
        playingLabel.text = text
    }

    function setLastInfo(info){
        lastInfo = info 
    }
    function setInfo(text){
        infoLabel.text = text
    }

    function setControlsVisibleState(state){
        controls.visible = state
    }

    function updatePlayPauseState(){
        if (root.media.status == "Playing"){
            playPauseButton.setIcon("music_pause")
        } else {
            playPauseButton.setIcon("music_play")
        }
    }

    // LEFT: text block
    GridLayout {
        columns: 1
        rows: 2
        rowSpacing: 0

        Layout.alignment: Qt.AlignVCenter

        Text {
            id: playingLabel
            font.family: root.settings.fontFamily
            font.weight: 700
            font.pixelSize: 15
            color: playingInternal.textColor
            text: ""
            wrapMode: textWordWrap ? Text.WordWrap : Text.NoWrap
        }

        Text {
            id: infoLabel
            font.family: root.settings.fontFamily
            font.weight: 500
            font.pixelSize: 14
            color: playingInternal.textColor
            text: ""
            wrapMode: textWordWrap ? Text.WordWrap : Text.NoWrap
        }
    }

    // SPACER → pushes buttons to the right
    Item {
        Layout.fillWidth: true
    }

    // RIGHT: buttons
    RowLayout {
        id:controls
        visible: controlsInitialState

        spacing: 0
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

        IconButton {
            iconName: "music_prev"
            iconSize: 25
            tooltipText: "Prev"
            onClicked: prevCommand.running = true

            Process{
                id: prevCommand
                command: ["playerctl", "previous"]
            }

        }

        IconButton {
            id: playPauseButton
            iconName: "music_pause"
            iconSize: 25
            tooltipText: "Play/Pause"
            onClicked: {
                considerReset = considerReset ? false : true
                if (considerReset){
                    playPauseButton.setIcon("music_pause")
                } else {
                    playPauseButton.setIcon("music_play")
                }
                toggleCommand.running = true
            }

            Process{
                id: toggleCommand
                command: ["playerctl", "play-pause"]
            }
        }

        IconButton {
            iconName: "music_skip"
            iconSize: 25
            tooltipText: "Skip"
            onClicked: nextCommand.running = true

            Process{
                id: nextCommand
                command: ["playerctl", "next"]
            }
        }
    }
}