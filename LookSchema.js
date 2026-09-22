.pragma library

// The catalogue of Hyprland look-and-feel options Lacquer exposes.
//
// Adapted from Omaland's Schema.js (MIT, Copyright (c) 2026 Bobby Nicholas —
// https://github.com/bobby-nicholas/omaland). Changes here: options are
// grouped under headings inside each section rather than one flat list, and
// Omaland's animation-speed multiplier is gone because Lacquer edits every
// animation leaf directly instead.
//
// Colors are absent on purpose. Omarchy themes own general:col:* via
// ~/.local/state/omarchy/current/theme/hyprland.lua, which loads *before*
// hypr/looknfeel.lua, so writing colors here would pin them and break
// `omarchy theme set` and the theme tools built on it.
//
// Item fields: key (hyprctl path), type, min/max/step, unit, and needs (key of
// a bool that must be on for the row to be live). Slider bounds are
// comfortable ranges, not Hyprland's limits — the row widens a track when the
// live value sits outside it.

function path(key) {
  return key.split(":")
}

function item(key, label, description, type, extra) {
  var o = {
    key: key,
    lua: path(key),
    label: label,
    description: description || "",
    type: type
  }
  for (var k in extra) o[k] = extra[k]
  return o
}

function group(title, items) {
  return { title: title, items: items }
}

// Synthetic options have no config key of their own. They are backed by the
// Lua they emit, and read back by measuring that Lua.
var OPAQUE_WINDOWS_KEY = "lacquer:opaque_windows"

