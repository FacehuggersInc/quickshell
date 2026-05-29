import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Window
import QtQuick.Controls

import QtQuick.Layouts

import qs.Objects.Design
import qs.Objects.Widgets



PanelWindow {
    id: mainWindow
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 60
    color: '#00ffffff'

    property int padding: 8
    property int spacing: 5

    Pane{
        anchors.fill: parent

        background : Rectangle {
            color: '#00000000'
            radius: 0
        }
        topPadding: mainWindow.padding

        //LEFT MODULES
        Row {
            anchors.left: parent.left
            anchors.leftMargin: mainWindow.padding
            spacing: mainWindow.spacing
        }
        
        // CENTER MODULES
        Row{
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: mainWindow.spacing

            AppBarWidget{
                id: appbar
                implicitHeight: rightModules.height 
            }
        }
        
        // RIGHT MODULES
        Row{
            anchors.right: parent.right
            anchors.rightMargin: mainWindow.padding
            spacing: mainWindow.spacing

            SystemTray {
                implicitHeight: rightModules.height
            }

            RoundedBlock{
                id: rightModules
                
                RowLayout {
                    spacing: 8

                    VolumeWidget {}
                    InterfaceWidget {}
                    DatetimeWidget { 
                        format: "%I:%M%p %a, %b %d" 
                        textColor: '#7be376'
                    }
                    NotificationsWidget {}
                    BluetoothWidget {}
                    IconButton{
                        id: settingsIconButton
                        iconName: "settings"
                        iconSize: 22
                        tooltipText: "Open Settings"
                        onClicked: {
                            settingsPopupWin.toggle(settingsIconButton) 
                        }

                        SettingsManagementPopup{
                            id: settingsPopupWin
                        }

                    }
                }
            }
        }
    }
}
