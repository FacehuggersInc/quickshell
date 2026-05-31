import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design

ComboBox {
    id: widget 

    property int selectedId

    property string textColor: root.settings.theme.text
    property string backgroundColor: root.settings.theme.primary
    property string popupBackgroundColor: root.settings.theme.secondary
    property string popupItemBackgroundColor: root.settings.theme.primary
    
    textRole: "name"
    valueRole: "id"

    property ListModel items: ListModel {}
    model: items

    implicitWidth: popup.width
    implicitHeight: 35

    HoverHandler {
        id:hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    background: Rectangle {
        radius: 6
        color: backgroundColor
        border.color: "transparent"
    }

    contentItem: Text {
        text: widget.displayText.trim() + " (" + selectedId + ")" 
        color: textColor
        font.family: root.settings.fontFamily
        font.weight: 300
        font.pixelSize: 14
        leftPadding: 10
        topPadding: 6
        width: widget.width
    }

    popup: Popup {
        y: widget.height
        width: widget.width
        height: 0
        background: Rectangle {
            radius: 8
            color: popupBackgroundColor
        }
        contentItem: ListView {
            clip: true
            model: items
            delegate: ItemDelegate {
                width: parent.width
                background: Rectangle {
                    color: hovered ? popupItemBackgroundColor : "transparent"
                }
                contentItem: Text {
                    text: model.name.trim() + " (" + model.id + ")" 
                    color: widget.textColor
                    font.family: root.settings.fontFamily
                    font.weight: 500
                    font.pixelSize: 14
                }

                HoverHandler {
                    id:hoverHandler
                    cursorShape: Qt.PointingHandCursor
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        currentIndex = model.index
                        selectedId = model.id
                        widget.popup.close()
                        volumeSettingsPopup.setDevice(currentValue, false)
                    }
                        
                }
            }
        }
    }
}