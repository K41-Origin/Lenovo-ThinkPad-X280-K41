// Standalone K41 Quickshell entry point.
// No imports or instances from Caelestia are permitted here.
import Quickshell
import "modules/topbar" as K41StandaloneTopbar

ShellRoot {
    id: root
    K41StandaloneTopbar.Topbar {
        objectName: "K41StandaloneTopbar"
    }
}
