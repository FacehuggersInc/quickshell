import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Design
import qs.Objects.Widgets
import qs.Objects.Window

PopupPanel {
    id: popup
    implicitHeight: 350
    implicitWidth: popupColumn.implicitWidth + 16
    sidePadding: 0
    fadingEffectMax: 1.0
    property ListModel actions: ListModel{}

    // Component-level signal — AppBar connects to this
    signal actionTriggered(var action)

    content: ColumnLayout {
        id: popupColumn
        anchors.fill: parent
        spacing: 0
        Repeater {
            model: popup.actions
            delegate: RoundButton {
                id: actionbtn
                required property var modelData
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft

                text: modelData.name
                font.family: root.settings.fontFamily
                font.weight: 700
                font.pixelSize: 14

                icon.source: modelData.icon ? root.iconSource(modelData.icon) : undefined
                icon.color: "transparent"

                padding: 5
                horizontalPadding: 10

                contentItem: RowLayout {
                    spacing: 6
                    Image {
                        source: actionbtn.icon.source
                        width: 16
                        height: 16
                        fillMode: Image.PreserveAspectFit
                        visible: source != ""
                    }
                    Text {
                        text: actionbtn.text
                        color: root.settings.theme.text
                        font: actionbtn.font
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                        Layout.fillWidth: true
                    }
                }

                HoverHandler {
                    id: hoverHandler
                    cursorShape: Qt.PointingHandCursor
                }

                background: Rectangle {
                    radius: 6
                    color: hoverHandler.hovered ? root.settings.theme.primary : "transparent"
                }

                onClicked: {
                    popup.actionTriggered(modelData)
                    popup.forceClose()
                }
            }
        }
    }
}