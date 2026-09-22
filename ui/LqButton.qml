import QtQuick

// An action: a round, flat pill.
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

  Rectangle {
    id: body
    anchors.fill: parent
    radius: height / 2
    color: button.selected ? (button.soft ? button.design.accentSoft : button.design.accent) : button.hot ? button.design.hover : button.design.raised
    border.width: button.selected && !button.soft ? 0 : 1
    border.color: button.danger ? "#d0485f" : (button.hasCursor || (button.soft && button.selected)) ? button.design.alpha(button.design.accent, 0.5) : button.design.hairline
    Behavior on color { ColorAnimation { duration: 160 } }
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

  // A press darkens it for a moment rather than squashing it.
  opacity: enabled ? (mouse.pressed ? 0.8 : 1) : 0.4
  Behavior on opacity { NumberAnimation { duration: 120 } }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: button.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: button.clicked()
  }
}