var SECTIONS = [
  {
    id: "windows",
    icon: "󰆏",
    title: "Spacing & layout",
    blurb: "The space around windows and how they arrange themselves.",
    groups: [
      group("Space and borders", [
        item("general:gaps_in", "Space between windows", "How much room is left between windows sitting next to each other.", "int",
             { min: 0, max: 40, unit: "px" }),
        item("general:gaps_out", "Space around the edge", "How much room is left between your windows and the edge of the screen.", "int",
             { min: 0, max: 80, unit: "px" }),
        item("general:gaps_workspaces", "Space when switching desktops", "A gap shown between two desktops while one slides over to the next.", "int",
             { min: 0, max: 100, unit: "px" }),
        item("general:float_gaps", "Space around floating windows", "Room kept around windows that float freely instead of filling a spot. 0 uses the same space as between windows.", "int",
             { min: 0, max: 40, unit: "px" }),
        item("general:border_size", "Border thickness", "How thick the coloured line around each window is. Its colour comes from your theme.", "int",
             { min: 0, max: 12, unit: "px" }),
        item("decoration:border_part_of_window", "Border inside the window", "Draw the border on the window's own edge instead of just outside it.", "bool")
      ]),
      group("Snapping", [
        item("general:snap:enabled", "Snap floating windows into place", "When you drag a floating window close to another window or to the edge of the screen, it lines up with it.", "bool"),
        item("general:snap:window_gap", "Snap to other windows from", "How close a dragged window has to get to another window before it snaps against it.", "int",
             { min: 0, max: 50, unit: "px", needs: "general:snap:enabled" }),
        item("general:snap:monitor_gap", "Snap to the screen edge from", "How close a dragged window has to get to the edge of the screen before it snaps against it.", "int",
             { min: 0, max: 50, unit: "px", needs: "general:snap:enabled" })
      ]),
      group("How windows are arranged", [
        item("general:layout", "How windows arrange themselves", "Split: every new window shares the space with the one you are in. Main and stack: one big window with the rest lined up beside it. Scrolling: windows sit in a long row you scroll along.", "enum",
             { options: [
                 { value: "dwindle", label: "Split" },
                 { value: "master", label: "Main and stack" },
                 { value: "scrolling", label: "Scrolling" }
               ] }),

        item("dwindle:preserve_split", "Keep the arrangement", "When a window closes, the others keep being side by side or above each other as they were.", "bool",
             { needs: "general:layout", needsValue: "dwindle" }),
        item("dwindle:smart_split", "Split where you drop it", "When you drag a window onto another, which half it lands in depends on where you let go.", "bool",
             { needs: "general:layout", needsValue: "dwindle" }),
        item("dwindle:force_split", "Where a new window opens", "Which side of the window you are in a new window appears on.", "enum",
             { numeric: true, needs: "general:layout", needsValue: "dwindle",
               options: [
                 { value: 0, label: "Where the pointer is" },
                 { value: 1, label: "Left or above" },
                 { value: 2, label: "Right or below" }
               ] }),
        item("dwindle:split_width_multiplier", "Prefer side by side", "Above 1.0, new windows go next to each other more often than above and below.", "float",
             { min: 0.5, max: 2.0, step: 0.05, decimals: 2, needs: "general:layout", needsValue: "dwindle" }),
        item("dwindle:default_split_ratio", "Size of a new window", "How big a new window is compared with the one it shares its space with.", "float",
             { min: 0.5, max: 1.5, step: 0.05, decimals: 2, needs: "general:layout", needsValue: "dwindle" }),

        item("master:mfact", "Main window size", "How much of the screen the main window takes; the others share the rest.", "float",
             { min: 0.1, max: 0.9, step: 0.01, decimals: 2, needs: "general:layout", needsValue: "master" }),
        item("master:orientation", "Main window side", "Which side of the screen the main window sits on.", "enum",
             { needs: "general:layout", needsValue: "master",
               options: [
                 { value: "left", label: "Left" },
                 { value: "right", label: "Right" },
                 { value: "top", label: "Top" },
                 { value: "bottom", label: "Bottom" },
                 { value: "center", label: "Center" }
               ] }),
        item("master:new_status", "Where new windows go", "Whether a new window becomes the main one, joins the others, or follows your usual choice.", "enum",
             { needs: "general:layout", needsValue: "master",
               options: [
                 { value: "master", label: "Becomes the main one" },
                 { value: "slave", label: "Joins the others" },
                 { value: "inherit", label: "Your usual choice" }
               ] }),

        item("scrolling:column_width", "Column width", "How much of the screen one column of windows takes. 0.97 shows one window at a time.", "float",
             { min: 0.2, max: 1.0, step: 0.01, decimals: 2, needs: "general:layout", needsValue: "scrolling" }),
        item("scrolling:fullscreen_on_one_column", "One column fills the screen", "When only one column is open, let it use the whole screen.", "bool",
             { needs: "general:layout", needsValue: "scrolling" })
      ])
    ]
  },
  {
    id: "decoration",
    icon: "󰝤",
    title: "Corners & see-through",
    blurb: "Rounded corners, see-through windows, and darkening the ones you aren't using.",
    groups: [
      group("Corners", [
        item("decoration:rounding", "Window corners", "How round the corners of your windows are. 0 is square. The top bar and menus round to match.", "int",
             { min: 0, max: 30, unit: "px" }),
        item("decoration:rounding_power", "Corner shape", "2.0 is an even curve; higher gives a softer, more squarish corner.", "float",
             { min: 1.0, max: 10.0, step: 0.1, decimals: 1 })
      ]),
      group("See-through", [
        // Omarchy tags every window and applies opacity "0.985 0.96" in
        // default/hypr/windows.lua. That rule multiplies with the globals
        // below, so without this switch the sliders top out at 0.985.
        item(OPAQUE_WINDOWS_KEY, "Allow fully solid windows", "Omarchy makes every window very slightly see-through. Turn this on so the settings below can make windows completely solid.", "bool",
             { synthetic: true, fallback: false }),
        item("decoration:active_opacity", "The window you are using", "How solid the window you are working in is. 1.00 is fully solid; lower lets the background show through.", "float",
             { min: 0.3, max: 1.0, step: 0.01, decimals: 2 }),
        item("decoration:inactive_opacity", "Other windows", "How solid every other window is. 1.00 is fully solid.", "float",
             { min: 0.3, max: 1.0, step: 0.01, decimals: 2 }),
        item("decoration:fullscreen_opacity", "A window filling the screen", "How solid a window is while it fills the whole screen.", "float",
             { min: 0.3, max: 1.0, step: 0.01, decimals: 2 })
      ]),
      group("Darkening", [
        item("decoration:dim_inactive", "Darken other windows", "Shade every window except the one you are using, so it stands out.", "bool"),
        item("decoration:dim_strength", "How much darker", "How strongly the other windows are shaded.", "float",
             { min: 0.0, max: 1.0, step: 0.01, decimals: 2, needs: "decoration:dim_inactive" }),
        item("decoration:dim_special", "Darken behind the scratchpad", "How much the screen darkens behind the scratchpad, the hidden desktop you can pop up over the others.", "float",
             { min: 0.0, max: 1.0, step: 0.01, decimals: 2 }),
        item("decoration:dim_around", "Darken around pop-up windows", "How much the rest of the screen darkens behind windows that are set to shade what is around them.", "float",
             { min: 0.0, max: 1.0, step: 0.01, decimals: 2 }),
        item("decoration:dim_modal", "Darken behind dialogs", "Shade a window while one of its little dialog windows, like Save or Open, is showing.", "bool")
      ])
    ]
  },
  {
    id: "effects",
    icon: "󱒛",
    title: "Glass & shadow",
    blurb: "Frosted glass, shadows and glow. These make your graphics work a little harder.",
    groups: [
      group("Frosted glass", [
        item("decoration:blur:enabled", "Frosted glass", "Blur whatever is behind see-through windows and panels, like frosted glass.", "bool"),
        item("decoration:blur:size", "How blurry", "How strongly things behind the glass are blurred.", "int",
             { min: 1, max: 20, needs: "decoration:blur:enabled" }),
        item("decoration:blur:passes", "Blur smoothness", "Higher is smoother but works your graphics harder. 3 is plenty.", "int",
             { min: 1, max: 5, needs: "decoration:blur:enabled" }),
        item("decoration:blur:noise", "Grain", "A little speckle mixed into the blur so smooth colour changes don't look stepped.", "float",
             { min: 0.0, max: 0.2, step: 0.005, decimals: 3, needs: "decoration:blur:enabled" }),
        item("decoration:blur:contrast", "Contrast behind the glass", "How strong the difference between light and dark is behind the glass.", "float",
             { min: 0.0, max: 2.0, step: 0.01, decimals: 2, needs: "decoration:blur:enabled" }),
        item("decoration:blur:brightness", "Brightness behind the glass", "How bright things look behind the glass.", "float",
             { min: 0.0, max: 2.0, step: 0.01, decimals: 2, needs: "decoration:blur:enabled" }),
        item("decoration:blur:vibrancy", "Colour boost", "Makes the colours behind the glass more vivid.", "float",
             { min: 0.0, max: 1.0, step: 0.01, decimals: 2, needs: "decoration:blur:enabled" }),
        item("decoration:blur:vibrancy_darkness", "Colour boost in the dark parts", "How much the colour boost also reaches the dark parts.", "float",
             { min: 0.0, max: 1.0, step: 0.01, decimals: 2, needs: "decoration:blur:enabled" }),
        item("decoration:blur:xray", "Only blur the wallpaper", "Behind a see-through window, show your blurred wallpaper rather than the windows underneath.", "bool",
             { needs: "decoration:blur:enabled" }),
        item("decoration:blur:special", "Blur behind the scratchpad", "Frost the screen behind the scratchpad, the hidden desktop you can pop up.", "bool",
             { needs: "decoration:blur:enabled" }),
        item("decoration:blur:popups", "Blur behind menus", "Frost what is behind right-click menus and the little hints that appear under the pointer.", "bool",
             { needs: "decoration:blur:enabled" })
      ]),
      group("Shadow", [
        item("decoration:shadow:enabled", "Shadows", "Draw a soft shadow under each window.", "bool"),
        item("decoration:shadow:range", "Shadow size", "How far the shadow spreads out from the window.", "int",
             { min: 0, max: 50, unit: "px", needs: "decoration:shadow:enabled" }),
        item("decoration:shadow:render_power", "Shadow softness", "How quickly the shadow fades away from the window's edge.", "int",
             { min: 1, max: 4, needs: "decoration:shadow:enabled" }),
        item("decoration:shadow:scale", "Shadow scale", "How big the shadow is compared with the window.", "float",
             { min: 0.0, max: 1.0, step: 0.01, decimals: 2, needs: "decoration:shadow:enabled" }),
        item("decoration:shadow:sharp", "Hard shadow", "A crisp-edged shadow instead of a soft one.", "bool",
             { needs: "decoration:shadow:enabled" })
      ]),
      group("Glow", [
        item("decoration:glow:enabled", "Glow", "A soft halo of light around the window you are using.", "bool"),
        item("decoration:glow:range", "Glow size", "How far the glow spreads.", "int",
             { min: 0, max: 50, unit: "px", needs: "decoration:glow:enabled" }),
        item("decoration:glow:render_power", "Glow softness", "How quickly the glow fades away.", "int",
             { min: 1, max: 4, needs: "decoration:glow:enabled" })
      ])
    ]
  },
  {
    id: "groups",
    icon: "󰓪",
    title: "Grouped windows",
    blurb: "The row of tabs on windows stacked together in one spot. Its colours come from your theme.",
    groups: [
      group("Tabs on grouped windows", [
        item("group:groupbar:enabled", "Tabs on grouped windows", "Several windows can be stacked into one spot as a group; this shows a row of tabs to switch between them.", "bool"),
        item("group:groupbar:height", "Tab height", "How tall the row of tabs is.", "int",
             { min: 0, max: 40, unit: "px", needs: "group:groupbar:enabled" }),
        item("group:groupbar:font_size", "Tab text size", "How big the window names in the tabs are.", "int",
             { min: 6, max: 24, unit: "px", needs: "group:groupbar:enabled" }),
        item("group:groupbar:render_titles", "Show window names", "Write each window's name in its tab.", "bool",
             { needs: "group:groupbar:enabled" }),
        item("group:groupbar:indicator_height", "Marker under the open tab", "How thick the line under the tab you are on is.", "int",
             { min: 0, max: 12, unit: "px", needs: "group:groupbar:enabled" }),
        item("group:groupbar:rounding", "Tab corners", "How round the corners of the tabs are.", "int",
             { min: 0, max: 20, unit: "px", needs: "group:groupbar:enabled" }),
        item("group:groupbar:gradients", "Shaded tabs", "Give the tabs a colour fade instead of a flat colour.", "bool",
             { needs: "group:groupbar:enabled" }),
        item("group:groupbar:stacked", "Tabs in a column", "List the tabs one above the other instead of side by side.", "bool",
             { needs: "group:groupbar:enabled" }),
        item("group:groupbar:disable_when_only", "Hide tabs for a single window", "Don't show the tabs when a group has only one window in it.", "bool",
             { needs: "group:groupbar:enabled" })
      ])
    ]
  }
]

