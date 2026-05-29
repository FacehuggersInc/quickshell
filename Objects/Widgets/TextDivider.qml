import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: widget
    spacing: 10
    Layout.fillWidth: true

    required property string dividerText
    property string dividerColor: root.settings.theme.primary
    property int dividerHeight: 1
    property int dividerWidth: 250

    function setExtraText(text){
        if (text){
            textObj.text = dividerText + "(" + text + ")"
        } else {
            textObj.text = dividerText
        }
        
    }

    Text {
        id: textObj
        text: dividerText
        color: dividerColor
        font.family: root.settings.fontFamily
        font.weight: 500
        font.pixelSize: 15
    }

    Rectangle {
        width: dividerWidth
        height: dividerHeight
        color: dividerColor
        opacity: 0.2
    }
}