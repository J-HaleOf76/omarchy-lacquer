import QtQuick
import Quickshell
import Quickshell.Io

// Saved looks: the whole set of settings under one name.
//
// A look is a snapshot of what Lacquer writes — the theme, the Hyprland block
// (spacing, borders, corners, effects, motion), the bar and menu style, fonts
// and text size, the pointer, and how text is drawn. It does not carry window
// rules, monitor arrangement or launcher entries: those describe a machine and
// its apps rather than a look, and moving them to another computer would do
// harm rather than good.
//
// They all live in one file, looks.json, which is also what "Save to a file"
// hands over — so taking a look to another machine is a copy, not an export
// format of its own.
Item {
  id: root
  visible: false

  required property var app

  readonly property string path: app.home + "/.local/state/omarchy/" + root.pluginId + "/looks.json"
  readonly property string pluginId: "io.github.deunnis.lacquer"
  readonly property int version: 1
  // Generous next to a real file (a look is a few kB), and still bounded.
  readonly property int maxBytes: 1024 * 1024

  // [{ slug, name, saved, theme, ... }], newest first.
  property var looks: []
  property bool loaded: false
  // The look most recently saved or applied, so the page can show which it is.
  property string current: ""
  // Second press confirms, the way the font pickers do it.
  property string confirmRemove: ""

  readonly property string beforeSlug: "before"

  function nameOf(slug) {
    for (var i = 0; i < root.looks.length; i++) if (root.looks[i].slug === slug) return root.looks[i].name
    return ""
  }

  function lookFor(slug) {
    for (var i = 0; i < root.looks.length; i++) if (root.looks[i].slug === slug) return root.looks[i]
    return null
  }

  function slugify(name) {
    var s = String(name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
    return s === "" ? "look" : s.slice(0, 40)
  }

  // ---------------------------------------------------------------- capture

  function capture(name, slug) {
    var hypr = app.hypr
    var d = app.desktop.info || ({})
    return {
      version: root.version,
      slug: slug,
      name: String(name || "").slice(0, 60),
      saved: new Date().toISOString(),
      theme: String(app.theme.current || ""),
      hypr: {
        overrides: JSON.parse(JSON.stringify(hypr.overrides || ({}))),
        curves: JSON.parse(JSON.stringify(hypr.curves || ({}))),
        leaves: JSON.parse(JSON.stringify(hypr.leaves || ({}))),
        opaque: hypr.opaqueWindows === true,
        desk: hypr.deskColour === true,
        borders: JSON.parse(JSON.stringify(app.borders.spec || ({})))
      },
      // The user's own shell.toml, verbatim: putting the text back is exactly
      // what a person editing it by hand would do.
      shell: String(app.toml.shellUserText || ""),
      desktop: {
        textPx: Number(app.desktop.textPx) || 0,
        mono: d.mono ? String(d.mono.current || "") : "",
        ui: d.ui ? String(d.ui.family || "") : "",
        uiSize: Number(app.desktop.uiSize) || 0,
        cursorTheme: d.gsettings ? String(d.gsettings["cursor-theme"] || "") : "",
        cursorSize: d.gsettings ? Number(d.gsettings["cursor-size"]) || 0 : 0,
        pins: JSON.parse(JSON.stringify(app.desktop.pins || ({})))
      },
      text: JSON.parse(JSON.stringify(app.fontRender.chosen || ({})))
    }
  }

  // ------------------------------------------------------------------- save

  function save(name) {
    var clean = String(name || "").replace(/[\x00-\x1f\x7f]/g, " ").trim()
    if (clean === "") { app.errorText = "Give the look a name first."; return }
    var slug = root.slugify(clean)
    if (slug === root.beforeSlug) slug = slug + "-1"
    var next = []
    next.push(root.capture(clean, slug))
    for (var i = 0; i < root.looks.length; i++) if (root.looks[i].slug !== slug) next.push(root.looks[i])
    root.looks = next
    root.current = slug
    root.persist("Saved the look “" + clean + "”.")
  }

  function remove(slug) {
    var name = root.nameOf(slug)
    var next = []
    for (var i = 0; i < root.looks.length; i++) if (root.looks[i].slug !== slug) next.push(root.looks[i])
    root.looks = next
    root.confirmRemove = ""
    if (root.current === slug) root.current = ""
    root.persist("Removed “" + name + "”.")
  }

  function persist(status) {
    file.setText(JSON.stringify({ version: root.version, looks: root.looks }, null, 2) + "\n")
    if (status) app.statusText = status
  }

  // ------------------------------------------------------------------ apply

  property string applying: ""

  function apply(slug) {
    var look = root.lookFor(slug)
    if (!look) return
    // One step back, always: applying a look changes a great deal at once, and
    // the way out should not depend on having thought of it first.
    if (slug !== root.beforeSlug) {
      var before = root.capture("Just before", root.beforeSlug)
      var kept = [before]
      for (var i = 0; i < root.looks.length; i++) if (root.looks[i].slug !== root.beforeSlug) kept.push(root.looks[i])
      root.looks = kept
      root.persist("")
    }

    root.applying = slug
    var wantTheme = String(look.theme || "")
    if (wantTheme !== "" && wantTheme !== String(app.theme.current || "")) {
      // The theme rewrites a great many files of its own; the rest of the look
      // goes on top once it has landed.
      app.theme.apply(wantTheme)
      afterTheme.restart()
      return
    }
    root.applyRest(look)
  }

  Timer {
    id: afterTheme
    interval: 1400
    onTriggered: {
      var look = root.lookFor(root.applying)
      if (look) root.applyRest(look)
    }
  }

  function applyRest(look) {
    var hypr = app.hypr
    var h = look.hypr || ({})

    hypr.overrides = JSON.parse(JSON.stringify(h.overrides || ({})))
    hypr.curves = JSON.parse(JSON.stringify(h.curves || ({})))
    hypr.leaves = JSON.parse(JSON.stringify(h.leaves || ({})))
    hypr.opaqueWindows = h.opaque === true
    hypr.deskColour = h.desk === true
    if (h.borders) app.borders.restoreSpec(h.borders)
    hypr.persistNow()

    if (typeof look.shell === "string" && look.shell !== String(app.toml.shellUserText || ""))
      app.toml.writeShell(look.shell)

    var d = look.desktop || ({})
    var now = app.desktop.info || ({})
    if (Number(d.textPx) > 0 && Number(d.textPx) !== Number(app.desktop.textPx))
      app.desktop.setTextSize(Number(d.textPx))
    if (d.mono && now.mono && d.mono !== now.mono.current) app.desktop.setMonoFont(String(d.mono))
    if (d.ui && now.ui && (d.ui !== now.ui.family || Number(d.uiSize) !== Number(app.desktop.uiSize)))
      app.desktop.setUiFont(String(d.ui), Number(d.uiSize) || app.desktop.uiSize)
    if (d.cursorTheme && now.gsettings
        && (d.cursorTheme !== now.gsettings["cursor-theme"] || Number(d.cursorSize) !== Number(now.gsettings["cursor-size"])))
      app.desktop.setCursor(String(d.cursorTheme), Number(d.cursorSize) || 24)
    if (d.pins) app.desktop.writePins(JSON.parse(JSON.stringify(d.pins)))

    var t = look.text || ({})
    var names = ["antialias", "hintstyle", "rgba"]
    var wantsText = false
    for (var n = 0; n < names.length; n++) if (t[names[n]] !== undefined) wantsText = true
    if (wantsText) {
      for (var m = 0; m < names.length; m++)
        if (t[names[m]] !== undefined) app.fontRender.write(names[m], t[names[m]])
    }

    root.current = look.slug
    root.applying = ""
    app.statusText = "Put on “" + look.name + "”."
  }

  // --------------------------------------------------------- file in, file out

  readonly property string exportPath: app.home + "/lacquer-looks.json"

  function exportAll() {
    if (root.looks.length === 0) { app.errorText = "There are no looks to save yet."; return }
    exportFile.setText(JSON.stringify({ version: root.version, looks: root.looks }, null, 2) + "\n")
    app.statusText = "Saved " + root.looks.length + " look" + (root.looks.length === 1 ? "" : "s")
      + " to ~/lacquer-looks.json."
  }

  // The file chooser is another shell surface, so the panel steps out of the
  // way and a detached helper summons it back with what was picked.
  readonly property string pickScript:
      'sel=$(omarchy-file-select --title "Pick a Lacquer looks file" --extensions "json" | head -n 1)\n'
    + 'if [ -n "$sel" ] && [ -f "$sel" ]; then payload=$(jq -nc --arg s "$sel" \'{section:"looks", looksFile:$s}\')\n'
    + 'else payload=\'{"section":"looks"}\'; fi\n'
    + 'omarchy-shell shell summon io.github.deunnis.lacquer "$payload" >/dev/null\n'

  function pickFile() {
    root.app.dismiss()
    Quickshell.execDetached(["bash", "-c", root.pickScript, "lacquer-looks-pick"])
  }

  // Looks from a file join the ones already here; a name that is already taken
  // gets the incoming one, since that is what was just asked for.
  function importFrom(path) {
    if (!path) return
    importProc.command = ["timeout", "-k", "1", "5", app.pluginDir + "/read-state", String(path), String(root.maxBytes)]
    importProc.running = true
  }

  function merge(text) {
    var parsed
    try { parsed = JSON.parse(text) } catch (e) { parsed = null }
    if (!parsed || !Array.isArray(parsed.looks)) {
      app.errorText = "That file does not hold any Lacquer looks."
      return
    }
    var added = 0
    var next = root.looks.slice()
    for (var i = 0; i < parsed.looks.length && i < 100; i++) {
      var look = root.sane(parsed.looks[i])
      if (!look || look.slug === root.beforeSlug) continue
      var at = -1
      for (var j = 0; j < next.length; j++) if (next[j].slug === look.slug) { at = j; break }
      if (at >= 0) next[at] = look
      else next.unshift(look)
      added++
    }
    if (added === 0) { app.errorText = "That file does not hold any Lacquer looks."; return }
    root.looks = next
    root.persist("Added " + added + " look" + (added === 1 ? "" : "s") + " from that file.")
  }

  // Anything read from a file is treated as a stranger: only the shapes this
  // store writes are kept, and everything else in it is dropped.
  function sane(raw) {
    if (!raw || typeof raw !== "object") return null
    var name = String(raw.name || "").replace(/[\x00-\x1f\x7f]/g, " ").trim().slice(0, 60)
    if (name === "") return null
    var slug = root.slugify(raw.slug || name)
    var h = (raw.hypr && typeof raw.hypr === "object") ? raw.hypr : ({})
    var d = (raw.desktop && typeof raw.desktop === "object") ? raw.desktop : ({})
    return {
      version: root.version,
      slug: slug,
      name: name,
      saved: String(raw.saved || "").slice(0, 40),
      theme: String(raw.theme || "").replace(/[^a-z0-9._-]/g, "").slice(0, 128),
      hypr: {
        overrides: (h.overrides && typeof h.overrides === "object") ? h.overrides : ({}),
        curves: (h.curves && typeof h.curves === "object") ? h.curves : ({}),
        leaves: (h.leaves && typeof h.leaves === "object") ? h.leaves : ({}),
        opaque: h.opaque === true,
        desk: h.desk === true,
        borders: (h.borders && typeof h.borders === "object") ? h.borders : null
      },
      shell: typeof raw.shell === "string" ? raw.shell.slice(0, 64 * 1024) : "",
      desktop: {
        textPx: Number(d.textPx) || 0,
        mono: String(d.mono || "").slice(0, 120),
        ui: String(d.ui || "").slice(0, 120),
        uiSize: Number(d.uiSize) || 0,
        cursorTheme: String(d.cursorTheme || "").slice(0, 120),
        cursorSize: Number(d.cursorSize) || 0,
        pins: (d.pins && typeof d.pins === "object") ? d.pins : ({})
      },
      text: (raw.text && typeof raw.text === "object") ? raw.text : ({})
    }
  }

  // ------------------------------------------------------------------- files

  FileView {
    id: file
    path: root.path
    preload: false
    printErrors: false
    atomicWrites: true
  }

  FileView {
    id: exportFile
    path: root.exportPath
    preload: false
    printErrors: false
    atomicWrites: true
  }

  Process {
    id: readProc
    command: ["timeout", "-k", "1", "5", app.pluginDir + "/read-state", root.path, String(root.maxBytes)]
    stdout: StdioCollector { id: readOut; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        try {
          var parsed = JSON.parse(readOut.text)
          var out = []
          if (parsed && Array.isArray(parsed.looks))
            for (var i = 0; i < parsed.looks.length && i < 100; i++) {
              var look = root.sane(parsed.looks[i])
              if (look) out.push(look)
            }
          root.looks = out
        } catch (e) { root.looks = [] }
      }
      root.loaded = true
    }
  }

  Process {
    id: importProc
    stdout: StdioCollector { id: importOut; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) { root.app.errorText = "That file could not be read."; return }
      root.merge(importOut.text)
    }
  }

  function rescan() { if (!readProc.running) readProc.running = true }

  Component.onCompleted: rescan()
}
