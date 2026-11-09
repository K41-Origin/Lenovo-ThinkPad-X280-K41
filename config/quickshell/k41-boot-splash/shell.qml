import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "k41-boot-splash"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "#050505"

    property real angle: 0

    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            root.angle = (root.angle + 7) % 360
            spinner.requestPaint()
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 30

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "K41"
            color: "#f2f2f2"
            font.family: "Sans"
            font.pixelSize: 54
            font.weight: Font.DemiBold
            font.letterSpacing: 8
        }

        Canvas {
            id: spinner
            width: 42
            height: 42
            anchors.horizontalCenter: parent.horizontalCenter
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.strokeStyle = "#eeeeee"
                ctx.beginPath()
                ctx.arc(width / 2, height / 2, 16,
                        root.angle * Math.PI / 180,
                        (root.angle + 245) * Math.PI / 180)
                ctx.stroke()
            }
        }
    }
}
