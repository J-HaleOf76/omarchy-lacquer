import QtQuick

// A number you can drag: a hairline rule with the filled part inked in and a
// small slug of ink to take hold of. While it is dragged the slug grows a
// little and the ink ripples behind it; let go, it settles.
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
      var ox = 12, cy = Math.round(height / 2)
      var w = slider.trackWidth
      var kx = ox + goo.kx
      var R = slider.knobR + goo.swell * 1.2

      // The track: a hairline ruled across the page.
      ctx.fillStyle = slider.design.rule
      ctx.fillRect(ox, cy - 0.5, w, 1)

      // The part that is filled in, in the second ink, rippling a little
      // behind the slug while it is dragged.
      ctx.fillStyle = slider.design.accent
      ctx.beginPath()
      ctx.moveTo(ox, cy - 1.5)
      for (var x = ox; x < kx; x += 4) {
        var fade = Math.max(0, 1 - (kx - x) / 90)
        ctx.lineTo(x, cy - 1.5 - Math.sin(x / 5 + goo.phase) * goo.ripple * 0.8 * fade)
      }
      ctx.lineTo(kx, cy - 1.5)
      ctx.lineTo(kx, cy + 1.5)
      ctx.lineTo(ox, cy + 1.5)
      ctx.closePath()
      ctx.fill()

      // The slug: a small block of ink you can take hold of.
      var hw = Math.max(3, R * 0.42), hh = R
      ctx.fillRect(Math.round(kx - hw), Math.round(cy - hh), Math.round(hw * 2), Math.round(hh * 2))

      if (slider.hasCursor) {
        ctx.strokeStyle = slider.design.accent
        ctx.lineWidth = 1
        ctx.strokeRect(Math.round(kx - hw) - 3.5, Math.round(cy - hh) - 3.5, Math.round(hw * 2) + 7, Math.round(hh * 2) + 7)
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
