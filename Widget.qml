import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Bar icon that toggles a bar-anchored popup (PopupCard) with MPRIS track
// info, playback controls, and a cava visualizer. Mirrors omarchy.media.
BarWidget {
    id: root
    moduleName: "sanjar.now-playing"

    readonly property var players: Mpris.players ? Mpris.players.values : []
    property string preferredPlayerKey: ""
    property var playerStartedAt: ({})
    property int playSerial: 0

    function playerKey(player) {
        if (!player) return ""
        return String(player.dbusName || player.desktopEntry || player.identity || "")
    }
    function hasMetadata(player) {
        return !!(player && (player.trackTitle || player.trackArtist || player.identity || player.desktopEntry))
    }
    function playerOrder(player, fallback) {
        var key = root.playerKey(player)
        var value = key ? root.playerStartedAt[key] : undefined
        return value === undefined ? fallback : value
    }
    function syncPlayingOrder() {
        var next = {}
        var alive = {}
        var serial = root.playSerial
        for (var i = 0; i < root.players.length; i++) {
            var p = root.players[i]
            var key = root.playerKey(p)
            if (!key) continue
            alive[key] = true
            if (!p.isPlaying) continue
            if (root.playerStartedAt[key] === undefined) {
                serial += 1
                next[key] = serial
            } else {
                next[key] = root.playerStartedAt[key]
            }
        }
        if (root.preferredPlayerKey && !alive[root.preferredPlayerKey]) root.preferredPlayerKey = ""
        root.playSerial = serial
        root.playerStartedAt = next
    }
    function oldestPlayingPlayer() {
        var oldest = null
        var oldestOrder = 0
        for (var i = 0; i < root.players.length; i++) {
            var p = root.players[i]
            if (!p || !p.isPlaying) continue
            var order = root.playerOrder(p, i + 1000)
            if (!oldest || order < oldestOrder) {
                oldest = p
                oldestOrder = order
            }
        }
        return oldest
    }
    function selectActivePlayer() {
        if (root.preferredPlayerKey) {
            for (var i = 0; i < root.players.length; i++) {
                var p = root.players[i]
                if (root.playerKey(p) === root.preferredPlayerKey && root.hasMetadata(p)) return p
            }
        }
        var playing = root.oldestPlayingPlayer()
        if (playing) return playing
        for (var j = 0; j < root.players.length; j++) {
            if (root.hasMetadata(root.players[j])) return root.players[j]
        }
        return null
    }

    readonly property var player: root.selectActivePlayer()

    onPlayersChanged: root.syncPlayingOrder()
    Component.onCompleted: root.syncPlayingOrder()

    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { root.syncPlayingOrder() }
        }
    }

    property bool popupOpen: false
    function close() { root.popupOpen = false }

    readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
    readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

    readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    property int wallpaperVersion: 0
    readonly property string wallpaperUrl: Util.fileUrl(root.wallpaperPath) + "?v=" + root.wallpaperVersion

    Timer {
        id: closeDelay
        interval: 220
        onTriggered: root.popupOpen = false
    }

    implicitWidth: icon.implicitWidth + Style.space(12)
    implicitHeight: barSize

    Text {
        id: icon
        anchors.centerIn: parent
        text: "\uf001" // nerd-font note icon
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.fontFam
        font.pixelSize: Style.font.body
    }

    MouseArea {
        id: trigger
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { closeDelay.stop(); root.wallpaperVersion++; root.popupOpen = true }
        onExited: closeDelay.restart()
    }

    PopupCard {
        id: popup
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        triggerMode: "hover"
        contentWidth: popup.fittedContentWidth(Style.space(300))
        contentHeight: popup.fittedContentHeight(column.implicitHeight)

        onContainsMouseChanged: {
            if (popup.containsMouse) closeDelay.stop()
            else if (root.popupOpen && !trigger.hovered) closeDelay.restart()
        }

        Column {
            id: column
            anchors.fill: parent
            spacing: Style.space(10)

            Text {
                text: root.player ? (root.player.trackTitle || "Nothing playing") : "No player"
                color: root.fg
                font.family: root.fontFam
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
            }
            Text {
                text: root.player ? root.player.trackArtist : ""
                color: Qt.darker(root.fg, 1.3)
                font.family: root.fontFam
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
                width: parent.width
                visible: text !== ""
            }

            PanelSeparator {
            }

            Item {
                width: parent.width
                height: width * 9 / 16

                Image {
                    anchors.fill: parent
                    source: root.wallpaperUrl
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    clip: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 0.5)
                }

                Row {
                    id: buttonsRow
                    anchors.centerIn: parent
                    spacing: Style.space(6)

                    Button {
                        iconText: "\uf048"
                        foreground: root.fg
                        enabled: root.player && root.player.canGoPrevious
                        opacity: enabled ? 1.0 : 0.4
                        onClicked: {
                            if (root.player) root.preferredPlayerKey = root.playerKey(root.player)
                            if (root.player) root.player.previous()
                        }
                    }
                    Button {
                        iconText: root.player && root.player.isPlaying ? "\uf04c" : "\uf04b"
                        foreground: root.fg
                        enabled: root.player && root.player.canTogglePlaying
                        opacity: enabled ? 1.0 : 0.4
                        onClicked: {
                            if (root.player) root.preferredPlayerKey = root.playerKey(root.player)
                            if (root.player) root.player.togglePlaying()
                        }
                    }
                    Button {
                        iconText: "\uf051"
                        foreground: root.fg
                        enabled: root.player && root.player.canGoNext
                        opacity: enabled ? 1.0 : 0.4
                        onClicked: {
                            if (root.player) root.preferredPlayerKey = root.playerKey(root.player)
                            if (root.player) root.player.next()
                        }
                    }
                }
            }

            PanelSeparator {
            }

            CavaVisualizer {
                width: parent.width
                height: Style.space(60)
                running: root.popupOpen
            }
        }
    }
}
