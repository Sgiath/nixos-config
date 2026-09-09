import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Regular workspaces of this bar's monitor; special workspaces have negative ids.
Row {
    id: root

    required property ShellScreen screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    spacing: Theme.spacing

    Repeater {
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(ws => ws.monitor === root.monitor && ws.id > 0).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            id: pill

            required property HyprlandWorkspace modelData

            width: label.implicitWidth + 2 * Theme.padding
            height: Theme.barHeight - 2 * Theme.padding
            radius: Theme.radius
            color: modelData.urgent ? Theme.urgent : modelData.focused ? Theme.accent : modelData.active ? Theme.overlay : Theme.surface

            Text {
                id: label

                anchors.centerIn: parent
                text: pill.modelData.name
                color: pill.modelData.focused || pill.modelData.urgent ? Theme.background : Theme.text
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize
            }

            MouseArea {
                anchors.fill: parent
                onClicked: pill.modelData.activate()
            }
        }
    }
}
