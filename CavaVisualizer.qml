import QtQuick
import Quickshell.Io
import qs.Commons

Item {
    id: viz
    property int barCount: 30
    property color barColor: Color.accent
    property bool running: true
    property var levels: Array(barCount).fill(0)

    // cava_config lives next to this file; Qt.resolvedUrl resolves against
    // this file's own directory regardless of where the plugin is installed.
    readonly property string cavaConfigFile: {
        var url = String(Qt.resolvedUrl("cava_config"))
        if (url.indexOf("file://") === 0) url = url.substring(7)
        try { return decodeURIComponent(url) } catch (e) { return url }
    }

    Process {
        id: cavaProc
        running: viz.running
        command: ["cava", "-p", viz.cavaConfigFile]
        stdout: SplitParser {
            onRead: line => {
                const vals = line.split(";").map(v => {
                    var n = Number(v);
                    return isNaN(n) ? 0 : n;
                });
                while (vals.length < viz.barCount) vals.push(0);
                viz.levels = vals.slice(0, viz.barCount);
            }
        }
    }

    Row {
        anchors.fill: parent
        spacing: 2
        Repeater {
            model: viz.barCount
            Rectangle {
                width: (viz.width - viz.barCount * 2) / viz.barCount
                height: (viz.levels[index] || 0) / 100 * viz.height
                anchors.bottom: parent.bottom
                color: viz.barColor
            }
        }
    }
}
