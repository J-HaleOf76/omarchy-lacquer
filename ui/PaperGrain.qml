import QtQuick

// The tooth of the paper: a faint, even speckle over the whole sheet. It is
// drawn once at the size it is given and never again, so it costs nothing.
Canvas {
  id: grain

  required property var design
  property real amount: design.dark ? 0.05 : 0.045
  // Always the same speckle, so a repaint never shifts the texture.
  property int seed: 20260925
  // One speckle per cell of this many pixels square. Scattering within a cell
  // rather than over the whole sheet is what keeps it even: purely random
  // points clump into blotches and leave bald patches, which reads as dirt
  // rather than as paper.
  readonly property int cell: 5

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

    ctx.fillStyle = design.alpha(design.ink, amount)
    var cols = Math.ceil(width / cell)
    var rows = Math.ceil(height / cell)
    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        // A quarter of the cells stay bare, so it is a speckle and not a wash.
        if (rnd() < 0.25) continue
        var x = Math.floor(cx * cell + rnd() * cell)
        var y = Math.floor(cy * cell + rnd() * cell)
        if (x < width && y < height) ctx.fillRect(x, y, 1, 1)
      }
    }
  }
}
