import Quickshell.Services.UPower
import QtQuick

QtObject {
    readonly property real percentage: UPower.displayDevice.percentage
    readonly property bool onBattery: UPower.onBattery
    readonly property bool available: UPower.displayDevice.isPresent
}