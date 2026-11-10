// K41 lock-screen override for Caelestia Shell 2.5.0.
// Keep the upstream LockSurface, PAM handler, session-lock protocol and wallpaper blur.
// Fill the available lock-content area so Center can position its content geometrically.
import QtQuick
import Caelestia.Config
import qs.services

Item {
    id: root

    required property var lock

    Center {
        anchors.fill: parent
        lock: root.lock
    }
}
