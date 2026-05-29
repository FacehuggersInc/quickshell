import QtQuick.Controls.Basic
import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects

Pane {
    id: block
    property string color: root.wallpaperColors.colors[0];
    property int radius: 25;
    property double alpha: 0.8;
    property int sidePadding: 15
    property int tbPadding: 0
    
    width: block.implicitWidth

    Behavior on width {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutQuad
        }
    }

    background : Rectangle {
        id: rect
        color: block.color
        radius: block.radius
        opacity: alpha
        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            horizontalOffset: 1
            verticalOffset: 1
            radius: 25
            samples: 100
            color: "#80000000"
            source: rect
        }
    }
    padding: 0
    leftPadding: sidePadding
    rightPadding: sidePadding
    topPadding: tbPadding
    bottomPadding: tbPadding
}