import Quickshell
import Quickshell.Wayland
import QtQuick

// K41 handoff splash: intentionally mirrors themes/plymouth/k41/k41.script.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "k41-boot-splash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "#000000"

    readonly property int dotCount: 12
    readonly property real ringRadius: 24
    property int phase: 0

    Timer {
        interval: 90
        running: true
        repeat: true
        onTriggered: root.phase = (root.phase + 1) % root.dotCount
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 - 58
        text: "K41"
        color: "#ffffff"
        font.family: "Sans"
        font.pixelSize: 42
        font.weight: Font.DemiBold
        font.letterSpacing: 5
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height / 2 + 2
        width: 58
        height: 58

        Repeater {
            model: root.dotCount

            delegate: Rectangle {
                required property int index

                width: 5
                height: 5
                radius: width / 2
                color: "#e0e0e0"

                readonly property int distance:
                    (index - root.phase + root.dotCount) % root.dotCount

                opacity: 0.22 + ((root.dotCount - distance) / root.dotCount) * 0.78
                x: parent.width / 2 - width / 2
                   + Math.cos(index * 2 * Math.PI / root.dotCount) * root.ringRadius
                y: parent.height / 2 - height / 2
                   + Math.sin(index * 2 * Math.PI / root.dotCount) * root.ringRadius
            }
        }
    }
}
