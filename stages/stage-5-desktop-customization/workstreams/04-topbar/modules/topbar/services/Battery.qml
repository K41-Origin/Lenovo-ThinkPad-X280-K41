import Quickshell.Services.UPower
import QtQuick

// Follows Caelestia's bar BatteryStatus.qml and Battery.qml semantics.
// UPower percentage is a 0.0-1.0 fraction; consumers multiply by 100.
QtObject {
    readonly property bool available: UPower.displayDevice.isLaptopBattery
    readonly property real percentage: UPower.displayDevice.percentage
    readonly property bool onBattery: UPower.onBattery
    readonly property int state: UPower.displayDevice.state
    readonly property real timeToEmpty: UPower.displayDevice.timeToEmpty
    readonly property real timeToFull: UPower.displayDevice.timeToFull
}