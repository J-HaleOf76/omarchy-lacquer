import QtQuick

// A number you can drag, drawn as goo: the filled part and the knob are one
// body, the knob a swelling at the end of the fill, joined by a neck. While
// it is dragged the knob swells and the fill ripples a little behind it; let
// go, it settles slowly.
//
// `value` is where it is; dragging shows `shown` and emits `moved` for pages
// that preview live, and `committed` once on release, measured from where the
// drag began. Arrow keys and the wheel emit `stepped(±1)` like a stepper did.
Item {
  id: slider

  required property var design
  property real value: 0
  // Omarchy's PanelSlider names, so a use of it can switch by name.
  property real minimum: 0
  property real maximum: 1
  property real step: 1
  property bool integer: false
  property color fillColor: "white"
  property color knobColor: "white"
  property real from: minimum
  property real to: maximum
  property real stepSize: step
  // What the label says for a given number; the page supplies units.
  property var format: function(v) { return String(Math.round(v)) }
  property bool hasCursor: false
  property bool showLabel: true

  signal committed(real value)
  signal stepped(int delta)
  // While dragging, for pages that preview live.
  signal moved(real value)
  // PanelSlider's name for committed.
  signal released(real value)

  property bool dragging: false
  // Where a drag began: with a live preview, `value` already follows the
  // pointer, so a release is compared with this instead.
  property real startValue: 0
  property real dragValue: value
  // A value that is not a number sits at the start rather than nowhere.
  readonly property real safeValue: isFinite(value) ? value : from
  readonly property real shown: dragging ? dragValue : safeValue
  readonly property real range: Math.max(0.000001, to - from)
  readonly property real progress: { var p = (shown - from) / range; return isFinite(p) ? Math.max(0, Math.min(1, p)) : 0 }

  implicitWidth: 320
  implicitHeight: 30

  readonly property real labelWidth: showLabel ? 78 : 0
  readonly property real trackWidth: Math.max(40, width - labelWidth - (showLabel ? 14 : 0))
  readonly property real knobR: 8

  function snap(v) {
    var s = stepSize > 0 ? stepSize : 1
    return Math.max(from, Math.min(to, from + Math.round((v - from) / s) * s))
  }
  function valueAt(x) { return snap(from + Math.max(0, Math.min(1, (x - knobR) / Math.max(1, trackWidth - knobR * 2))) * range) }

  Canvas {
    id: goo
    width: slider.trackWidth + 24
    height: slider.height + 20
    x: -12
    y: -10
    antialiasing: true
    renderStrategy: Canvas.Cooperative

    // Where the knob is drawn, on a heavy spring (none while dragging, so it
    // stays under the pointer), how swollen it is, and how much the fill is
    // rippling.
    property real kx: slider.knobR + slider.progress * (slider.trackWidth - slider.knobR * 2)
    Behavior on kx { enabled: slider.design.motion && !slider.dragging; SpringAnimation { spring: 4.0; damping: 0.52; mass: slider.design.mass; epsilon: 0.1 } }
    property real swell: slider.dragging ? 1 : (knobHover.containsMouse || slider.hasCursor ? 0.45 : 0)
    Behavior on swell { enabled: slider.design.motion; SpringAnimation { spring: 2.6; damping: 0.4; epsilon: 0.01 } }
    property real ripple: 0
    property real phase: 0

    onKxChanged: requestPaint()
    onSwellChanged: requestPaint()
    onRippleChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var ox = 12, cy = height / 2
      var w = slider.trackWidth
      var th = 8
      function capsule(a0, a1, t, b) {
        var r = (b - t) / 2, k = r * 0.5523, m = (t + b) / 2
        ctx.moveTo(a0 + r, t); ctx.lineTo(a1 - r, t)
        ctx.bezierCurveTo(a1 - r + k, t, a1, m - k, a1, m)
        ctx.bezierCurveTo(a1, m + k, a1 - r + k, b, a1 - r, b)
        ctx.lineTo(a0 + r, b)
        ctx.bezierCurveTo(a0 + r - k, b, a0, m + k, a0, m)
        ctx.bezierCurveTo(a0, m - k, a0 + r - k, t, a0 + r, t)
      }
      // The body of the track.
      ctx.fillStyle = slider.design.surface
      ctx.beginPath(); capsule(ox, ox + w, cy - th / 2, cy + th / 2); ctx.fill()

      var kx = ox + goo.kx
      var R = slider.knobR + goo.swell * 1.5
      // The fill, rippling along its top while it moves.
      ctx.fillStyle = slider.design.alpha(slider.design.accent, 0.5)
      ctx.beginPath()
      var t = cy - th / 2, b = cy + th / 2
      ctx.moveTo(ox + th / 2, t)
      for (var x = ox + th / 2; x < kx; x += 4) {
        var fade = Math.max(0, 1 - (kx - x) / 90)
        ctx.lineTo(x, t - Math.sin(x / 5 + goo.phase) * goo.ripple * 0.8 * fade)
      }
      ctx.lineTo(kx, t)
      ctx.lineTo(kx, b)
      ctx.lineTo(ox + th / 2, b)
      ctx.arc(ox + th / 2, cy, th / 2, Math.PI / 2, Math.PI * 1.5)
      ctx.fill()

      // The knob: a swelling of the fill, with a neck running back into it,
      // sitting a touch low as if it sags.
      ctx.fillStyle = slider.design.accent
      var ky = cy + 0.8
      ctx.beginPath()
      ctx.moveTo(kx - R - 7, t)
      ctx.bezierCurveTo(kx - R - 2, t, kx - R * 0.8, ky - R * 0.8, kx, ky - R)
      ctx.bezierCurveTo(kx + R * 0.56, ky - R, kx + R, ky - R * 0.56, kx + R, ky)
      ctx.bezierCurveTo(kx + R, ky + R * 0.56, kx + R * 0.56, ky + R, kx, ky + R)
      ctx.bezierCurveTo(kx - R * 0.8, ky + R * 0.8, kx - R - 2, b, kx - R - 7, b)
      ctx.closePath()
      ctx.fill()

      // The keyboard cursor.
      if (slider.hasCursor) {
        ctx.strokeStyle = slider.design.accent
        ctx.lineWidth = 1.5
        ctx.beginPath(); ctx.arc(kx, ky, R + 4, 0, Math.PI * 2); ctx.stroke()
      }
    }

    NumberAnimation { id: rippleDecay; target: goo; property: "ripple"; to: 0; duration: 480; easing.type: Easing.OutCubic }
    NumberAnimation { id: phaseRun; target: goo; property: "phase"; from: 0; to: 6.283; duration: 480; running: goo.ripple > 0.01 }
  }

  Connections {
    target: slider
    function onDragValueChanged() {
      if (!slider.dragging || !slider.design.motion) return
      goo.ripple = 1
      rippleDecay.restart()
    }
    function onHasCursorChanged() { goo.requestPaint() }
  }

  MouseArea {
    id: knobHover
    width: slider.trackWidth
    height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    preventStealing: true
    onPressed: function(m) { slider.startValue = slider.safeValue; slider.dragging = true; slider.dragValue = slider.valueAt(m.x); slider.moved(slider.dragValue) }
    onPositionChanged: function(m) {
      if (!slider.dragging) return
      var v = slider.valueAt(m.x)
      if (v !== slider.dragValue) { slider.dragValue = v; slider.moved(v) }
    }
    onReleased: {
      var v = slider.dragValue
      slider.dragging = false
      if (Math.abs(v - slider.startValue) > 0.0000001) { slider.committed(v); slider.released(v) }
    }
    onCanceled: slider.dragging = false
    onWheel: function(w) { slider.stepped(w.angleDelta.y > 0 ? 1 : -1) }
  }

  Text {
    visible: slider.showLabel
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: slider.labelWidth
    horizontalAlignment: Text.AlignRight
    text: slider.format(slider.shown)
    color: slider.dragging ? slider.design.accent : slider.design.foreground
    font.family: slider.design.mono
    font.pixelSize: 14
    font.weight: Font.DemiBold
    elide: Text.ElideLeft
  }
}
