import QtQuick
import Quickshell
import qs.config

Text {
    text: Qt.formatDateTime(clock.date, "yyyy-MM-dd HH:mm:ss")
    color: Theme.text
    font.family: Theme.fontFamily
    font.pointSize: Theme.fontSize

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }
}