// Shown at the top of the Animations section, above the per-leaf editor.
var ANIMATION_MASTER = group("Main window and stack", [
  item("animations:enabled", "Animations", "Turn every window and desktop animation on or off.", "bool"),
  item("animations:workspace_wraparound", "Wrap round the desktops", "Going past your last desktop brings you round to the first. Only desktops that are open count, so with just two open every switch wraps round.", "bool",
       { needs: "animations:enabled" })
])

function allItems() {
  var out = []
  for (var i = 0; i < SECTIONS.length; i++)
    for (var g = 0; g < SECTIONS[i].groups.length; g++)
      for (var j = 0; j < SECTIONS[i].groups[g].items.length; j++)
        out.push(SECTIONS[i].groups[g].items[j])
  for (var m = 0; m < ANIMATION_MASTER.items.length; m++) out.push(ANIMATION_MASTER.items[m])
  return out
}

function itemFor(key) {
  var items = allItems()
  for (var i = 0; i < items.length; i++)
    if (items[i].key === key) return items[i]
  return null
}

// Everything `hyprctl getoption` can answer for, i.e. all but the synthetics.
function queryKeys() {
  var items = allItems()
  var out = []
  for (var i = 0; i < items.length; i++)
    if (!items[i].synthetic) out.push(items[i].key)
  return out
}

function quantize(item, value) {
  // Type dispatch must come first: a numeric guard up top would run Number()
  // on an enum's name, and Number("dwindle") is NaN, which then writes
  // layout = 0. Hyprland accepts a layout named "0" without a config error.
  if (item.type === "bool") return value === true
  if (item.type === "enum") return item.numeric ? Number(value) : String(value)

  var n = Number(value)
  if (!isFinite(n)) return 0
  if (item.type === "int") return Math.round(n)
  var decimals = item.decimals === undefined ? 2 : item.decimals
  var factor = Math.pow(10, decimals)
  return Math.round(n * factor) / factor
}
