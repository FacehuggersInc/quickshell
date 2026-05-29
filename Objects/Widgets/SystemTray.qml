
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick.Controls.Material

import qs.Objects.Design
import qs.Objects.Widgets

RoundedBlock {
    id: tray
    visible: true

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            tray.visible = row.children.length > 1 ? true : false
        }
    }

    QsMenuOpener { id: menuOpener }

    RowLayout {
        id: row
        anchors.centerIn: parent

        Repeater {
            model: SystemTray.items
            delegate: Item {
                width: 24
                height: 24

                property var item: modelData

            
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button == Qt.LeftButton){
                            item.activate()
                        } else if (mouse.button == Qt.RightButton){
                            menuOpener.menu = item.menu
                            // Map the click coordinates to the mainWindow's coordinate system
                            let mappedPoint = mapToItem(mainWindow.contentItem, mouse.x, mouse.y)
                            item.display(
                                mainWindow, 
                                mappedPoint.x, 
                                mappedPoint.y
                            )
                        } 
                    }

                    IconImage {
                        id: iconImage
                        anchors.fill: parent
                        source: item.icon

                        Material.foreground: "white"

                        Tooltip {
                            id: tooltip
                            text: item.title ? item.title : "Tray App"
                            hoverManager: hoverHandler
                        }

                        HoverHandler {
                            id:hoverHandler
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged : {
                                tooltip.toggleOnTo(hoverHandler.point)
                            }
                        }
                    }
                }
            }
        }
    }
}