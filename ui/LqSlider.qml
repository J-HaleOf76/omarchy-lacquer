import QtQuick

// A number you can drag. The knob is goo: it smears along the track behind
// the pointer and jiggles when let go.
//
// `value` is where it is; dragging shows `preview` and only emits `committed`
// on release, so a drag writes once rather than once per pixel. Arrow keys and
// the wheel emit `stepped(±1)` like a stepper did.
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

  signal committed(real value)
  signal stepped(int delta)
  // While dragging, for pages that preview live.
  signal moved(real value)
  // PanelSlider's name for committed.
  signal released(real value)

  property bool showLabel: true

  property bool dragging: false
  // Where a drag began: with a live preview, `value` already follows the
  // pointer, so a release is compared with this instead.
  property real startValue: 0
  property real dragValue: value
  readonly property real shown: dragging ? dragValue : value
  readonly property real range: Math.max(0.000001, to - from)
  readonly property real progress: Math.max(0, Math.min(1, (shown - from) / range))

  implicitWidth: 320
  implicitHeight: 30

  readonly property real labelWidth: showLabel ? 78 : 0
  readonly property real trackWidth: width - labelWidth - (showLabel ? 14 : 0)
  readonly property real knobSize: 16

  function snap(v) {
    var s = stepSize > 0 ? stepSize : 1
    return Math.max(from, Math.min(to, from + Math.round((v - from) / s) * s))
  }
  function valueAt(x) { return snap(from + Math.max(0, Math.min(1, (x - knobSize / 2) / Math.max(1, trackWidth - knobSize))) * range) }

  Item {
    id: trackArea
    width: slider.trackWidth
    height: parent.height

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: slider.design.rounding <= 0 ? 1 : 3
      color: slider.design.surface
      border.width: 1
      border.color: slider.design.hairline
    }

    // The filled part, also a little wet at its end.
    GooBlob {
      pad: 16
      color: slider.design.accentSoft
      radius: track.radius
      animated: slider.design.motion && !slider.dragging
      mass: slider.design.mass
      target: Qt.rect(0, track.y, Math.max(track.height, slider.knobSize / 2 + slider.progress * (slider.trackWidth - slider.knobSize)), track.height)
    }

    GooBlob {
      id: knob
      pad: 22
      color: slider.design.accent
      radius: slider.design.rounding <= 0 ? 2 : slider.knobSize / 2
      animated: slider.design.motion
      mass: slider.design.mass * 0.7
      target: Qt.rect(slider.progress * (slider.trackWidth - slider.knobSize), (trackArea.height - slider.knobSize) / 2, slider.knobSize, slider.knobSize)
    }

    Rectangle {
      x: slider.progress * (slider.trackWidth - slider.knobSize) - 4
      y: (trackArea.height - slider.knobSize) / 2 - 4
      width: slider.knobSize + 8
      height: slider.knobSize + 8
      radius: slider.design.rounding <= 0 ? 3 : width / 2
      visible: slider.hasCursor || drag.containsMouse
      color: "transparent"
      border.width: 1.5
      border.color: slider.design.alpha(slider.design.accent, slider.hasCursor ? 1 : 0.4)
    }

    MouseArea {
      id: drag
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      preventStealing: true
      onPressed: function(m) { slider.startValue = slider.value; slider.dragging = true; slider.dragValue = slider.valueAt(m.x); slider.moved(slider.dragValue) }
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
