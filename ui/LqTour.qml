import QtQuick
import QtQuick.Shapes

// The tour: a minute of printed notes pinned over the app, each one pointing
// at the thing it is talking about. The sheet is washed out except for the one
// part under discussion, which stays clickable — a note that says "click here"
// means it.
Item {
  id: tour

  required property var design
  // One entry per note:
  //   { title, body, click, at: function() -> rect, enter: function() }
  // `at` is read again while the note is up, so the ring follows anything that
  // moves. An empty rect means the note sits in the middle of the sheet, with
  // nothing singled out.
  property var steps: []
  property int index: -1

  readonly property bool active: index >= 0 && index < steps.length
  readonly property var step: active ? steps[index] : null

  signal finished()

  // Re-read while a note is up, so the ring keeps up with the page settling.
  property int tick: 0
  readonly property rect hole: {
    tour.tick  // read, so this is worked out again on every beat
    if (!tour.active || !tour.step || !tour.step.at) return Qt.rect(0, 0, 0, 0)
    var r = tour.step.at()
    if (!r || r.width <= 0 || r.height <= 0) return Qt.rect(0, 0, 0, 0)
    var pad = 6
    return Qt.rect(Math.max(0, r.x - pad), Math.max(0, r.y - pad),
                   Math.min(tour.width, r.width + pad * 2), Math.min(tour.height, r.height + pad * 2))
  }
  readonly property bool hasHole: hole.width > 1 && hole.height > 1

  Timer {
    running: tour.active
    interval: 250
    repeat: true
    onTriggered: tour.tick = tour.tick + 1
  }

  function begin() {
    tour.index = -1
    tour.goTo(0)
  }

  function goTo(i) {
    if (i < 0 || i >= tour.steps.length) { tour.stop(); return }
    tour.index = i
    tour.tick = tour.tick + 1
    var s = tour.steps[i]
    if (s && s.enter) s.enter()
  }

  function next() { tour.goTo(tour.index + 1) }
  function back() { if (tour.index > 0) tour.goTo(tour.index - 1) }

  function stop() {
    if (tour.index < 0) return
    tour.index = -1
    tour.finished()
  }

  visible: opacity > 0.01
  opacity: active ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: tour.design.motion ? 180 : 0; easing.type: Easing.OutCubic } }

  // ------------------------------------------------------------- the wash
  //
  // Four panes around the hole rather than one sheet with a cut-out, so a
  // click inside the hole reaches the real control underneath.

  readonly property real hx: hasHole ? hole.x : 0
  readonly property real hy: hasHole ? hole.y : 0
  readonly property real hw: hasHole ? hole.width : 0
  readonly property real hh: hasHole ? hole.height : 0

  component Pane: Rectangle {
    color: tour.design.alpha(tour.design.paper, tour.design.dark ? 0.86 : 0.88)
    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: {} }
    Behavior on x { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
  }

  Pane { x: 0; y: 0; width: tour.width; height: tour.hasHole ? tour.hy : tour.height }
  Pane { x: 0; y: tour.hy; width: tour.hasHole ? tour.hx : 0; height: tour.hh }
  Pane { x: tour.hx + tour.hw; y: tour.hy; width: tour.hasHole ? Math.max(0, tour.width - tour.hx - tour.hw) : 0; height: tour.hh }
  Pane { x: 0; y: tour.hy + tour.hh; width: tour.width; height: tour.hasHole ? Math.max(0, tour.height - tour.hy - tour.hh) : 0 }

  // The ring around what is being pointed at.
  Rectangle {
    visible: tour.hasHole
    x: tour.hx
    y: tour.hy
    width: tour.hw
    height: tour.hh
    radius: tour.design.cardRadius
    color: "transparent"
    border.width: 2
    border.color: tour.design.accent
    Behavior on x { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on width { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on height { enabled: tour.design.motion; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
  }

  // ------------------------------------------------------------ the note

  readonly property real noteWidth: Math.min(340, tour.width - 48)
  // Where the note goes: beside what it points at when there is room, below it
  // otherwise, and in the middle of the sheet when it points at nothing.
  // A ring around most of the sheet means "look at all of this": there is no
  // room beside it and no point in an arrow, so the note sits in the middle.
  readonly property bool wideHole: hasHole && (hw * hh) > (width * height * 0.45)
  readonly property string place: {
    if (!tour.hasHole || tour.wideHole) return "centre"
    if (tour.hx + tour.hw + 28 + tour.noteWidth <= tour.width) return "right"
    if (tour.hx - 28 - tour.noteWidth >= 0) return "left"
    if (tour.hy + tour.hh + 24 + note.height <= tour.height) return "below"
    return "above"
  }

  Rectangle {
    id: note
    width: tour.noteWidth
    height: noteColumn.implicitHeight + 34
    color: tour.design.paper
    radius: tour.design.cardRadius
    border.width: 1
    border.color: tour.design.ruleStrong

    x: {
      switch (tour.place) {
        case "right": return Math.min(tour.width - width - 8, tour.hx + tour.hw + 28)
        case "left": return Math.max(8, tour.hx - 28 - width)
        case "centre": return Math.round((tour.width - width) / 2)
        default: return Math.max(8, Math.min(tour.width - width - 8, tour.hx + tour.hw / 2 - width / 2))
      }
    }
    y: {
      switch (tour.place) {
        case "centre": return Math.round((tour.height - height) / 2)
        case "below": return Math.min(tour.height - height - 8, tour.hy + tour.hh + 24)
        case "above": return Math.max(8, tour.hy - 24 - height)
        default: return Math.max(8, Math.min(tour.height - height - 8, tour.hy + tour.hh / 2 - height / 2))
      }
    }

    Behavior on x { enabled: tour.design.motion; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: tour.design.motion; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: {} }

    // The heavy rule along the top, as every printed block in Lacquer has.
    Rectangle {
      x: 0
      y: 0
      width: parent.width
      height: 2
      topLeftRadius: parent.radius
      topRightRadius: parent.radius
      color: tour.design.accent
    }

    Column {
      id: noteColumn
      x: 18
      y: 20
      width: parent.width - 36
      spacing: 8

      Text {
        width: parent.width
        text: tour.step ? String(tour.step.title || "") : ""
        wrapMode: Text.WordWrap
        color: tour.design.ink
        font.family: tour.design.serif
        font.pixelSize: 19
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: tour.step ? String(tour.step.body || "") : ""
        wrapMode: Text.WordWrap
        lineHeight: 1.25
        color: tour.design.muted
        font.family: tour.design.sans
        font.pixelSize: 13
      }

      // The invitation, when the thing being pointed at can be clicked.
      Row {
        visible: !!(tour.step && tour.step.click)
        spacing: 8
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 7
          height: 7
          radius: 3.5
          color: tour.design.accent
          scale: pulse.on ? 1.55 : 1
          opacity: pulse.on ? 0.45 : 1
          Behavior on scale { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
          Behavior on opacity { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: tour.step ? String(tour.step.click || "") : ""
          color: tour.design.accent
          font.family: tour.design.sans
          font.pixelSize: 13
        }
      }

      Item { width: 1; height: 4 }

      Rectangle { width: parent.width; height: 1; color: tour.design.rule }

      Item {
        width: parent.width
        height: Math.max(nextButton.implicitHeight, counter.implicitHeight)

        Text {
          id: counter
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          text: (tour.index + 1) + " / " + tour.steps.length
          color: tour.design.faint
          font.family: tour.design.mono
          font.pixelSize: 12
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 14

          LqButton {
            anchors.verticalCenter: parent.verticalCenter
            design: tour.design
            compact: true
            text: tour.index === 0 ? "No thanks" : "Close"
            onClicked: tour.stop()
          }

          LqButton {
            id: nextButton
            anchors.verticalCenter: parent.verticalCenter
            design: tour.design
            compact: true
            selected: true
            text: tour.index === 0 ? "Show me"
                                   : (tour.index >= tour.steps.length - 1 ? "Done" : "Next")
            onClicked: tour.next()
          }
        }
      }
    }
  }

  // A slow blink for the invitation dot, only while the tour is up.
  QtObject {
    id: pulse
    property bool on: false
  }

  Timer {
    running: tour.active && tour.design.motion
    interval: 620
    repeat: true
    onTriggered: pulse.on = !pulse.on
  }

  // ----------------------------------------------------------- the pointer
  //
  // A pen stroke from the note to the thing it is about, drawn the way you
  // would scribble an arrow on a proof sheet.

  readonly property point fromPt: {
    if (!tour.hasHole || tour.wideHole) return Qt.point(0, 0)
    switch (tour.place) {
      case "right": return Qt.point(note.x, note.y + 34)
      case "left": return Qt.point(note.x + note.width, note.y + 34)
      case "below": return Qt.point(note.x + note.width / 2, note.y)
      case "above": return Qt.point(note.x + note.width / 2, note.y + note.height)
      default: return Qt.point(0, 0)
    }
  }
  readonly property point toPt: {
    if (!tour.hasHole || tour.wideHole) return Qt.point(0, 0)
    switch (tour.place) {
      case "right": return Qt.point(tour.hx + tour.hw + 7, Math.min(tour.hy + tour.hh - 6, note.y + 34))
      case "left": return Qt.point(tour.hx - 7, Math.min(tour.hy + tour.hh - 6, note.y + 34))
      case "below": return Qt.point(Math.max(tour.hx + 8, Math.min(tour.hx + tour.hw - 8, note.x + note.width / 2)), tour.hy + tour.hh + 7)
      case "above": return Qt.point(Math.max(tour.hx + 8, Math.min(tour.hx + tour.hw - 8, note.x + note.width / 2)), tour.hy - 7)
      default: return Qt.point(0, 0)
    }
  }

  Shape {
    anchors.fill: parent
    visible: tour.hasHole && !tour.wideHole
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: tour.design.accent
      strokeWidth: 2
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: tour.fromPt.x
      startY: tour.fromPt.y
      // A single bowed stroke: it leaves the note sideways and arrives at the
      // ring, bending the way a hand would.
      PathCubic {
        x: tour.toPt.x
        y: tour.toPt.y
        relativeControl1X: (tour.toPt.x - tour.fromPt.x) * 0.4
        relativeControl1Y: (tour.toPt.y - tour.fromPt.y) * 0.05 - 14
        relativeControl2X: (tour.toPt.x - tour.fromPt.x) * 0.7
        relativeControl2Y: (tour.toPt.y - tour.fromPt.y) * 0.75 + 10
      }
    }

    // The head, a small filled wedge aimed along the stroke.
    ShapePath {
      id: head
      strokeWidth: -1
      fillColor: tour.design.accent
      // Aimed along the last part of the stroke, not the chord, so the head
      // sits square on the ring.
      readonly property real ang: Math.atan2(tour.toPt.y - tour.fromPt.y, tour.toPt.x - tour.fromPt.x)
      startX: tour.toPt.x
      startY: tour.toPt.y
      PathLine {
        x: tour.toPt.x - 11 * Math.cos(head.ang - 0.42)
        y: tour.toPt.y - 11 * Math.sin(head.ang - 0.42)
      }
      PathLine {
        x: tour.toPt.x - 11 * Math.cos(head.ang + 0.42)
        y: tour.toPt.y - 11 * Math.sin(head.ang + 0.42)
      }
      PathLine { x: tour.toPt.x; y: tour.toPt.y }
    }
  }
}
