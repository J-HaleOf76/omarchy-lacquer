import QtQuick

// A raised surface with a sheen along its top edge — the lacquer. Content goes
// inside, padded; the card is as tall as what it holds.
Item {
  id: card

  required property var design
  property real padding: 16
  property bool active: false
  // Under the pointer: it rises a little on a spring and its shadow deepens.
  property bool lifted: false
  property real lift: lifted ? 1 : 0
  Behavior on lift { enabled: card.design.motion; SpringAnimation { spring: 3.5; damping: 0.2; mass: card.design.mass } }
  default property alias content: inner.data

  implicitHeight: inner.childrenRect.height + padding * 2

  // A soft shadow, one step down.
  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 2 + card.lift * 2
    anchors.bottomMargin: -2 - card.lift * 3
    radius: body.radius
    color: card.design.shade
    opacity: 0.8 + card.lift * 0.4
  }

  Rectangle {
    id: body
    anchors.fill: parent
    anchors.topMargin: -card.lift * 2
    anchors.bottomMargin: card.lift * 2
    radius: card.design.cardRadius
    color: card.design.raised
    border.width: 1
    border.color: card.active ? card.design.alpha(card.design.accent, 0.55) : card.design.hairline
    Behavior on border.color { ColorAnimation { duration: 200 } }

    // The sheen: light pooled along the top, fading out a third of the way down.
    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: Math.max(0, parent.radius - 1)
      gradient: Gradient {
        GradientStop { position: 0; color: card.design.sheen }
        GradientStop { position: 0.34; color: "transparent" }
      }
    }
  }

  Item {
    id: inner
    x: card.padding
    y: card.padding - card.lift * 2
    width: card.width - card.padding * 2
    height: childrenRect.height
  }
}
