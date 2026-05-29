import Quickshell
import Quickshell.Io
import QtQuick
import Quickshell.Widgets
import QtQuick.Layouts

import qs.Objects.Window

IconButton {
    id: notifyWidget
    iconName: "notify"
    iconSize: 25
    tooltipText: "0 Unread"
    color: '#252525'

    Component.onCompleted: {
        root.notifyServer.notification.connect(notifyWidget.onNewNotification)
    }

    NotificationsPanel {
        id: notificationsPanel
    }

    NotificationPopup {
        id: notificationPopup
    }

    function onNewNotification(notif) {
        if (!notif || notif.lastGeneration) return

        notif.tracked = true

        // Pass the full notification object so the popup card
        // can render action buttons (e.g. "Open in Files" for USB)
        notificationPopup.notification = notif
        notificationPopup.setPopupIcon(root.notifyServer.iconName)
        notificationPopup.toggle()

        // Update badge immediately on new notification
        updateBadge()
    }

    function updateBadge() {
        var count = root.notifyServer.trackedNotifications.values.length
        tooltipText = count + " Unread"
        if (count > 0) {
            notifyWidget.setIcon("notify_unread")
            notifyWidget.setColor("#ffffff")
        } else {
            notifyWidget.setIcon("notify")
            notifyWidget.setColor("#252525")
        }
    }

    // Poll count reactively — catches dismissals and any missed signals
    Timer {
        id: badgePoller
        interval: 500
        repeat: true
        running: true
        onTriggered: notifyWidget.updateBadge()
    }

    // Also wire object signals as a fast path for immediate updates
    Connections {
        target: root.notifyServer.trackedNotifications
        function onObjectInserted() { notifyWidget.updateBadge() }
        function onObjectRemoved()  { notifyWidget.updateBadge() }
    }

    onClicked: notificationsPanel.toggle(notifyWidget)
}