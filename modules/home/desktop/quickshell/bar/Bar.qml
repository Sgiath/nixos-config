import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// One bar per connected screen; Variants tracks hotplug.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        screen: modelData
        color: "transparent"
        implicitHeight: Theme.barHeight
        WlrLayershell.namespace: "sgiath-bar"

        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.background

            Workspaces {
                screen: bar.screen

                anchors {
                    left: parent.left
                    leftMargin: Theme.padding
                    verticalCenter: parent.verticalCenter
                }
            }

            Clock {
                anchors.centerIn: parent
            }

            Text {
                text: bar.screen.name
                color: Theme.subtext
                font.family: Theme.fontFamily
                font.pointSize: Theme.fontSize

                anchors {
                    right: parent.right
                    rightMargin: Theme.padding
                    verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
