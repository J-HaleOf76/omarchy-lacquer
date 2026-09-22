import QtQuick

// An action: a glossy pill that squishes when pressed and springs back.
Item {
  id: button

  required property var design
  property string text: ""
  property string iconText: ""
  property bool selected: false
  property bool danger: false
  property bool hasCursor: false
  property bool compact: false
  // For one of many picks (a multi-select): selected reads as a tint, not a
  // solid fill, so a list with most things on stays calm.
  property bool soft: false
  property string tooltipText: ""


  // Accepted so a use of Omarchy's control can switch to this one by name;
  // the kit draws its own colours, border and type.
  property bool bordered: true
  property color foreground: "white"
  property color accent: "white"
  property string fontFamily: ""
  property real fontSize: 0
  property bool leftAlign: false

  signal clicked()

  readonly property bool hot: mouse.containsMouse || hasCursor
  readonly property real padX: compact ? 10 : 14
  readonly property real padY: compact ? 5 : 7

  implicitWidth: row.implicitWidth + padX * 2
  implicitHeight: row.implicitHeight + padY * 2
  opacity: enabled ? 1 : 0.4

  Rectangle {
    id: body
    anchors.fill: parent
    radius: button.design.rounding <= 0 ? 0 : button.design.controlRadius
    color: button.selected ? (button.soft ? button.design.accentSoft : button.design.accent) : button.hot ? button.design.hover : button.design.raised
    border.width: button.selected && !button.soft ? 0 : 1
    border.color: button.danger ? "#d0485f" : (button.hasCursor || (button.soft && button.selected)) ? button.design.alpha(button.design.accent, 0.5) : button.design.hairline
    Behavior on color { ColorAnimation { duration: 160 } }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: Math.max(0, parent.radius - 1)
      visible: !button.selected || button.soft
      gradient: Gradient {
        GradientStop { position: 0; color: button.design.sheen }
        GradientStop { position: 0.55; color: "transparent" }
      }
    }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 7
    Text {
      visible: text !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: button.iconText
      color: label.color
      font.family: button.design.mono
      font.pixelSize: button.compact ? 13 : 14
    }
    Text {
      id: label
      visible: text !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: button.text
      color: button.selected ? (button.soft ? button.design.accent : button.design.onAccent) : button.danger ? "#d0485f" : button.design.foreground
      font.family: button.design.sans
      font.pixelSize: button.compact ? 13 : 14
      font.weight: Font.Medium
    }
  }

  // Squash on press (wider, flatter), then a jelly spring back to shape.
  transform: Scale {
    origin.x: button.width / 2
    origin.y: button.height / 2
    xScale: mouse.pressed ? 1.05 : 1
    yScale: mouse.pressed ? 0.88 : 1
    Behavior on xScale { enabled: button.design.motion; SpringAnimation { spring: 5; damping: 0.13; mass: button.design.mass } }
    Behavior on yScale { enabled: button.design.motion; SpringAnimation { spring: 5; damping: 0.13; mass: button.design.mass } }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: button.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
