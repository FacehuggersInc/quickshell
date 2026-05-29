
import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Widgets
import QtQuick.Controls.Material

IconImage {
    id: sIO
    required property string iconName
    required property real iconSize
    property string color: "#ffffff";

    Material.foreground: color

    implicitHeight: iconSize
    implicitWidth: iconSize
    source: root.iconSource(iconName)

    function setIcon(name){
        sIO.iconName = name
        var source = root.iconSource(name)
        sIO.source = source
        return source
    }

    function setColor(color){
        sIO.color = color
        Material.foreground = color
    }

}