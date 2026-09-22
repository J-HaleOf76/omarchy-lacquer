import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "LookSchema.js" as LookSchema
import "AnimSchema.js" as AnimSchema
import "StyleLua.js" as StyleLua
import "ShellSchema.js" as ShellSchema
import "TomlEdit.js" as TomlEdit
import "ui"
import "stores"
import "sections"

// Lacquer — one app for how Omarchy looks.
//
// This file owns the Hyprland half: everything that lands in a single managed
// block in ~/.config/hypr/looknfeel.lua. Theme and background are deliberately
// absent; aether and OmaShuffle own those.
//
// Changes apply live and persist themselves:
//
//   during a drag   `hyprctl eval` only — nothing touches disk
//   on release      debounced write of the block, then `hyprctl reload`
//
// That split is why dragging a slider does not fire dozens of reloads. Undo is
// a stack of whole-state snapshots taken at each commit, which is cheap at
// this size and cannot get out of step with the file the way a stack of
// inverse operations can.
//
// `hyprctl keyword` is not usable — Hyprland rejects it under the Lua parser
// ("keyword can't work with non-legacy parsers, use eval").
Item {
  id: root

  // Domain stores. Each owns its files, processes and state; the panel keeps
  // navigation, undo, status and the UI.
  HyprStore { id: hyprStore; app: root }
  ShellTomlStore { id: tomlStore; app: root }
  ShellJsonStore { id: sjsonStore; app: root }
  ThemeStore { id: themeStore; app: root }
  AetherStore { id: aetherStore; app: root }
  DesktopStore { id: desktopStore; app: root }
  NightStore { id: nightStore; app: root }
  ScreensStore { id: screensStore; app: root }
  MenuLookStore { id: menuLookStore; app: root; Component.onCompleted: rescan() }
  MotionStore { id: motionStore; app: root }
  BordersStore { id: bordersStore; app: root }
  MonitorsStore { id: monitorsStore; app: root }
  RulesStore { id: rulesStore; app: root }
  CompanionStore { id: companionStore; app: root; Component.onCompleted: rescan() }
  LauncherStore { id: launcherStore; app: root }
  ToolsStore { id: toolsStore; app: root }

  // Sections can appear after load (Menu look, once OmaMenu answers); keep the
  // page the user is on rather than the index it used to have.
  property string currentSectionId: "home"
  onSectionsChanged: {
    // Menu look only joins the list once OmaMenu has answered its probe, so
    // the service is told again here or that page would stay unknown to
    // showSection.
    root.publishSections()
    for (var i = 0; i < root.sections.length; i++) {
      if (root.sections[i].id !== root.currentSectionId) continue
      if (i !== root.sectionIndex) { root.lastSectionIndex = i; root.sectionIndex = i }
      return
    }
  }
  AppsStore { id: appsStore; app: root }
  readonly property alias hypr: hyprStore
  readonly property alias pointerGate: pointerGateObj

  PointerMoveGate {
    id: pointerGateObj
    referenceItem: card
  }
  readonly property alias toml: tomlStore
  readonly property alias sjson: sjsonStore
  readonly property alias theme: themeStore
  readonly property alias feel: motionStore
  readonly property alias borders: bordersStore
  readonly property alias monitors: monitorsStore
  readonly property alias rules: rulesStore
  readonly property alias companion: companionStore
  readonly property alias launcher: launcherStore
  readonly property alias tools: toolsStore
  readonly property alias aether: aetherStore
  readonly property alias desktop: desktopStore
  readonly property alias night: nightStore
  readonly property alias screens: screensStore
  readonly property alias menuLook: menuLookStore
  readonly property alias apps: appsStore
  // Lacquer's own service, which owns the shuffle engine (it has to run
  // whether or not this panel has been opened). The host injects it when it
  // summons the panel (shell.qml: `item.service = shell.serviceFor(...)`), so this
  // must stay writable — declaring it readonly made every summon throw and the
  // panel never appeared. The binding is only a fallback until that assignment.
  property var service: root.shell && typeof root.shell.serviceFor === "function"
    ? root.shell.serviceFor((root.manifest && root.manifest.id) || "io.github.deunnis.lacquer") : null
  readonly property var shuffle: root.service ? root.service.shuffle : null

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  property var shell: null

  property var manifest: null

  readonly property string home: Quickshell.env("HOME")

  // 4.0.3 strips __sourceDir from every third-party manifest
  // (shell.qml publicPluginManifest), so the plugin's own directory has to
  // come from the QML file's own URL rather than from the host.
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return decodeURIComponent(url).replace(/\/+$/, "")
  }

  property bool opened: false

  property int shellTab: 0

  // ------------------------------------------------------------------ motion
  //
  // One switch for every animation Lacquer itself draws: page transitions,
  // the rail marker, row cascades, Home's live miniature and palette, and the
  // rows' small fades. Saved in ui.json so it holds across restarts. (The
  // curve preview's Play still plays: that is the feature, not decoration.)
  property bool motion: true
  property bool motionLoaded: false
  // The desktop's motion feel and its speed multiplier (see MotionStore).
  property string motionFeel: ""
  property real motionSpeed: 1
  readonly property string uiStatePath: root.home + "/.local/state/omarchy/io.github.deunnis.lacquer/ui.json"

  function saveUiState() {
    uiStateFile.setText(JSON.stringify({ motion: root.motion, feel: root.motionFeel,
                                         speed: root.motionSpeed, panel: root.panelSize },
                                       null, 2) + "\n")
  }

  function setMotion(on) {
    root.motion = on === true
    root.saveUiState()
    root.statusText = root.motion ? "Animations on" : "Animations off"
  }

  // How big Lacquer's own window is. Saved next to the motion settings.
  property string panelSize: "normal"
  readonly property var panelSizes: [
    { value: "compact", label: "Compact", w: 720, h: 560 },
    { value: "normal", label: "Normal", w: 880, h: 680 },
    { value: "large", label: "Large", w: 1040, h: 820 },
    { value: "full", label: "Full screen", w: 100000, h: 100000 }
  ]

  readonly property var panelSizeSpec: {
    for (var i = 0; i < root.panelSizes.length; i++)
      if (root.panelSizes[i].value === root.panelSize) return root.panelSizes[i]
    return root.panelSizes[1]
  }

  function setPanelSize(id) {
    root.panelSize = String(id || "normal")
    root.saveUiState()
    root.statusText = "Panel size: " + root.panelSizeSpec.label
  }

  function setMotionFeel(id, speed) {
    root.motionFeel = String(id || "")
    root.motionSpeed = Number(speed) > 0 ? Number(speed) : 1
    root.saveUiState()
  }

  // Easing by name, so a feel can carry one as a string.
  function easingFor(name) {
    switch (name) {
      case "OutCubic": return Easing.OutCubic
      case "OutQuad": return Easing.OutQuad
      case "OutBack": return Easing.OutBack
      case "InOutCubic": return Easing.InOutCubic
      default: return Easing.OutQuint
    }
  }

  // Written through FileView, read through the bounded reader.
  FileView {
    id: uiStateFile
    path: root.uiStatePath
    preload: false
    printErrors: false
    atomicWrites: true
  }

  Process {
    id: uiStateRead
    command: ["timeout", "-k", "1", "5", root.pluginDir + "/read-state", root.uiStatePath, "4096"]
    running: true
    stdout: StdioCollector { id: uiStateOut; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        try {
          var parsed = JSON.parse(uiStateOut.text)
          if (parsed && typeof parsed.motion === "boolean") root.motion = parsed.motion
          if (parsed && typeof parsed.feel === "string") root.motionFeel = parsed.feel
          if (parsed && Number(parsed.speed) > 0) root.motionSpeed = Number(parsed.speed)
          if (parsed && typeof parsed.panel === "string") root.panelSize = parsed.panel
        } catch (e) { }
      }
      root.motionLoaded = true
    }
  }

  // Set for a moment after a section or sub-tab change, so the rows created
  // for the new page cascade in while rows scrolled into view later do not.
  property bool cascadeArmed: false
  property int lastSectionIndex: 0
  property int lastSubTab: 0

  Timer {
    id: cascadeWindow
    interval: 450
    onTriggered: root.cascadeArmed = false
  }

  function playTransition(axis, dir) {
    if (!root.motion || !root.opened) return
    root.cascadeArmed = true
    cascadeWindow.restart()
    pageEnter.axis = axis
    pageEnter.dir = dir
    pageEnter.restart()
  }

  onSectionIndexChanged: {
    if (root.sections[root.sectionIndex]) root.currentSectionId = root.sections[root.sectionIndex].id
    var here = root.sections[root.sectionIndex]
    if (here && here.group) {
      var m = root.lastInMain; m[here.group] = here.id; root.lastInMain = m
      var sb = root.lastInSub; sb[here.group + "/" + here.sub] = here.id; root.lastInSub = sb
    }
    var dir = root.sectionIndex > root.lastSectionIndex ? 1 : -1
    root.lastSectionIndex = root.sectionIndex
    root.playTransition("y", dir)
    Qt.callLater(rail.placeMarker)
  }
  onShellTabChanged: {
    var dir = root.shellTab > root.lastSubTab ? 1 : -1
    root.lastSubTab = root.shellTab
    root.playTransition("x", dir)
  }
  onAnimTabChanged: {
    var dir = root.animTab > root.lastSubTab ? 1 : -1
    root.lastSubTab = root.animTab
    root.playTransition("x", dir)
  }

  property string selectedPlugin: ""

  property string backupStamp: ""

  property bool backupsDone: false

  property var undoStack: []

  property var pendingUndo: null

  property int sectionIndex: 0

  property int cursorIndex: 0

  property int animTab: 0

  property string curveName: "easeOutQuint"

  property string errorText: ""

  property string statusText: ""

  property var legacyPresent: []
  // "Not now" on the Omaland banner, for this session.
  property bool legacyDismissed: false

  property bool confirmRemove: false

  property bool confirmResetAll: false
  // "?" in the header, or the ? key: the keyboard shortcuts for this page.
  property bool showHints: false

  // Someone is using Lacquer while they have moved the pointer over it or
  // pressed a key in the last half minute. The ambient goo and the breathing
  // run only then, so an open panel left alone costs nothing.
  property bool lively: true
  function poke() {
    if (!root.lively) root.lively = true
    idleTimer.restart()
  }
  Timer { id: idleTimer; interval: 30000; running: true; onTriggered: root.lively = false }

  // The breath: a slow swell and settle, about one every four seconds.
  property real breath: 0
  property real breathT: 0
  Timer {
    interval: 100
    repeat: true
    running: root.opened && root.lively && root.motion
    onTriggered: { root.breathT += 0.1; root.breath = Math.sin(root.breathT * 1.55) }
  }

  readonly property string footerMessage: root.errorText !== "" ? root.errorText
    : root.statusText !== "" ? root.statusText
    : root.backupStamp !== "" ? "Kept a copy of your settings before changing anything, just in case (*.lacquer-backup-" + root.backupStamp + ")"
    : ""

  readonly property string keyHints: {
    if (root.isHome) return homeSection.query !== ""
      ? "↑↓ choose · Enter open · Backspace edit · Esc clear"
      : "type to search · ←→ group · ↑↓ section · Enter open · Tab next page · Esc close"
    if (root.isGenerate) return (root.confirmGenerate ? "g again to generate and apply · Esc cancel" : "w pick a wallpaper · f any picture · l light or dark · g make the theme (asks first) · o open the theme maker · Esc close")
    if (root.isShuffle) return "the shuffle keeps working while Lacquer is closed · Tab next page · Esc close"
    // Only the pages that pin a value or carry a default mention Del.
    if (root.isDesktop && ["fonts", "gtk", "cursor", "sizes"].indexOf(root.section.id) < 0)
      return "↑↓ group · ←→ choose or step · Enter pick · Tab next page · Esc close"
    if (root.section.id === "nightlight") return "↑↓ group · ←→ choose or step · Enter pick · Tab next page · Esc close"
    if (root.isDesktop) return "↑↓ group · ←→ choose or step a size · Enter pick · Del back to normal · Tab next page · Esc close"
    if (root.isTheme) return "←→↑↓ hjkl choose · Enter apply · click a wallpaper to set it · Tab next page · Esc close"
    if (root.isBar) return "◀ ▶ move · ▲ ▼ order · ✕ take off the bar · Tab next page · Esc close"
    if (root.isPlugins) return "[ ] pick an add-on, then change its settings with the mouse · Tab next page · Esc close"
    var hint = root.isCurves
      ? "drag a handle · P play · Tab next page"
      : "↑↓ kj row · ←→ hl adjust · Space toggle · Backspace reset · Tab next page"
        + ((root.isShell || root.isAnimations) ? " · [ ] next tab" : "")
    return hint + " · Ctrl+Z undo · Esc close"
  }

  // Reset all asks once, then acts on a second press within a few seconds.
  function pressResetAll() {
    if (root.confirmResetAll) {
      root.confirmResetAll = false
      root.resetAll()
    } else {
      root.confirmResetAll = true
      resetAllTimeout.restart()
    }
  }
  property bool confirmShuffleMove: false
  property bool confirmGenerate: false

  property color background: Color.menu.background

  property color foreground: Color.menu.text

  property color accent: Color.accent

  property color scrim: Color.menu.scrim

  // Words in Lacquer's sans, numbers and keys in the theme's mono.
  property string monoFamily: Style.font.menuFamily
  property string fontFamily: designObj.sans

  Design { id: designObj; app: root }
  readonly property var design: designObj

  // Lacquer's corners follow the windows'.
  readonly property real windowRounding: {
    var item = LookSchema.itemFor("decoration:rounding")
    var v = item ? Number(hypr.valueFor(item)) : 8
    return isFinite(v) ? v : 8
  }
  readonly property int uiDuration: motionStore.uiDuration

  // `group` is the rail heading a section sits under; `pane` is which view
  // renders it. Keyboard Tab order is simply this order.
  readonly property var sections: {
    var out = [
      { id: "home", group: "", pane: "home", icon: "󰋜", title: "Home",
        blurb: "Everything you can change, and what it is set to now." },
      { id: "theme", group: "Theme", pane: "theme", icon: "", title: "Themes & wallpaper",
        blurb: "Pick a theme, which recolours everything, and one of its wallpapers." },
      { id: "shuffle", group: "Theme", pane: "shuffle", icon: "󰒝", title: "Theme shuffle",
        blurb: "A different theme every time you start the computer, or a light one by day and a dark one at night." },
      { id: "generate", group: "Theme", pane: "generate", icon: "󰏘", title: "Make a theme",
        blurb: "Make a new theme from any picture, using its colours." },
      { id: "motion", group: "Theme", pane: "desktop", kind: "motion", icon: "✦", title: "Motion feel",
        blurb: "One setting for how everything moves: windows, desktops and this app." },
      { id: "fonts", group: "Desktop", pane: "desktop", kind: "fonts", icon: "󰛖", title: "Fonts & text size",
        blurb: "How big text is everywhere, and the fonts used for apps and the terminal." },
      { id: "gtk", group: "Desktop", pane: "desktop", kind: "gtk", icon: "󰉼", title: "Light or dark & icons",
        blurb: "Whether apps are light or dark, how they are styled, and which icons they use. A choice here stays when you change theme." },
      { id: "cursor", group: "Desktop", pane: "desktop", kind: "cursor", icon: "󰇀", title: "Mouse pointer",
        blurb: "The look and size of the mouse pointer." },
      { id: "nightlight", group: "Desktop", pane: "desktop", kind: "night", icon: "󰖔", title: "Night light",
        blurb: "A warmer, easier-on-the-eyes screen now, or every evening." },
      { id: "sizes", group: "Desktop", pane: "desktop", kind: "sizes", icon: "⤢", title: "Size of everything",
        blurb: "Make text, the pointer, the gaps between windows and the top bar bigger or smaller together, and choose how big this window opens." },
      { id: "displays", group: "Desktop", pane: "desktop", kind: "monitors", icon: "▣", title: "Resolution & scale",
        blurb: "How sharp and how big things look on each screen, and which way up it is. Tried first, kept only if you say so." }
    ]
    for (var i = 0; i < LookSchema.SECTIONS.length; i++) {
      var look = LookSchema.SECTIONS[i]
      out.push({ id: look.id, group: "Windows", pane: "rows", icon: look.icon, title: look.title,
                 blurb: look.blurb, groups: look.groups })
    }
    out.push({ id: "borders", group: "Windows", pane: "desktop", kind: "borders", icon: "◰", title: "Shape & border",
               blurb: "Ready-made window shapes, and a border colour that fades between shades of your theme." })
    out.push({ id: "frame", group: "Windows", pane: "desktop", kind: "frame", icon: "⬚", title: "Screen frame",
               blurb: "Rounded screen corners, a frame around the screen and a soft shade over it, drawn by an optional extra." })
    out.push({ id: "animations", group: "Windows", pane: "rows", icon: "󱐋", title: "Animations",
               blurb: "How fast each kind of animation plays and how it moves." })
    out.push({ id: "curves", group: "Windows", pane: "curves", icon: "󰓅", title: "Animation curves",
               blurb: "The shape of an animation's speed-up and slow-down. Drag either handle; everything using that curve follows." })
    out.push({ id: "shell", group: "Shell", pane: "rows", icon: "󰒓", title: "Bar & menu style",
               blurb: "Text size, spacing and colours of the top bar, menus, pop-ups and notifications." })
    out.push({ id: "bar", group: "Shell", pane: "bar", icon: "󰞍", title: "Top bar",
               blurb: "Where the top bar sits, and what it shows." })
    // Needs OmaMenu with its Menu Look IPC; without it the section is left out.
    if (menuLookStore.available)
    out.push({ id: "menulook", group: "Shell", pane: "desktop", kind: "menu", icon: "󰍜", title: "App menu look",
               blurb: "The size, corners, border and see-through look of the app menu." })
    out.push({ id: "lock", group: "Screens", pane: "desktop", kind: "lock", icon: "󰌾", title: "Lock & start-up screen",
               blurb: "When the screen locks, and the screen asking for your password when the computer starts." })
    out.push({ id: "screensaver", group: "Screens", pane: "desktop", kind: "screensaver", icon: "󱄄", title: "Screensaver",
               blurb: "When the screensaver starts, and the picture it shows." })
    out.push({ id: "terminals", group: "Apps", pane: "desktop", kind: "terminal", icon: "󰆍", title: "Terminal",
               blurb: "Spacing, cursor and see-through background of the terminal, the window where you type commands." })
    out.push({ id: "btop", group: "Apps", pane: "desktop", kind: "btop", icon: "󰄨", title: "System monitor & prompt",
               blurb: "How the system monitor shows your computer's activity, and the spacing of the terminal's prompt line." })
    out.push({ id: "launcher", group: "Apps", pane: "desktop", kind: "launcher", icon: "≡", title: "App list",
               blurb: "What each app is called in the app list, its icon, and whether it shows up at all." })
    out.push({ id: "apprules", group: "Apps", pane: "desktop", kind: "rules", icon: "◱", title: "App windows",
               blurb: "How one app's windows open: floating or filling a spot, their size, desktop and see-through look." })
    out.push({ id: "plugins", group: "Apps", pane: "plugins", icon: "󰏖", title: "Add-on settings",
               blurb: "Settings for each add-on you have installed." })
    // Where each page lives: main tab (group), then sub tab (sub). A sub tab
    // holding more than one page shows them as a third row. Keyboard Tab
    // walks this order, so it is also the order the pages are listed in.
    var placed = [out[0]]
    var used = { home: true }
    for (var p = 0; p < root.pagePlaces.length; p++) {
      var place = root.pagePlaces[p]
      for (var q = 0; q < out.length; q++) {
        if (out[q].id !== place[0]) continue
        out[q].group = place[1]
        out[q].sub = place[2]
        placed.push(out[q])
        used[out[q].id] = true
      }
    }
    // Anything not placed above still gets a home rather than vanishing.
    for (var r = 0; r < out.length; r++)
      if (!used[out[r].id]) { out[r].group = "Apps"; out[r].sub = out[r].title; placed.push(out[r]) }
    return placed
  }

  // [page id, main tab, sub tab], in the order they are shown.
  readonly property var pagePlaces: [
    ["theme", "Colours & wallpaper", "Themes"], ["shuffle", "Colours & wallpaper", "Shuffle"], ["generate", "Colours & wallpaper", "Make a theme"],
    ["fonts", "Screen & text", "Text"], ["sizes", "Screen & text", "Text"],
    ["gtk", "Screen & text", "Look of apps"], ["cursor", "Screen & text", "Look of apps"],
    ["displays", "Screen & text", "Screens"], ["nightlight", "Screen & text", "Screens"],
    ["lock", "Screen & text", "Lock screen"], ["screensaver", "Screen & text", "Lock screen"],
    ["borders", "Windows", "Shape"], ["decoration", "Windows", "Shape"],
    ["effects", "Windows", "Effects"], ["frame", "Windows", "Effects"],
    ["windows", "Windows", "Layout"], ["groups", "Windows", "Layout"],
    ["motion", "Windows", "Motion"], ["animations", "Windows", "Motion"], ["curves", "Windows", "Motion"],
    ["shell", "Top bar & menus", "Style"], ["bar", "Top bar & menus", "Top bar"], ["menulook", "Top bar & menus", "App menu"],
    ["terminals", "Apps", "Terminal"], ["btop", "Apps", "Terminal"],
    ["launcher", "Apps", "App list"], ["apprules", "Apps", "App list"],
    ["plugins", "Apps", "Add-ons"]
  ]

  readonly property var mainTabs: [
    { title: "Colours & wallpaper", icon: "" },
    { title: "Screen & text", icon: "󰍹" },
    { title: "Windows", icon: "󱆏" },
    { title: "Top bar & menus", icon: "󰒓" },
    { title: "Apps", icon: "󰀻" }
  ]

  // The rail: Home, then the main tabs.
  readonly property var railEntries: {
    var out = [{ kind: "home", title: "Home", icon: "󰋜" }]
    for (var i = 0; i < mainTabs.length; i++) out.push({ kind: "main", title: mainTabs[i].title, icon: mainTabs[i].icon })
    return out
  }

  readonly property string currentMain: section.group || ""
  readonly property string currentSub: section.sub || ""

  // The sub tabs of the main tab on screen, in order.
  readonly property var subTabs: {
    var out = []
    for (var i = 0; i < sections.length; i++)
      if (sections[i].group === currentMain && currentMain !== "" && out.indexOf(sections[i].sub) < 0) out.push(sections[i].sub)
    return out
  }

  // The pages of the sub tab on screen, when there is more than one.
  readonly property var deepTabs: {
    var out = []
    for (var i = 0; i < sections.length; i++)
      if (sections[i].group === currentMain && sections[i].sub === currentSub && currentMain !== "") out.push(sections[i])
    return out.length > 1 ? out : []
  }

  // The page last open in each main tab and sub tab, so going back to one
  // returns where you were rather than to its first page.
  property var lastInMain: ({})
  property var lastInSub: ({})

  function indexOfSection(id) {
    for (var i = 0; i < sections.length; i++) if (sections[i].id === id) return i
    return -1
  }

  function goToIndex(i) {
    if (i >= 0 && i !== root.sectionIndex) root.moveSection(i - root.sectionIndex)
  }

  function goToMain(title) {
    if (title === "Home") { root.goToIndex(0); return }
    var remembered = root.indexOfSection(root.lastInMain[title] || "")
    if (remembered >= 0 && sections[remembered].group === title) { root.goToIndex(remembered); return }
    for (var i = 0; i < sections.length; i++) if (sections[i].group === title) { root.goToIndex(i); return }
  }

  function goToSub(sub) {
    var key = currentMain + "/" + sub
    var remembered = root.indexOfSection(root.lastInSub[key] || "")
    if (remembered >= 0 && sections[remembered].sub === sub && sections[remembered].group === currentMain) { root.goToIndex(remembered); return }
    for (var i = 0; i < sections.length; i++)
      if (sections[i].group === currentMain && sections[i].sub === sub) { root.goToIndex(i); return }
  }

  readonly property var section: sections[Math.max(0, Math.min(sections.length - 1, sectionIndex))]

  readonly property bool isTheme: section.id === "theme"
  readonly property bool isShuffle: section.id === "shuffle"
  readonly property bool isGenerate: section.id === "generate"
  readonly property bool isDesktop: section.pane === "desktop"
  readonly property bool isHome: section.pane === "home"

  readonly property bool isAnimations: section.id === "animations"

  readonly property bool isCurves: section.id === "curves"

  readonly property bool isShell: section.id === "shell"

  readonly property bool isBar: section.id === "bar"

  readonly property bool isPlugins: section.id === "plugins"

  readonly property var animTabs: {
    var out = [{ title: "Master" }]
    for (var i = 0; i < AnimSchema.SECTIONS.length; i++) out.push(AnimSchema.SECTIONS[i])
    return out
  }

  // A flat list of { kind } records, so one ListView can render headers,
  // config rows and animation-leaf rows without three parallel views.
  readonly property var rows: {
    var out = []
    if (section.pane !== "rows") return out

    if (isShell) {
      var tab = ShellSchema.TABS[shellTab]
      for (var sg = 0; sg < tab.groups.length; sg++) {
        out.push({ kind: "header", title: tab.groups[sg].title })
        for (var si = 0; si < tab.groups[sg].items.length; si++)
          out.push({ kind: "shell", item: tab.groups[sg].items[si] })
      }
      return out
    }

    if (isAnimations) {
      if (animTab === 0) {
        out.push({ kind: "header", title: LookSchema.ANIMATION_MASTER.title })
        var master = LookSchema.ANIMATION_MASTER.items
        for (var m = 0; m < master.length; m++) out.push({ kind: "item", item: master[m] })
        return out
      }
      var leafGroup = AnimSchema.SECTIONS[animTab - 1]
      out.push({ kind: "header", title: leafGroup.title })
      for (var l = 0; l < leafGroup.leaves.length; l++)
        out.push({ kind: "leaf", leaf: leafGroup.leaves[l] })
      return out
    }

    var groups = section.groups || []
    for (var g = 0; g < groups.length; g++) {
      var visible = []
      for (var i = 0; i < groups[g].items.length; i++) {
        var entry = groups[g].items[i]
        // A `needs` + `needsValue` drops the row entirely, so the Tiling
        // engine group only ever shows the active engine's knobs instead of
        // three greyed-out sets.
        if (entry.needsValue !== undefined) {
          var dep = LookSchema.itemFor(entry.needs)
          if (dep && String(hypr.valueFor(dep)) !== String(entry.needsValue)) continue
        }
        visible.push(entry)
      }
      if (visible.length === 0) continue
      out.push({ kind: "header", title: groups[g].title })
      for (var v = 0; v < visible.length; v++) out.push({ kind: "item", item: visible[v] })
    }
    return out
  }

  readonly property bool sectionModified: {
    if (isCurves) return hypr.curveModified(curveName)
    for (var i = 0; i < rows.length; i++) {
      var entry = rows[i]
      if (entry.kind === "item" && hypr.isModified(entry.item.key)) return true
      if (entry.kind === "leaf" && hypr.leafModified(entry.leaf.name)) return true
      if (entry.kind === "shell" && toml.shellModified(entry.item)) return true
    }
    return false
  }

  readonly property int overrideCount: {
    var n = hypr.opaqueWindows ? 1 : 0
    var k
    for (k in hypr.overrides) n++
    for (k in hypr.leaves) if (!hypr.baseLeaves[k] || !StyleLua.sameLeaf(hypr.leaves[k], hypr.baseLeaves[k])) n++
    for (k in hypr.curves) if (!hypr.curveBaseline(k) || !StyleLua.sameCurve(hypr.curves[k], hypr.curveBaseline(k))) n++
    var known = ShellSchema.allItems()
    for (var i = 0; i < known.length; i++)
      if (toml.shellUser[known[i].id] !== undefined) n++
    return n
  }

  // ------------------------------------------------------------- lifecycle

  // Removes OmaShuffle and lets Lacquer's engine take the shuffle over. Only ever
  // reached through the Shuffle section's two-step confirmation.
  function moveShuffleToLacquer() {
    root.confirmShuffleMove = false
    if (shuffleMoveProc.running) return
    root.errorText = ""
    root.statusText = "Moving the shuffle to Lacquer…"
    shuffleMoveProc.running = true
  }

  // Sections hand keyboard focus back to the panel through this.
  function focusPanel() { keyCatcher.forceActiveFocus() }

  function open(payloadJson) {
    root.opened = true
    root.errorText = ""
    root.confirmRemove = false
    hypr.defaultsFileRef.reload()
    hypr.configFileRef.reload()
    hypr.windowsFileRef.reload()
    toml.shellUserFileRef.reload()
    toml.shellThemeFileRef.reload()
    toml.themeNameFileRef.reload()
    sjson.shellJsonFileRef.reload()
    sjson.scanProcRef.command = ["timeout", "-k", "2", "20", "python3", root.pluginDir + "/scan-plugins.py"]
    sjson.scanProcRef.running = true
    legacyProbe.running = true
    themeStore.rescan()
    pointerGateObj.reset()
    // Never start on a group header, where the first arrow key would do nothing.
    if (!root.rowIsFocusable(root.cursorRow())) { root.cursorIndex = 0; root.moveCursor(1) }
    var target = "home"
    try {
      var payload = JSON.parse(payloadJson || "{}")
      if (payload && typeof payload.section === "string") target = payload.section
    } catch (e) { }
    if (!root.showSectionById(target)) root.showSectionById("home")
    // A pick from the wallpaper picker that Generate opened.
    if (payload && typeof payload.aetherSource === "string" && root.isImagePath(payload.aetherSource))
      aetherStore.setSource(payload.aetherSource)
    // What the font/cursor helper did, in one line (see DesktopStore.add).
    if (payload && typeof payload.status === "string" && payload.status !== "")
      root.statusText = payload.status.replace(/[\x00-\x1f\x7f]/g, " ").slice(0, 200)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    // A pending edit is already live on the compositor, so it has to reach the
    // file rather than evaporate at the next reload.
    if (hypr.persistTimerRef.running) hypr.persistNow()
    toml.clearDraft()
    root.opened = false
    root.confirmRemove = false
    root.confirmResetAll = false
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "lacquer")
    else close()
  }

  function toggle() {
    if (root.opened) { close(); dismiss() }
    else root.open("{}")
  }

  // ------------------------------------------------------------------ undo

  function snapshot() {
    return {
      overrides: StyleLua.cloneOverrides(hypr.overrides),
      leaves: StyleLua.cloneLeafMap(hypr.leaves),
      curves: StyleLua.cloneCurveMap(hypr.curves),
      shell: toml.shellUserText,
      opaque: hypr.opaqueWindows,
      borders: bordersStore.clone(bordersStore.spec),
      rules: rulesStore.rules.slice()
    }
  }

  function restore(state) {
    hypr.overrides = StyleLua.cloneOverrides(state.overrides)
    hypr.leaves = StyleLua.cloneLeafMap(state.leaves)
    hypr.curves = StyleLua.cloneCurveMap(state.curves)
    if (state.opaque !== undefined) hypr.opaqueWindows = state.opaque === true
    if (state.borders !== undefined) bordersStore.restoreSpec(state.borders)
    if (state.rules !== undefined) rulesStore.restoreRules(state.rules)
    if (state.shell !== undefined) toml.writeShell(state.shell)
  }

  // Captured before the first edit of a gesture, pushed when that gesture
  // commits, so undoing a slider drag goes back to where the drag started
  // rather than to the previous animation frame.
  function beginEdit() {
    if (!root.pendingUndo) root.pendingUndo = snapshot()
  }

  function commitEdit(label) {
    var before = root.pendingUndo || snapshot()
    root.pendingUndo = null
    var next = root.undoStack.slice()
    next.push({ label: label, state: before })
    if (next.length > 50) next.shift()
    root.undoStack = next
    hypr.persistTimerRef.restart()
  }

  function undo() {
    if (root.undoStack.length === 0) return
    var next = root.undoStack.slice()
    var entry = next.pop()
    root.undoStack = next
    restore(entry.state)
    root.pendingUndo = null
    root.statusText = "Undid " + entry.label
    hypr.persistNow()
  }

  function resetSection() {
    if (root.isCurves) { hypr.resetCurve(root.curveName); return }
    if (root.isShell) {
      beginEdit()
      var text = toml.shellUserText
      for (var i = 0; i < root.rows.length; i++)
        if (root.rows[i].kind === "shell")
          text = TomlEdit.unset(text, root.rows[i].item.section, root.rows[i].item.key)
      toml.writeShell(text)
      commitEdit(ShellSchema.TABS[root.shellTab].title)
      return
    }
    if (root.isAnimations && root.animTab > 0) {
      beginEdit()
      var nextLeaves = StyleLua.cloneLeafMap(hypr.leaves)
      var group = AnimSchema.SECTIONS[root.animTab - 1]
      for (var l = 0; l < group.leaves.length; l++) delete nextLeaves[group.leaves[l].name]
      hypr.leaves = nextLeaves
      commitEdit(group.title)
      hypr.persistNow()
      return
    }
    var keys = []
    for (var i = 0; i < root.rows.length; i++)
      if (root.rows[i].kind === "item") keys.push(root.rows[i].item.key)
    hypr.resetKeys(keys, root.section.title)
  }

  function resetAll() {
    beginEdit()
    hypr.overrides = ({})
    hypr.leaves = ({})
    hypr.curves = ({})
    hypr.opaqueWindows = false
    // The border gradient and the per-app window rules are Lacquer's too, and
    // both are rendered into the same blocks; leaving them behind would make
    // "Reset all" a half-measure. Undo carries both back (see snapshot()).
    bordersStore.restoreSpec({ mode: "", amount: 0.4, angle: 45, inactive: false, groups: true })
    rulesStore.restoreRules([])
    var text = toml.shellUserText
    var all = ShellSchema.allItems()
    for (var i = 0; i < all.length; i++) text = TomlEdit.unset(text, all[i].section, all[i].key)
    toml.writeShell(text)
    commitEdit("everything")
    hypr.persistNow()
  }

  function removeLegacyPlugins() {
    var ids = root.legacyPresent
    if (ids.length === 0) return
    removeProc.command = ["sh", "-c", 'for id in "$@"; do omarchy plugin remove "$id" --yes; done', "lacquer-remove"].concat(ids)
    removeProc.running = true
    root.confirmRemove = false
    hypr.migrationNotice = ""
    root.statusText = "Removing " + ids.join(", ") + "…"
  }

  // ------------------------------------------------------------- keyboard

  function rowIsFocusable(entry) {
    return entry && entry.kind !== "header"
  }

  function moveCursor(delta) {
    pointerGateObj.reset()
    var count = root.rows.length
    if (count === 0) return
    var at = root.cursorIndex
    for (var guard = 0; guard < count; guard++) {
      at = (at + delta + count) % count
      if (rowIsFocusable(root.rows[at])) break
    }
    root.cursorIndex = at
    rowsSection.positionAt(at, ListView.Contain)
  }

  // Sub-tabs were reachable only by mouse, which strands the keyboard in the
  // first tab of a section that has 134 rows behind three others.
  function moveSubTab(delta) {
    pointerGateObj.reset()
    if (isShell) {
      var n = ShellSchema.TABS.length
      root.shellTab = (root.shellTab + delta + n) % n
    } else if (isAnimations) {
      var m = root.animTabs.length
      root.animTab = (root.animTab + delta + m) % m
    } else if (isPlugins) {
      var ids = []
      for (var i = 0; i < sjson.plugins.length; i++)
        if ((sjson.plugins[i].schema || []).length > 0) ids.push(sjson.plugins[i].id)
      if (ids.length === 0) return
      var at = ids.indexOf(root.selectedPlugin)
      root.selectedPlugin = ids[(at + delta + ids.length) % ids.length]
      return
    } else {
      return
    }
    toml.clearDraft()
    root.cursorIndex = 0
    moveCursor(1)
  }

  // Opens a search result from Home: the section, its sub-tab, then the row
  // or choice group, once the section's rows exist.
  function jumpTo(entry) {
    if (!entry || !root.showSectionById(entry.section)) return
    if (entry.shellTab !== undefined) root.shellTab = entry.shellTab
    if (entry.animTab !== undefined) root.animTab = entry.animTab
    Qt.callLater(function() {
      if (entry.group && root.isDesktop) { desktopSection.focusGroupTitle(entry.group); return }
      if (!entry.key && !entry.leaf) return
      for (var i = 0; i < root.rows.length; i++) {
        var r = root.rows[i]
        var hit = (entry.leaf && r.leaf && r.leaf.name === entry.leaf)
          || (entry.key && r.item && (r.item.key === entry.key || r.item.id === entry.key))
        if (!hit) continue
        root.cursorIndex = i
        rowsSection.positionAt(i, ListView.Center)
        return
      }
    })
  }

  // An absolute path to an image, with nothing odd in it. The file itself is
  // only ever handed to aether as a single argument.
  function isImagePath(p) {
    return typeof p === "string" && p.length < 4096 && p.charAt(0) === "/"
      && !/[\u0000-\u001f\u007f]/.test(p) && /\.(png|jpe?g|webp|gif|bmp)$/i.test(p)
  }

  function showSectionById(id) {
    for (var i = 0; i < root.sections.length; i++) {
      if (root.sections[i].id !== id) continue
      if (i !== root.sectionIndex) root.moveSection(i - root.sectionIndex)
      return true
    }
    return false
  }

  function moveSection(delta) {
    pointerGateObj.reset()
    var count = root.sections.length
    root.sectionIndex = (root.sectionIndex + delta + count) % count
    toml.clearDraft()
    root.confirmResetAll = false
    root.confirmGenerate = false
    desktopStore.confirmMono = ""
    nightStore.confirmReplace = false
    root.cursorIndex = 0
    moveCursor(1)
  }

  function cursorRow() {
    if (root.cursorIndex < 0 || root.cursorIndex >= root.rows.length) return null
    return root.rows[root.cursorIndex]
  }

  function nudge(direction) {
    var entry = cursorRow()
    if (!entry) return

    if (entry.kind === "leaf") {
      var value = hypr.leafValue(entry.leaf.name)
      if (!value) { hypr.setLeaf(entry.leaf.name, hypr.inheritedFrom(entry.leaf), true); return }
      if (value.enabled === false) return
      var speed = Math.max(AnimSchema.SPEED_MIN, Number(value.speed) + direction * 0.1)
      hypr.setLeaf(entry.leaf.name, { enabled: true, speed: speed, bezier: value.bezier, style: value.style }, true)
      return
    }

    if (entry.kind === "shell") {
      var spec = entry.item
      if (spec.type === "color") return
      if (spec.type === "bool") {
        toml.setShell(spec, direction > 0, true)
        return
      }
      var raw = toml.shellValue(spec)
      if (raw === undefined) raw = toml.shellDefault(spec)
      var n = Number(raw)
      if (!isFinite(n)) n = spec.min
      var shellStep = spec.step === undefined ? 1 : spec.step
      toml.setShell(spec, Math.max(spec.min, Math.min(spec.max, n + shellStep * direction)), true)
      return
    }

    var item = entry.item
    if (!item || !hypr.isAvailable(item)) return
    var current = hypr.valueFor(item)
    if (item.type === "bool") { hypr.setValue(item, direction > 0, true); return }
    if (item.type === "enum") {
      var options = item.options || []
      if (options.length === 0) return
      var at = 0
      for (var i = 0; i < options.length; i++)
        if (String(options[i].value) === String(current)) at = i
      hypr.setValue(item, options[(at + direction + options.length) % options.length].value, true)
      return
    }
    var step = item.step === undefined ? 1 : item.step
    var min = Math.min(item.min, Number(current))
    var max = Math.max(item.max, Number(current))
    hypr.setValue(item, Math.max(min, Math.min(max, Number(current) + step * direction)), true)
  }

  function activateCursor() {
    var entry = cursorRow()
    if (!entry) return
    if (entry.kind === "leaf") {
      var value = hypr.leafValue(entry.leaf.name)
      if (!value) { hypr.setLeaf(entry.leaf.name, hypr.inheritedFrom(entry.leaf), true); return }
      hypr.setLeaf(entry.leaf.name, { enabled: value.enabled === false, speed: value.speed,
                                 bezier: value.bezier, style: value.style }, true)
      return
    }
    if (entry.kind === "shell") {
      if (entry.item.type !== "bool") return
      var current = toml.shellValue(entry.item)
      if (current === undefined) current = toml.shellDefault(entry.item)
      toml.setShell(entry.item, String(current) !== "true", true)
      return
    }
    var item = entry.item
    if (!item || !hypr.isAvailable(item)) return
    if (item.type === "bool") hypr.setValue(item, hypr.valueFor(item) !== true, true)
    else if (item.type === "enum") nudge(1)
  }

  function resetCursor() {
    var entry = cursorRow()
    if (!entry) return
    if (entry.kind === "leaf") { if (hypr.leafModified(entry.leaf.name)) hypr.resetLeaf(entry.leaf.name); return }
    if (entry.kind === "shell") { if (toml.shellModified(entry.item)) toml.resetShellItem(entry.item); return }
    if (entry.item && hypr.isModified(entry.item.key)) hypr.resetKeys([entry.item.key], entry.item.label)
  }

  function jumpToCurve(name) {
    if (!name) return
    root.curveName = name
    for (var i = 0; i < root.sections.length; i++)
      if (root.sections[i].id === "curves") root.sectionIndex = i
  }

  Process {
    id: legacyProbe
    command: ["sh", "-c",
      'for p in bobbynicholas.omaland; do '
      + '[ -d "$HOME/.config/omarchy/plugins/$p" ] && echo "$p"; done; true']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var found = []
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++)
          if (lines[i].trim() !== "") found.push(lines[i].trim())
        root.legacyPresent = found
      }
    }
  }

  Process {
    id: removeProc
    onExited: function(code) {
      root.statusText = code === 0 ? "Removed" : ""
      if (code !== 0) root.errorText = "Could not remove the old plugins"
      legacyProbe.running = true
    }
  }

  // A confirm that waits forever is a trap for the next click.
  Timer {
    id: resetAllTimeout
    interval: 4000
    onTriggered: root.confirmResetAll = false
  }

  Timer {
    id: statusClear
    interval: 2200
    running: root.statusText !== "" && root.statusText !== "Saving…"
    onTriggered: root.statusText = ""
  }

  // QML cannot glob, and the host's registry snapshot covers only bar widgets,
  // so the manifests are read off disk instead — the one source that also sees
  // panel, service and overlay plugins.
  // Live apply means a mistake reaches disk, so the first time Lacquer ever
  // loads it snapshots the three files it can write. Once only — a marker in
  // the state dir — so the snapshot is of the state before Lacquer, not of
  // whatever it wrote yesterday.
  Process {
    id: backupProc
    command: ["sh", "-c",
      'state="$HOME/.local/state/omarchy"; marker="$state/lacquer-backups-made"\n'
      + 'mkdir -p "$state" || exit 0\n'
      + '[ -e "$marker" ] && exit 0\n'
      + 'stamp=$(date +%Y%m%d-%H%M%S)\n'
      + 'made=""\n'
      + 'for f in "$HOME/.config/hypr/looknfeel.lua" "$HOME/.config/omarchy/shell.toml" '
      + '"$HOME/.config/omarchy/shell.json"; do\n'
      + '  [ -f "$f" ] || continue\n'
      + '  cp -a "$f" "$f.lacquer-backup-$stamp" 2>/dev/null && made="$made $f"\n'
      + 'done\n'
      + '[ -n "$made" ] && printf %s "$stamp"\n'
      + 'touch "$marker"\n']
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var stamp = String(text || "").trim()
        if (stamp !== "") root.backupStamp = stamp
      }
    }
    onExited: {
      root.backupsDone = true
      if (!hypr.migrationWaiting) return
      hypr.migrationWaiting = false
      hypr.applyMigration()
    }
  }

  // ------------------------------------------------------------------- UI

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lacquer"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: root.scrim
      MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(root.panelSizeSpec.w), window.width - Style.gapsOut * 4)
      height: Math.min(Style.space(root.panelSizeSpec.h), window.height - Style.gapsOut * 4)
      // As round as the cards inside it: no square window around the goo.
      radius: root.design.cardRadius + 6
      color: root.background
      borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.panelPadding

      MouseArea { anchors.fill: parent; onClicked: {} }

      // The pointer moving over the panel counts as someone using it. Only real
      // movement: Qt re-sends hover to a pointer that is resting still whenever
      // the scene under it repaints, and counting those would let the breathing
      // keep itself awake forever.
      HoverHandler {
        property point last: Qt.point(-1, -1)
        onPointChanged: {
          var p = point.scenePosition
          if (Math.abs(p.x - last.x) < 0.5 && Math.abs(p.y - last.y) < 0.5) return
          last = p
          root.poke()
        }
      }

      // The slow goo behind everything. Inset so it stays inside the card's
      // rounded corners.
      AmbientGoo {
        anchors.fill: parent
        anchors.margins: card.radius * 0.5
        design: root.design
        palette: {
          var info = root.theme.themeFor(root.theme.current) || ({})
          var out = []
          var raw = [info.accent].concat(info.colors || [])
          for (var i = 0; i < raw.length && out.length < 7; i++) if (raw[i]) out.push(String(raw[i]))
          return out.length ? out : [String(root.accent)]
        }
        running: root.opened && root.lively
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
          root.poke()
          var plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))

          if (event.modifiers & Qt.ControlModifier) {
            if (event.key === Qt.Key_Z) { root.undo(); event.accepted = true }
            else if (event.key === Qt.Key_M) { root.setMotion(!root.motion); event.accepted = true }
            else if (event.key === Qt.Key_I && hypr.legacyBlocks.length > 0 && !root.legacyDismissed) { hypr.importLegacy(); event.accepted = true }
            return
          }

          if (event.text === "?") { root.showHints = !root.showHints; event.accepted = true; return }

          if (root.isHome) {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              // fall through to section switching below
            } else if (event.key === Qt.Key_Escape) {
              if (!homeSection.clearQuery()) root.dismiss()
              event.accepted = true; return
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
              homeSection.moveBy(event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0,
                                 event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0)
              event.accepted = true; return
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              homeSection.activate(); event.accepted = true; return
            } else if (event.key === Qt.Key_Backspace) {
              homeSection.backspace(); event.accepted = true; return
            } else if (plain && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
              homeSection.typeText(event.text); event.accepted = true; return
            }
          }

          if (root.isTheme || root.isDesktop) {
            var target = root.isTheme ? themeSection : desktopSection
            var dx = 0, dy = 0
            if (event.key === Qt.Key_Right || (plain && event.key === Qt.Key_L)) dx = 1
            else if (event.key === Qt.Key_Left || (plain && event.key === Qt.Key_H)) dx = -1
            else if (event.key === Qt.Key_Down || (plain && event.key === Qt.Key_J)) dy = 1
            else if (event.key === Qt.Key_Up || (plain && event.key === Qt.Key_K)) dy = -1
            if (dx !== 0 || dy !== 0) { target.moveBy(dx, dy); event.accepted = true; return }
            if (root.isDesktop && (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace)) {
              target.clearPin(); event.accepted = true; return
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
              target.activate(); event.accepted = true; return
            }
          }

          if (root.isGenerate && plain) {
            if (event.key === Qt.Key_Escape && root.confirmGenerate) { root.confirmGenerate = false; event.accepted = true; return }
            if (event.key === Qt.Key_L) { aetherStore.setLight(!aetherStore.light); event.accepted = true; return }
            if (event.key === Qt.Key_O) { aetherStore.openAether(); event.accepted = true; return }
            if (event.key === Qt.Key_W) { aetherStore.pick("wallpapers"); event.accepted = true; return }
            if (event.key === Qt.Key_F) { aetherStore.pick("file"); event.accepted = true; return }
            if (event.key === Qt.Key_G) {
              if (root.confirmGenerate) { root.confirmGenerate = false; aetherStore.generate() }
              else if (!aetherStore.generating && aetherStore.source !== "") root.confirmGenerate = true
              event.accepted = true; return
            }
          }

          if (event.key === Qt.Key_Escape) { root.dismiss(); event.accepted = true }
          else if (event.key === Qt.Key_Down || (plain && event.key === Qt.Key_J)) {
            root.moveCursor(1); event.accepted = true
          }
          else if (event.key === Qt.Key_Up || (plain && event.key === Qt.Key_K)) {
            root.moveCursor(-1); event.accepted = true
          }
          else if (event.key === Qt.Key_Right || (plain && event.key === Qt.Key_L)) {
            root.nudge(1); event.accepted = true
          }
          else if (event.key === Qt.Key_Left || (plain && event.key === Qt.Key_H)) {
            root.nudge(-1); event.accepted = true
          }
          else if (plain && event.key === Qt.Key_BracketLeft) {
            root.moveSubTab(-1); event.accepted = true
          }
          else if (plain && event.key === Qt.Key_BracketRight) {
            root.moveSubTab(1); event.accepted = true
          }
          else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            var back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)
            root.moveSection(back ? -1 : 1)
            event.accepted = true
          }
          else if (plain && event.key === Qt.Key_P && root.isCurves) {
            curvesSection.play(); event.accepted = true
          }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                   || event.key === Qt.Key_Space) { root.activateCursor(); event.accepted = true }
          else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete) {
            root.resetCursor(); event.accepted = true
          }
        }
      }

      ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: Style.spacing.panelGap

        // ------------------------------------------------------ header

        Item {
          Layout.fillWidth: true
          Layout.preferredHeight: Math.max(titleBlock.implicitHeight, headerActions.implicitHeight)

          Text {
            id: titleBlock
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Lacquer"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.md

            PanelActionButton {
              iconText: "󰕌"
              enabled: root.undoStack.length > 0
              opacity: enabled ? 1 : 0.35
              tooltipText: "Undo  ·  Ctrl+Z"
              foreground: root.foreground
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.undo()
            }

            PanelActionButton {
              iconText: "?"
              tooltipText: root.keyHints
              foreground: root.showHints ? root.accent : root.foreground
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.showHints = !root.showHints
            }

            PanelActionButton {
              iconText: "󰅖"
              tooltipText: "Close  ·  Esc"
              foreground: root.foreground
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.dismiss()
            }
          }
        }

        // ------------------------------------------- migration banner

        BorderSurface {
          Layout.fillWidth: true
          readonly property bool showing: !root.legacyDismissed && (hypr.legacyBlocks.length > 0 || root.legacyPresent.length > 0)
          Layout.preferredHeight: showing ? migrationRow.implicitHeight + Style.spacing.xxl : 0
          visible: showing
          radius: root.design.cardRadius
          color: Style.selectedFillFor(root.accent, root.accent)
          borderSpec: Border.controlSpec("normal", root.accent, root.accent)

          Row {
            id: migrationRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Style.spacing.lg
            anchors.rightMargin: Style.spacing.lg
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.lg

            Text {
              width: parent.width - keepButton.width - Style.spacing.lg
                - (importButton.visible ? importButton.width + Style.spacing.lg : 0)
                - (removeButton.visible ? removeButton.width + Style.spacing.lg : 0)
              text: {
                var names = root.legacyPresent.join(" and ")
                if (root.confirmRemove) return "Uninstall " + names + "? Its settings stay in looknfeel.lua unless you imported them."
                if (hypr.legacyBlocks.length > 0)
                  return "Omaland settings found in looknfeel.lua. Import them to edit them here; nothing changes until you do."
                if (hypr.migrationNotice !== "") return hypr.migrationNotice
                  + (names ? " " + names + " is still installed and rewrites its block when opened." : "")
                return names + " is installed too. Both write to looknfeel.lua, so opening it can undo changes made here."
              }
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
              anchors.verticalCenter: parent.verticalCenter
            }

            LqButton {
              design: root.design
              id: importButton
              visible: hypr.legacyBlocks.length > 0 && !root.confirmRemove
              text: "Import settings"
              tooltipText: "Ctrl+I"
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              anchors.verticalCenter: parent.verticalCenter
              onClicked: hypr.importLegacy()
            }

            LqButton {
              design: root.design
              id: removeButton
              visible: root.legacyPresent.length > 0
              text: root.confirmRemove ? "Yes, uninstall" : "Uninstall Omaland"
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              anchors.verticalCenter: parent.verticalCenter
              onClicked: {
                if (root.confirmRemove) root.removeLegacyPlugins()
                else root.confirmRemove = true
              }
            }

            LqButton {
              design: root.design
              id: keepButton
              text: root.confirmRemove ? "Cancel" : "Not now"
              bordered: true
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              anchors.verticalCenter: parent.verticalCenter
              onClicked: {
                if (root.confirmRemove) root.confirmRemove = false
                else root.legacyDismissed = true
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground; Layout.fillWidth: true }

        // ------------------------------------------------------ body

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.spacing.panelGap

          // Home and the five main tabs, with a blob of accent that oozes
          // between them.
          Item {
            id: rail
            Layout.preferredWidth: Style.space(186)
            Layout.fillHeight: true
            function placeMarker() {}

            LqTabs {
              id: railTabs
              z: 2
              width: parent.width
              design: root.design
              style: "rail"
              fontSize: 14
              breath: root.breath
              options: {
                var out = []
                for (var i = 0; i < root.railEntries.length; i++)
                  out.push({ value: root.railEntries[i].title, label: root.railEntries[i].title, icon: root.railEntries[i].icon })
                return out
              }
              value: root.isHome ? "Home" : root.currentMain
              dripEnabled: false
              onSelectedIndexChanged: Qt.callLater(rail.dropFromSelection)
              onChanged: function(v) { root.goToMain(v) }
            }

            // A drop falls from the selected tab, slips behind the theme card
            // and lands in the puddle at the bottom, which ripples.
            function dropFromSelection() {
              if (!root.design.motion || !root.opened) return
              var r = railTabs.selectedCell()
              if (!r) return
              fallingDrop.x = r.x + r.width / 2 - fallingDrop.width / 2
              fallingDrop.y = r.y + r.height - 4
              fallingDrop.opacity = 0.7
              fall.to = puddle.y + puddle.height * 0.45 - fallingDrop.height
              fall.duration = Math.round(Math.sqrt(Math.max(1, fall.to - fallingDrop.y)) * 34)
              falling.restart()
            }

            Rectangle {
              id: fallingDrop
              // In front of the theme card, so you can watch it fall all the way.
              z: 3
              width: 7
              height: 9
              radius: 3.5
              color: root.design.accent
              opacity: 0
            }
            SequentialAnimation {
              id: falling
              PauseAnimation { duration: 160 }
              NumberAnimation { id: fall; target: fallingDrop; property: "y"; easing.type: Easing.InQuad }
              ScriptAction { script: {
                fallingDrop.opacity = 0
                var cx = fallingDrop.x + fallingDrop.width / 2
                puddle.splash(cx, 1)
                // Like water: a small droplet jumps back up out of the puddle
                // where the drop went in, hangs for a moment, and falls back.
                var surface = puddle.y + puddle.surfaceY(cx - puddle.x)
                rebound.x = cx - rebound.width / 2
                rebound.y = surface - rebound.height / 2
                reboundUp.from = rebound.y
                reboundUp.to = rebound.y - 16
                reboundDown.to = rebound.y
                rebound.opacity = 0.8
                bouncing.restart()
              } }
            }

            Rectangle {
              id: rebound
              z: 3
              width: 5
              height: 5
              radius: 2.5
              color: root.design.accent
              opacity: 0
            }
            SequentialAnimation {
              id: bouncing
              PauseAnimation { duration: 60 }
              NumberAnimation { id: reboundUp; target: rebound; property: "y"; duration: 230; easing.type: Easing.OutQuad }
              NumberAnimation { id: reboundDown; target: rebound; property: "y"; duration: 210; easing.type: Easing.InQuad }
              ScriptAction { script: { rebound.opacity = 0; puddle.splash(rebound.x + rebound.width / 2 - puddle.x, 0.4) } }
            }

            ThemeGlance {
              id: glance
              z: 2
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: puddle.top
              anchors.bottomMargin: 10
              // Hidden when the window is too short for it to sit under the tabs.
              visible: y > railTabs.height + 16
              design: root.design
              theme: root.theme.themeFor(root.theme.current) || ({})
              note: {
                var e = root.shuffle
                if (!e || !e.stateLoaded || !e.st) return ""
                if (e.st.schedule && e.st.schedule.enabled) return "Changes by itself at sunrise and sunset"
                if (e.st.enabled) return "A new theme at the next start-up"
                return ""
              }
              onClicked: root.showSectionById("theme")
            }

            GooPuddle {
              id: puddle
              z: 2
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 14
              design: root.design
            }
          }

          Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
          }

          ColumnLayout {
            id: pageContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Style.spacing.sm

            // Page transition: sections glide in along the rail's direction,
            // sub-tabs from the side, with a fade and a small settle.
            transform: [
              Translate { id: pageShift },
              Scale { id: pageScale; origin.x: pageContent.width / 2; origin.y: Style.space(40) }
            ]

            // A new page sinks gently into place, as if settling under its
            // own weight: a short slide and a fade, nothing that bounces.
            ParallelAnimation {
              id: pageEnter
              property string axis: "y"
              property int dir: 1
              NumberAnimation { target: pageShift; property: pageEnter.axis; from: pageEnter.dir * Style.space(pageEnter.axis === "y" ? 12 : 16); to: 0; duration: Math.round(motionStore.uiDuration * 0.75); easing.type: Easing.OutQuint }
              NumberAnimation { target: pageContent; property: "opacity"; from: 0; to: 1; duration: Math.round(motionStore.uiDuration * 0.5); easing.type: Easing.OutCubic }
              onStopped: { pageShift.x = 0; pageShift.y = 0; pageContent.opacity = 1; pageScale.xScale = 1; pageScale.yScale = 1 }
            }

            // The sub tabs of this main tab, and on the right the page reset.
            Item {
              Layout.fillWidth: true
              Layout.preferredHeight: Math.max(subTabRow.implicitHeight, sectionReset.implicitHeight)
              visible: !root.isHome

              LqTabs {
                id: subTabRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - Style.space(48))
                design: root.design
                style: "pills"
                fontSize: 14
                breath: root.breath
                options: root.subTabs
                value: root.currentSub
                onChanged: function(v) { root.goToSub(v) }
              }

              PanelActionButton {
                id: sectionReset
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰕌"
                tooltipText: root.isCurves ? "Reset this curve" : "Reset this section"
                foreground: root.foreground
                visible: root.sectionModified && root.section.pane !== "bar" && root.section.pane !== "plugins" && root.section.pane !== "theme" && root.section.pane !== "shuffle" && root.section.pane !== "generate" && root.section.pane !== "desktop"
                onClicked: root.resetSection()
              }
            }

            // The pages of this sub tab, when it holds more than one.
            LqTabs {
              Layout.fillWidth: true
              Layout.preferredHeight: implicitHeight
              visible: root.deepTabs.length > 0
              design: root.design
              style: "underline"
              fontSize: 13.5
              options: {
                var out = []
                for (var i = 0; i < root.deepTabs.length; i++) out.push({ value: root.deepTabs[i].id, label: root.deepTabs[i].title })
                return out
              }
              value: root.section.id
              onChanged: function(v) { root.goToIndex(root.indexOfSection(v)) }
            }

            // Sub-tabs, so 35 animation leaves or 134 shell tokens do not
            // become one scroll.
            LqTabs {
              Layout.fillWidth: true
              Layout.preferredHeight: implicitHeight
              visible: root.isAnimations || root.isShell
              design: root.design
              style: "underline"
              fontSize: 13
              options: {
                var out = []
                if (root.isShell) {
                  for (var t = 0; t < ShellSchema.TABS.length; t++) out.push(ShellSchema.TABS[t].title)
                  return out
                }
                for (var i = 0; i < root.animTabs.length; i++) out.push(root.animTabs[i].title)
                return out
              }
              value: root.isShell ? ShellSchema.TABS[root.shellTab].title
                                  : (root.animTabs[root.animTab] ? root.animTabs[root.animTab].title : "")
              onChanged: function(v) {
                if (root.isShell) {
                  for (var t = 0; t < ShellSchema.TABS.length; t++)
                    if (ShellSchema.TABS[t].title === v) root.shellTab = t
                } else {
                  for (var i = 0; i < root.animTabs.length; i++)
                    if (root.animTabs[i].title === v) root.animTab = i
                }
                root.cursorIndex = 0
                root.moveCursor(1)
              }
            }

            PanelSeparator { foreground: root.foreground; Layout.fillWidth: true }

            // ------------------------------------------------ rows

            RowsSection {
              id: rowsSection
              app: root
              visible: root.section.pane === "rows"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            HomeSection {
              id: homeSection
              app: root
              visible: root.section.pane === "home"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            DesktopSection {
              id: desktopSection
              app: root
              kind: root.section.kind || "fonts"
              visible: root.section.pane === "desktop"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }
            GenerateSection {
              app: root
              visible: root.section.pane === "generate"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            ShuffleSection {
              app: root
              visible: root.section.pane === "shuffle"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            ThemeSection {
              id: themeSection
              app: root
              visible: root.section.pane === "theme"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            BarSection {
              app: root
              visible: root.section.pane === "bar"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            // ------------------------------------------------ plugins

            PluginsSection {
              app: root
              visible: root.section.pane === "plugins"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }

            // ------------------------------------------------ curves

            CurvesSection {
              id: curvesSection
              app: root
              visible: root.section.pane === "curves"
              Layout.fillWidth: true
              Layout.fillHeight: true
            }
          }
        }

        PanelSeparator { foreground: root.foreground; Layout.fillWidth: true; visible: footerRow.visible }

        // ------------------------------------------------------ footer
        // Only there when something needs saying, or the keys were asked for.

        Item {
          id: footerRow
          Layout.fillWidth: true
          Layout.preferredHeight: visible ? footerText.implicitHeight + Style.spacing.md : 0
          visible: footerText.text !== ""

          Text {
            id: footerText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.footerMessage !== "" ? root.footerMessage : (root.showHints ? root.keyHints : "")
            color: root.errorText !== "" ? Color.urgent : Qt.darker(root.foreground, 1.6)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // Tell the service which pages exist, so its showSection can refuse a name
  // that is not one of them instead of quietly falling back to Home. The panel
  // is the only place the list is written down. The host sets `shell` after
  // building the panel, so this runs again when the service turns up.
  function publishSections() {
    if (!root.service) return
    var ids = []
    for (var i = 0; i < root.sections.length; i++) ids.push(root.sections[i].id)
    root.service.knownSections = ids
  }

  onServiceChanged: root.publishSections()

  Component.onCompleted: {
    backupProc.running = true
    root.publishSections()
  }

  // OmaShuffle's service builds its launcher-entry path from manifest.__sourceDir,
  // which Omarchy 4.0.3 strips from third-party manifests, so its removal can
  // orphan the entry (exactly what happened with Omaland). Only a file carrying
  // OmaShuffle's own marker, with the plugin really gone, is deleted.
  Process {
    id: shuffleMoveProc
    command: ["sh", "-c",
      'mkdir -p "$HOME/.local/state/omarchy/io.github.deunnis.lacquer" && touch "$HOME/.local/state/omarchy/io.github.deunnis.lacquer/adopt-omashuffle"\n'
      + 'omarchy plugin remove io.github.omashuffle --yes >/dev/null 2>&1 || { rm -f "$HOME/.local/state/omarchy/io.github.deunnis.lacquer/adopt-omashuffle"; exit 1; }\n'
      + 'f="$HOME/.local/share/applications/omashuffle.desktop"\n'
      + 'if [ -f "$f" ] && grep -q "^X-OmaShuffle-Managed=true$" "$f" '
      + '&& [ ! -d "$HOME/.config/omarchy/plugins/io.github.omashuffle" ]; then rm -f "$f"; fi\n']
    onExited: function(code) {
      if (code !== 0) {
        root.statusText = ""
        root.errorText = "Could not remove OmaShuffle — the shuffle is still running there"
        return
      }
      root.statusText = "The shuffle now runs in Lacquer"
      if (root.shuffle) root.shuffle.wake()
    }
  }

  // The IPC handler lives in Service.qml: the service is always loaded, so a
  // script does not have to open the panel before it can ask Lacquer anything.
}
