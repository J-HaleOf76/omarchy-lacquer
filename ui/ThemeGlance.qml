import QtQuick

// The theme you are on, at a glance: a little picture of it, its name, its
// colours as drops of goo, and what the shuffle will do next. Clicking it goes
// to Themes.
Item {
  id: glance

  required property var design
  // { display, mode, preview, colors, accent } from the theme store.
  property var theme: ({})
  property string note: ""

  signal clicked()

  implicitHeight: column.implicitHeight + 20

  readonly property var dots: {
    var out = []
    var raw = [theme.accent].concat(theme.colors || [])
    for (var i = 0; i < raw.length && out.length < 6; i++) {
      var c = String(raw[i] || "")
      if (c && out.indexOf(c) < 0) out.push(c)
    }
    return out
  }

  Rectangle {
    anchors.fill: parent
    radius: glance.design.cardRadius
    color: mouse.containsMouse ? glance.design.hover : glance.design.surface
    Behavior on color { ColorAnimation { duration: 160 } }
  }

  Column {
    id: column
    x: 10
    y: 10
    width: glance.width - 20
    spacing: 8

    Rectangle {
      width: parent.width
      height: Math.round(width * 9 / 16)
      radius: glance.design.cardRadius - 6
      color: glance.design.raised
      clip: true
      Image {
        anchors.fill: parent
        visible: !!glance.theme.preview
        source: glance.theme.preview ? "file://" + encodeURI(glance.theme.preview) : ""
        sourceSize.width: 320
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
      }
    }

    Text {
      width: parent.width
      text: glance.theme.display || ""
      elide: Text.ElideRight
      color: glance.design.foreground
      font.family: glance.design.sans
      font.pixelSize: 14
      font.weight: Font.Medium
    }

    // The colours as little drops, heavier at the bottom.
    Row {
      spacing: 5
      Repeater {
        model: glance.dots
        Rectangle {
          required property var modelData
          width: 11
          height: 13
          radius: 5.5
          bottomLeftRadius: 5.5
          bottomRightRadius: 5.5
          topLeftRadius: 5.5
          topRightRadius: 5.5
          color: modelData
          border.width: 1
          border.color: glance.design.hairline
        }
      }
    }

    Text {
      visible: text !== ""
      width: parent.width
      text: glance.note
      wrapMode: Text.WordWrap
      color: glance.design.muted
      font.family: glance.design.sans
      font.pixelSize: 12
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: glance.clicked()
  }
}
