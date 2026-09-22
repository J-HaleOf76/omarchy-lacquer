.pragma library

// The catalogue of ~/.config/omarchy/shell.toml options Lacquer exposes.
//
// This file is the whole-shell styling surface and nothing in Omarchy has a UI
// for it. Values here are layered on top of whatever the active theme ships in
// ~/.local/state/omarchy/current/theme/shell.toml, user wins, and the shell
// watches the user file — so every change applies with no restart and survives
// a theme switch.
//
// Which is exactly why colour rows are marked. Pinning a colour here means a
// theme change will no longer move it, and colour belongs to the theme. Structural rows (sizes, widths, alphas, spacing,
// font) carry no such tension and are unmarked.
//
// Key catalogue and defaults come from
// /usr/share/omarchy/default/themed/shell.toml.tpl.

// `fallback` is Omarchy's documented default for the key, from
// /usr/share/omarchy/default/themed/shell.toml.tpl. Many of those keys ship
// commented out, so there is no theme value to read and a row would otherwise
// show its slider minimum — a number that is simply untrue.
function num(section, key, label, description, min, max, step, unit, fallback) {
  return { section: section, key: key, label: label, description: description || "",
           type: "num", min: min, max: max, step: step === undefined ? 1 : step,
           unit: unit || "", fallback: fallback, id: section + "." + key }
}

function alpha(section, key, label, description, fallback) {
  return num(section, key, label, description, 0, 1, 0.01, "", fallback)
}

function bool(section, key, label, description, fallback) {
  return { section: section, key: key, label: label, description: description || "",
           type: "bool", fallback: fallback, id: section + "." + key }
}

// `theme: true` marks a value the active theme would otherwise supply.
function color(section, key, label, description) {
  return { section: section, key: key, label: label, description: description || "",
           type: "color", theme: true, id: section + "." + key }
}

function group(title, items) {
  return { title: title, items: items }
}

// Every surface shares the same shape, so the colour groups are generated
// rather than typed out nine times.
function surface(section, title, extras) {
  var items = [
    color(section, "background", "Background", ""),
    alpha(section, "background-alpha", "Background opacity", ""),
    color(section, "text", "Text", ""),
    color(section, "border", "Border", "A colour, or the name hyprland.active-border to use your windows' border colour."),
    alpha(section, "border-alpha", "Border opacity", "")
  ]
  // omamenu's Menu Look transparency, when above 0 %, replaces this opacity.
  if (section === "menu")
    items[1].description = "App menu look's see-through setting replaces this while it is above 0 %."
  for (var i = 0; i < (extras || []).length; i++) items.push(extras[i])
  return group(title, items)
}

