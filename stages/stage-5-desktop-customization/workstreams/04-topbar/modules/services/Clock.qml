import Quickshell
import QtQuick

// Adapted from caelestia-dots/shell services/Time.qml (GPL-3.0):
// use Quickshell SystemClock rather than constructing Date on every tick.
Item {
    id: root
    visible: false
    width: 0
    height: 0

    readonly property date date: clock.date
    readonly property int hours: clock.hours
    readonly property int minutes: clock.minutes
    readonly property int seconds: clock.seconds
    readonly property string text: Qt.formatDateTime(clock.date, "hh:mm  ddd, dd MMM")

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}