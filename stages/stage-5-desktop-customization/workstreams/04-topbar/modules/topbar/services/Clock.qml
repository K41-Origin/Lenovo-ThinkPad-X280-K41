import QtQuick

QtObject {
    id: root
    property string text: Qt.formatDateTime(new Date(), "hh:mm  ddd, dd MMM")
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.text = Qt.formatDateTime(new Date(), "hh:mm  ddd, dd MMM")
    }
}