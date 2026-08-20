import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.Ui
import qs.Commons

// Bar icon that toggles a bar-anchored popup (PopupCard) with MPRIS track
// info, playback controls, and a cava visualizer. Mirrors omarchy.media.
BarWidget {
    id: root
    moduleName: "omnimedia"

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
    onPlayerChanged: root.refreshProgress()
    Component.onCompleted: root.syncPlayingOrder()

    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                root.syncPlayingOrder()
                if (modelData === root.player) root.refreshProgress()
            }
        }
    }

    property bool popupOpen: false
    property bool showMiniCava: false
    function close() { root.popupOpen = false }

    readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
    readonly property string fontFam: root.bar ? root.bar.fontFamily : Style.font.family

    readonly property string iconGlyph: root.player && root.player.isPlaying ? "󰏤" : "󰐊"
    readonly property string labelText: {
        var p = root.player
        if (!p) return ""
        var parts = []
        if (p.trackTitle) parts.push(p.trackTitle)
        if (p.trackArtist) parts.push(p.trackArtist)
        return parts.join("  ·  ")
    }
    readonly property real labelMaxWidth: labelMetrics.advanceWidth + Style.space(2)

    property real progress: 0
    property real progressDrag: -1

    function refreshProgress() {
        if (!root.player || root.player.length <= 0) { root.progress = 0; return }
        root.progress = Math.min(1, Math.max(0, root.player.position / root.player.length))
    }

    function seekTo(x, w) {
        if (!root.player || !root.player.positionSupported) return
        if (!w || w <= 0) return
        var frac = Math.min(1, Math.max(0, x / w))
        root.progressDrag = frac
        root.progress = frac
        root.player.position = root.player.length * frac
    }

    readonly property bool isCliamp: root.player && (
        String(root.player.identity || "").toLowerCase().indexOf("cliamp") >= 0
        || String(root.player.desktopEntry || "").toLowerCase().indexOf("cliamp") >= 0)
    property bool cliampShuffle: false
    property string cliampRepeatMode: "off"
    property bool widgetRepeat: false
    readonly property bool shuffleActive: root.isCliamp
        ? root.cliampShuffle
        : root.player ? !!root.player.shuffle : false
    readonly property bool repeatActive: root.isCliamp
        ? root.cliampRepeatMode !== "off"
        : root.player && root.player.loopSupported
            ? root.player.loopState !== MprisLoopState.None
            : root.widgetRepeat
    readonly property bool shuffleEnabled: root.player && (root.player.shuffleSupported || root.isCliamp)
    readonly property bool repeatEnabled: root.player && (
        root.player.loopSupported || root.isCliamp
        || (root.player.positionSupported && root.player.length > 0))

    function runCliamp(args) {
        root.cliampProc.command = ["cliamp"].concat(args)
        root.cliampProc.running = true
    }

    function refreshCliampState() {
        if (root.isCliamp) root.runCliamp(["status"])
    }

    function toggleShuffle() {
        if (!root.player) return
        root.preferredPlayerKey = root.playerKey(root.player)
        if (root.isCliamp) root.runCliamp(["shuffle", "toggle"])
        else if (root.player.shuffleSupported) root.player.shuffle = !root.player.shuffle
    }

    function toggleRepeat() {
        if (!root.player) return
        root.preferredPlayerKey = root.playerKey(root.player)
        if (root.isCliamp) root.runCliamp(["repeat", "cycle"])
        else if (root.player.loopSupported) {
            var s = root.player.loopState
            root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                : s === MprisLoopState.Playlist ? MprisLoopState.Track
                : MprisLoopState.None
        }
        else root.widgetRepeat = !root.widgetRepeat
    }

    readonly property string wallpaperPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
    property int wallpaperVersion: 0
    readonly property string wallpaperUrl: Util.fileUrl(root.wallpaperPath) + "?v=" + root.wallpaperVersion

    property int downloadState: 0 // 0=idle, 1=input, 2=downloading, 3=success, 4=failed, 5=no-ytdlp, 6=no-ffmpeg, 7=not-youtube
    property real downloadProgress: 0
    property string downloadError: ""
    property bool downloadCancelled: false
    property string depCheckTarget: ""
    property string pendingUrl: ""
    property string inputUrl: ""
    readonly property string musicDir: Quickshell.env("HOME") + "/Music"

    function isYouTubeUrl(url) {
        return url.indexOf("youtube.com") >= 0 || url.indexOf("youtu.be") >= 0
    }

    function downloadTrack() {
        if (root.downloadState === 1) {
            root.downloadState = 0
            root.inputUrl = ""
            root.downloadError = ""
            return
        }
        root.downloadCancelled = false
        root.downloadError = ""
        root.downloadProgress = 0
        root.pendingUrl = ""
        root.inputUrl = ""
        root.downloadState = 1
        closeDelay.stop()
    }

    function startActualDownload() {
        root.downloadCancelled = false
        root.downloadState = 2
        root.downloadProgress = 0
        root.depCheckTarget = "yt-dlp"
        root.depCheckProc.command = ["which", "yt-dlp"]
        root.depCheckProc.running = true
    }

    function cancelDownload() {
        root.downloadCancelled = true
        if (root.depCheckProc.running) root.depCheckProc.kill()
        if (root.downloadProc.running) root.downloadProc.kill()
        root.downloadState = 0
        root.downloadProgress = 0
        root.downloadError = ""
        root.inputUrl = ""
    }

    function submitUrl() {
        var url = root.inputUrl.trim()
        if (url === "") return
        if (!root.isYouTubeUrl(url)) {
            root.downloadState = 7
            root.downloadError = "Not a YouTube link"
            return
        }
        root.pendingUrl = url
        root.startActualDownload()
    }

    function downloadButtonLabel() {
        switch (root.downloadState) {
        case 0: return "Download YouTube"
        case 1: return "Enter URL"
        case 2: return "Downloading\u2026 " + Math.round(root.downloadProgress) + "%"
        case 3: return "Downloaded"
        case 4: return "Failed \u2014 retry?"
        case 5: return "yt-dlp not found"
        case 6: return "ffmpeg not found"
        case 7: return "Not a YouTube link"
        default: return "Download YouTube"
        }
    }

    Timer {
        id: closeDelay
        interval: 220
        onTriggered: root.popupOpen = false
    }

    HyprlandFocusGrab {
        id: inputGrab
        active: root.downloadState === 1
        windows: [popup, root.QsWindow.window]
    }

    Timer {
        id: progressTimer
        interval: 250
        repeat: true
        running: root.player && root.player.isPlaying
        onTriggered: {
            root.refreshProgress()
            if (root.widgetRepeat && root.player
                && root.player.isPlaying && root.player.length > 0
                && root.player.position >= root.player.length - 0.4) {
                root.player.position = 0
            }
        }
    }

    Process {
        id: cliampProc
        stdout: SplitParser {
            onRead: line => {
                var s = String(line)
                if (s.indexOf("Shuffle:") === 0) root.cliampShuffle = s.substr(8).trim() === "on"
                else if (s.indexOf("Repeat:") === 0) root.cliampRepeatMode = s.substr(7).trim().toLowerCase()
            }
        }
    }

    Process {
        id: depCheckProc
        running: false
        onExited: function(exitCode) {
            if (root.downloadCancelled) return
            if (root.depCheckTarget === "yt-dlp") {
                if (exitCode !== 0) {
                    root.downloadState = 5
                    root.downloadError = "Install yt-dlp to download tracks"
                    return
                }
                root.depCheckTarget = "ffmpeg"
                root.depCheckProc.command = ["which", "ffmpeg"]
                root.depCheckProc.running = true
            } else if (root.depCheckTarget === "ffmpeg") {
                if (exitCode !== 0) {
                    root.downloadState = 6
                    root.downloadError = "Install ffmpeg for audio conversion"
                    return
                }
                root.downloadProc.command = [
                    "yt-dlp",
                    "--embed-metadata",
                    "--embed-thumbnail",
                    "--extract-audio",
                    "--audio-format", "mp3",
                    "--audio-quality", "0",
                    "--no-overwrites",
                    "--no-playlist",
                    "-o", root.musicDir + "/%(artist|uploader)s - %(title)s.%(ext)s",
                    root.pendingUrl
                ]
                root.downloadProc.running = true
            }
        }
    }

    Process {
        id: downloadProc
        running: false
        onRunningChanged: {
            if (!running && root.downloadState === 2 && !root.downloadCancelled) {
                if (exitCode === 0) {
                    root.downloadState = 3
                    root.downloadProgress = 100
                    downloadDoneTimer.start()
                } else if (exitCode !== -1) {
                    root.downloadState = 4
                    root.downloadError = root.downloadError || "Download failed (exit " + exitCode + ")"
                }
            }
        }
        onExited: function(exitCode) {
            if (exitCode !== 0 && root.downloadState === 2 && !root.downloadCancelled && exitCode !== -1) {
                root.downloadState = 4
                root.downloadError = root.downloadError || "Download failed (exit " + exitCode + ")"
            }
        }
        stdout: SplitParser {
            onRead: line => {
                var s = String(line).trim()
                if (s.indexOf("[download]") === 0 && s.indexOf("%") > 0) {
                    var pctStr = s.substring(10, s.indexOf("%")).trim()
                    var pct = Number(pctStr)
                    if (!isNaN(pct) && pct >= 0 && pct <= 100) {
                        root.downloadProgress = pct
                    }
                }
            }
        }
        stderr: SplitParser {
            onRead: line => {
                var s = String(line).trim()
                if (s.indexOf("ERROR:") === 0) {
                    root.downloadError = s.length > 7 ? s.substring(7).trim() : "Unknown error"
                } else if (s.indexOf("ffmpeg") >= 0 && s.indexOf("not found") >= 0) {
                    root.downloadError = "ffmpeg not found \u2014 install ffmpeg for audio conversion"
                }
            }
        }
    }

    Timer {
        id: downloadDoneTimer
        interval: 3000
        onTriggered: root.downloadState = 0
    }

    implicitWidth: icon.implicitWidth + (root.labelText !== "" ? Style.space(6) + root.labelMaxWidth : 0) + (root.showMiniCava && root.player && root.player.isPlaying ? Style.space(4) + Style.space(48) : 0) + Style.space(12)
    implicitHeight: barSize

    Text {
        id: icon
        x: Style.space(6)
        y: Math.round((parent.height - height) / 2)
        text: root.iconGlyph
        color: root.player && root.player.isPlaying
            ? (root.bar ? root.bar.barForeground : Color.foreground)
            : Qt.darker(root.bar ? root.bar.barForeground : Color.foreground, 1.5)
        font.family: root.fontFam
        font.pixelSize: Style.font.body
    }

    Text {
        id: label
        x: Math.round(icon.x + icon.width + Style.space(6))
        y: Math.round((parent.height - height) / 2)
        visible: root.labelText !== ""
        width: Math.round(root.labelMaxWidth)
        text: root.labelText
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.fontFam
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    Item {
        id: miniCavaContainer
        visible: root.showMiniCava && root.player && root.player.isPlaying
        x: label.visible ? Math.round(label.x + label.width + Style.space(4)) : Math.round(icon.x + icon.width + Style.space(4))
        y: Math.round((parent.height - height) / 2)
        width: Style.space(48)
        height: Math.round(barSize * 0.5)

        property var levels: Array(12).fill(0)

        readonly property string miniCavaConfigFile: {
            var url = String(Qt.resolvedUrl("cava_config_mini"))
            if (url.indexOf("file://") === 0) url = url.substring(7)
            try { return decodeURIComponent(url) } catch (e) { return url }
        }

        Process {
            id: miniCavaProc
            running: root.showMiniCava && root.player && root.player.isPlaying
            command: ["cava", "-p", miniCavaContainer.miniCavaConfigFile]
            stdout: SplitParser {
                onRead: line => {
                    const vals = line.split(";").map(v => {
                        var n = Number(v);
                        return isNaN(n) ? 0 : n;
                    });
                    while (vals.length < 12) vals.push(0);
                    miniCavaContainer.levels = vals.slice(0, 12);
                }
            }
        }

        Row {
            anchors.fill: parent
            spacing: 1
            Repeater {
                model: 12
                Rectangle {
                    width: (miniCavaContainer.width - 12) / 12
                    height: Math.max(1, (miniCavaContainer.levels[index] || 0) / 100 * miniCavaContainer.height)
                    anchors.bottom: parent.bottom
                    color: root.bar ? root.bar.barForeground : Color.foreground
                }
            }
        }
    }



    TextMetrics {
        id: labelMetrics
        font.family: root.fontFam
        font.pixelSize: Style.font.bodySmall
        text: "012345678901234567890123456789"
    }

    MouseArea {
        id: trigger
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: { closeDelay.stop(); root.wallpaperVersion++; root.popupOpen = true; root.refreshCliampState() }
        onExited: { if (root.downloadState !== 1) closeDelay.restart() }
        onClicked: {
            if (!root.player) return
            root.preferredPlayerKey = root.playerKey(root.player)
            root.player.togglePlaying()
        }
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
            if (root.downloadState === 1) return
            if (popup.containsMouse) closeDelay.stop()
            else if (root.popupOpen && !trigger.hovered) closeDelay.restart()
        }

        Column {
            id: column
            anchors.fill: parent
            spacing: Style.space(10)

            Row {
                spacing: Style.space(10)
                width: parent.width

                BorderSurface {
                    width: Style.space(64)
                    height: Style.space(64)
                    radius: Style.spacing.labelGap
                    color: Style.normalFillFor(root.fg, Color.accent)
                    borderSpec: Border.controlSpec("normal", root.fg, Color.accent)

                    Image {
                        anchors.fill: parent
                        anchors.margins: Style.space(2)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        visible: source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.player || !root.player.trackArtUrl
                        text: "󰝚"
                        color: root.fg
                        font.family: root.fontFam
                        font.pixelSize: Style.font.displayLarge
                    }
                }

                Column {
                    spacing: Style.space(4)
                    width: parent.width - Style.space(74)

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
                }
            }

            Item {
                id: progressArea
                width: parent.width
                height: Style.space(12)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(4)
                    radius: height / 2
                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    height: Style.space(4)
                    width: parent.width * (root.progressDrag >= 0 ? root.progressDrag : root.progress)
                    radius: height / 2
                    color: root.fg
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: function(mouse) { root.seekTo(mouse.x, progressArea.width) }
                    onPositionChanged: function(mouse) { if (pressed) root.seekTo(mouse.x, progressArea.width) }
                    onReleased: root.progressDrag = -1
                }
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
                        id: repeatButton
                        iconText: "\uf01e"
                        foreground: root.fg
                        selected: root.repeatActive
                        enabled: root.repeatEnabled
                        opacity: root.repeatEnabled ? 1.0 : 0.4
                        onClicked: root.toggleRepeat()
                    }
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
                    Button {
                        id: shuffleButton
                        iconText: "\uf074"
                        foreground: root.fg
                        selected: root.shuffleActive
                        enabled: root.shuffleEnabled
                        opacity: root.shuffleEnabled ? 1.0 : 0.4
                        onClicked: root.toggleShuffle()
                    }
                }
            }

            Row {
                width: parent.width
                spacing: Style.space(6)

                Button {
                    iconText: "\uf130"
                    foreground: root.fg
                    selected: root.showMiniCava
                    tooltipText: root.showMiniCava ? "Hide bar visualizer" : "Show bar visualizer"
                    onClicked: root.showMiniCava = !root.showMiniCava
                }

                Text {
                    text: "Bar visualizer"
                    color: Qt.darker(root.fg, 1.3)
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            PanelSeparator {
            }

            CavaVisualizer {
                width: parent.width
                height: Style.space(60)
                running: root.popupOpen
            }

            PanelSeparator {
                visible: root.players.length > 1
            }

            Column {
                id: sourceList
                visible: root.players.length > 1
                width: parent.width
                spacing: Style.space(4)

                Repeater {
                    model: root.players

                    BorderSurface {
                        id: sourceRow
                        required property var modelData

                        readonly property var sourcePlayer: modelData
                        readonly property bool active: root.player && sourcePlayer
                            && root.playerKey(root.player) === root.playerKey(sourcePlayer)
                        readonly property string sourceTitle: sourcePlayer
                            ? (sourcePlayer.trackTitle || sourcePlayer.identity || sourcePlayer.desktopEntry || "Media source")
                            : "Media source"
                        readonly property string sourceDetail: sourcePlayer && sourcePlayer.trackArtist
                            ? sourcePlayer.trackArtist
                            : (sourcePlayer && sourcePlayer.identity ? sourcePlayer.identity : "")

                        width: sourceList.width
                        height: sourceInner.implicitHeight + Style.space(10)
                        radius: Style.cornerRadius
                        color: active ? Style.selectedFillFor(root.fg, Color.accent) : "transparent"
                        borderSpec: active ? Border.controlSpec("normal", root.fg, Color.accent) : Border.none()

                        Row {
                            id: sourceInner
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: sourceRow.borderLeft + Style.space(8)
                            anchors.rightMargin: sourceRow.borderRight + Style.space(8)
                            spacing: Style.space(8)

                            Text {
                                text: sourceRow.sourcePlayer && sourceRow.sourcePlayer.isPlaying ? "󰏤" : "󰐊"
                                color: root.fg
                                font.family: root.fontFam
                                font.pixelSize: Style.font.body
                                width: Style.space(18)
                                horizontalAlignment: Text.AlignHCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                width: parent.width - Style.space(26)
                                spacing: Style.space(1)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: sourceRow.sourceTitle
                                    color: root.fg
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: sourceRow.active
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: sourceRow.sourceDetail
                                    color: Qt.darker(root.fg, 1.5)
                                    font.family: root.fontFam
                                    font.pixelSize: Style.font.caption
                                    elide: Text.ElideRight
                                    width: parent.width
                                    visible: text !== ""
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!sourceRow.sourcePlayer) return
                                root.preferredPlayerKey = root.playerKey(sourceRow.sourcePlayer)
                                sourceRow.sourcePlayer.togglePlaying()
                            }
                        }
                    }
                }
            }

            PanelSeparator {
            }

            Button {
                id: downloadBtn
                width: parent.width
                iconText: root.downloadState === 2 ? "\uf110"
                    : root.downloadState === 3 ? "\uf00c"
                    : root.downloadState === 4 ? "\uf00d"
                    : root.downloadState === 5 || root.downloadState === 6 ? "\uf06a"
                    : root.downloadState === 7 ? "\uf071"
                    : root.downloadState === 1 ? "\uf00d"
                    : "\uf019"
                iconSpinning: root.downloadState === 2
                text: root.downloadButtonLabel()
                foreground: root.fg
                fontSize: Style.font.bodySmall
                tooltipText: root.downloadState === 2 ? "Click to cancel"
                    : root.downloadState === 4 ? "Click to retry"
                    : ""
                onClicked: {
                    if (root.downloadState === 0 || root.downloadState === 5
                        || root.downloadState === 3 || root.downloadState === 4
                        || root.downloadState === 7 || root.downloadState === 6)
                        root.downloadTrack()
                    else if (root.downloadState === 2) root.cancelDownload()
                    else if (root.downloadState === 1) root.downloadTrack()
                }
            }

            Rectangle {
                width: parent.width
                height: root.downloadState === 1 ? urlInput.implicitHeight + Style.space(16) : 0
                color: Color?.alpha(root.fg, 0.06) ?? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
                radius: Style.radius(6)
                clip: true
                visible: root.downloadState === 1
                Behavior on height { NumberAnimation { duration: 150 } }

                TextInput {
                    id: urlInput
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    color: root.fg
                    font.family: root.fontFam
                    font.pixelSize: Style.font.bodySmall
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    selectionColor: Color.accent
                    echoMode: TextInput.Normal
                    visible: root.downloadState === 1
                    focus: root.downloadState === 1
                    activeFocusOnTab: false
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Paste YouTube URL..."
                        color: Qt.darker(root.fg, 1.5)
                        font.family: root.fontFam
                        font.pixelSize: Style.font.bodySmall
                        visible: !urlInput.text && !urlInput.activeFocus
                    }
                    onAccepted: root.submitUrl()
                    Keys.onEscapePressed: {
                        root.downloadState = 0
                        root.inputUrl = ""
                        root.downloadError = ""
                    }
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.MetaModifier)) {
                            urlInput.paste()
                            event.accepted = true
                        } else if (event.key === Qt.Key_V && event.modifiers === Qt.NoModifier) {
                            urlInput.paste()
                            event.accepted = true
                        }
                    }
                    Connections {
                        target: root
                        function onDownloadStateChanged() {
                            if (root.downloadState === 1) {
                                urlInput.text = ""
                                urlInput.forceActiveFocus()
                            }
                        }
                    }
                    Binding on text { value: root.inputUrl; when: false }
                    onTextChanged: root.inputUrl = text
                }
            }

            Button {
                width: parent.width
                text: "Go"
                foreground: root.fg
                fontSize: Style.font.bodySmall
                visible: root.downloadState === 1
                onClicked: root.submitUrl()
            }

            PanelSeparator {
                visible: root.downloadError !== "" && root.downloadState !== 3
            }

            Text {
                visible: root.downloadError !== "" && root.downloadState !== 3
                width: parent.width
                text: root.downloadError
                color: Qt.darker(root.fg, 1.5)
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
