.pragma library

// The catalogue of Hyprland animation leaves Lacquer exposes, grouped the
// way Hyprland's own animation tree is shaped.
//
// A leaf Omarchy does not ship a value for inherits from its parent. Hyprland
// reports those as "not overridden" rather than resolving them, so Lacquer
// shows them as inherited and materialises them from the parent's effective
// values the moment you touch one — there is no honest number to show first.
//
// `styles` are curated strings rather than a parsed grammar: Hyprland's style
// field is free-form per family, and a dropdown of the ones that exist beats
// a text box that accepts typos.

var NO_STYLE = []

var WINDOW_STYLES = [
  { value: "", label: "None" },
  { value: "popin", label: "Pop in" },
  { value: "popin 50%", label: "Pop in 50%" },
  { value: "popin 70%", label: "Pop in 70%" },
  { value: "popin 87%", label: "Pop in 87%" },
  { value: "slide", label: "Slide" },
  { value: "slide left", label: "Slide from the left" },
  { value: "slide right", label: "Slide from the right" },
  { value: "slide top", label: "Slide from the top" },
  { value: "slide bottom", label: "Slide from the bottom" },
  { value: "gnomed", label: "Grow from a line" }
]

var LAYER_STYLES = [
  { value: "", label: "None" },
  { value: "fade", label: "Fade" },
  { value: "slide", label: "Slide" },
  { value: "popin", label: "Pop in" },
  { value: "popin 80%", label: "Pop in 80%" }
]

var WORKSPACE_STYLES = [
  { value: "", label: "None" },
  { value: "slide", label: "Slide" },
  { value: "slidevert", label: "Slide up and down" },
  { value: "fade", label: "Fade" },
  { value: "slidefade", label: "Slide + fade" },
  { value: "slidefade 20%", label: "Slide + fade 20%" },
  { value: "slidefadevert", label: "Slide up and down + fade" },
  { value: "slidefadevert 20%", label: "Slide up and down + fade 20%" }
]

var ANGLE_STYLES = [
  { value: "", label: "None" },
  { value: "once", label: "Turn once" },
  { value: "loop", label: "Keep turning" }
]

function leaf(name, label, description, parent, styles) {
  return {
    name: name,
    label: label,
    description: description || "",
    parent: parent || "",
    styles: styles || NO_STYLE
  }
}

