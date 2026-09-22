import QtQuick
import Quickshell
import Quickshell.Io
import "../StyleLua.js" as StyleLua

// Screens: resolution, refresh rate, scale and placement.
//
// A wrong mode can leave a screen black with no way back, so nothing here is
// written first: a change is applied live through `hyprctl eval`, and then it
// has to be confirmed inside KEEP_SECONDS. Without a confirmation the previous
// settings are put back and the file is never touched — the pattern every
// desktop's display settings use.
Item {
  id: root
  visible: false

  required property var app

  readonly property string home: Quickshell.env("HOME")
  readonly property string path: root.home + "/.config/hypr/monitors.lua"
  readonly property int keepSeconds: 10

  // The file as last read, so a write never starts from a stale or empty copy.
  property string fileText: ""

  // What Hyprland reports right now.
  property var monitors: []
  property bool scanned: false

  // The change waiting to be confirmed, and what to go back to without one.
  property var pending: null
  property var previous: null
  property int countdown: 0
  readonly property bool asking: root.pending !== null

  function rescan() {
    if (!readProc.running) readProc.running = true
    // Never ask Hyprland what it has while a trial is on screen: the answer
    // would be the trial, and that is exactly what a revert has to undo.
    if (root.asking || scanProc.running) return
    scanProc.running = true
  }

  Component.onCompleted: root.rescan()

  function monitorFor(name) {
    for (var i = 0; i < root.monitors.length; i++)
      if (root.monitors[i].name === name) return root.monitors[i]
    return null
  }

  // Hyprland reports modes as "1920x1080@59.98000Hz"; keep one entry per
  // resolution plus refresh rate, newest first, and tidy the numbers.
  function modesOf(name) {
    var m = root.monitorFor(name)
    if (!m) return []
    var seen = {}
    var out = []
    for (var i = 0; i < (m.availableModes || []).length; i++) {
      var raw = String(m.availableModes[i])
      var parsed = raw.match(/^(\d+)x(\d+)@([\d.]+)/)
      if (!parsed) continue
      var value = parsed[1] + "x" + parsed[2] + "@" + Number(parsed[3]).toFixed(2)
      if (seen[value]) continue
      seen[value] = true
      out.push({ value: value,
                 label: parsed[1] + "×" + parsed[2] + "  " + Math.round(Number(parsed[3])) + " Hz",
                 width: Number(parsed[1]), height: Number(parsed[2]), hz: Number(parsed[3]) })
    }
    out.sort(function(a, b) { return (b.width * b.height - a.width * a.height) || (b.hz - a.hz) })
    return out
  }

  function currentMode(name) {
    var m = root.monitorFor(name)
    if (!m) return ""
    return m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2)
  }

  function specOf(m) {
    return { name: m.name, mode: root.currentMode(m.name),
             position: Math.round(m.x) + "x" + Math.round(m.y),
             scale: Number(m.scale), transform: Number(m.transform || 0) }
  }

  // Every monitor as it stands, with one of them changed.
  function specsWith(name, change) {
    var out = []
    for (var i = 0; i < root.monitors.length; i++) {
      var spec = root.specOf(root.monitors[i])
      if (spec.name === name)
        for (var k in change) spec[k] = change[k]
      out.push(spec)
    }
    return out
  }

  function applyLive(specs) {
    var lines = StyleLua.renderMonitorsBody(specs)
    if (!lines) return
    liveProc.command = ["timeout", "-k", "1", "5", "hyprctl", "eval", "--", lines]
    liveProc.running = true
  }

  // Try a change: apply it live and start the countdown.
  function propose(name, change, label) {
    // Trying a second thing without answering the first goes back to what the
    // screens were before any of it — not to the trial that is on screen now.
    // The new trial is applied straight over the old one rather than putting
    // the screen back in between, which would be two mode changes in a row.
    var before = root.asking ? root.previous : root.specsWith(name, {})
    if (root.asking) {
      root.pending = null
      keepTimer.stop()
    }
    root.previous = before
    root.pending = { specs: root.specsWith(name, change), label: label }
    root.countdown = root.keepSeconds
    root.applyLive(root.pending.specs)
    keepTimer.restart()
    root.app.statusText = label + " — keep it?"
  }

  function keep() {
    if (!root.asking) return
    var specs = root.pending.specs
    var label = root.pending.label
    root.pending = null
    keepTimer.stop()
    root.countdown = 0
    root.writeBlock(StyleLua.renderMonitorsBody(specs))
    root.app.statusText = label + " \u2014 kept"
  }

  function revert() {
    if (!root.asking) return
    var back = root.previous
    root.pending = null
    keepTimer.stop()
    root.countdown = 0
    if (back) root.applyLive(back)
    root.app.statusText = "Put the screen back"
    // The rescan waits for the change to land — settleTimer does it.
  }

  // Everything Lacquer wrote here goes; Omarchy's own lines stay.
  function forget() {
    root.writeBlock("")
    root.app.statusText = "Screens follow Omarchy's own settings again"
  }

  // monitors-write owns the file: it replaces only what is between the fences,
  // through a temporary file in the same folder, so a crash mid-write cannot
  // leave half a config behind.
  function writeBlock(body) {
    writeProc.command = body === ""
      ? ["timeout", "-k", "2", "10", root.app.pluginDir + "/monitors-write", "--clear"]
      : ["bash", "-c", 'printf "%s\\n" "$2" | "$1"', "lacquer-monitors",
         root.app.pluginDir + "/monitors-write", body]
    writeProc.running = true
  }

  readonly property bool managed: root.fileText.indexOf(StyleLua.MONITORS_BEGIN) >= 0

  Timer {
    id: keepTimer
    interval: 1000
    repeat: true
    onTriggered: {
      root.countdown -= 1
      if (root.countdown <= 0) root.revert()
    }
  }

  // A mode change is not finished when hyprctl returns: asking straight away
  // gets the old answer, or the trial's. Give it a moment, then look.
  Timer {
    id: settleTimer
    interval: 700
    onTriggered: root.rescan()
  }

  Process {
    id: liveProc
    onExited: settleTimer.restart()
  }

  Process {
    id: scanProc
    command: ["timeout", "-k", "2", "10", "hyprctl", "monitors", "all", "-j"]
    stdout: StdioCollector {
      id: scanOut
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.monitors = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.monitors = []
        }
        root.scanned = true
      }
    }
  }

  Process {
    id: writeProc
    stderr: StdioCollector { id: writeErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0)
        root.app.errorText = String(writeErr.text || "").trim() || "Could not save your screen settings (~/.config/hypr/monitors.lua)"
      root.rescan()
    }
  }

  // Only to know whether Lacquer's block is in the file; the writing helper
  // does its own reading.
  Process {
    id: readProc
    command: ["timeout", "-k", "1", "5", root.app.pluginDir + "/read-state", root.path, "1048576"]
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: function(code) { root.fileText = code === 0 ? String(readOut.text || "") : "" }
  }
}
