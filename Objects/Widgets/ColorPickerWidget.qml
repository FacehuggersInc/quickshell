import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts
import QtQuick.Controls

import qs.Objects.Window
import qs.Objects.Widgets

Item {
    id: colorPickerWidget
    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    property var colors: root.settings.colorHistory || []

    // hyprpicker prints the hex color to stdout and exits when user picks
    // Using Process lets us react exactly when it finishes, not on a timer
    Process {
        id: hyprpickerProc
        command: ["hyprpicker"]   // no -a so we get stdout instead of clipboard
        stdout: StdioCollector {
            onStreamFinished: {
                var color = this.text.trim()
                if (!color.match(/^#[0-9a-fA-F]{6}$/i)) return
                // Copy to clipboard ourselves
                Quickshell.clipboardText = color
                // Save to history
                addColorProc.command = root.newUtill(["--addcolor", color])
                addColorProc.running = true
            }
        }
    }

    Process {
        id: addColorProc
        stdout: StdioCollector {
            onStreamFinished: {
                var list = this.text.trim().split(",").filter(function(c) { return c !== "" })
                root.settings.colorHistory = list
                root.saveSettings()
                colorPickerWidget.colors = list
            }
        }
    }

    RowLayout {
        id: row
        spacing: 6

        // Last picked color swatch — click to open history popup
        Rectangle {
            id: lastColorSwatch
            width: 20
            height: 20
            radius: 10
            color: colorPickerWidget.colors.length > 0
                ? colorPickerWidget.colors[0]
                : root.settings.theme.surface
            border.color: root.settings.theme.text
            border.width: 1
            opacity: 0.9

            Behavior on color { ColorAnimation { duration: 200 } }

            HoverHandler { id: swatchHov; cursorShape: Qt.PointingHandCursor }

            Tooltip {
                id: swatchTooltip
                text: colorPickerWidget.colors.length > 0
                    ? colorPickerWidget.colors[0]
                    : "No colors yet"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: colorHistoryPopup.toggle(colorPickerWidget)
                HoverHandler {
                    onHoveredChanged: swatchTooltip.toggleOnTo(point)
                }
            }
        }

        // Pick button
        IconButton {
            id: pickButton
            iconName: "copy_content"
            iconSize: 22
            tooltipText: "Pick color"
            color: hyprpickerProc.running
                ? root.settings.theme.primary
                : root.settings.theme.text
            onClicked: {
                if (!hyprpickerProc.running) hyprpickerProc.running = true
            }
        }
    }

    ColorHistoryPopup {
        id: colorHistoryPopup
    }
}