// K41 Floating Password Card composition.
// Components Clock, PasswordInput and StateMessage are upstream Caelestia components.
import "center"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var lock
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    // Center the complete clock/date/password group in the full available area.
    ColumnLayout {
        anchors.centerIn: parent
        width: root.centerWidth
        spacing: Tokens.spacing.largeIncreased

        Clock {
            Layout.alignment: Qt.AlignHCenter
            centerScale: root.centerScale
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd • d MMM").toUpperCase()
            color: Colours.palette.m3onSurface
            font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
        }

        PasswordInput {
            Layout.alignment: Qt.AlignHCenter
            centerScale: Math.max(0.8, root.centerScale)
            centerWidth: root.centerWidth
            lock: root.lock
        }

        StateMessage {
            Layout.fillWidth: true
            pam: root.lock.pam
        }
    }
}
