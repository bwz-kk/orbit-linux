import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import qs.Ui as Ui

// Orbit popup: polls bin/orbit-status, renders the detail card, and sends
// connect/disconnect notifications. All colors come from the omarchy theme.
Ui.Panel {
  id: root
  moduleName: "bwzkk.orbit"
  ipcTarget: "bwzkk.orbit"

  property var anchorItem: null
  property var hostWidget: null

  readonly property string script: decodeURIComponent(String(Qt.resolvedUrl("bin/orbit-status")).replace(/^file:\/\//, ""))

  property var st: ({ state: "disconnected" })
  readonly property var headset: st.headset || ({})
  readonly property var leftCtl: st.left || ({ level: null, status: "Off" })
  readonly property var rightCtl: st.right || ({ level: null, status: "Off" })
  readonly property bool connected: st.state === "connected"
  readonly property string model: st.model || lastModel
  property string lastModel: "Meta Quest"
  property var wasOnline: null         // null until the first poll, so startup is silent
  property real now: Date.now()
  property var chargeStart: null       // {t, level} when charging began, for the ETA
  property int etaMinutes: -1
  property string actionError: ""

  readonly property string label: "󰢔" + (headset.level != null ? " " + headset.level + "%" : "")

  // ---- Theme shorthands
  readonly property color fg: Commons.Color.popups.text
  readonly property color muted: Commons.Color.muted
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent

  function levelText(l) { return l == null ? "—" : l + "%" }
  function levelColor(l) { return l != null && l <= 20 ? urgent : accent }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function runAction(arg) {
    if (actionProc.running) return
    actionError = ""
    actionProc.command = [script, arg]
    actionProc.running = true
  }

  function notify(title, body) {
    if (notifyProc.running) return
    notifyProc.command = ["notify-send", "-a", "Orbit", "-r", "9101", title, body]
    notifyProc.running = true
  }

  function summary() {
    return "Headset " + levelText(headset.level) + " · L " + levelText(leftCtl.level) + " · R " + levelText(rightCtl.level)
  }

  function updateEta() {
    var lvl = headset.level
    if (!connected || !headset.charging || lvl == null) { chargeStart = null; etaMinutes = -1; return }
    if (!chargeStart || lvl < chargeStart.level) { chargeStart = { t: Date.now(), level: lvl }; etaMinutes = -1; return }
    var gained = lvl - chargeStart.level
    var mins = (Date.now() - chargeStart.t) / 60000
    // ponytail: linear estimate from charge start; ignores the slow top-off above ~90%.
    etaMinutes = gained >= 2 && mins > 0 ? Math.round((100 - lvl) / (gained / mins)) : -1
  }

  function apply(text) {
    var parsed
    try { parsed = JSON.parse(text) } catch (e) { return }
    st = parsed
    if (connected) wakeBurst.stop()
    if (parsed.model) lastModel = parsed.model
    updateEta()
    // In standby the headset's Wi-Fi flaps between connected/offline every few
    // seconds. Only count it as gone after 2 min without a live reading, so
    // notifications fire on real arrivals/departures, not on each flap.
    var online = connected || (st.seen > 0 && Date.now() / 1000 - st.seen < 120)
    if (wasOnline !== null && online !== wasOnline)
      notify(model + (online ? " connected" : " disconnected"), summary())
    wasOnline = online
  }

  // st.seen is when the reading was taken; while stale it is the last good one.
  function agoText() {
    if (!st.seen) return connected ? "synced just now" : "no reading yet"
    var s = Math.max(0, Math.round(now / 1000 - st.seen))
    var t = s < 60 ? s + "s" : s < 3600 ? Math.round(s / 60) + " min" : Math.round(s / 3600) + " h"
    if (st.stale) return "last seen " + (s < 60 ? "just now" : t + " ago")
    return s < 5 ? "synced just now" : "synced " + t + " ago"
  }

  readonly property string stateText: ({
    "connected": "Live", "offline": "Asleep", "unauthorized": "Unauthorized",
    "disconnected": "No headset", "no-adb": "adb missing"
  })[st.state] || st.state

  readonly property string hint: st.state === "unauthorized" ? "Accept the USB debugging prompt inside the headset."
    : st.state === "no-adb" ? "Install adb: sudo pacman -S android-tools"
    : st.state === "offline" ? "Headset is asleep or Wi-Fi ADB dropped."
    : st.state === "disconnected" ? "Plug in over USB, or Reconnect for Wi-Fi."
    : ""

  // Opening the card only shows the last reading; connecting to the headset is
  // manual (header button) so a sleeping headset is not kept awake.
  onOpenedChanged: if (opened) now = Date.now()

  // Connecting the Quest from the Bluetooth menu wakes it, but its Wi-Fi takes
  // a while to come back. Watch for that connect and poll every 5 s for up to
  // 2 min instead of waiting for the next 30-60 s poll.
  readonly property var questBt: {
    var devs = Bluetooth.devices ? Bluetooth.devices.values : []
    for (var i = 0; i < devs.length; i++)
      if (String(devs[i].name || "").indexOf("Quest") === 0) return devs[i]
    return null
  }
  readonly property bool btConnected: questBt ? questBt.connected === true : false
  onBtConnectedChanged: if (btConnected && !connected) { wakeBurst.left = 24; wakeBurst.restart() }

  Process {
    id: statusProc
    command: [root.script]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.actionError = String(text || "").trim()
    }
    onExited: function(code) {
      if (code === 0) root.actionError = ""
      root.refresh()
    }
  }

  Process { id: notifyProc }

  // Background polling; the card being open does not speed it up.
  Timer {
    interval: root.connected ? 60000 : 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: wakeBurst
    property int left: 0
    interval: 5000
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refresh()
      if (--left <= 0) stop()
    }
  }

  Timer {
    interval: 1000
    running: root.opened
    repeat: true
    onTriggered: root.now = Date.now()
  }

  // ---- Reusable bits
  component Label: Text {
    color: Commons.Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    textFormat: Text.PlainText
    elide: Text.ElideRight
  }

  component Card: Rectangle {
    radius: Style.cornerRadius
    color: Style.normalFill
    border.color: Style.normalBorderColor
    border.width: 1
  }

  component Chip: Rectangle {
    property alias text: chipLabel.text
    visible: text !== ""
    radius: Style.cornerRadius
    color: Commons.Util.alpha(Commons.Color.accent, 0.12)
    implicitWidth: chipLabel.implicitWidth + Style.space(14)
    implicitHeight: chipLabel.implicitHeight + Style.space(6)
    Label {
      id: chipLabel
      anchors.centerIn: parent
      color: Commons.Color.accent
      font.pixelSize: Style.font.bodySmall
    }
  }

  component ControllerCard: Card {
    property string side: ""
    property var info: ({})
    function lvlColor(l) { return l != null && l <= 20 ? Commons.Color.urgent : Commons.Color.accent }
    readonly property bool hasLevel: info.level != null
    implicitHeight: ctlCol.implicitHeight + Style.space(28)

    Column {
      id: ctlCol
      anchors.fill: parent
      anchors.margins: Style.space(14)
      spacing: Style.space(8)

      Item {
        width: parent.width
        height: ctlName.implicitHeight
        Label { id: ctlName; text: "󰊴  " + (side === "L" ? "Left" : "Right"); font.pixelSize: Style.font.subtitle }
        Label { anchors.right: parent.right; text: side; color: Commons.Color.accent; font.bold: true }
      }

      Label {
        text: hasLevel ? info.level + "%" : "—"
        color: hasLevel ? lvlColor(info.level) : Commons.Color.muted
        font.pixelSize: Style.font.displayLarge
        font.bold: true
      }

      Rectangle {
        width: parent.width
        height: Style.space(6)
        radius: height / 2
        color: Commons.Util.alpha(Commons.Color.accent, 0.15)
        Rectangle {
          width: parent.width * (hasLevel ? info.level / 100 : 0)
          height: parent.height
          radius: parent.radius
          color: lvlColor(info.level)
        }
      }

      Label { text: info.status || "Off"; color: Commons.Color.muted; font.pixelSize: Style.font.bodySmall }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.item ? content.item.implicitHeight : 0)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // Card UI exists only while the popup is open.
      Loader {
        id: content
        width: parent.width
        active: root.opened
        sourceComponent: Column {
          width: content.width
          spacing: Style.space(12)

          // ---- Header
          Item {
            width: parent.width
            height: Math.max(titleCol.implicitHeight, refreshBtn.implicitHeight)

            Rectangle {
              id: logo
              width: Style.space(40); height: width
              radius: Style.cornerRadius
              color: Commons.Util.alpha(root.accent, 0.15)
              anchors.verticalCenter: parent.verticalCenter
              Label { anchors.centerIn: parent; text: "󰢔"; color: root.accent; font.pixelSize: Style.font.iconLarge }
            }

            Column {
              id: titleCol
              anchors.left: logo.right
              anchors.leftMargin: Style.space(12)
              anchors.right: pill.left
              anchors.verticalCenter: parent.verticalCenter
              Label { width: parent.width; text: "Orbit"; font.pixelSize: Style.font.heading; font.bold: true }
              Label { width: parent.width; text: root.model + (root.st.os ? " · OS " + root.st.os : ""); color: root.muted; font.pixelSize: Style.font.bodySmall }
            }

            Rectangle {
              id: pill
              anchors.right: refreshBtn.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              readonly property color tone: root.connected ? root.accent
                : (root.st.state === "unauthorized" || root.st.state === "no-adb") ? root.urgent : root.muted
              radius: height / 2
              color: Commons.Util.alpha(tone, 0.15)
              implicitWidth: pillRow.implicitWidth + Style.space(18)
              implicitHeight: pillRow.implicitHeight + Style.space(8)
              Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: Style.space(6)
                Rectangle { width: Style.space(7); height: width; radius: width / 2; color: pill.tone; anchors.verticalCenter: parent.verticalCenter }
                Label { text: root.stateText; color: pill.tone; font.pixelSize: Style.font.bodySmall }
              }
            }

            Button {
              id: refreshBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              iconText: "󰑐"
              iconSpinning: statusProc.running
              bordered: true
              tooltipText: "Connect & update"
              onClicked: root.refresh()
            }
          }

          Label {
            width: parent.width
            visible: root.hint !== ""
            text: root.hint
            wrapMode: Text.WordWrap
            color: root.st.state === "unauthorized" || root.st.state === "no-adb" ? root.urgent : root.muted
          }

          // ---- Headset
          Card {
            width: parent.width
            implicitHeight: Math.max(ring.height, headCol.implicitHeight) + Style.space(32)
            opacity: root.connected ? 1 : 0.5

            Canvas {
              id: ring
              anchors.left: parent.left
              anchors.leftMargin: Style.space(16)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(104); height: width
              readonly property real value: root.headset.level != null ? root.headset.level / 100 : 0
              readonly property color fill: root.levelColor(root.headset.level)
              readonly property color track: Commons.Util.alpha(root.accent, 0.15)
              onValueChanged: requestPaint()
              onFillChanged: requestPaint()
              onTrackChanged: requestPaint()
              onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var lw = width * 0.09, r = (width - lw) / 2, c = width / 2
                ctx.lineWidth = lw
                ctx.lineCap = "round"
                ctx.strokeStyle = track
                ctx.beginPath(); ctx.arc(c, c, r, 0, 2 * Math.PI); ctx.stroke()
                if (value > 0) {
                  ctx.strokeStyle = fill
                  ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * value); ctx.stroke()
                }
              }

              Column {
                anchors.centerIn: parent
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: root.levelText(root.headset.level); font.pixelSize: Style.font.display; font.bold: true }
                Label { anchors.horizontalCenter: parent.horizontalCenter; text: "headset"; color: root.muted; font.pixelSize: Style.font.caption }
              }
            }

            Column {
              id: headCol
              anchors.left: ring.right
              anchors.leftMargin: Style.space(18)
              anchors.right: parent.right
              anchors.rightMargin: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Label { text: "Headset"; font.pixelSize: Style.font.title; font.bold: true }
              Label {
                width: parent.width
                wrapMode: Text.WordWrap
                color: root.headset.charging && !root.st.stale ? root.accent : root.muted
                text: root.st.stale ? root.stateText + " · " + root.agoText()
                  : (root.headset.charging ? "󱐋 " : "") + (root.headset.status || "—")
                    + (root.etaMinutes > 0 ? " · full in ~" + root.etaMinutes + " min" : "")
              }
              Flow {
                width: parent.width
                spacing: Style.space(6)
                Chip { text: root.headset.temp != null ? Math.round(root.headset.temp) + "°C" : "" }
                Chip { text: root.headset.plug || "" }
                Chip { text: root.headset.worn || "" }
              }
            }
          }

          // ---- Controllers
          Row {
            width: parent.width
            spacing: Style.space(12)
            ControllerCard { width: (parent.width - parent.spacing) / 2; side: "L"; info: root.leftCtl; opacity: root.connected ? 1 : 0.5 }
            ControllerCard { width: (parent.width - parent.spacing) / 2; side: "R"; info: root.rightCtl; opacity: root.connected ? 1 : 0.5 }
          }

          // ---- Connection
          Card {
            width: parent.width
            implicitHeight: connRow.implicitHeight + Style.space(24)
            Row {
              id: connRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(14)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(12)
              Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.st.transport === "wifi" ? "󰖩" : "󰕓"
                color: root.accent
                font.pixelSize: Style.font.iconLarge
              }
              Column {
                anchors.verticalCenter: parent.verticalCenter
                Label {
                  text: !root.st.transport ? "Not connected"
                    : root.st.transport === "wifi" ? "Wi-Fi" + (root.st.ip ? " · " + root.st.ip : "")
                    : "USB" + (root.st.ip ? " · Wi-Fi " + root.st.ip : "")
                  font.pixelSize: Style.font.subtitle
                }
                Label { text: root.agoText(); color: root.muted; font.pixelSize: Style.font.bodySmall }
              }
            }
          }

          Label {
            width: parent.width
            visible: root.actionError !== ""
            text: root.actionError
            wrapMode: Text.WordWrap
            color: root.urgent
          }

          // ---- Actions
          Row {
            width: parent.width
            spacing: Style.space(12)
            Button {
              width: (parent.width - parent.spacing) / 2
              text: actionProc.running ? "Working…" : "Set up Wi-Fi"
              bordered: true
              active: true
              enabled: !actionProc.running && root.connected && root.st.transport === "usb"
              tooltipText: "Switch this USB-connected headset to wireless ADB"
              onClicked: root.runAction("wifi")
            }
            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Reconnect"
              bordered: true
              enabled: !actionProc.running
              tooltipText: "adb connect to the saved Wi-Fi address"
              onClicked: root.runAction("reconnect")
            }
          }
        }
      }
    }
  }
}
