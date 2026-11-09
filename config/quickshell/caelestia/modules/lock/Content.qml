// K41 lock-screen override for Caelestia Shell 2.5.0.
// Keep the upstream LockSurface, PAM handler, session-lock protocol and wallpaper blur.
// Replace only the three-column content with the approved minimal center layout.
import QtQuick
import Caelestia.Config
import qs.services

Item {
    id: root

    required property var lock

    Center {
        anchors.centerIn: parent
        width: centerWidth
        height: implicitHeight
        lock: root.lock
    }
}
