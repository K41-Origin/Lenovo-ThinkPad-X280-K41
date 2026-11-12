import QtQuick

// Do not claim org.freedesktop.Notifications until an explicit D-Bus
// ownership handoff is implemented and validated.
QtObject {
    readonly property int count: 0
    readonly property bool backendAvailable: false
    readonly property string status: "Notification backend pending D-Bus ownership handoff"
}