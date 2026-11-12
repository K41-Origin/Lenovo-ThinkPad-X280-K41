// Standalone K41 Quickshell entry point.
// K41StandaloneTopbar is owned by this configuration; no Caelestia imports.
import Quickshell
import "modules/topbar" as K41StandaloneTopbar

ShellRoot {
    id: root
    K41StandaloneTopbar.Topbar {}
}
