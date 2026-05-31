import QtQuick
import Quickshell

import qs.Objects.Design

Item {
    id: tooltip
    property string text: ""
    property var hoverManager: null

    function showAt(point) {
        if (!tooltip.text) return
        // scenePosition.x is relative to the window root.
        // For mainWindow (PanelWindow spanning full width) this equals screen x.
        // For PopupWindows we add anchor.rect.x to get the true screen x.
        var x = point.scenePosition.x + getWindowOffsetX()
        tooltipWindow.show(tooltip.text, x)
    }

    function getWindowOffsetX() {
        // Walk up the QML parent chain looking for a PopupWindow
        // (identified by having an anchor property and not being mainWindow)
        // PopupWindows are NOT in the QML parent chain of their content —
        // so we check if our nearest Window ancestor differs from mainWindow
        // by comparing the window property of our parent item
        if (!tooltip.parent) return 0
        var w = tooltip.parent.Window.window
        if (!w || w === mainWindow) return 0
        // w is a PopupWindow — get its screen x from anchor.rect.x
        if (w.anchor && w.anchor.rect) return w.anchor.rect.x || 0
        return 0
    }

    function hide() {
        tooltipWindow.hide()
    }

    function toggleOnTo(point) {
        showAt(point)
    }
}