var TABS = [
  {
    id: "text",
    title: "Text",
    blurb: "How big text is in the top bar, menus and pop-ups. Base text size is what all the others grow from.",
    groups: [
      group("Size", [
        num("font", "base-size", "Base text size", "The size everything else grows from. Text size in Fonts & text size changes this too.", 8, 24, 1, "px", 12)
      ]),
      group("Individual sizes", [
        num("font", "caption", "Smallest labels", "The tiniest text, like hints and small labels.", 6, 30, 1, "px", 10),
        num("font", "body-small", "Small text", "", 6, 30, 1, "px", 11),
        num("font", "body", "Normal text", "", 6, 30, 1, "px", 12),
        num("font", "subtitle", "Subheadings", "", 6, 34, 1, "px", 13),
        num("font", "title", "Titles", "", 6, 34, 1, "px", 14),
        num("font", "heading", "Headings", "", 8, 40, 1, "px", 16),
        num("font", "display", "Large text", "", 10, 60, 1, "px", 24),
        num("font", "display-large", "Largest text", "", 10, 72, 1, "px", 28),
        num("font", "icon-small", "Small icons", "", 6, 30, 1, "px", 11),
        num("font", "icon", "Icons", "", 6, 34, 1, "px", 14),
        num("font", "icon-large", "Large icons", "", 8, 40, 1, "px", 18)
      ])
    ]
  },
  {
    id: "spacing",
    title: "Spacing",
    blurb: "How roomy or tight the top bar, menus and panels feel. Overall spacing changes it all at once.",
    groups: [
      group("Overall", [
        num("spacing", "scale", "Overall spacing", "Makes all the spacing below bigger or smaller together.", 0.5, 2.0, 0.05, "x", 1.0),
        bool("spacing", "scale-with-font", "Grow with the text", "Give things more room when the base text size grows.", true)
      ]),
      group("Standard gaps", [
        num("spacing", "xxs", "Tiniest gap", "One of the standard gap sizes everything else is built from.", 0, 20, 1, "px", 2),
        num("spacing", "xs", "Very small gap", "", 0, 20, 1, "px", 3),
        num("spacing", "sm", "Small gap", "", 0, 24, 1, "px", 4),
        num("spacing", "md", "Medium gap", "", 0, 28, 1, "px", 6),
        num("spacing", "lg", "Large gap", "", 0, 32, 1, "px", 8),
        num("spacing", "xl", "Larger gap", "", 0, 36, 1, "px", 10),
        num("spacing", "xxl", "Very large gap", "", 0, 40, 1, "px", 12),
        num("spacing", "xxxl", "Huge gap", "", 0, 48, 1, "px", 14),
        num("spacing", "huge", "Biggest gap", "", 0, 64, 1, "px", 18)
      ]),
      group("Buttons and rows", [
        num("spacing", "control-gap", "Space between buttons", "", 0, 32, 1, "px", 8),
        num("spacing", "control-padding-x", "Space inside buttons, left and right", "", 0, 40, 1, "px", 10),
        num("spacing", "control-padding-y", "Space inside buttons, top and bottom", "", 0, 32, 1, "px", 6),
        num("spacing", "input-padding-y", "Space inside text boxes", "", 0, 32, 1, "px", 7),
        num("spacing", "control-height", "Button height", "", 16, 60, 1, "px", 28),
        num("spacing", "popup-row-height", "Menu row height", "", 16, 60, 1, "px", 28),
        num("spacing", "row-gap", "Space between rows", "", 0, 32, 1, "px", 8),
        num("spacing", "row-padding-x", "Space at the ends of rows", "", 0, 40, 1, "px", 12),
        num("spacing", "label-gap", "Space beside labels", "", 0, 24, 1, "px", 4)
      ]),
      group("Panels and pop-ups", [
        num("spacing", "panel-gap", "Space between panel parts", "", 0, 48, 1, "px", 14),
        num("spacing", "panel-padding", "Space inside panels", "", 0, 60, 1, "px", 18),
        num("spacing", "popup-padding", "Space inside pop-ups", "", 0, 48, 1, "px", 14),
        num("spacing", "dropdown-width", "Drop-down list width", "", 120, 480, 5, "px", 240),
        num("spacing", "searchable-dropdown-width", "Search list width", "", 120, 480, 5, "px", 260),
        num("spacing", "number-field-width", "Number box width", "", 60, 320, 5, "px", 120),
        num("spacing", "searchable-popup-min-height", "Search list height", "", 100, 600, 10, "px", 220)
      ])
    ]
  },
  {
    id: "controls",
    title: "Buttons",
    blurb: "How buttons, switches, sliders and boxes look: resting, under the pointer, chosen and so on.",
    groups: [
      group("Resting", [
        color("controls", "normal-color", "Colour", ""),
        alpha("controls", "normal-fill-alpha", "Fill strength", "", 0.04),
        color("controls", "normal-border", "Border colour", ""),
        num("controls", "normal-border-width", "Border thickness", "", 0, 6, 1, "px", 1),
        alpha("controls", "normal-border-alpha", "Border strength", "", 0.4)
      ]),
      group("Under the pointer", [
        color("controls", "hover-cursor-color", "Colour", ""),
        alpha("controls", "hover-cursor-fill-alpha", "Fill strength", "", 0.08),
        color("controls", "hover-cursor-border", "Border colour", ""),
        num("controls", "hover-cursor-border-width", "Border thickness", "", 0, 6, 1, "px", 1),
        alpha("controls", "hover-cursor-border-alpha", "Border strength", "", 0.25)
      ]),
      group("Picked with the keyboard", [
        color("controls", "focus-color", "Colour", ""),
        alpha("controls", "focus-fill-alpha", "Fill strength", "", 0.08),
        color("controls", "focus-border", "Border colour", ""),
        num("controls", "focus-border-width", "Border thickness", "", 0, 6, 1, "px", 1),
        alpha("controls", "focus-border-alpha", "Border strength", "", 0.25)
      ]),
      group("Chosen", [
        color("controls", "selected-color", "Colour", ""),
        alpha("controls", "selected-fill-alpha", "Fill strength", "", 0.18),
        color("controls", "selected-border", "Border colour", ""),
        num("controls", "selected-border-width", "Border thickness", "", 0, 6, 1, "px", 0),
        alpha("controls", "selected-border-alpha", "Border strength", "", 1.0)
      ]),
      group("Other moments", [
        alpha("controls", "pressed-fill-alpha", "While pressed", "How strongly a button fills in while you press it.", 0.22),
        alpha("controls", "selection-fill-alpha", "Selected text highlight", "How strong the highlight behind selected text is.", 0.35)
      ])
    ]
  },
  {
    id: "surfaces",
    title: "Bar & pop-ups",
    blurb: "Colours and sizes of the top bar and everything that pops up. A colour set here stays put when you change theme.",
    groups: [
      group("Top bar", [
        color("bar", "background", "Background colour", ""),
        alpha("bar", "background-alpha", "Background strength", ""),
        color("bar", "text", "Text colour", ""),
        color("bar", "active", "Highlight colour", "The colour used for something that wants your attention."),
        num("bar", "size-horizontal", "Height", "How tall the bar is when it sits along the top or bottom.", 16, 72, 1, "px", 26),
        num("bar", "size-vertical", "Width", "How wide the bar is when it sits down one side.", 16, 96, 1, "px", 28),
        bool("bar", "scale-with-font", "Grow with the text", "Make the bar bigger when the base text size grows.", true)
      ]),
      surface("menu", "App menu", [
        color("menu", "scrim", "Shade behind it", "The darkening over the rest of the screen while it is open."),
        alpha("menu", "scrim-alpha", "Shade strength", ""),
        color("menu", "selected-background", "Highlighted row", ""),
        alpha("menu", "selected-background-alpha", "Highlighted row strength", ""),
        color("menu", "selected-text", "Highlighted text", "")
      ]),
      surface("launcher", "App launcher", [
        color("launcher", "scrim", "Shade behind it", ""),
        alpha("launcher", "scrim-alpha", "Shade strength", ""),
        color("launcher", "selected-background", "Highlighted row", ""),
        alpha("launcher", "selected-background-alpha", "Highlighted row strength", ""),
        color("launcher", "selected-text", "Highlighted text", "")
      ]),
      surface("popups", "Pop-ups", [
        num("popups", "border-width", "Border thickness", "", 0, 8, 1, "px")
      ]),
      surface("tooltip", "Hints under the pointer", []),
      surface("notifications", "Notifications", [
        num("notifications", "border-width", "Border thickness", "", 0, 8, 1, "px"),
        color("notifications", "countdown", "Countdown bar", "The little bar that shows how long a notification will stay.")
      ]),
      surface("polkit", "Password prompt", [
        color("polkit", "text-error", "Wrong password text", ""),
        color("polkit", "border-error", "Wrong password border", ""),
        color("polkit", "scrim", "Shade behind it", ""),
        alpha("polkit", "scrim-alpha", "Shade strength", ""),
        color("polkit", "accent", "Main colour", "")
      ]),
      surface("lock", "Lock screen", [
        color("lock", "placeholder", "Hint in the password box", ""),
        color("lock", "text-error", "Wrong password text", ""),
        color("lock", "border-active", "Border while typing", ""),
        color("lock", "border-error", "Wrong password border", ""),
        color("lock", "selection", "Highlighted text", ""),
        alpha("lock", "selection-alpha", "Selected text strength", "")
      ]),
      group("Picture picker", [
        color("image-picker", "scrim", "Shade behind it", ""),
        alpha("image-picker", "scrim-alpha", "Shade strength", ""),
        color("image-picker", "text", "Text colour", ""),
        color("image-picker", "selected-border", "Chosen picture's border", ""),
        alpha("image-picker", "selected-border-alpha", "Chosen picture's border strength", ""),
        color("image-picker", "unselected-border", "Other pictures' border", ""),
        alpha("image-picker", "unselected-border-alpha", "Other pictures' border strength", "")
      ])
    ]
  }
]

function tabFor(id) {
  for (var i = 0; i < TABS.length; i++)
    if (TABS[i].id === id) return TABS[i]
  return null
}

function itemFor(id) {
  var all = allItems()
  for (var i = 0; i < all.length; i++)
    if (all[i].id === id) return all[i]
  return null
}

function allItems() {
  var out = []
  for (var t = 0; t < TABS.length; t++)
    for (var g = 0; g < TABS[t].groups.length; g++)
      for (var i = 0; i < TABS[t].groups[g].items.length; i++)
        out.push(TABS[t].groups[g].items[i])
  return out
}

function quantize(item, value) {
  if (item.type === "bool") return value === true
  if (item.type === "color") return String(value)
  var n = Number(value)
  if (!isFinite(n)) return 0
  var step = item.step === undefined ? 1 : item.step
  if (step >= 1) return Math.round(n)
  var factor = Math.round(1 / step)
  return Math.round(n * factor) / factor
}
