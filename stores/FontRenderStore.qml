import QtQuick
import Quickshell
import Quickshell.Io

// How text is drawn: smoothing, hinting and subpixel order.
//
// These are fontconfig's, not Hyprland's, and Lacquer owns one file of its
// own for them — ~/.config/fontconfig/conf.d/99-lacquer-rendering.conf — so
// the user's own fonts.conf is never touched. "Back to normal" leaves the file
// in place with nothing in it, which is exactly the same as not having it;
// lacquer-cleanup removes it.
//
// Nothing here can be previewed: an app reads fontconfig when it starts.
Item {
  id: root
  visible: false

  required property var app

  readonly property string path: app.home + "/.config/fontconfig/conf.d/99-lacquer-rendering.conf"

  // What the system does with no help from Lacquer, measured once with
  // fc-match, so the page can show the truth rather than a guess.
  property var base: ({ antialias: true, hintstyle: "hintslight", rgba: "none" })
  // What Lacquer has written, or {} when it has written nothing.
  property var chosen: ({})
  property bool loaded: false

  readonly property bool touched: Object.keys(root.chosen).length > 0

  function valueOf(name) {
    if (root.chosen[name] !== undefined) return root.chosen[name]
    return root.base[name]
  }

  function isSet(name) { return root.chosen[name] !== undefined }

  // ------------------------------------------------------------------ write

  function write(name, value) {
    var next = {}
    // Everything is written out together: a file with one edit in it would
    // leave the other two at whatever the system happened to be doing, which
    // is not what the page shows.
    var names = ["antialias", "hintstyle", "rgba"]
    for (var i = 0; i < names.length; i++) next[names[i]] = root.valueOf(names[i])
    next[name] = value
    root.chosen = next
    save(render(next), "Text drawing changed. Apps pick it up when they start.")
  }

  function resetAll() {
    root.chosen = ({})
    save(render(null), "Text drawing back to normal.")
  }

  // The folder is fontconfig's own and may not exist yet, so it is made just
  // before the first write and never otherwise.
  property string pending: ""
  property string pendingStatus: ""

  function save(text, status) {
    root.pending = text
    root.pendingStatus = status
    makeDir.running = true
  }

  Process {
    id: makeDir
    command: ["mkdir", "-p", root.app.home + "/.config/fontconfig/conf.d"]
    onExited: function(code) {
      if (code !== 0) {
        root.app.errorText = "Could not make ~/.config/fontconfig/conf.d, so nothing was written."
        return
      }
      file.setText(root.pending)
      root.app.statusText = root.pendingStatus
    }
  }

  function render(s) {
    var head = '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n'
      + "<!-- Written by Lacquer. Removing this file undoes everything in it. -->\n"
      + "<fontconfig>\n"
    if (!s) return head + "</fontconfig>\n"
    var lines = ['  <match target="font">']
    lines.push('    <edit name="antialias" mode="assign"><bool>' + (s.antialias === true ? "true" : "false") + "</bool></edit>")
    // hintstyle carries the "no hinting at all" case, so hinting follows it.
    lines.push('    <edit name="hinting" mode="assign"><bool>' + (s.hintstyle === "hintnone" ? "false" : "true") + "</bool></edit>")
    lines.push('    <edit name="hintstyle" mode="assign"><const>' + s.hintstyle + "</const></edit>")
    lines.push('    <edit name="rgba" mode="assign"><const>' + s.rgba + "</const></edit>")
    // Without a filter the colour stripes fringe badly; with none picked, the
    // filter is irrelevant and fontconfig ignores it.
    lines.push('    <edit name="lcdfilter" mode="assign"><const>' + (s.rgba === "none" ? "none" : "lcddefault") + "</const></edit>")
    lines.push("  </match>")
    return head + lines.join("\n") + "\n</fontconfig>\n"
  }

  // ------------------------------------------------------------------- read

  function parse(text) {
    var out = {}
    var t = String(text || "")
    if (t.indexOf("<match") < 0) return out
    function constOf(name) {
      var m = t.match(new RegExp('name="' + name + '"[^>]*>\\s*<const>\\s*([a-z]+)\\s*</const>'))
      return m ? m[1] : undefined
    }
    var aa = t.match(/name="antialias"[^>]*>\s*<bool>\s*(true|false)\s*<\/bool>/)
    if (aa) out.antialias = aa[1] === "true"
    var hs = constOf("hintstyle")
    if (hs) out.hintstyle = hs
    var rgba = constOf("rgba")
    if (rgba) out.rgba = rgba
    return out
  }

  FileView {
    id: file
    path: root.path
    preload: false
    printErrors: false
    atomicWrites: true
    watchChanges: true
    onFileChanged: reload()
  }

  Process {
    id: read
    command: ["timeout", "-k", "1", "5", "cat", root.path]
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: function(code) {
      root.chosen = code === 0 ? root.parse(readOut.text) : ({})
      root.loaded = true
    }
  }

  // What is actually in force, as fc-match reports it. This only stands in for
  // the system's own settings while Lacquer has written nothing — which is
  // exactly when it is used, since anything written wins over it.
  Process {
    id: measure
    command: ["timeout", "-k", "1", "5", "bash", "-c",
              "fc-match -v monospace 2>/dev/null | grep -E '^\\s*(antialias|hintstyle|rgba):'"]
    stdout: StdioCollector { id: measureOut; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) return
      var text = String(measureOut.text || "")
      var next = { antialias: true, hintstyle: "hintslight", rgba: "none" }
      var aa = text.match(/antialias:\s*(True|False)/)
      if (aa) next.antialias = aa[1] === "True"
      // fc-match prints these as numbers.
      var hs = text.match(/hintstyle:\s*(\d)/)
      if (hs) next.hintstyle = ["hintnone", "hintslight", "hintmedium", "hintfull"][Number(hs[1])] || "hintslight"
      var rg = text.match(/rgba:\s*(\d)/)
      if (rg) next.rgba = ["unknown", "rgb", "bgr", "vrgb", "vbgr", "none"][Number(rg[1])] || "none"
      if (next.rgba === "unknown") next.rgba = "none"
      root.base = next
    }
  }

  function rescan() {
    if (!read.running) read.running = true
    if (!measure.running) measure.running = true
  }

  Component.onCompleted: rescan()
}
