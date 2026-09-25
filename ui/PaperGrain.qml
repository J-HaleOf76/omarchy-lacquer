import QtQuick

// The tooth of the paper: a faint, even speckle over the whole sheet. It is
// drawn once at the size it is given and never again, so it costs nothing.
Canvas {
  id: grain

  required property var design
  property real amount: design.dark ? 0.075 : 0.068
  // Always the same speckle, so a repaint never shifts the texture.
  property int seed: 20260925

  antialiasing: false
  renderStrategy: Canvas.Cooperative
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    if (width < 2 || height < 2) return
    var r = seed
    function rnd() { r = (r * 1103515245 + 12345) & 0x7fffffff; return r / 0x7fffffff }
    // The speckle itself: single pixels, dense enough to read as tooth.
    ctx.fillStyle = design.alpha(design.ink, amount)
    var dots = Math.round(width * height / 24)
    for (var i = 0; i < dots; i++) {
      var x = Math.floor(rnd() * width)
      var y = Math.floor(rnd() * height)
      ctx.fillRect(x, y, 1, 1)
    }
    // A few heavier flecks, the way a sheet of rough paper has them, so the
    // texture has some grain size and not just an even hiss.
    ctx.fillStyle = design.alpha(design.ink, amount * 1.5)
    var flecks = Math.round(width * height / 900)
    for (var f = 0; f < flecks; f++) {
      var fx = Math.floor(rnd() * (width - 2))
      var fy = Math.floor(rnd() * (height - 2))
      ctx.fillRect(fx, fy, rnd() > 0.5 ? 2 : 1, rnd() > 0.5 ? 2 : 1)
    }
  }
}
