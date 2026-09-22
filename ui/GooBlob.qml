import QtQuick

// A blob of something wet that slides to wherever it is told to sit.
//
// Each of its four edges is on its own spring. The edges on the side it is
// heading towards are stiff and quick, the trailing ones soft and slow, so a
// move stretches it out, pinches it at the waist like a drop about to split,
// then lets the tail slap in and wobble. Stretching one way thins it the other
// way (it keeps its volume), which is what makes it jiggle as it settles.
//
// Set `target` (x, y, width, height in the parent's coordinates). The canvas
// only repaints while an edge is moving, so a blob at rest costs nothing.
Canvas {
  id: goo

  property rect target: Qt.rect(0, 0, 0, 0)
  property color color: "white"
  property real radius: 8
  property bool animated: true
  property real mass: 1
  // How far outside the parent it may bulge while overshooting.
  property real pad: 24
  // 0 = a plain rounded shape, 1 = full goo.
  property real gooiness: 1

  anchors.fill: parent
  anchors.margins: -pad
  antialiasing: true
  renderStrategy: Canvas.Cooperative

  // The edges, in the canvas's own coordinates.
  property real el: 0
  property real er: 0
  property real et: 0
  property real eb: 0
  property real kl: 3
  property real kr: 3
  property real kt: 3
  property real kb: 3
  property bool placed: false

  readonly property real damping: 0.14
  readonly property real fast: 6.2
  readonly property real slow: 1.7

  Behavior on el { enabled: goo.animated && goo.placed; SpringAnimation { spring: goo.kl; damping: goo.damping; mass: goo.mass; epsilon: 0.08 } }
  Behavior on er { enabled: goo.animated && goo.placed; SpringAnimation { spring: goo.kr; damping: goo.damping; mass: goo.mass; epsilon: 0.08 } }
  Behavior on et { enabled: goo.animated && goo.placed; SpringAnimation { spring: goo.kt; damping: goo.damping; mass: goo.mass; epsilon: 0.08 } }
  Behavior on eb { enabled: goo.animated && goo.placed; SpringAnimation { spring: goo.kb; damping: goo.damping; mass: goo.mass; epsilon: 0.08 } }

  function settle() {
    // A target that is not a number (a slider handed undefined, say) would
    // never be reached: NaN is never equal to itself, so the springs would
    // run and repaint forever. Stay where it is instead.
    if (!isFinite(target.x) || !isFinite(target.y) || !isFinite(target.width) || !isFinite(target.height)) return
    var tl = target.x + pad, tr = target.x + target.width + pad
    var tt = target.y + pad, tb = target.y + target.height + pad
    if (!placed || target.width <= 0) {
      el = tl; er = tr; et = tt; eb = tb
      placed = target.width > 0
      requestPaint()
      return
    }
    // Leading edges quick, trailing edges slow.
    kl = tl < el ? fast : slow
    kr = tr > er ? fast : slow
    kt = tt < et ? fast : slow
    kb = tb > eb ? fast : slow
    el = tl; er = tr; et = tt; eb = tb
  }

  // Put it somewhere at once, with no travel, e.g. to start a drip from.
  function jump(r) {
    placed = false
    target = r
    settle()
  }

  onTargetChanged: Qt.callLater(settle)
  onElChanged: requestPaint()
  onErChanged: requestPaint()
  onEtChanged: requestPaint()
  onEbChanged: requestPaint()
  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  Component.onCompleted: settle()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = er - el, h = eb - et
    if (w < 0.5 || h < 0.5) return
    var tw = Math.max(1, target.width), th = Math.max(1, target.height)
    // Signed stretch along each axis: positive while the tail lags, negative
    // on the overshoot as it slaps into place.
    var sx = (w - tw) / tw, sy = (h - th) / th
    // Keep the volume: stretched one way, thinner the other; squashed, fatter.
    var fy = Math.max(0.7, Math.min(1.24, 1 / (1 + 0.45 * sx * gooiness)))
    var fx = Math.max(0.7, Math.min(1.24, 1 / (1 + 0.45 * sy * gooiness)))
    var cx = (el + er) / 2, cy = (et + eb) / 2
    var l = cx - (w * fx) / 2, r = cx + (w * fx) / 2
    var t = cy - (h * fy) / 2, b = cy + (h * fy) / 2
    w = r - l; h = b - t
    // The waist: how far each long side dips in while stretched.
    var dipY = gooiness * Math.min(h * 0.24, h * 0.3 * Math.max(0, sx))
    var dipX = gooiness * Math.min(w * 0.24, w * 0.3 * Math.max(0, sy))
    var rad = Math.max(0, Math.min(radius, w / 2, h / 2))

    ctx.fillStyle = color
    ctx.beginPath()
    ctx.moveTo(l + rad, t)
    ctx.quadraticCurveTo(cx, t + dipY * 2, r - rad, t)
    if (rad > 0) ctx.arcTo(r, t, r, t + rad, rad); else ctx.lineTo(r, t)
    ctx.quadraticCurveTo(r - dipX * 2, cy, r, b - rad)
    if (rad > 0) ctx.arcTo(r, b, r - rad, b, rad); else ctx.lineTo(r, b)
    ctx.quadraticCurveTo(cx, b - dipY * 2, l + rad, b)
    if (rad > 0) ctx.arcTo(l, b, l, b - rad, rad); else ctx.lineTo(l, b)
    ctx.quadraticCurveTo(l + dipX * 2, cy, l, t + rad)
    if (rad > 0) ctx.arcTo(l, t, l + rad, t, rad); else ctx.lineTo(l, t)
    ctx.closePath()
    ctx.fill()
  }
}
