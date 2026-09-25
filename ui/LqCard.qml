import QtQuick

// A group of settings on the printed page: a hairline rule across the top and
// room underneath. No fill, no shadow — the rule and the space do the work a
// box used to do.
Item {
  id: card

  required property var design
  property real padding: 16
  property bool active: false
  // Kept so pages can still say a card is under the pointer; nothing rises.
  property bool lifted: false
  // The first group on a page sets this false: a rule directly under the page
  // tabs is one line too many.
  property bool ruled: true
  default property alias content: inner.data

  implicitHeight: inner.childrenRect.height + padding * 1.6

  Rectangle {
    visible: card.ruled
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: 1
    color: card.active ? card.design.accent : card.design.rule
    Behavior on color { ColorAnimation { duration: 200 } }
  }

  Item {
    id: inner
    x: 0
    y: card.padding
    width: card.width
    height: childrenRect.height
  }
}