var SECTIONS = [
  {
    id: "windows",
    icon: "󰆏",
    title: "Windows",
    blurb: "Windows opening, closing and moving.",
    leaves: [
      leaf("windows", "All window animations", "Sets every window animation below at once, except ones you have changed on their own.", "global", WINDOW_STYLES),
      leaf("windowsIn", "A window opens", "A new window appearing.", "windows", WINDOW_STYLES),
      leaf("windowsOut", "A window closes", "A window going away.", "windows", WINDOW_STYLES),
      leaf("windowsMove", "A window moves", "Moving or resizing a window, and the others shuffling up when one closes.", "windows", WINDOW_STYLES)
    ]
  },
  {
    id: "layers",
    icon: "󰓪",
    title: "Bars & menus",
    blurb: "The top bar, menus, notifications and the app launcher appearing and going away.",
    leaves: [
      leaf("layers", "All bar and menu animations", "Sets the two below at once.", "global", LAYER_STYLES),
      leaf("layersIn", "A menu or panel opens", "The top bar, a menu, a notification or the app launcher appearing, like the Omarchy menu.", "layers", LAYER_STYLES),
      leaf("layersOut", "A menu or panel closes", "A menu, notification or panel going away.", "layers", LAYER_STYLES)
    ]
  },
  {
    id: "fade",
    icon: "󰶉",
    title: "Fades",
    blurb: "Things fading in and out. These happen alongside the movements.",
    leaves: [
      leaf("fade", "All fades", "Sets every fade below at once.", "global", NO_STYLE),
      leaf("fadeIn", "Fade in", "A window fading into view as it opens.", "fade", NO_STYLE),
      leaf("fadeOut", "Fade out", "A window fading away as it closes.", "fade", NO_STYLE),
      leaf("fadeSwitch", "Switching windows", "The soft change when you move from one window to another.", "fade", NO_STYLE),
      leaf("fadeShadow", "Shadow", "The shadow fading as you switch windows.", "fade", NO_STYLE),
      leaf("fadeDim", "Darkening", "Other windows darkening and brightening as you switch.", "fade", NO_STYLE),
      leaf("fadeLayers", "Menus and panels", "Sets the two below at once.", "fade", NO_STYLE),
      leaf("fadeLayersIn", "A menu fades in", "A menu or panel fading into view.", "fadeLayers", NO_STYLE),
      leaf("fadeLayersOut", "A menu fades out", "A menu or panel fading away.", "fadeLayers", NO_STYLE),
      leaf("fadePopups", "Small pop-ups", "Sets the two below at once.", "fade", NO_STYLE),
      leaf("fadePopupsIn", "A pop-up fades in", "A right-click menu or a small pop-up inside an app fading into view.", "fadePopups", NO_STYLE),
      leaf("fadePopupsOut", "A pop-up fades out", "A small pop-up fading away.", "fadePopups", NO_STYLE),
      leaf("fadeDpms", "Screen waking up", "The screen fading back in after it turned itself off.", "fade", NO_STYLE)
    ]
  },
  {
    id: "workspaces",
    icon: "󰕰",
    title: "Desktops",
    blurb: "Switching between desktops, and the hidden scratchpad desktop.",
    leaves: [
      leaf("workspaces", "All desktop switching", "Sets the ones below at once. Off in a fresh Omarchy.", "global", WORKSPACE_STYLES),
      leaf("workspacesIn", "The desktop you go to", "The desktop sliding in when you switch to it.", "workspaces", WORKSPACE_STYLES),
      leaf("workspacesOut", "The desktop you leave", "The desktop sliding out when you switch away.", "workspaces", WORKSPACE_STYLES),
      leaf("specialWorkspace", "The scratchpad", "Sets the two below at once. The scratchpad is a hidden desktop you can pop up over the others.", "workspaces", WORKSPACE_STYLES),
      leaf("specialWorkspaceIn", "The scratchpad appears", "The scratchpad sliding into view.", "specialWorkspace", WORKSPACE_STYLES),
      leaf("specialWorkspaceOut", "The scratchpad goes", "The scratchpad sliding away.", "specialWorkspace", WORKSPACE_STYLES)
    ]
  },
  {
    id: "borders",
    icon: "󰝤",
    title: "Borders",
    blurb: "Border colours changing. The colours themselves come from your theme.",
    leaves: [
      leaf("border", "Border colour change", "The border changing colour as you move between windows.", "global", NO_STYLE),
      leaf("borderangle", "Border fade turning", "How a border colour fade turns round the window. Loop keeps it turning.", "global", ANGLE_STYLES),
      leaf("glowangle", "Glow turning", "How a glow's colours turn round the window.", "global", ANGLE_STYLES),
      leaf("shadowangle", "Shadow turning", "How a shadow's colours turn round the window.", "global", ANGLE_STYLES)
    ]
  },
  {
    id: "global",
    icon: "󱐋",
    title: "Everything",
    blurb: "Settings that every other animation starts from.",
    leaves: [
      leaf("global", "Everything", "Turn this off to stop every animation at once.", "", NO_STYLE),
      leaf("zoomFactor", "Zooming in", "The screen zooming in and out, for anyone using the zoom.", "global", NO_STYLE),
      leaf("monitorAdded", "Plugging in a screen", "A new screen appearing when you connect it.", "global", NO_STYLE)
    ]
  }
]

var CURVES_SECTION = { id: "curves", icon: "󰓅", title: "Animation curves", blurb: "The shape of an animation's speed-up and slow-down. Drag either handle; every animation using that curve follows." }

function sectionFor(id) {
  for (var i = 0; i < SECTIONS.length; i++)
    if (SECTIONS[i].id === id) return SECTIONS[i]
  return null
}

function leafFor(name) {
  for (var i = 0; i < SECTIONS.length; i++)
    for (var j = 0; j < SECTIONS[i].leaves.length; j++)
      if (SECTIONS[i].leaves[j].name === name) return SECTIONS[i].leaves[j]
  return null
}

// Speed is a duration in deciseconds, so a bigger number is a slower
// animation. 0.1 ds (10 ms) is instant; 20 ds (2 s) is glacial.
var SPEED_MIN = 0.1
var SPEED_MAX = 12
var SPEED_STEP = 0.01
