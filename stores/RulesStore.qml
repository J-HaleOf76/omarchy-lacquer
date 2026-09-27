import QtQuick
import Quickshell
import Quickshell.Io

// Per-app window rules: how one app's windows look and where they land.
//
// The rules live in Lacquer's state file and are rendered into its block in
// hypr/hyprland.lua (StyleLua.renderWindowRules), next to the blanket opacity
// rule — the same place Omarchy's own template invites personal rules. A rule
// only exists while an app is listed here, so removing one removes its lines.
Item {
  id: root
  visible: false

  required property var app

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: root.home + "/.local/state/omarchy/io.github.deunnis.lacquer/rules.json"

  // [{ match, name, float, center, pin, width, height, workspace, monitor, opacity,
  //    noBlur, noShadow, noBorder, noRounding }]
  property var rules: []
  property bool loaded: false

  // Windows on screen right now, so a rule can be made by pointing at one.
  property var clients: []
  property string picked: ""

  readonly property var known: {
    var seen = {}
    var out = []
    for (var i = 0; i < root.rules.length; i++) {
      seen[root.rules[i].match] = true
      out.push({ match: root.rules[i].match, name: root.rules[i].name || root.rules[i].match, ruled: true })
    }
    for (var j = 0; j < root.clients.length; j++) {
      var c = root.clients[j]
      if (!c.class || seen[c.class]) continue
      seen[c.class] = true
      out.push({ match: c.class, name: c.class, ruled: false })
    }
    return out
  }

  readonly property var current: root.ruleFor(root.picked)

  function ruleFor(match) {
    for (var i = 0; i < root.rules.length; i++)
      if (root.rules[i].match === match) return root.rules[i]
    return null
  }

  function clone(r) {
    return { match: String(r.match || ""), name: String(r.name || r.match || ""),
             float: r.float === true ? true : (r.float === false ? false : undefined),
             center: r.center === true, pin: r.pin === true,
             width: Number(r.width) || 0, height: Number(r.height) || 0,
             workspace: String(r.workspace || ""),
             monitor: String(r.monitor || ""),
             opacity: r.opacity === undefined || r.opacity === "" ? "" : Number(r.opacity),
             noBlur: r.noBlur === true, noShadow: r.noShadow === true,
             noBorder: r.noBorder === true, noRounding: r.noRounding === true }
  }

  function save(list, label) {
    root.app.beginEdit()
    var out = []
    for (var i = 0; i < list.length; i++) out.push(root.clone(list[i]))
    root.rules = out
    stateFile.setText(JSON.stringify(root.rules, null, 2) + "\n")
    root.app.commitEdit(label)
    // A window rule is not something `hyprctl eval` can preview into place, so
    // it only starts applying once the file is written and reloaded.
    root.app.hypr.persistNow()
  }

  function restoreRules(list) {
    if (!list) return
    var out = []
    for (var i = 0; i < list.length; i++) out.push(root.clone(list[i]))
    root.rules = out
    stateFile.setText(JSON.stringify(root.rules, null, 2) + "\n")
  }

  // Change one field of the picked app's rule, creating the rule if needed.
  function set(field, value, label) {
    if (!root.picked) return
    var list = []
    var found = false
    for (var i = 0; i < root.rules.length; i++) {
      var r = root.clone(root.rules[i])
      if (r.match === root.picked) { r[field] = value; found = true }
      list.push(r)
    }
    if (!found) {
      var fresh = root.clone({ match: root.picked, name: root.picked })
      fresh[field] = value
      list.push(fresh)
    }
    root.save(list, label + " · " + root.picked)
  }

  function setSize(w, h) {
    if (!root.picked) return
    var list = []
    var found = false
    for (var i = 0; i < root.rules.length; i++) {
      var r = root.clone(root.rules[i])
      if (r.match === root.picked) { r.width = w; r.height = h; found = true }
      list.push(r)
    }
    if (!found) {
      var fresh = root.clone({ match: root.picked, name: root.picked })
      fresh.width = w
      fresh.height = h
      list.push(fresh)
    }
    root.save(list, (w > 0 ? "Size " + w + "×" + h : "Size follows the layout") + " · " + root.picked)
  }

  function forget(match) {
    var list = []
    for (var i = 0; i < root.rules.length; i++)
      if (root.rules[i].match !== match) list.push(root.rules[i])
    root.save(list, "Rules for " + match + " removed")
  }

  function rescan() {
    if (!clientsProc.running) clientsProc.running = true
    if (!stateRead.running && !root.loaded) stateRead.running = true
  }

  FileView {
    id: stateFile
    path: root.statePath
    preload: false
    printErrors: false
    atomicWrites: true
  }

  Process {
    id: clientsProc
    command: ["timeout", "-k", "2", "10", "hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.clients = Array.isArray(parsed) ? parsed : []
        } catch (e) {
          root.clients = []
        }
        if (root.picked === "" && root.known.length > 0) root.picked = root.known[0].match
      }
    }
  }

  Process {
    id: stateRead
    command: ["timeout", "-k", "1", "5", root.app.pluginDir + "/read-state", root.statePath, "65536"]
    running: true
    stdout: StdioCollector { id: stateOut; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        try {
          var parsed = JSON.parse(stateOut.text)
          if (Array.isArray(parsed)) {
            var out = []
            for (var i = 0; i < parsed.length && i < 200; i++)
              if (parsed[i] && parsed[i].match) out.push(root.clone(parsed[i]))
            root.rules = out
          }
        } catch (e) { }
      }
      root.loaded = true
      if (root.picked === "" && root.rules.length > 0) root.picked = root.rules[0].match
    }
  }
}
