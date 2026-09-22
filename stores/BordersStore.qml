import QtQuick
import Quickshell
import Quickshell.Io

// Border decoration: a gradient derived from the theme's own border colour.
//
// The settings live in Lacquer's own state file rather than in the managed
// block, because what the block carries is generated Lua (see
// StyleLua.renderBorders) that derives colours at config-load time — there is
// no colour in it to read back. Every change re-renders the block and previews
// through the same HyprStore paths as the rest of the look.
Item {
  id: root
  visible: false

  required property var app

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: root.home + "/.local/state/omarchy/io.github.deunnis.lacquer/borders.json"

  // mode: "" (leave the theme alone), lighter, darker, unfocused, hue.
  property var spec: ({ mode: "", amount: 0.4, angle: 45, inactive: false, groups: true })
  property bool loaded: false

  readonly property bool on: root.spec && root.modes.indexOf(root.spec.mode) >= 0
  readonly property var modes: ["lighter", "darker", "unfocused", "hue"]

  readonly property string modeLabel: {
    switch (root.spec.mode) {
      case "lighter": return "Lighter"
      case "darker": return "Darker"
      case "unfocused": return "Towards unfocused"
      case "hue": return "Hue shift"
      default: return "Theme colour"
    }
  }

  function clone(s) {
    return { mode: String(s.mode || ""), amount: Number(s.amount), angle: Number(s.angle),
             inactive: s.inactive === true, groups: s.groups === true }
  }

  function write(next, label) {
    root.app.beginEdit()
    root.spec = root.clone(next)
    stateFile.setText(JSON.stringify(root.spec, null, 2) + "\n")
    root.app.hypr.livePreview()
    root.app.commitEdit(label)
    // A gradient only reaches Hyprland from the file: `hyprctl eval` applies
    // it, but a later reload would drop it if the block had not caught up.
    root.app.hypr.persistNow()
  }

  // Undo hands the whole spec back; the file follows, but nothing is committed
  // again — this is already the undo of an earlier commit.
  function restoreSpec(spec) {
    if (!spec) return
    root.spec = root.clone(spec)
    stateFile.setText(JSON.stringify(root.spec, null, 2) + "\n")
  }

  function setMode(mode) {
    var next = root.clone(root.spec)
    next.mode = root.modes.indexOf(mode) >= 0 ? mode : ""
    root.write(next, next.mode === "" ? "Border follows the theme" : "Border gradient: " + mode)
  }

  function stepAngle(delta) {
    var next = root.clone(root.spec)
    next.angle = ((Math.round(next.angle / 15) * 15) + delta * 15 + 360) % 360
    root.write(next, "Fade direction " + next.angle + "°")
  }

  function stepAmount(delta) {
    var next = root.clone(root.spec)
    next.amount = Math.max(0.05, Math.min(0.95, Math.round((next.amount + delta * 0.05) * 100) / 100))
    root.write(next, "Fade " + Math.round(next.amount * 100) + " %")
  }

  function toggle(key, on) {
    var next = root.clone(root.spec)
    next[key] = on === true
    root.write(next, (key === "groups" ? "Group bar gradient " : "Unfocused gradient ") + (on ? "on" : "off"))
  }

  // The angle only turns while Hyprland animates it; the leaf is what makes it
  // spin, so the two live together in the section.
  readonly property bool spinning: {
    var leaf = root.app.hypr.leaves["borderangle"]
    return !!(leaf && leaf.enabled && String(leaf.style || "") === "loop")
  }

  function setSpin(on) {
    root.app.beginEdit()
    if (on) root.app.hypr.setLeaf("borderangle", { enabled: true, speed: 100, bezier: "linear", style: "loop" }, false)
    else root.app.hypr.setLeaf("borderangle", { enabled: false, speed: 1, bezier: "default", style: "" }, false)
    root.app.commitEdit(on ? "Gradient spins" : "Gradient still")
  }

  FileView {
    id: stateFile
    path: root.statePath
    preload: false
    printErrors: false
    atomicWrites: true
  }

  Process {
    id: stateRead
    command: ["timeout", "-k", "1", "5", root.app.pluginDir + "/read-state", root.statePath, "4096"]
    running: true
    stdout: StdioCollector { id: stateOut; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        try {
          var parsed = JSON.parse(stateOut.text)
          if (parsed && typeof parsed === "object") {
            root.spec = root.clone({
              mode: parsed.mode,
              amount: isFinite(parsed.amount) ? parsed.amount : 0.4,
              angle: isFinite(parsed.angle) ? parsed.angle : 45,
              inactive: parsed.inactive,
              groups: parsed.groups
            })
          }
        } catch (e) { }
      }
      root.loaded = true
    }
  }
}
