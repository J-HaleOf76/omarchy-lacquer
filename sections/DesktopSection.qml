import QtQuick
import qs.Commons
import qs.Ui
import "../LookSchema.js" as LookSchema
import "../ShellSchema.js" as ShellSchema

// Fonts & text, GTK & icons, and Cursor: three views over DesktopStore.
Item {
  id: section

  required property var app
  property string kind: "fonts"

  readonly property var store: app.desktop
  readonly property var d: store.info

  function moveBy(dx, dy) { choices.moveBy(dx, dy) }
  function activate() { choices.activate() }
  function clearPin() { choices.clearPin() }
  function focusGroupTitle(title) { return choices.focusGroupTitle(title) }

  readonly property var night: app.night
  readonly property var screens: app.screens
  readonly property var menuLook: app.menuLook
  readonly property var apps: app.apps

  function rescanAll() {
    if (kind === "motion" || kind === "borders") return
    if (kind === "monitors") { section.app.monitors.rescan(); return }
    if (kind === "rules") { section.app.rules.rescan(); return }
    if (kind === "launcher") { section.app.launcher.rescan(); return }
    if (kind === "frame") { section.app.companion.rescan(); return }
    if (kind === "night") night.rescan()
    else if (kind === "lock" || kind === "screensaver") screens.rescan()
    else if (kind === "menu") menuLook.rescan()
    else if (kind === "terminal" || kind === "btop") { apps.rescan(); if (kind === "btop") section.app.tools.rescan() }
    else store.rescan()
  }

  onVisibleChanged: if (visible) rescanAll()
  // The three Desktop sections share this one view, so switching between them
  // changes the kind without ever hiding it.
  onKindChanged: if (visible) { rescanAll(); Qt.callLater(choices.reset) }

  function chips(list) {
    return (list || []).map(function(v) { return { value: v, label: v } })
  }

  function followNote(key, what) {
    if (!section.d) return ""
    if (section.store.isPinned(key)) return "Held at " + section.store.pins[key] + " through theme switches. The theme would use " + section.d.follows[key] + "."
    return "Following the theme (" + section.d.follows[key] + "). Pick " + what + " to hold it through theme switches."
  }

  readonly property var fontGroups: !section.d ? [] : [
    section.addGroup("font", "Add a font",
      "A downloaded .ttf or .otf, or a .zip or .tar.gz of them. They go to ~/.local/share/fonts/ and appear in the lists below once the font cache is rebuilt."),
    {
      id: "text-size", kind: "stepper", title: "Text size",
      note: "One knob for the shell, GTK apps and terminals, the same as `omarchy display text size`."
        + (section.d.text.terminalPt ? " Terminals are at " + section.d.text.terminalPt + " pt now; "
           + section.store.textPx + " px sets them to " + Math.floor(section.store.textPx * 9 / 12 + 0.5) + " pt." : ""),
      value: section.store.textPx, unit: "px",
      step: function(delta) { section.store.stepTextSize(delta) },
      reset: function() { section.store.resetTextSize() }, resetLabel: "Default (12)"
    },
    {
      id: "mono", kind: "chips", title: "Terminal & code font",
      note: section.store.confirmMono !== ""
        ? "Pick " + section.store.confirmMono + " again to set it. The shell restarts to load it, and Lacquer reopens here."
        : "Used by terminals and the shell. Setting one restarts the shell.",
      current: section.d.mono.current,
      options: section.d.mono.list.map(function(f) {
        return { value: f, label: section.store.confirmMono === f ? "Set " + f + "?" : f }
      }),
      pick: function(v) { if (v !== section.d.mono.current) section.store.setMonoFont(v) }
    },
    {
      id: "ui-size", kind: "stepper", title: "Interface font size",
      note: "The GTK interface font, before text size scales it.",
      value: section.store.uiSize, unit: "pt",
      step: function(delta) { section.store.setUiFont("", section.store.uiSize + delta) },
      reset: function() { section.store.setUiFont("", 11) }, resetLabel: "Default (11)"
    },
    {
      id: "ui-font", kind: "fonts", title: "Interface font",
      note: "Used by GTK apps and anything following the desktop font. Currently " + section.d.ui.family + ".",
      current: section.d.ui.family,
      options: section.d.uiFonts.map(function(f) { return { value: f, label: f } }),
      pick: function(v) { section.store.setUiFont(v, section.store.uiSize) }
    }
  ]

  readonly property var gtkGroups: !section.d ? [] : [
    {
      id: "scheme", kind: "chips", title: "Light or dark apps",
      note: section.followNote("color-scheme", "one"),
      current: section.d.gsettings["color-scheme"],
      pinned: section.store.isPinned("color-scheme"),
      unpin: function() { section.store.unpin("color-scheme") },
      options: [{ value: "prefer-light", label: "Light" }, { value: "prefer-dark", label: "Dark" }, { value: "default", label: "No preference" }],
      pick: function(v) { section.store.pin("color-scheme", v) }
    },
    {
      id: "gtk", kind: "chips", title: "GTK theme",
      note: section.followNote("gtk-theme", "one"),
      current: section.d.gsettings["gtk-theme"],
      pinned: section.store.isPinned("gtk-theme"),
      unpin: function() { section.store.unpin("gtk-theme") },
      options: section.chips(section.d.gtkThemes),
      pick: function(v) { section.store.pin("gtk-theme", v) }
    },
    {
      id: "icons", kind: "icons", title: "Icon theme",
      note: section.followNote("icon-theme", "a set"),
      current: section.d.gsettings["icon-theme"],
      pinned: section.store.isPinned("icon-theme"),
      unpin: function() { section.store.unpin("icon-theme") },
      options: section.d.iconThemes.map(function(t) { return { value: t.name, label: t.label, icons: t.icons } }),
      pick: function(v) { section.store.pin("icon-theme", v) }
    }
  ]

  // ------------------------------------------------------------------ screen frame
  //
  // Everything here is drawn by the companion plugin (Lacquer Shell). Without
  // it the section says what it would add and offers to install it; Lacquer
  // itself keeps working exactly as before.
  readonly property var companion: section.app.companion

  readonly property var frameGroups: {
    var c = section.companion
    if (!c.probed) return []
    if (!c.present) {
      if (c.confirming) {
        return [{
          id: "install-confirm", kind: "chips", title: "Install Lacquer Shell?",
          note: "This runs Omarchy's own installer in a terminal you can watch: "
            + "`omarchy plugin add " + c.repo + " --enable`. It adds a second plugin that draws the frame; "
            + "everything in it stays off until you turn it on, and you can remove it with "
            + "`omarchy plugin remove " + c.pluginId + "`.",
          options: [{ value: "yes", label: "Install it" }, { value: "no", label: "Not now" }],
          pick: function(v) { if (v === "yes") c.install(); else c.cancelInstall() }
        }]
      }
      return [{
        id: "install", kind: "chips", title: "Needs the companion",
        note: "Rounded screen corners, corner brackets, a frame around the display, a vignette, scanlines and grain are drawn by a second, optional plugin \u2014 Lacquer Shell \u2014 because something has to stay on screen to draw them. Lacquer works fine without it.",
        options: [{ value: "install", label: "Tell me more / install" }],
        pick: function(v) { c.askInstall() }
      }]
    }
    if (!c.frame) return [{
      id: "no-answer", kind: "chips", title: "Companion installed",
      note: "Lacquer Shell is installed but has not answered yet. If this stays, restart the shell with `omarchy restart shell`.",
      options: []
    }]
    var f = c.frame
    return [
      {
        id: "frame-on", kind: "chips", title: "Screen frame",
        note: "Drawn above everything, and it takes no clicks: the desktop underneath behaves exactly as before.",
        current: f.enabled ? "on" : "off",
        options: section.onOff(),
        pick: function(v) { c.set("enabled", v === "on", v === "on" ? "Screen frame on" : "Screen frame off") }
      },
      {
        id: "frame-style", kind: "chips", title: "Corners",
        note: "Rounded cuts the display's corners; brackets draws a short stroke in each corner instead.",
        current: f.style,
        options: [{ value: "corners", label: "Rounded" }, { value: "brackets", label: "Brackets" }],
        pick: function(v) { c.set("style", v, v === "corners" ? "Rounded corners" : "Corner brackets") }
      },
      {
        id: "frame-corner-size", kind: "stepper", title: f.style === "brackets" ? "Bracket length" : "Corner radius",
        value: Math.round(f.corners), unit: "px",
        step: function(d) { c.step("corners", d, 0, 200, 4, f.style === "brackets" ? "Bracket" : "Corner", " px") }
      },
      {
        id: "frame-width", kind: "stepper", title: "Frame width",
        note: "A line just inside the screen's edge, in the theme's accent colour.",
        value: Math.round(f.frame), unit: "px",
        step: function(d) { c.step("frame", d, 0, 40, 1, "Frame", " px") }
      },
      {
        id: "frame-vignette", kind: "stepper", title: "Vignette",
        note: "Darkens towards the edges.",
        value: Math.round(f.vignette * 100) + " %", unit: "",
        step: function(d) { c.step("vignette", d, 0, 1, 0.05, "Vignette", "%") }
      },
      {
        id: "frame-scanlines", kind: "stepper", title: "Scanlines",
        value: Math.round(f.scanlines * 100) + " %", unit: "",
        step: function(d) { c.step("scanlines", d, 0, 1, 0.05, "Scanlines", "%") }
      },
      {
        id: "frame-grain", kind: "stepper", title: "Grain",
        note: "A still speckle over the screen. Drawn once, so it costs nothing to leave on.",
        value: Math.round(f.grain * 100) + " %", unit: "",
        step: function(d) { c.step("grain", d, 0, 1, 0.05, "Grain", "%") }
      }
    ]
  }

  // ------------------------------------------------------------------ app launcher
  //
  // Only ever Lacquer's own copy in ~/.local/share/applications is edited; the
  // packaged .desktop file underneath stays exactly as the package left it.
  readonly property var launcherGroups: {
    var store = section.app.launcher
    if (!store.scanned) return []
    var entry = store.current
    var out = [{
      id: "which-launcher-app", kind: "chips", title: "App",
      note: store.changedCount === 0
        ? "Every app the launcher can show. Nothing is changed until you change it."
        : store.changedCount + (store.changedCount === 1 ? " app has" : " apps have") + " been changed; those are marked.",
      current: store.picked,
      options: store.apps.map(function(a) {
        return { value: a.id, label: a.name + (a.managed ? "  \u00b7  changed" : "") + (a.hidden ? "  \u00b7  hidden" : "") }
      }),
      pick: function(v) { store.picked = v }
    }]
    if (!entry) return out
    out.push({
      id: "launcher-name", kind: "text", title: "Name",
      note: "What the launcher calls it. Enter to save.",
      value: entry.name, placeholder: "Name in the launcher",
      commit: function(v) { if (v && v !== entry.name) store.set("name", v, "Renamed to " + v) }
    })
    out.push({
      id: "launcher-icon", kind: "chips", title: "Icon",
      note: entry.icon ? "Now: " + entry.icon : "This app has no icon of its own.",
      options: [{ value: "pick", label: "Choose an image\u2026" }],
      pick: function(v) { store.pickIcon() }
    })
    out.push({
      id: "launcher-hidden", kind: "chips", title: "In the launcher",
      note: "Hidden apps still run; they just stop cluttering the list.",
      current: entry.hidden ? "hidden" : "shown",
      options: [{ value: "shown", label: "Show it" }, { value: "hidden", label: "Hide it" }],
      pick: function(v) { store.set("hidden", v === "hidden" ? "on" : "off", v === "hidden" ? "Hidden from the launcher" : "Back in the launcher") }
    })
    if (entry.managed) {
      out.push({
        id: "launcher-reset", kind: "chips", title: "Undo",
        note: "Deletes Lacquer's copy; the packaged entry takes over again.",
        options: [{ value: "reset", label: "Back to how it was packaged" }],
        pick: function(v) { store.reset() }
      })
    }
    return out
  }

  // ------------------------------------------------------------------ app windows
  //
  // Rules are written as `o.window("^class$", { ... })` into Lacquer's block in
  // hyprland.lua, the same shape as Omarchy's own per-app rules. Apps on screen
  // are offered first, so a rule can be made by pointing at a real window.
  readonly property var rulesStore: section.app.rules

  readonly property var ruleGroups: {
    var store = section.rulesStore
    var picked = store.picked
    var rule = store.current
    var out = [{
      id: "which-app", kind: "chips", title: "App",
      note: store.known.length === 0
        ? "Nothing is open to point at yet. Open the app you want to rule, then come back."
        : "Apps with rules, and everything on screen right now. A rule matches the window class exactly.",
      current: picked,
      options: store.known.map(function(k) {
        return { value: k.match, label: k.name + (k.ruled ? "  \u00b7  ruled" : "") }
      }),
      pick: function(v) { store.picked = v }
    }]
    if (!picked) return out
    out.push({
      id: "float", kind: "chips", title: "Floating",
      note: "Take this app out of the tiling layout, or force it into it.",
      current: rule && rule.float !== undefined ? (rule.float ? "float" : "tile") : "",
      options: [{ value: "", label: "Follow the layout" }, { value: "float", label: "Always float" },
                { value: "tile", label: "Always tile" }],
      pick: function(v) { store.set("float", v === "" ? undefined : v === "float", v === "" ? "Follows the layout" : (v === "float" ? "Floats" : "Tiles")) }
    })
    out.push({
      id: "size", kind: "chips", title: "Size when it floats",
      note: "Only used while the window floats.",
      current: rule && rule.width > 0 ? rule.width + "x" + rule.height : "",
      options: [{ value: "", label: "Leave it" }, { value: "800x600", label: "800\u00d7600" },
                { value: "1100x700", label: "1100\u00d7700" }, { value: "1280x800", label: "1280\u00d7800" },
                { value: "1600x900", label: "1600\u00d7900" }],
      pick: function(v) {
        if (v === "") { store.setSize(0, 0); return }
        var parts = String(v).split("x")
        store.setSize(Number(parts[0]), Number(parts[1]))
      }
    })
    out.push({
      id: "centered", kind: "chips", title: "Centred",
      current: rule && rule.center ? "on" : "off", options: section.onOff(),
      pick: function(v) { store.set("center", v === "on", v === "on" ? "Opens centred" : "Opens where the layout puts it") }
    })
    out.push({
      id: "workspace", kind: "chips", title: "Opens on",
      note: "Send this app to the same workspace every time. `special` is the scratchpad.",
      current: rule ? rule.workspace : "",
      options: [{ value: "", label: "Wherever you are" }].concat([1, 2, 3, 4, 5, 6].map(function(n) {
        return { value: String(n), label: "Workspace " + n }
      })).concat([{ value: "special", label: "Scratchpad" }]),
      pick: function(v) { store.set("workspace", v, v === "" ? "Opens wherever you are" : "Opens on " + v) }
    })
    out.push({
      id: "opacity", kind: "chips", title: "Opacity",
      note: "Overrides the global window opacity for this app only.",
      current: rule && rule.opacity !== "" ? rule.opacity : "",
      options: [{ value: "", label: "Follow the global" }, { value: 1, label: "Solid" },
                { value: 0.95, label: "95 %" }, { value: 0.9, label: "90 %" }, { value: 0.8, label: "80 %" }],
      pick: function(v) { store.set("opacity", v, v === "" ? "Follows the global opacity" : "Opacity " + v) }
    })
    out.push({
      id: "effects-off", kind: "chips", title: "Turn off for this app",
      note: "Handy for apps that draw their own chrome, or that a blur makes slow.",
      options: [{ value: "noBlur", label: (rule && rule.noBlur ? "\u2713 " : "") + "Blur" },
                { value: "noShadow", label: (rule && rule.noShadow ? "\u2713 " : "") + "Shadow" },
                { value: "noBorder", label: (rule && rule.noBorder ? "\u2713 " : "") + "Border" },
                { value: "noRounding", label: (rule && rule.noRounding ? "\u2713 " : "") + "Rounding" }],
      pick: function(v) {
        var now = rule ? rule[v] === true : false
        store.set(v, !now, (now ? "On again: " : "Off: ") + v.replace("no", ""))
      }
    })
    if (rule) {
      out.push({
        id: "forget-rule", kind: "chips", title: "Remove",
        note: "Takes every rule for this app back out of hyprland.lua.",
        options: [{ value: "forget", label: "Remove the rules for " + picked }],
        pick: function(v) { store.forget(picked) }
      })
    }
    return out
  }

  // ------------------------------------------------------------------ screens
  //
  // Nothing is written until a change has been confirmed: MonitorsStore applies
  // it live and puts it back on its own if the countdown runs out, which is the
  // only safe way to try a mode that might show nothing at all.
  readonly property var mon: section.app.monitors

  function monitorGroupsFor(m) {
    var modes = section.mon.modesOf(m.name)
    var scales = [1, 1.25, 1.5, 1.75, 2]
    var current = section.mon.currentMode(m.name)
    var label = m.name + (m.description ? "  \u00b7  " + m.description : "")
    return [
      {
        id: "mode-" + m.name, kind: "chips", title: label,
        note: "Resolution and refresh rate. " + m.width + "\u00d7" + m.height + " at "
          + Math.round(m.refreshRate) + " Hz right now"
          + (m.availableModes && m.availableModes.length ? ", " + modes.length + " to choose from." : "."),
        current: current,
        options: modes,
        pick: function(v) { section.mon.propose(m.name, { mode: v }, m.name + " at " + v.replace("@", " @ ")) }
      },
      {
        id: "scale-" + m.name, kind: "chips", title: "Scale",
        note: "Everything is drawn this much bigger. Fractional scales can blur apps that do not handle them.",
        current: Number(m.scale),
        options: scales.map(function(s) { return { value: s, label: s === 1 ? "100 %" : Math.round(s * 100) + " %" } }),
        pick: function(v) { section.mon.propose(m.name, { scale: v }, m.name + " at " + Math.round(v * 100) + " %") }
      },
      {
        id: "transform-" + m.name, kind: "chips", title: "Rotation",
        current: Number(m.transform || 0),
        options: [{ value: 0, label: "None" }, { value: 1, label: "90\u00b0" },
                  { value: 2, label: "180\u00b0" }, { value: 3, label: "270\u00b0" }],
        pick: function(v) { section.mon.propose(m.name, { transform: v }, m.name + " rotated") }
      }
    ]
  }

  readonly property var monitorGroups: {
    if (!section.mon.scanned) return []
    var out = []
    if (section.mon.asking) {
      out.push({
        id: "keep", kind: "chips", title: "Keep this?",
        note: "Trying " + section.mon.pending.label + ". Without a Keep it goes back in "
          + section.mon.countdown + " second" + (section.mon.countdown === 1 ? "" : "s")
          + ", so a screen that went black comes back on its own.",
        options: [{ value: "keep", label: "Keep it" }, { value: "revert", label: "Put it back" }],
        pick: function(v) { if (v === "keep") section.mon.keep(); else section.mon.revert() }
      })
    }
    for (var i = 0; i < section.mon.monitors.length; i++)
      out = out.concat(section.monitorGroupsFor(section.mon.monitors[i]))
    if (section.mon.managed) {
      out.push({
        id: "forget", kind: "chips", title: "Written by Lacquer",
        note: "Your screen settings are in a Lacquer block in ~/.config/hypr/monitors.lua. Omarchy's own lines above it are untouched.",
        options: [{ value: "forget", label: "Hand them back to Omarchy" }],
        pick: function(v) { section.mon.forget() }
      })
    }
    return out
  }

  // ------------------------------------------------------------------ sizes
  //
  // One knob that moves text, cursor, gaps and the bar together, plus the size
  // of Lacquer's own window. Every value it sets stays editable in its own
  // section afterwards, so a preset is a starting point, not a mode.
  readonly property var scalePresets: [
    { value: "small", label: "Small", text: 10, cursor: 20, gapsIn: 2, gapsOut: 4, bar: 22 },
    { value: "normal", label: "Normal", text: 12, cursor: 24, gapsIn: 4, gapsOut: 8, bar: 26 },
    { value: "large", label: "Large", text: 15, cursor: 32, gapsIn: 6, gapsOut: 12, bar: 32 },
    { value: "huge", label: "Huge", text: 18, cursor: 40, gapsIn: 8, gapsOut: 16, bar: 38 }
  ]

  function gapValue(key, fallback) {
    var v = section.app.hypr.overrides[key]
    return v === undefined ? fallback : Number(v)
  }

  readonly property int barHeight: {
    var item = ShellSchema.itemFor("bar.size-horizontal")
    if (!item) return 26
    var v = section.app.toml.shellValue(item)
    if (v === undefined) v = section.app.toml.shellDefault(item)
    return v === undefined ? 26 : Number(v)
  }

  // Which preset the desktop is actually at, or "" when the numbers are mixed.
  readonly property string scaleNow: {
    for (var i = 0; i < section.scalePresets.length; i++) {
      var p = section.scalePresets[i]
      if (section.store.textPx === p.text
          && section.cursorSize === p.cursor
          && section.gapValue("general:gaps_in", 4) === p.gapsIn
          && section.gapValue("general:gaps_out", 8) === p.gapsOut
          && section.barHeight === p.bar) return p.value
    }
    return ""
  }

  function applyScale(value) {
    var preset = null
    for (var i = 0; i < section.scalePresets.length; i++)
      if (section.scalePresets[i].value === value) preset = section.scalePresets[i]
    if (!preset) return
    section.app.beginEdit()
    section.store.setTextSize(preset.text)
    section.store.setCursor(section.cursorTheme, preset.cursor)
    var gapsIn = LookSchema.itemFor("general:gaps_in")
    var gapsOut = LookSchema.itemFor("general:gaps_out")
    if (gapsIn) section.app.hypr.setValue(gapsIn, preset.gapsIn, false)
    if (gapsOut) section.app.hypr.setValue(gapsOut, preset.gapsOut, false)
    var bar = ShellSchema.itemFor("bar.size-horizontal")
    if (bar) section.app.toml.setShell(bar, preset.bar, true)
    section.app.commitEdit("Desktop size: " + preset.label)
    section.app.hypr.persistNow()
    section.app.statusText = "Desktop size: " + preset.label
  }

  readonly property var sizeGroups: !section.d ? [] : [
    {
      id: "desktop-scale", kind: "chips", title: "Desktop size",
      note: "Text, cursor, window gaps and the bar's height in one go"
        + (section.scaleNow === "" ? ". Your own numbers don't match any of these right now." : ".")
        + " Everything it sets stays editable in Fonts & text, Cursor, Windows and Bar.",
      current: section.scaleNow,
      options: section.scalePresets.map(function(p) { return { value: p.value, label: p.label } }),
      pick: function(v) { section.applyScale(v) }
    },
    {
      id: "text-size", kind: "stepper", title: "Text size",
      note: "The same knob as Fonts & text: the shell, GTK apps and terminals.",
      value: section.store.textPx, unit: "px",
      step: function(d) { section.store.stepTextSize(d) },
      reset: function() { section.store.resetTextSize() }, resetLabel: "Default (12)"
    },
    {
      id: "panel-size", kind: "chips", title: "This window",
      note: "How big Lacquer itself opens. Saved for next time.",
      current: section.app.panelSize,
      options: section.app.panelSizes.map(function(p) { return { value: p.value, label: p.label } }),
      pick: function(v) { section.app.setPanelSize(v) }
    },
    {
      id: "size-where", kind: "chips", title: "Go to",
      note: "Each surface on its own: the bar's height, menu size, notification and lock sizes in Shell style, gaps in Windows.",
      options: [{ value: "bar", label: "Bar" }, { value: "shell", label: "Shell style" },
                { value: "windows", label: "Windows" }, { value: "cursor", label: "Cursor" }],
      pick: function(v) { section.app.showSectionById(v) }
    }
  ]

  // ------------------------------------------------------------------ borders
  //
  // Shape presets set several Hyprland keys and the gradient together, as one
  // undo step; the gradient itself derives its colours from the theme at
  // config-load time (StyleLua.renderBorders), so it survives theme switches.
  readonly property var shapePresets: [
    { value: "sharp", label: "Sharp", blurb: "No rounding, a hairline border, nothing behind it.",
      keys: { "decoration:rounding": 0, "decoration:rounding_power": 2, "general:border_size": 1,
              "decoration:shadow:enabled": false, "decoration:glow:enabled": false },
      border: { mode: "", amount: 0.4, angle: 45, inactive: false, groups: true } },
    { value: "soft", label: "Soft", blurb: "Rounded corners, a light gradient and a soft shadow.",
      keys: { "decoration:rounding": 12, "decoration:rounding_power": 2, "general:border_size": 2,
              "decoration:shadow:enabled": true, "decoration:shadow:range": 20, "decoration:glow:enabled": false },
      border: { mode: "lighter", amount: 0.35, angle: 45, inactive: false, groups: true } },
    { value: "pill", label: "Pill", blurb: "Deep corners and a hue shift around the border.",
      keys: { "decoration:rounding": 24, "decoration:rounding_power": 4, "general:border_size": 2,
              "decoration:shadow:enabled": false, "decoration:glow:enabled": false },
      border: { mode: "hue", amount: 0.12, angle: 90, inactive: false, groups: true } },
    { value: "neon", label: "Neon", blurb: "A thick spinning gradient with a glow behind it.",
      keys: { "decoration:rounding": 8, "decoration:rounding_power": 2, "general:border_size": 3,
              "decoration:glow:enabled": true, "decoration:glow:range": 12, "decoration:shadow:enabled": false },
      border: { mode: "hue", amount: 0.25, angle: 0, inactive: true, groups: true }, spin: true },
    { value: "paper", label: "Paper", blurb: "A thin border, a sharp shadow and dimmed unfocused windows.",
      keys: { "decoration:rounding": 4, "decoration:rounding_power": 2, "general:border_size": 1,
              "decoration:shadow:enabled": true, "decoration:shadow:sharp": true, "decoration:shadow:range": 8,
              "decoration:dim_inactive": true, "decoration:glow:enabled": false },
      border: { mode: "darker", amount: 0.3, angle: 90, inactive: false, groups: true } }
  ]

  function applyShape(value) {
    var preset = null
    for (var i = 0; i < section.shapePresets.length; i++)
      if (section.shapePresets[i].value === value) preset = section.shapePresets[i]
    if (!preset) return
    section.app.beginEdit()
    for (var key in preset.keys) {
      var item = LookSchema.itemFor(key)
      if (item) section.app.hypr.setValue(item, preset.keys[key], false)
    }
    section.app.hypr.setLeaf("borderangle", preset.spin
      ? { enabled: true, speed: 100, bezier: "linear", style: "loop" }
      : { enabled: false, speed: 1, bezier: "default", style: "" }, false)
    section.app.borders.spec = section.app.borders.clone(preset.border)
    section.app.borders.restoreSpec(preset.border)
    section.app.commitEdit("Window shape: " + preset.label)
    section.app.hypr.persistNow()
    section.app.statusText = preset.label + " \u00b7 " + preset.blurb
  }

  // A gradient can only show on a border wide enough to see.
  readonly property int borderWidth: {
    var item = LookSchema.itemFor("general:border_size")
    if (!item) return 1
    var value = section.app.hypr.valueFor(item)
    return value === undefined ? 1 : Number(value)
  }

  readonly property var borderGroups: [
    {
      id: "shape", kind: "chips", title: "Window shape",
      note: "Rounding, border width, shadow, glow and the border gradient in one go. Every one of them stays editable afterwards, here and in Decoration and Effects.",
      options: section.shapePresets.map(function(p) { return { value: p.value, label: p.label } }),
      pick: function(v) { section.applyShape(v) }
    },
    {
      id: "gradient", kind: "chips", title: "Border gradient",
      note: "Lacquer never pins a colour: it asks Hyprland for the border colour your theme just set and builds the second stop from it, so the gradient re-derives itself on every theme switch."
        + (section.app.borders.on ? "" : " Right now the border is the theme's flat colour.")
        + (section.borderWidth < 2
           ? " Your window border is " + section.borderWidth + " px, so any gradient on it is nearly invisible \u2014 widen it under Window shape or in Windows."
           : ""),
      current: section.app.borders.spec.mode,
      options: [{ value: "", label: "Theme colour" }, { value: "lighter", label: "Lighter" },
                { value: "darker", label: "Darker" }, { value: "unfocused", label: "To unfocused" },
                { value: "hue", label: "Hue shift" }],
      pick: function(v) { section.app.borders.setMode(v) }
    },
    {
      id: "gradient-amount", kind: "stepper", title: section.app.borders.spec.mode === "hue" ? "Hue turn" : "Blend",
      note: section.app.borders.spec.mode === "hue"
        ? "How far around the colour wheel the second stop sits."
        : "How far the second stop moves from the theme's colour.",
      value: section.app.borders.spec.mode === "hue"
        ? Math.round(section.app.borders.spec.amount * 360) + "\u00b0"
        : Math.round(section.app.borders.spec.amount * 100) + " %",
      unit: "",
      step: function(d) { section.app.borders.stepAmount(d) }
    },
    {
      id: "gradient-angle", kind: "stepper", title: "Gradient angle",
      note: "Which way the gradient runs across the border.",
      value: section.app.borders.spec.angle + "\u00b0", unit: "",
      step: function(d) { section.app.borders.stepAngle(d) }
    },
    {
      id: "gradient-spin", kind: "chips", title: "Spin the gradient",
      note: "Hyprland turns the angle on its own, so the border keeps moving. It repaints the border continuously, which costs a little GPU.",
      current: section.app.borders.spinning ? "on" : "off",
      options: section.onOff(),
      pick: function(v) { section.app.borders.setSpin(v === "on") }
    },
    {
      id: "gradient-where", kind: "chips", title: "Unfocused windows too",
      note: "Give the unfocused border the same treatment, derived from its own colour.",
      current: section.app.borders.spec.inactive ? "on" : "off",
      options: section.onOff(),
      pick: function(v) { section.app.borders.toggle("inactive", v === "on") }
    },
    {
      id: "gradient-groups", kind: "chips", title: "Grouped windows too",
      note: "The tab bar on grouped windows follows the same gradient.",
      current: section.app.borders.spec.groups ? "on" : "off",
      options: section.onOff(),
      pick: function(v) { section.app.borders.toggle("groups", v === "on") }
    },
    {
      id: "corners-where", kind: "chips", title: "Go to",
      note: "Rounding, opacity and dimming live in Decoration; blur, shadow and glow in Effects.",
      options: [{ value: "decoration", label: "Decoration" }, { value: "effects", label: "Effects" },
                { value: "windows", label: "Windows" }],
      pick: function(v) { section.app.showSectionById(v) }
    }
  ]

  // ------------------------------------------------------------------ motion
  //
  // A feel is a whole set of curves and speeds (MotionTokens.js). Picking one
  // writes them through HyprStore like any other edit, so it previews live and
  // undoes in one step; Animations and Curves still edit each value underneath.
  readonly property var motionGroups: [
    {
      id: "feel", kind: "chips", title: "Motion feel",
      note: (function() {
        var f = section.app.feel
        if (!f.feelSpec) return "Pick how the desktop moves. Each feel sets the animation curves and speeds for windows, layers, workspaces and borders, and the pace of Lacquer's own pages."
        var line = f.feelSpec.blurb + " Speed " + f.speed.toFixed(1) + "\u00d7."
        return f.matches ? line
          : line + " Some of its curves or speeds were changed since, in Animations or Curves \u2014 pick it again to put the feel back."
      })(),
      current: section.app.feel.feel,
      options: section.app.feel.feels.map(function(f) { return { value: f.id, label: f.label } }),
      pick: function(v) { section.app.feel.applyFeel(v) }
    },
    {
      id: "speed", kind: "stepper", title: "Speed",
      note: "Multiplies the whole feel: 2\u00d7 is twice as quick, 0.5\u00d7 half as quick. Everything keeps its shape.",
      value: section.app.feel.speed.toFixed(1) + "\u00d7", unit: "",
      step: function(d) { section.app.feel.stepSpeed(d) }
    },
    {
      id: "app-motion", kind: "chips", title: "Lacquer's own animations",
      note: "Page transitions, the rail marker, row cascades and Home's live miniature. Ctrl+M does the same.",
      current: section.app.motion ? "on" : "off",
      options: [{ value: "on", label: "On" }, { value: "off", label: "Off" }],
      pick: function(v) { section.app.setMotion(v === "on") }
    },
    {
      id: "where", kind: "chips", title: "Go to",
      note: "Every animation one at a time, and the named curves they share.",
      options: [{ value: "animations", label: "Animations" }, { value: "curves", label: "Curves" }],
      pick: function(v) { section.app.showSectionById(v) }
    }
  ].concat(section.barMotionGroups)

  // The bar can only move if the companion's bar is the one running: Omarchy's
  // own bar has no motion settings at all.
  readonly property var barMotionGroups: {
    var c = section.app.companion
    if (!c.present || !c.barMotion) return []
    var m = c.barMotion
    return [
      {
        id: "bar-motion", kind: "chips", title: "Bar motion",
        note: "Lacquer Shell's bar, at the feel's pace (" + Math.round(Number(m.duration)) + " ms). "
          + "Widgets glide when they change size, lift under the pointer, and fade in as they appear."
          + (c.barIsOurs ? ""
             : " The bar on screen is Omarchy's own right now, so none of this shows: enable Lacquer Shell's bar in "
               + "`omarchy plugin list`, or check that it loaded (it needs Omarchy 4.0.4 or newer)."),
        current: m.enabled ? "on" : "off",
        options: section.onOff(),
        pick: function(v) { c.setMotion("enabled", v === "on", v === "on" ? "Bar motion on" : "Bar motion off") }
      },
      {
        id: "bar-motion-parts", kind: "chips", title: "What moves in the bar",
        options: [{ value: "glide", label: (m.glide ? "\u2713 " : "") + "Glide" },
                  { value: "hover", label: (m.hover ? "\u2713 " : "") + "Hover lift" },
                  { value: "appear", label: (m.appear ? "\u2713 " : "") + "Fade in" }],
        pick: function(v) { c.setMotion(v, !(m[v] === true), (m[v] === true ? "Off: " : "On: ") + v) }
      }
    ]
  }

  // Downloaded fonts and cursor themes, straight from the file chooser.
  function addGroup(kind, title, note) {
    return {
      id: "add-" + kind, kind: "chips", title: title, note: note,
      options: [{ value: "files", label: "Add from files\u2026" }, { value: "folder", label: "Add from a folder\u2026" }],
      pick: function(v) { section.store.add(kind, v) }
    }
  }

  readonly property string cursorTheme: section.d ? section.d.gsettings["cursor-theme"] : ""
  readonly property int cursorSize: section.d ? section.d.gsettings["cursor-size"] : 24
  readonly property var savedCursor: section.store.block ? section.store.block.cursor : null

  readonly property var cursorGroups: !section.d ? [] : [
    section.addGroup("cursor", "Add a cursor theme",
      "A downloaded theme folder, or its .zip or .tar.gz. It goes to ~/.local/share/icons/ and shows up below; only the theme's own files are taken."),
    {
      id: "cursor-theme", kind: "chips", title: "Cursor theme",
      note: section.savedCursor
        ? "Applied live and saved in ~/.config/hypr/autostart.lua, so it survives a restart. Apps already open may keep the old cursor until relaunched."
        : "Using the system default. Picking one applies it live and saves it in ~/.config/hypr/autostart.lua.",
      current: section.cursorTheme,
      pinned: section.savedCursor !== null,
      pinnedText: section.savedCursor ? "saved: " + section.savedCursor.theme + " " + section.savedCursor.size : "",
      unpinLabel: "Back to default",
      unpin: function() { section.store.resetCursor() },
      options: [{ value: "default", label: "Default (" + (section.d.cursorDefault || "Adwaita") + ")" }]
        .concat(section.chips(section.d.cursorThemes)),
      pick: function(v) { section.store.setCursor(v, section.cursorSize) }
    },
    {
      id: "cursor-size", kind: "chips", title: "Cursor size",
      note: "Hyprland and GTK both follow this.",
      current: section.cursorSize,
      options: [16, 20, 24, 32, 40, 48, 64].map(function(n) { return { value: n, label: String(n) } }),
      pick: function(v) { section.store.setCursor(section.cursorTheme, v) }
    }
  ]

  readonly property var ns: section.night.status
  readonly property var nowTemps: [5500, 5000, 4500, 4000, 3500, 3000]

  readonly property var nightGroups: !section.ns ? [] : [
    {
      id: "now", kind: "chips", title: "Right now",
      note: section.ns.running
        ? "hyprsunset is running" + (section.ns.temperature ? " at " + section.ns.temperature + " K." : ".")
          + (section.night.scheduled ? " The schedule takes over again at its next change." : "")
        : "hyprsunset is not running; picking a warmth starts it.",
      current: section.ns.temperature && section.ns.temperature < 6000 ? section.ns.temperature : "off",
      options: [{ value: "off", label: "Off" }].concat(section.nowTemps.map(function(t) { return { value: t, label: t + " K" } })),
      pick: function(v) { section.night.setNow(v) }
    },
    {
      id: "schedule", kind: "chips", title: "Schedule",
      note: section.night.confirmReplace
        ? "hyprsunset.conf has a hand-written schedule. Pick On again to replace it; the old file is kept as a backup."
        : section.night.custom
          ? "hyprsunset.conf has a hand-written schedule, which Lacquer leaves alone."
          : section.night.scheduled
            ? "A warmer screen every evening. hyprsunset starts with Hyprland"
              + (section.ns.autostartElsewhere ? " (from your own autostart line)." : " (added to autostart.lua by Lacquer).")
            : "Off. hyprsunset.conf is Omarchy's default and nothing starts hyprsunset at login.",
      current: section.night.custom ? "" : (section.night.scheduled ? "on" : "off"),
      options: [{ value: "off", label: "Off" }, { value: "on", label: section.night.confirmReplace ? "Replace it?" : "On" }],
      pick: function(v) { section.night.setScheduled(v === "on") }
    },
    {
      id: "evening", kind: "stepper", title: "Warmer from",
      note: section.night.scheduled ? "" : "Used when the schedule is turned on.",
      value: section.night.evening, unit: "",
      step: function(d) { section.night.shiftTime("evening", d * 30) }
    },
    {
      id: "morning", kind: "stepper", title: "Back to normal at",
      value: section.night.morning, unit: "",
      step: function(d) { section.night.shiftTime("morning", d * 30) }
    },
    {
      id: "warmth", kind: "stepper", title: "Evening warmth",
      note: "Lower is warmer. Omarchy's nightlight toggle uses 4000 K.",
      value: section.night.warmth, unit: "K",
      step: function(d) { section.night.stepWarmth(d) }
    }
  ]

  readonly property var sd: section.screens.info
  readonly property var ls: section.sd ? section.sd.status : null

  function secondsChips(list) {
    return list.map(function(n) { return { value: n, label: n === 0 ? "Never" : section.screens.formatSeconds(n) } })
  }

  // The boot screen's unlock prompt (Omarchy's Plymouth theme). Themes that
  // ship an unlock screen are offered as they are; the current theme always
  // is, drawn in its own colours when it has none.
  readonly property var unlockGroup: {
    var u = section.sd ? section.sd.unlock : null
    if (!u) return null
    var t = u.theme
    var name = function(slug) { return section.app.theme.displayOf(slug) }
    var options = [{ value: "default", label: "Default", preview: u.defaultPreview, sub: "" }]
    if (t && !t.ships) options.push({ value: "current", label: name(t.name), preview: t.preview, sub: "this theme" })
    for (var i = 0; i < u.themes.length; i++)
      options.push({ value: u.themes[i].name, label: name(u.themes[i].name), preview: u.themes[i].preview,
                     sub: t && t.name === u.themes[i].name ? "this theme" : "" })
    for (var j = 0; j < options.length; j++)
      if (options[j].value === u.onBoot) options[j].sub = options[j].sub ? options[j].sub + " · on boot" : "on boot"
    var mine = t ? (t.ships ? t.name : "current") : ""
    var shows = u.onBoot === "" ? "a design Lacquer does not recognise"
      : u.onBoot === "default" ? "the Omarchy default"
      : u.onBoot === "current" ? name(t.name) : name(u.onBoot)
    var note = "Shown while the laptop starts and asks for the disk password. It shows " + shows + "."
    if (t && mine !== u.onBoot) note += " Pick " + name(t.name) + " to match your theme."
    if (u.active && u.active !== "omarchy")
      note += " Right now the boot screen uses the \u201c" + u.active + "\u201d Plymouth theme; picking here switches it back to Omarchy's."
    note += " Applying asks for your password in a small terminal and rebuilds the boot image, which takes a minute."
    return {
      id: "unlock-screen", kind: "cards", title: "Boot unlock screen", note: note,
      current: u.onBoot, options: options,
      pick: function(v) { section.screens.setUnlock(v) }
    }
  }

  readonly property var lockAfterGroup: !section.sd ? null : {
    id: "lock-after", kind: "chips", title: "Lock after",
    note: "Idle time before the session locks (shell.json).",
    current: section.sd.idle.lock,
    options: section.secondsChips([120, 300, 600, 900, 1800, 3600]),
    pick: function(v) { section.screens.setIdle("lock", v) }
  }

  readonly property var lockGroups: !section.sd ? [] : !section.sd.lockExplorer ? [
    {
      id: "stock-lock", kind: "chips", title: "Lock screen",
      note: "Omarchy's lock screen follows your theme on its own: the wallpaper, blurred, behind a password field in the theme's colours. Its colours can be tuned under Shell style \u203a Lock screen.",
      options: [{ value: "lock", label: "Lock now" }, { value: "colours", label: "Lock screen colours" }],
      pick: function(v) { if (v === "lock") section.screens.lockNow(); else section.app.showSectionById("shell") }
    },
    section.lockAfterGroup,
    section.unlockGroup
  ].filter(function(g) { return !!g }) : [
    {
      id: "design", kind: "chips", title: "Lock design",
      note: (function() {
        for (var i = 0; i < section.sd.designs.length; i++)
          if (section.sd.designs[i].active) return section.sd.designs[i].name + ": " + section.sd.designs[i].description + "."
        return ""
      })(),
      current: section.ls.design,
      options: section.sd.designs.map(function(d) { return { value: d.id, label: d.name } }),
      pick: function(v) { section.screens.setDesign(v) }
    },
    {
      id: "try", kind: "chips", title: "Try it",
      note: "Shows the chosen design full screen without locking. Click to close it.",
      options: [{ value: "preview", label: "Preview lock screen" }, { value: "styling", label: "Open lock-explorer" }, { value: "editor", label: "Design editor" }],
      pick: function(v) { if (v === "preview") section.screens.previewDesign(section.ls.design); else section.screens.openExplorer(v) }
    },
    {
      id: "unlock", kind: "chips", title: "Unlock animation",
      current: section.ls.unlockAnimated ? section.ls.unlock : "none",
      options: ["fade", "zoom", "rise", "none"].map(function(a) { return { value: a, label: a.charAt(0).toUpperCase() + a.slice(1) } }),
      pick: function(v) { section.screens.setUnlockAnimation(v) }
    },
    {
      id: "unlock-ms", kind: "stepper", title: "Unlock length",
      value: section.screens.unlockMs, unit: "ms",
      step: function(d) { section.screens.stepUnlockMs(d) }
    },
    {
      id: "clock", kind: "chips", title: "Clock",
      current: section.sd.clock,
      options: [{ value: "24", label: "24-hour" }, { value: "12", label: "12-hour" }],
      pick: function(v) { section.screens.setClock(v) }
    },
    {
      id: "blank", kind: "stepper", title: "Blank the screen after",
      note: section.ls.keepDisplayOn ? "Ignored while the display is kept on." : "How long the lock screen stays lit with no input.",
      value: section.screens.formatSeconds(section.screens.blankMs / 1000), unit: "",
      step: function(d) { section.screens.stepBlank(d) }
    },
    {
      id: "keep-on", kind: "chips", title: "Keep the display on while locked",
      current: section.ls.keepDisplayOn ? "on" : "off",
      options: [{ value: "off", label: "Off" }, { value: "on", label: "On" }],
      pick: function(v) { section.screens.setKeepDisplayOn(v === "on") }
    },
    section.lockAfterGroup,
    section.unlockGroup,
    {
      id: "boot", kind: "cards", title: "lock-explorer boot screen",
      note: section.ls.bootApplying ? "lock-explorer is rebuilding the boot screen…"
        : section.ls.boot !== (section.ls.bootApplied || "stock")
          ? "Chosen: " + section.ls.boot + ", but the boot screen still shows " + (section.ls.bootApplied || "stock")
            + ". Building it needs your password, so it happens in lock-explorer's Boot tab."
          : "This is what shows while the laptop boots. Choosing only marks it; lock-explorer's Boot tab builds it.",
      current: section.ls.boot,
      options: section.sd.bootCards.map(function(c) {
        return { value: c.id, label: c.name, preview: c.preview,
                 sub: c.id === (section.ls.bootApplied || "stock") ? "applied" : "" }
      }),
      pick: function(v) { section.screens.setBoot(v) }
    },
    {
      id: "boot-apply", kind: "chips", title: "Build the boot screen",
      options: [{ value: "boot", label: "Open the Boot tab to apply" }],
      pick: function(v) { section.screens.openExplorer(v) }
    }
  ].filter(function(g) { return !!g })

  readonly property var screensaverGroups: !section.sd ? [] : [
    {
      id: "enabled", kind: "chips", title: "Screensaver",
      current: section.sd.screensaverOff ? "off" : "on",
      options: [{ value: "on", label: "On" }, { value: "off", label: "Off" }],
      pick: function(v) { section.screens.setScreensaverEnabled(v === "on") }
    },
    {
      id: "after", kind: "chips", title: "Start after",
      note: "Idle time before the screensaver starts (shell.json). The lock follows at "
        + section.screens.formatSeconds(section.sd.idle.lock) + ".",
      current: section.sd.idle.screensaver,
      options: section.secondsChips([60, 150, 300, 600, 900, 1800]),
      pick: function(v) { section.screens.setIdle("screensaver", v) }
    },
    {
      id: "ss-art", kind: "art", title: "Screensaver art",
      note: section.sd.screensaver.isDefault ? "The Omarchy logo." : "Your own art, in ~/.config/omarchy/branding/screensaver.txt.",
      art: section.sd.screensaver.text,
      options: [{ value: "preview", label: "Preview" }, { value: "image", label: "From an image…" },
                { value: "text", label: "Edit text" }, { value: "reset", label: "Omarchy logo" }],
      pick: function(v) { section.screens.branding("screensaver", v) }
    },
    {
      id: "about-art", kind: "art", title: "About screen art",
      note: section.sd.about.isDefault ? "The Omarchy icon." : "Your own art, in ~/.config/omarchy/branding/about.txt.",
      art: section.sd.about.text,
      options: [{ value: "preview", label: "Preview" }, { value: "image", label: "From an image…" },
                { value: "text", label: "Edit text" }, { value: "reset", label: "Omarchy icon" }],
      pick: function(v) { section.screens.branding("about", v) }
    }
  ]

  readonly property var ml: section.menuLook.look

  readonly property var menuGroups: !section.menuLook.probed ? [] : !section.menuLook.available ? [
    { id: "missing", kind: "chips", title: "Menu look",
      note: "omamenu is not answering. Menu Look needs io.github.omamenu on its local-look-ipc branch.", options: [] }
  ] : [
    {
      id: "scope", kind: "chips", title: "Applies to",
      note: section.ml.scope === "shared"
        ? "Every theme. To give " + section.ml.theme + " its own look, switch scope in the menu's own Menu Look row."
        : section.ml.theme + " only: this theme has its own override. The menu's Menu Look row can fold it back into the shared look.",
      current: section.ml.scope,
      options: [{ value: section.ml.scope, label: section.ml.scope === "shared" ? "All themes" : "This theme" }],
      pick: function(v) { }
    },
    {
      id: "scale", kind: "stepper", title: "Size",
      value: section.ml.scale.toFixed(2), unit: "×",
      step: function(d) { section.menuLook.step("scale", d) }
    },
    {
      id: "corners", kind: "stepper", title: "Corner radius",
      value: section.ml.cornerRadius < 0 ? "theme" : section.ml.cornerRadius, unit: section.ml.cornerRadius < 0 ? "" : "px",
      step: function(d) { section.menuLook.step("cornerRadius", d) }
    },
    {
      id: "border", kind: "stepper", title: "Border width",
      note: "Shell style's [menu] border-width wins over this when it is set.",
      value: section.ml.borderWidth < 0 ? "theme" : section.ml.borderWidth, unit: section.ml.borderWidth < 0 ? "" : "px",
      step: function(d) { section.menuLook.step("borderWidth", d) }
    },
    {
      id: "transparency", kind: "stepper", title: "Transparency",
      note: "Above 0 %, this replaces Shell style's [menu] background-alpha.",
      value: section.ml.transparency, unit: "%",
      step: function(d) { section.menuLook.step("transparency", d) }
    },
    {
      id: "reset", kind: "chips", title: "Reset",
      options: [{ value: "reset", label: section.ml.scope === "shared" ? "Back to the stock menu look" : "Drop this theme's override" }],
      pick: function(v) { section.menuLook.reset() }
    }
  ]

  readonly property var ai: section.apps.info
  readonly property var tv: section.apps.term

  function onOff(v) { return [{ value: "true", label: "On" }, { value: "false", label: "Off" }] }

  // The next preset above (delta > 0) or below the current value, which may
  // itself be off the list after a hand edit.
  function nextIn(list, current, delta) {
    if (delta > 0) {
      for (var i = 0; i < list.length; i++) if (list[i] > current) return list[i]
      return list[list.length - 1]
    }
    for (var j = list.length - 1; j >= 0; j--) if (list[j] < current) return list[j]
    return list[0]
  }

  readonly property var terminalGroups: !section.ai ? [] : !section.tv ? [
    { id: "none", kind: "chips", title: "Terminals", options: [],
      note: "No installed terminal with a config Lacquer knows (foot, alacritty, kitty, ghostty)." }
  ] : [
    {
      id: "which", kind: "chips", title: "Applies to",
      note: "Every installed terminal gets the same settings. The font and its size live in Fonts & text."
        + (section.ai.terminals.some(function(t) { return t.name === "foot" }) ? " foot shows a change in new windows only." : ""),
      current: "",
      options: section.ai.terminals.map(function(t) {
        return { value: t.name, label: t.name + (String(section.ai["default"]).indexOf(t.name) === 0 ? " (default)" : "") }
      }),
      pick: function(v) { }
    },
    {
      id: "padding", kind: "stepper", title: "Padding",
      value: section.apps.shown("terminal", "padding", section.tv.padding), unit: "px",
      step: function(d) {
        var cur = section.apps.shown("terminal", "padding", section.tv.padding)
        section.apps.stepTo("terminal", "padding", Math.max(0, Math.min(60, cur + d * 2)), "Terminal padding")
      }
    },
    {
      id: "cursor", kind: "chips", title: "Cursor",
      current: section.tv.cursor,
      options: [{ value: "block", label: "Block" }, { value: "beam", label: "Beam" }, { value: "underline", label: "Underline" }],
      pick: function(v) { section.apps.set("terminal", "cursor", v, "Terminal cursor: " + v) }
    },
    {
      id: "blink", kind: "chips", title: "Cursor blink",
      current: section.tv.blink ? "on" : "off",
      options: [{ value: "off", label: "Off" }, { value: "on", label: "On" }],
      pick: function(v) { section.apps.set("terminal", "blink", v, v === "on" ? "Cursor blinks" : "Cursor steady") }
    },
    {
      id: "opacity", kind: "stepper", title: "Background opacity",
      note: "Multiplies with Hyprland's window opacity (Windows › Decoration).",
      value: section.apps.shown("terminal", "opacity", section.tv.opacity), unit: "%",
      step: function(d) {
        var cur = section.apps.shown("terminal", "opacity", section.tv.opacity)
        section.apps.stepTo("terminal", "opacity", Math.max(30, Math.min(100, cur + d * 5)), "Terminal opacity")
      }
    }
  ]

  // Tools Omarchy leaves alone, offered next to btop and the prompt because
  // that is where the rest of the terminal-side colours already live.
  readonly property var toolGroups: {
    var store = section.app.tools
    if (!store.scanned || store.tools.length === 0) return []
    var out = []
    for (var i = 0; i < store.tools.length; i++) {
      var tool = store.tools[i]
      out.push({
        id: "tool-" + tool.id, kind: "chips", title: tool.name,
        note: tool.what + (tool.installed ? " Written into " + tool.path + "." : " Not installed here."),
        current: tool.on ? "on" : "off",
        options: [{ value: "on", label: "Follow the theme" }, { value: "off", label: "Leave it alone" }],
        pick: (function(id) {
          return function(v) { store.set(id, v === "on") }
        })(tool.id)
      })
    }
    return out
  }

  readonly property var btopGroups: !section.ai ? [] : [].concat(!section.ai.btop ? [] : [
    {
      id: "btop-bg", kind: "chips", title: "btop background",
      note: section.ai.btop.running ? "btop is running and reloads each change at once." : "Its colours always follow the theme.",
      current: section.ai.btop.theme_background,
      options: [{ value: "true", label: "Theme colour" }, { value: "false", label: "Transparent" }],
      pick: function(v) { section.apps.set("btop", "theme_background", v, "btop background") }
    },
    {
      id: "btop-corners", kind: "chips", title: "btop rounded corners",
      current: section.ai.btop.rounded_corners, options: section.onOff(),
      pick: function(v) { section.apps.set("btop", "rounded_corners", v, "btop corners") }
    },
    {
      id: "btop-graph", kind: "chips", title: "btop graphs",
      current: section.ai.btop.graph_symbol,
      options: [{ value: "braille", label: "Braille" }, { value: "block", label: "Block" }, { value: "tty", label: "TTY" }],
      pick: function(v) { section.apps.set("btop", "graph_symbol", v, "btop graphs: " + v) }
    },
    {
      id: "btop-update", kind: "stepper", title: "btop refresh",
      value: section.apps.shown("btop", "update_ms", Number(section.ai.btop.update_ms)), unit: "ms",
      step: function(d) {
        var cur = section.apps.shown("btop", "update_ms", Number(section.ai.btop.update_ms))
        section.apps.stepTo("btop", "update_ms", section.nextIn([250, 500, 1000, 1500, 2000, 3000, 5000, 10000], cur, d), "btop refresh")
      }
    },
    {
      id: "btop-vim", kind: "chips", title: "btop vim keys",
      current: section.ai.btop.vim_keys, options: section.onOff(),
      pick: function(v) { section.apps.set("btop", "vim_keys", v, "btop vim keys") }
    }
  ]).concat(!section.ai.starship ? [] : [
    {
      id: "star-newline", kind: "chips", title: "Blank line before the prompt",
      note: "Starship, the shell prompt. New prompts pick changes up straight away.",
      current: section.ai.starship.add_newline, options: section.onOff(),
      pick: function(v) { section.apps.set("starship", "add_newline", v, "Prompt spacing") }
    },
    {
      id: "star-timeout", kind: "stepper", title: "Prompt command timeout",
      note: "How long a slow prompt module may run before starship skips it.",
      value: section.apps.shown("starship", "command_timeout", Number(section.ai.starship.command_timeout)), unit: "ms",
      step: function(d) {
        var cur = section.apps.shown("starship", "command_timeout", Number(section.ai.starship.command_timeout))
        section.apps.stepTo("starship", "command_timeout", section.nextIn([100, 200, 300, 500, 750, 1000, 2000], cur, d), "Prompt timeout")
      }
    }
  ])

  ChoicePane {
    id: choices
    anchors.fill: parent
    app: section.app
    groups: section.kind === "fonts" ? section.fontGroups
      : section.kind === "gtk" ? section.gtkGroups
      : section.kind === "motion" ? section.motionGroups
      : section.kind === "borders" ? section.borderGroups
      : section.kind === "sizes" ? section.sizeGroups
      : section.kind === "monitors" ? section.monitorGroups
      : section.kind === "rules" ? section.ruleGroups
      : section.kind === "launcher" ? section.launcherGroups
      : section.kind === "frame" ? section.frameGroups
      : section.kind === "night" ? section.nightGroups
      : section.kind === "lock" ? section.lockGroups
      : section.kind === "screensaver" ? section.screensaverGroups
      : section.kind === "menu" ? section.menuGroups
      : section.kind === "terminal" ? section.terminalGroups
      : section.kind === "btop" ? section.btopGroups.concat(section.toolGroups) : section.cursorGroups
  }

  Text {
    anchors.centerIn: parent
    visible: section.kind === "night" ? !section.ns
      : section.kind === "sizes" ? !section.d
      : section.kind === "monitors" ? !section.app.monitors.scanned
      : section.kind === "frame" ? !section.app.companion.probed
      : section.kind === "launcher" ? !section.app.launcher.scanned
      : (section.kind === "lock" || section.kind === "screensaver") ? !section.sd
      : section.kind === "menu" ? !section.menuLook.probed
      : (section.kind === "terminal" || section.kind === "btop") ? !section.ai : !section.d
    text: "Reading desktop settings…"
    color: Qt.darker(section.app.foreground, 1.5)
    font.family: section.app.fontFamily
    font.pixelSize: Style.font.body
  }
}
