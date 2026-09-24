import QtQuick

// A row of choices drawn as one body of goo, with the selection a thicker
// bulge that slides along inside it.
//
// The body is a capsule under each line of options; the bulge is the selected
// option's shape swollen past the body's edges, joined to it by smooth necks,
// and a little heavier underneath than on top, as if it sags. It oozes to a new
// option on a heavy, well-damped spring — no wobble — and leans a little
// towards an option the pointer is on. `breath` swells it slightly and is fed
// from the panel's slow clock while someone is using Lacquer.
//
// All rectangles are in the parent's coordinates. The canvas repaints only
// while the bulge moves or breathes.
Canvas {
  id: track

  // One rect per option, and which one is selected.
  property var cells: []
  property int selected: -1
  property int hovered: -1
  property bool vertical: false
  // "body": options sit inside the goo.  "line": a thin strand runs under
  // the options and the selection hangs from it as a drop.
  property string mode: "body"

  property color bodyColor: "#333"
  property color bulgeColor: "white"
  property bool animated: true
  property real mass: 1
  property real breath: 0
  // How far the bulge swells past the body (top, bottom) in body mode.
  property real swell: 3

  readonly property real pad: 16

  anchors.fill: parent
  anchors.margins: -pad
  antialiasing: true
  renderStrategy: Canvas.Cooperative

  // The bulge's edges, in the canvas's own coordinates, each on a heavy spring.
  property real b0: 0
  property real b1: 0
  property real c0: 0
  property real c1: 0
  property bool placed: false

  readonly property real spring: 4.4
  readonly property real damping: 0.5

  Behavior on b0 { enabled: track.animated && track.placed; SpringAnimation { spring: track.spring; damping: track.damping; mass: track.mass; epsilon: 0.1 } }
  Behavior on b1 { enabled: track.animated && track.placed; SpringAnimation { spring: track.spring * 0.8; damping: track.damping; mass: track.mass; epsilon: 0.1 } }
  Behavior on c0 { enabled: track.animated && track.placed; SpringAnimation { spring: track.spring; damping: track.damping; mass: track.mass; epsilon: 0.1 } }
  Behavior on c1 { enabled: track.animated && track.placed; SpringAnimation { spring: track.spring; damping: track.damping; mass: track.mass; epsilon: 0.1 } }

  function along(r) { return vertical ? [r.y, r.y + r.height] : [r.x, r.x + r.width] }
  function cross(r) { return vertical ? [r.x, r.x + r.width] : [r.y, r.y + r.height] }

  function settle() {
    var r = cells[selected]
    if (!r || !isFinite(r.x) || !isFinite(r.width) || r.width <= 0) { requestPaint(); return }
    var a = along(r), c = cross(r)
    var lo = a[0] + pad, hi = a[1] + pad
    // Lean towards an option the pointer is on, a fifth of the way.
    var h = cells[hovered]
    if (h && hovered !== selected) {
      var ha = along(h)
      if (ha[0] > a[1]) hi += Math.min(10, (ha[0] - a[1]) * 0.08 + 3)
      else if (ha[1] < a[0]) lo -= Math.min(10, (a[0] - ha[1]) * 0.08 + 3)
    }
    if (!placed) {
      b0 = lo; b1 = hi; c0 = c[0] + pad; c1 = c[1] + pad
      placed = true
      requestPaint()
      return
    }
    b0 = lo; b1 = hi; c0 = c[0] + pad; c1 = c[1] + pad
  }

  onCellsChanged: Qt.callLater(settle)
  onSelectedChanged: Qt.callLater(settle)
  onHoveredChanged: Qt.callLater(settle)
  onB0Changed: requestPaint()
  onB1Changed: requestPaint()
  onC0Changed: requestPaint()
  onC1Changed: requestPaint()
  onBreathChanged: requestPaint()
  onBodyColorChanged: requestPaint()
  onBulgeColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  // Draw in along/cross coordinates; `pt` turns them into x/y.
  function pt(a, c) { return vertical ? [c, a] : [a, c] }

  function moveTo(ctx, a, c) { var p = pt(a, c); ctx.moveTo(p[0], p[1]) }
  function lineTo(ctx, a, c) { var p = pt(a, c); ctx.lineTo(p[0], p[1]) }
  function curveTo(ctx, a1, c1, a2, c2, a, c) {
    var p1 = pt(a1, c1), p2 = pt(a2, c2), p = pt(a, c)
    ctx.bezierCurveTo(p1[0], p1[1], p2[0], p2[1], p[0], p[1])
  }

  // How round a body's ends may get: a column as wide as the rail would
  // otherwise end in a circle the size of the rail.
  property real maxRadius: 18

  // A capsule from a0 to a1 along, t to b across — or, when that would make
  // its ends too big, a rounded bar.
  function capsule(ctx, a0, a1, t, b) {
    var r = Math.min((b - t) / 2, (a1 - a0) / 2, maxRadius)
    var k = r * 0.5523
    moveTo(ctx, a0 + r, t)
    lineTo(ctx, a1 - r, t)
    curveTo(ctx, a1 - r + k, t, a1, t + r - k, a1, t + r)
    lineTo(ctx, a1, b - r)
    curveTo(ctx, a1, b - r + k, a1 - r + k, b, a1 - r, b)
    lineTo(ctx, a0 + r, b)
    curveTo(ctx, a0 + r - k, b, a0, b - r + k, a0, b - r)
    lineTo(ctx, a0, t + r)
    curveTo(ctx, a0, t + r - k, a0 + r - k, t, a0 + r, t)
  }

  // A block of ink: corners rounded off, every edge bowed out a little, and
  // the far edge hanging a touch lower, the way ink sits on paper rather than
  // a rectangle drawn with a ruler.
  function inkBlock(ctx, a0, a1, t, b) {
    var len = a1 - a0, thick = b - t
    var r = Math.max(1, Math.min(5, len / 2.4, thick / 2.4))
    var bowA = Math.min(1.6, len * 0.02 + 0.4)      // along the ends
    var bowC = Math.min(1.5, thick * 0.02 + 0.4)    // along the sides
    var midA = (a0 + a1) / 2, midC = (t + b) / 2
    var k = r * 0.55
    // the t side, bowed out
    moveTo(ctx, a0 + r, t)
    curveTo(ctx, a0 + len * 0.3, t - bowC, a1 - len * 0.3, t - bowC, a1 - r, t)
    // corner
    curveTo(ctx, a1 - r + k, t, a1, t + r - k, a1, t + r)
    // the far end, bowed out
    curveTo(ctx, a1 + bowA, t + thick * 0.35, a1 + bowA, b - thick * 0.35, a1, b - r)
    // corner
    curveTo(ctx, a1, b - r + k, a1 - r + k, b, a1 - r, b)
    // the b side, hanging a little
    curveTo(ctx, a1 - len * 0.3, b + bowC * 1.3, a0 + len * 0.3, b + bowC * 1.3, a0 + r, b)
    // corner
    curveTo(ctx, a0 + r - k, b, a0, b - r + k, a0, b - r)
    // the near end, bowed out
    curveTo(ctx, a0 - bowA, b - thick * 0.35, a0 - bowA, t + thick * 0.35, a0, t + r)
    // corner
    curveTo(ctx, a0, t + r - k, a0 + r - k, t, a0 + r, t)
  }

  // The lines of options: cells that share a cross position form one strand.
  function lines() {
    var out = []
    for (var i = 0; i < cells.length; i++) {
      var r = cells[i]
      if (!r || !isFinite(r.x)) continue
      var a = along(r), c = cross(r)
      var line = null
      for (var j = 0; j < out.length; j++) if (Math.abs(out[j].t - c[0]) < 3) { line = out[j]; break }
      if (!line) { line = { t: c[0], b: c[1], a0: a[0], a1: a[1] }; out.push(line) }
      line.a0 = Math.min(line.a0, a[0]); line.a1 = Math.max(line.a1, a[1])
      line.b = Math.max(line.b, c[1])
    }
    return out
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var ls = lines()
    if (ls.length === 0) return

    // The body.
    ctx.fillStyle = bodyColor
    for (var i = 0; i < ls.length; i++) {
      var L = ls[i]
      ctx.beginPath()
      if (mode === "line") {
        var y = L.b - 1.5 + pad
        capsule(ctx, L.a0 + pad, L.a1 + pad, y - 1.5, y + 1.5)
      } else {
        capsule(ctx, L.a0 + pad, L.a1 + pad, L.t + pad, L.b + pad)
      }
      ctx.fill()
    }

    if (b1 - b0 < 1) return
    var lo = b0, hi = b1
    var s = 1 + breath * 0.025

    if (mode === "line") {
      // A drop hanging from the strand under the selection: wide where it
      // joins, heavy and round at the bottom.
      ctx.fillStyle = bulgeColor
      ctx.beginPath()
      var base = c1 - 3
      var w = (hi - lo) * 0.46 * s
      var mid = (lo + hi) / 2
      var drop = 6.5 * s
      moveTo(ctx, mid - w / 2 - 10, base)
      curveTo(ctx, mid - w / 2 - 3, base, mid - w / 2, base + 1, mid - w / 2, base + drop * 0.5)
      curveTo(ctx, mid - w / 2, base + drop * 1.25, mid + w / 2, base + drop * 1.25, mid + w / 2, base + drop * 0.5)
      curveTo(ctx, mid + w / 2, base + 1, mid + w / 2 + 3, base, mid + w / 2 + 10, base)
      lineTo(ctx, mid + w / 2 + 10, base - 3)
      lineTo(ctx, mid - w / 2 - 10, base - 3)
      ctx.closePath()
      ctx.fill()
      return
    }

    // The swelling: the body itself thickens around the selection, sagging a
    // little — a capsule of its own, in the body's colour — and where the body
    // carries on either side, a neck runs smoothly from one into the other, so
    // the outline reads as goo gathered in one place rather than a box on a bar.
    var t = c0, b = c1
    var up = swell * 0.7 * s, down = swell * 1.35 * s
    var tt = t - up, bb = b + down
    var R = Math.min((bb - tt) / 2, (hi - lo) / 2, maxRadius + 2)
    var neck = Math.min(14, (b - t) * 0.6)
    var line = null
    for (var n = 0; n < ls.length; n++) if (Math.abs(ls[n].t + pad - t) < 4) line = ls[n]
    var rBody = Math.min((b - t) / 2, maxRadius)
    var leftNeck = line && lo - neck > line.a0 + pad + rBody * 0.9
    var rightNeck = line && hi + neck < line.a1 + pad - rBody * 0.9

    ctx.fillStyle = bodyColor
    ctx.beginPath()
    capsule(ctx, lo, hi, tt, bb)
    ctx.fill()
    if (leftNeck) {
      ctx.beginPath()
      moveTo(ctx, lo - neck, t)
      curveTo(ctx, lo - neck * 0.35, t, lo - 1, tt + up * 0.3, lo + R * 0.7, tt)
      lineTo(ctx, lo + R * 0.7, bb)
      curveTo(ctx, lo - 1, bb - down * 0.3, lo - neck * 0.35, b, lo - neck, b)
      ctx.closePath()
      ctx.fill()
    }
    if (rightNeck) {
      ctx.beginPath()
      moveTo(ctx, hi + neck, t)
      curveTo(ctx, hi + neck * 0.35, t, hi + 1, tt + up * 0.3, hi - R * 0.7, tt)
      lineTo(ctx, hi - R * 0.7, bb)
      curveTo(ctx, hi + 1, bb - down * 0.3, hi + neck * 0.35, b, hi + neck, b)
      ctx.closePath()
      ctx.fill()
    }

    // And the selection inside it, in the accent: a block of ink, whose edges
    // bow out a little and whose corners are soft, the way ink sits on paper
    // rather than a rectangle drawn with a ruler.
    ctx.fillStyle = bulgeColor
    ctx.beginPath()
    inkBlock(ctx, lo, hi, tt + 1.5, bb - 1.5)
    ctx.fill()
  }
}
