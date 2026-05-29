import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

import qs.Objects.Design

PopupWindow {
    id: tooltip
    property string text: "Tooltip"
    property HoverHandler hoverManager

    anchor.window: mainWindow
    anchor.rect.x: 0
    anchor.rect.y: mainWindow.height
    color: "transparent"
    visible: false

    implicitWidth: (tooltip.text.length * 16) + 15
    implicitHeight: 35

    RoundedBlock{
        color: root.settings.theme.surface
        alpha: 1.0
        Text {
            text: tooltip.text
            color: root.settings.theme.text
            font.family: root.settings.fontFamily
            font.weight: 500
            font.pixelSize: 16
        }
    }

    function updatePosition(point){
        tooltip.anchor.rect.x = mapToItem(tooltip.parent, point.position.x, point.position.y).x
    }    

    function toggleOnTo(position) {
        if (!text) { return }
        updatePosition(position)
        tooltip.visible = tooltip.visible ? false : true
    }
}


