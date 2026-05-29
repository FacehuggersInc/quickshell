import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Widgets
import QtQuick.Controls.Material

RoundButton {
    id: button
    required property string iconName
    required property real iconSize
    property string color: "#ffffff";
    property string backgroundColor: "transparent"
    property string borderColor: 'transparent'
    property int borderWidth: 0
    property string tooltipText: ""
    signal hoveredEvent(point: var)

    Material.foreground: color
    background: Rectangle {
        radius: button.radius
        color: backgroundColor
        border.color: borderColor
        border.width: borderWidth
    }

    Tooltip {
        id: tooltip
        text: button.tooltipText
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            if (hovered) {
                tooltip.showAt(hoverHandler.point)
            } else {
                tooltip.hide()
            }
            button.hoveredEvent(hoverHandler.point)
        }
    }

    padding: 0
    spacing: 2

    implicitHeight: iconSize
    width: iconSize
    
    icon.cache: false
    icon.width: iconSize
    icon.height: iconSize
    icon.source: root.iconSource(iconName)
    font.family: root.settings.fontFamily

    function setIcon(name){
        button.iconName = name
        var source = root.iconSource(name)
        button.icon.source = source
        return source
    }

    function setIconSource(source){
        button.icon.source = source
    }

    function setColor(color){
        button.color = color
        Material.foreground = color
    }
}