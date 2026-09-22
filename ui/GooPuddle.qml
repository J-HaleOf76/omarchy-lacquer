import QtQuick

// A small pool of accent goo at the foot of the rail. A drop that falls into
// it (`splash(x)`) sends a ripple out from where it landed, which spreads,
// fades and settles. It is only redrawn while it ripples.
Canvas {
  id: puddle

  required property var design
  // Where along it the last drop landed, 0..1, and how much it is still rippling.
  property real at: 0.5
  property real ripple: 0
  property real phase: 0

  implicitHeight: 30
  antialiasing: true
  renderStrategy: Canvas.Cooperative

  function splash(x) {
    at = Math.max(0.1, Math.min(0.9, x / Math.max(1, width)))
    if (!design.motion) return
    ripple = 1
    settle.restart()
  }

  NumberAnimation { id: settle; target: puddle; property: "ripple"; to: 0; duration: 1300; easing.type: Easing.OutCubic }
  NumberAnimation { target: puddle; property: "phase"; from: 0; to: 12.566; duration: 1300; running: puddle.ripple > 0.005; loops: 1 }

  onRippleChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  Connections {
    target: puddle.design
    function onAccentChanged() { puddle.requestPaint() }
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = width, h = height
    var base = h - 2
    var top = h * 0.3
    var hit = at * w
    ctx.fillStyle = design.alpha(design.accent, design.dark ? 0.5 : 0.42)
    ctx.beginPath()
    ctx.moveTo(4, base)
    // The surface: a low dome, heavier towards the middle, with a ripple
    // travelling out from where the drop fell and dying away with distance.
    for (var x = 4; x <= w - 4; x += 3) {
      var u = (x - 4) / (w - 8)
      // Flat across the middle, rounding off only near the rims.
      var dome = Math.pow(Math.sin(Math.PI * u), 0.28)
      var d = Math.abs(x - hit)
      var wave = ripple * 3.2 * Math.exp(-d / 38) * Math.cos(d / 7 - phase)
      ctx.lineTo(x, base - (base - top) * dome - wave * dome)
    }
    ctx.lineTo(w - 4, base)
    // A flat, slightly rounded bottom where it sits.
    ctx.lineTo(4, base)
    ctx.closePath()
    ctx.fill()
  }
}
