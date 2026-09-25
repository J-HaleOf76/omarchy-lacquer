.pragma library

// How readable one colour is on another, by the same measure the web
// accessibility guidelines use: the ratio between the two relative
// luminances, from 1 (identical) to 21 (black on white).
//
// The thresholds are theirs as well — 4.5 for ordinary text, 7 for the
// comfortable level — and they are what the wording below is pinned to, so a
// theme built from a wallpaper can be judged rather than guessed at.

function parse(hex) {
  var s = String(hex || "").trim().replace(/^#/, "")
  if (s.length === 3) s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2]
  if (!/^[0-9a-fA-F]{6}$/.test(s.slice(0, 6))) return null
  return {
    r: parseInt(s.slice(0, 2), 16) / 255,
    g: parseInt(s.slice(2, 4), 16) / 255,
    b: parseInt(s.slice(4, 6), 16) / 255
  }
}

function channel(c) {
  return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
}

function luminance(hex) {
  var c = parse(hex)
  if (!c) return null
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
}

// 0 when either colour cannot be read.
function ratio(a, b) {
  var la = luminance(a), lb = luminance(b)
  if (la === null || lb === null) return 0
  var hi = Math.max(la, lb), lo = Math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
}

function rounded(a, b) {
  return Math.round(ratio(a, b) * 10) / 10
}

// What to say about a ratio, in the app's own voice.
function wordFor(r) {
  if (r >= 7) return "easy to read"
  if (r >= 4.5) return "readable"
  if (r >= 3) return "tight — small text will be hard"
  return "hard to read"
}

function comfortable(r) { return r >= 7 }
function passable(r) { return r >= 4.5 }

// An aether palette is sixteen ANSI colours: 0 is the background, 7 the
// ordinary text, 1..6 the hues everything colourful is drawn in.
function readPalette(colors) {
  if (!colors || colors.length < 8) return null
  var bg = colors[0]
  var fg = colors.length > 15 ? colors[15] : colors[7]
  var main = rounded(bg, fg)
  var weak = []
  for (var i = 1; i <= 6 && i < colors.length; i++)
    if (!passable(ratio(bg, colors[i]))) weak.push(colors[i])
  return { background: bg, foreground: fg, main: main, word: wordFor(main), weak: weak.length }
}
