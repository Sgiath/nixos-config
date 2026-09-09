pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Palette and fonts come from Home Manager (modules/home/desktop/quickshell.nix
// renders themes/sgiath.yaml + Stylix fonts into ~/.config/sgiath-shell/theme.json).
// Semantic names live here; the JSON only carries raw base16 slots.
Singleton {
    id: root

    readonly property color background: palette.base00
    readonly property color surface: palette.base01
    readonly property color overlay: palette.base02
    readonly property color muted: palette.base03
    readonly property color subtext: palette.base04
    readonly property color text: palette.base05

    readonly property color red: palette.base08
    readonly property color orange: palette.base09
    readonly property color yellow: palette.base0A
    readonly property color green: palette.base0B
    readonly property color cyan: palette.base0C
    readonly property color blue: palette.base0D
    readonly property color purple: palette.base0E
    readonly property color brown: palette.base0F

    readonly property color accent: blue
    readonly property color urgent: red

    readonly property string fontFamily: typeface.family
    readonly property int fontSize: typeface.size

    readonly property int barHeight: 36
    readonly property int padding: 8
    readonly property int spacing: 6
    readonly property int radius: 6

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/sgiath-shell/theme.json"
        watchChanges: true
        onFileChanged: reload()

        adapter: JsonAdapter {
            property JsonObject colors: JsonObject {
                id: palette

                property string base00: "#000000"
                property string base01: "#121212"
                property string base02: "#585858"
                property string base03: "#888888"
                property string base04: "#c8c8c8"
                property string base05: "#ffffff"
                property string base06: "#ffffff"
                property string base07: "#ffffff"
                property string base08: "#fa7883"
                property string base09: "#ffc387"
                property string base0A: "#ff9470"
                property string base0B: "#98c379"
                property string base0C: "#8af5ff"
                property string base0D: "#6bb8ff"
                property string base0E: "#e799ff"
                property string base0F: "#b3684f"
            }

            property JsonObject font: JsonObject {
                id: typeface

                property string family: "monospace"
                property int size: 12
            }
        }
    }
}
