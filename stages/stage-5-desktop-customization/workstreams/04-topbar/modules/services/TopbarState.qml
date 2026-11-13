import QtQuick

QtObject {
    property bool notificationPanelOpen: false
    function toggleNotifications() { notificationPanelOpen = !notificationPanelOpen }
    function closeNotifications() { notificationPanelOpen = false }
}