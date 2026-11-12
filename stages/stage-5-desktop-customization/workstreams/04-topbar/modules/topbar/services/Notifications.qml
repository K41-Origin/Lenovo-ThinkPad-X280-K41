import QtQuick

// Deliberately does not claim org.freedesktop.Notifications yet.
// Caelestia currently owns the notification service; enabling a second
// NotificationServer before an explicit ownership handoff is unsafe.
QtObject {
    readonly property int count: 0
    readonly property bool backendAvailable: false
    readonly property string status: "Notification backend pending D-Bus ownership handoff"
}