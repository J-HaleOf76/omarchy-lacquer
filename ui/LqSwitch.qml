import QtQuick

// On or off: an ink block that slides across a ruled track, spreading a
// little as it goes.
Item {
  id: sw

  required property var design
  property bool checked: false
  property bool hasCursor: false

  // Accepted from Omarchy's ToggleSwitch; the kit draws its own colours.
  property color foreground: "white"
  property color accent: "white"

  signal toggled()

  implicitWidth: 44
  implicitHeight: 24

  readonly property real knob: height - 8
  readonly property real trackRadius: design.controlRadius

  Rectangle {
    id: track
    anchors.fill: parent
    radius: sw.trackRadius
    color: sw.checked ? sw.design.accent : "transparent"
    border.width: 1
    border.color: sw.checked ? sw.design.accent : sw.design.rule
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
      radius: sw.design.controlRadius
      // A little goo as it slides across, none at rest.
      gooiness: 0.2
      animated: sw.design.motion
      mass: sw.design.mass * 0.8
      target: Qt.rect(sw.checked ? sw.width - sw.knob - 4 : 4, 4, sw.knob, sw.knob)
    }
  }


  MouseArea {
    id: mouse
    anchors.fill: parent
    anchors.margins: -4
    cursorShape: Qt.PointingHandCursor
    onClicked: sw.toggled()
  }
}
