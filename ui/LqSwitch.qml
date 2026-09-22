import QtQuick

// On or off. The knob is a drop of goo: it stretches across the track as it
// goes and wobbles when it lands.
Item {
  id: sw

  required property var design
  property bool checked: false
  property bool hasCursor: false

  signal toggled()

  implicitWidth: 44
  implicitHeight: 24

  readonly property real knob: height - 8
  readonly property real trackRadius: design.rounding <= 0 ? 3 : height / 2

  Rectangle {
    id: track
    anchors.fill: parent
    radius: sw.trackRadius
    color: sw.checked ? sw.design.accent : sw.design.surface
    border.width: sw.checked ? 0 : 1
    border.color: sw.design.hairline
    Behavior on color { ColorAnimation { duration: 220 } }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: -3
    visible: sw.hasCursor
    color: "transparent"
    radius: sw.trackRadius + 3
    border.width: 1.5
    border.color: sw.design.accent
  }

  Item {
    anchors.fill: parent
    GooBlob {
      pad: 10
      color: sw.checked ? sw.design.onAccent : sw.design.muted
      radius: sw.design.rounding <= 0 ? 2 : sw.knob / 2
      animated: sw.design.motion
      mass: sw.design.mass * 0.8
      target: Qt.rect(sw.checked ? sw.width - sw.knob - 4 : 4, 4, sw.knob, sw.knob)
    }
  }

  scale: mouse.pressed ? 0.92 : 1
  Behavior on scale { enabled: sw.design.motion; SpringAnimation { spring: 4; damping: 0.16; mass: sw.design.mass } }

  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.margins: -4
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled()
  }
}
