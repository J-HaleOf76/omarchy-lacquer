import QtQuick
import Quickshell
import Quickshell.Io

// The optional companion plugin, Lacquer Shell.
//
// Lacquer never needs it: without it the Frame section explains what it would
// add and offers to install it. Installing runs Omarchy's own
// `omarchy plugin add … --enable` in a terminal you watch, after a confirmation
// — nothing is fetched or installed quietly.
//
// Once it is there, its settings are driven over IPC exactly the way Menu look
// drives OmaMenu.
Item {
  id: root
  visible: false

  required property var app

  readonly property string repo: "https://github.com/Deunnis/omarchy-lacquer-shell"
  readonly property string pluginId: "io.github.deunnis.lacquer.shell"

  property bool present: false
  property bool probed: false
  // Whether the bar on screen is the companion's. Omarchy falls back to its own
  // bar when a replacement cannot load, and then the bar's motion settings
  // would look like they were in charge when they are not.
  property bool barIsOurs: false
  property bool confirming: false
  property var frame: null
  property var barMotion: null

  readonly property bool on: root.present && root.frame && root.frame.enabled === true

  function rescan() {
    if (!probeProc.running) probeProc.running = true
  }

  function clone(f) {
    return { enabled: f.enabled === true,
             style: f.style === "brackets" ? "brackets" : "corners",
             corners: Number(f.corners) || 0, frame: Number(f.frame) || 0,
             vignette: Number(f.vignette) || 0, scanlines: Number(f.scanlines) || 0,
             grain: Number(f.grain) || 0, tint: String(f.tint || ""),
             hideFullscreen: f.hideFullscreen !== false }
  }

  function cloneMotion(m) {
    return { enabled: m.enabled === true, duration: Number(m.duration) || 260,
             glide: m.glide !== false, hover: m.hover !== false, appear: m.appear !== false }
  }

  // The bar's motion follows Lacquer's feel: MotionStore pushes the duration
  // whenever the feel or speed changes, and the toggles below say what moves.
  function setMotion(field, value, label) {
    if (!root.present || !root.barMotion) return
    var next = root.cloneMotion(root.barMotion)
    next[field] = value
    root.barMotion = next
    motionSend.command = ["timeout", "-k", "2", "10", "omarchy-shell", "lacquer.shell",
                          "setMotion", JSON.stringify(next)]
    motionSend.running = true
    if (label) root.app.statusText = label
  }

  function pushDuration(ms) {
    if (!root.present || !root.barMotion) return
    if (Math.abs(Number(root.barMotion.duration) - ms) < 2) return
    root.setMotion("duration", Math.round(ms), "")
  }

  function set(field, value, label) {
    if (!root.present || !root.frame) return
    var next = root.clone(root.frame)
    next[field] = value
    root.frame = next
    sendProc.command = ["timeout", "-k", "2", "10", "omarchy-shell", "lacquer.shell",
                        "setFrame", JSON.stringify(next)]
    sendProc.running = true
    root.app.statusText = label
  }

  function step(field, delta, min, max, stepSize, label, suffix) {
    if (!root.frame) return
    var value = Math.max(min, Math.min(max, Math.round((Number(root.frame[field]) + delta * stepSize) * 100) / 100))
    root.set(field, value, label + " " + (suffix === "%" ? Math.round(value * 100) + " %" : value + (suffix || "")))
  }

  // Installing is the user's decision, made twice: a confirmation here, and
  // Omarchy's own installer running in a terminal in front of them.
  function askInstall() { root.confirming = true }
  function cancelInstall() { root.confirming = false }

  function install() {
    root.confirming = false
    root.app.dismiss()
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation",
                             "omarchy plugin add " + root.repo + " --enable && omarchy-restart-shell"])
  }

  Process {
    id: probeProc
    command: ["timeout", "-k", "2", "6", "omarchy-shell", "lacquer.shell", "ping"]
    stdout: StdioCollector { id: probeOut; waitForEnd: true }
    onExited: function(code) {
      root.present = code === 0 && String(probeOut.text || "").indexOf("lacquer.shell") >= 0
      root.probed = true
      if (root.present) { readProc.running = true; motionRead.running = true; barProc.running = true }
      else { root.frame = null; root.barMotion = null; root.barIsOurs = false }
    }
  }

  Process {
    id: readProc
    command: ["timeout", "-k", "2", "6", "omarchy-shell", "lacquer.shell", "frame"]
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.frame = null; return }
      try {
        root.frame = root.clone(JSON.parse(readOut.text))
      } catch (e) {
        root.frame = null
      }
    }
  }

  // `omarchy plugin list` says which bar option is live: the built-in one is
  // listed as disabled while a replacement is in use.
  Process {
    id: barProc
    command: ["timeout", "-k", "2", "10", "bash", "-c",
              "omarchy plugin list | grep -E '^omarchy.bar +disabled'"]
    onExited: function(code) { root.barIsOurs = code === 0 }
  }

  Process {
    id: motionRead
    command: ["timeout", "-k", "2", "6", "omarchy-shell", "lacquer.shell", "motion"]
    stdout: StdioCollector { id: motionOut; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.barMotion = null; return }
      try {
        root.barMotion = root.cloneMotion(JSON.parse(motionOut.text))
      } catch (e) {
        root.barMotion = null
      }
    }
  }

  Process {
    id: motionSend
    stderr: StdioCollector { id: motionErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) root.app.errorText = String(motionErr.text || "").trim() || "Lacquer Shell did not answer"
    }
  }

  Process {
    id: sendProc
    stderr: StdioCollector { id: sendErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) root.app.errorText = String(sendErr.text || "").trim() || "Lacquer Shell did not answer"
    }
  }
}
