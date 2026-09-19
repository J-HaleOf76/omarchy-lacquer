.pragma library

// One motion vocabulary for the whole desktop.
//
// A "feel" is a set of bezier curves plus a duration for every family of
// movement (enter, exit, move, emphasis). Picking one writes Hyprland's
// animation leaves and curves, sets the pace of Lacquer's own panel, and — when
// the companion shell plugin is installed — the bar, menu and notifications,
// so one choice makes the whole desktop move the same way.
//
// The shape is borrowed from Material 3's motion scheme (standard, emphasized,
// expressive), which is also what Caelestia's shell tokens follow.
//
// Curves are written under Lacquer's own names, never over Omarchy's, so a
// theme's curves stay intact and every leaf can be pointed back at them.
// Hyprland speeds are deciseconds: bigger is slower, so the speed multiplier
// divides them, the same as it divides Lacquer's own durations in ms.

var CURVE_PREFIX = "lq"
var CURVE_NAMES = ["lqEnter", "lqExit", "lqMove", "lqEmphasis"]

// The leaves a feel drives. Only parents: anything overridden underneath keeps
// its own value, and the parents are what Hyprland hands down by default.
var DRIVEN_LEAVES = ["windows", "layers", "fade", "workspaces", "specialWorkspace", "border"]

var FEELS = [
  {
    id: "calm",
    label: "Calm",
    blurb: "Slow and soft. Nothing snaps; everything settles.",
    curves: {
      lqEnter: [0.25, 0.1, 0.25, 1],
      lqExit: [0.4, 0, 1, 1],
      lqMove: [0.33, 0, 0.2, 1],
      lqEmphasis: [0.2, 0, 0, 1]
    },
    leaves: {
      windows: { speed: 7, bezier: "lqEnter", style: "popin 90%" },
      layers: { speed: 6, bezier: "lqEnter", style: "fade" },
      fade: { speed: 8, bezier: "lqExit", style: "" },
      workspaces: { speed: 8, bezier: "lqMove", style: "slidefade 20%" },
      specialWorkspace: { speed: 8, bezier: "lqMove", style: "slidefadevert 20%" },
      border: { speed: 12, bezier: "lqMove", style: "" }
    },
    ui: { duration: 520, easing: "OutCubic", cascade: 40 }
  },
  {
    id: "standard",
    label: "Standard",
    blurb: "Omarchy's pace, tidied up: one curve family everywhere.",
    curves: {
      lqEnter: [0.2, 0, 0, 1],
      lqExit: [0.3, 0, 0.8, 1],
      lqMove: [0.25, 0.1, 0.25, 1],
      lqEmphasis: [0.05, 0.7, 0.1, 1]
    },
    leaves: {
      windows: { speed: 4.5, bezier: "lqEnter", style: "popin 87%" },
      layers: { speed: 4, bezier: "lqEnter", style: "fade" },
      fade: { speed: 5, bezier: "lqExit", style: "" },
      workspaces: { speed: 5, bezier: "lqMove", style: "slide" },
      specialWorkspace: { speed: 5, bezier: "lqMove", style: "slidevert" },
      border: { speed: 10, bezier: "lqMove", style: "" }
    },
    ui: { duration: 380, easing: "OutQuint", cascade: 30 }
  },
  {
    id: "expressive",
    label: "Expressive",
    blurb: "Overshoots a little and lands. The showy one.",
    curves: {
      lqEnter: [0.34, 1.4, 0.64, 1],
      lqExit: [0.36, 0, 0.66, -0.3],
      lqMove: [0.2, 1.2, 0.3, 1],
      lqEmphasis: [0.34, 1.56, 0.64, 1]
    },
    leaves: {
      windows: { speed: 6, bezier: "lqEnter", style: "popin 70%" },
      layers: { speed: 5, bezier: "lqEnter", style: "popin 80%" },
      fade: { speed: 6, bezier: "lqExit", style: "" },
      workspaces: { speed: 7, bezier: "lqMove", style: "slidefade" },
      specialWorkspace: { speed: 7, bezier: "lqMove", style: "slidefadevert" },
      border: { speed: 8, bezier: "lqEmphasis", style: "" }
    },
    ui: { duration: 460, easing: "OutBack", cascade: 45 }
  },
  {
    id: "snappy",
    label: "Snappy",
    blurb: "Short and sharp. Movement you notice but never wait for.",
    curves: {
      lqEnter: [0.2, 0, 0, 1],
      lqExit: [0.4, 0, 1, 1],
      lqMove: [0.3, 0, 0.1, 1],
      lqEmphasis: [0.15, 0.6, 0.1, 1]
    },
    leaves: {
      windows: { speed: 2.4, bezier: "lqEnter", style: "popin 90%" },
      layers: { speed: 2, bezier: "lqEnter", style: "fade" },
      fade: { speed: 2.6, bezier: "lqExit", style: "" },
      workspaces: { speed: 2.8, bezier: "lqMove", style: "slide" },
      specialWorkspace: { speed: 2.8, bezier: "lqMove", style: "slidevert" },
      border: { speed: 6, bezier: "lqMove", style: "" }
    },
    ui: { duration: 220, easing: "OutQuad", cascade: 18 }
  }
]

var SPEED_MIN = 0.5
var SPEED_MAX = 2
var SPEED_STEP = 0.1

function feelFor(id) {
  for (var i = 0; i < FEELS.length; i++)
    if (FEELS[i].id === id) return FEELS[i]
  return null
}

function round2(n) {
  return Math.round(Number(n) * 100) / 100
}

// Speed is a multiplier on the pace, so a faster pace is a shorter duration:
// every number a feel carries is divided by it.
function scaled(feel, speed) {
  var factor = Number(speed) > 0 ? Number(speed) : 1
  var out = { curves: {}, leaves: {}, ui: {} }
  var name
  for (name in feel.curves) out.curves[name] = feel.curves[name].slice()
  for (name in feel.leaves) {
    var leaf = feel.leaves[name]
    out.leaves[name] = {
      enabled: true,
      speed: Math.max(0.1, Math.min(12, round2(leaf.speed / factor))),
      bezier: leaf.bezier,
      style: leaf.style || ""
    }
  }
  out.ui = {
    duration: Math.max(60, Math.round(feel.ui.duration / factor)),
    easing: feel.ui.easing,
    cascade: Math.max(0, Math.round(feel.ui.cascade / factor))
  }
  return out
}

// Whether the desktop still moves the way the feel says, so the section can own
// up to a value that was changed by hand afterwards.
function leafMatches(applied, wanted) {
  if (!applied) return false
  if (applied.enabled === false) return false
  if (Math.abs(Number(applied.speed) - Number(wanted.speed)) > 0.05) return false
  if (String(applied.bezier || "") !== String(wanted.bezier)) return false
  return String(applied.style || "") === String(wanted.style || "")
}

function sameCurve(a, b) {
  if (!a || !b || a.length !== 4 || b.length !== 4) return false
  for (var i = 0; i < 4; i++)
    if (Math.abs(Number(a[i]) - Number(b[i])) > 0.001) return false
  return true
}
