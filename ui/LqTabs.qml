import QtQuick

// A set of tabs with a blob of accent that oozes from one to the next.
//
//   style "rail"      a column, the selected entry a filled pill
//   style "pills"     a row on a sunken track, the selected entry a filled pill
//   style "underline" a row of words, a short drop of accent under the selected one
//   style "chips"     wrapping choices on a sunken track (the settings' options)
//
// options: [{ value, label, icon, family }] or plain strings.
Item {
  id: tabs

  required property var design
  property var options: []
  property string value: ""
  property string style: "pills"
  property real fontSize: 14
  // A keyboard cursor, drawn as a ring, for panels that drive one.
  property int cursorIndex: -1

  // Accepted from Omarchy's ButtonGroup; the kit draws its own colours and type.
  property color foreground: "white"
  property color accent: "white"
  property string fontFamily: ""
  property bool focusable: false

  signal changed(string value)

  readonly property bool isRail: style === "rail"
  readonly property bool isUnderline: style === "underline"
  readonly property bool onTrack: style === "pills" || style === "chips"
  readonly property real padX: isRail ? 12 : isUnderline ? 4 : 13
  readonly property real padY: isRail ? 9 : isUnderline ? 6 : 7
  readonly property real inset: onTrack ? 3 : 0

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o) }
  function optionIcon(o) { return (o && typeof o === "object" && o.icon) ? String(o.icon) : "" }
  function optionFamily(o) { return (o && typeof o === "object" && o.family) ? String(o.family) : design.sans }

  readonly property int selectedIndex: {
    for (var i = 0; i < options.length; i++) if (optionValue(options[i]) === value) return i
    return -1
  }

  // A row's natural width is its entries side by side; it only wraps when
  // it is given less than that.
  property real naturalWidth: 0
  function measure() {
    var w = 0, n = 0
    for (var i = 0; i < repeater.count; i++) {
      var it = repeater.itemAt(i)
      if (it) { w += it.width; n++ }
    }
    naturalWidth = w + Math.max(0, n - 1) * flow.spacing
  }
  implicitWidth: isRail ? 128 : naturalWidth + inset * 2
  implicitHeight: flow.implicitHeight + inset * 2

  // Where the blob should sit: over the selected entry, or as a drop of ink
  // under it.
  function placeBlob() {
    var item = repeater.itemAt(selectedIndex)
    if (!item) { blob.target = Qt.rect(blob.target.x, blob.target.y, 0, 0); return }
    var p = item.mapToItem(tabs, 0, 0)
    if (isUnderline) {
      var w = Math.max(10, item.width * 0.42)
      blob.target = Qt.rect(p.x + (item.width - w) / 2, p.y + item.height - 2, w, 3)
    } else {
      blob.target = Qt.rect(p.x, p.y, item.width, item.height)
    }
  }
  onSelectedIndexChanged: {
    Qt.callLater(placeBlob)
    if (isRail && design.motion) dripTimer.restart()
  }
  onWidthChanged: Qt.callLater(placeBlob)
  onOptionsChanged: Qt.callLater(placeBlob)

  // The sunken track under pills and chips.
  Rectangle {
    visible: tabs.onTrack
    anchors.fill: parent
    radius: tabs.design.rounding <= 0 ? 0 : tabs.design.controlRadius + tabs.inset
    color: tabs.design.surface
    border.width: 1
    border.color: tabs.design.hairline
  }

  GooBlob {
    id: blob
    z: 1
    color: tabs.design.accent
    radius: tabs.isUnderline ? 1.5 : (tabs.design.rounding <= 0 ? 0 : tabs.design.controlRadius)
    animated: tabs.design.motion
    mass: tabs.design.mass
  }

  // On the rail, a drop of accent falls from the blob once it has landed:
  // it starts stuck to the bottom of the pill, stretches a neck as it pulls
  // away — the trailing edge is the slow one — and fades as it falls.
  GooBlob {
    id: drip
    z: 1
    visible: tabs.isRail && tabs.design.motion
    color: tabs.design.accent
    radius: 5
    mass: tabs.design.mass * 1.3
    opacity: 0
  }
  Timer {
    id: dripTimer
    interval: Math.round(300 * tabs.design.mass)
    onTriggered: {
      var b = blob.target
      if (b.width <= 0) return
      var cx = b.x + b.width * 0.5
      drip.opacity = 1
      drip.jump(Qt.rect(cx - 9, b.y + b.height - 10, 18, 10))
      drip.target = Qt.rect(cx - 5, b.y + b.height + 36, 10, 11)
      dripFade.restart()
    }
  }
  NumberAnimation { id: dripFade; target: drip; property: "opacity"; from: 1; to: 0; duration: Math.round(820 * tabs.design.mass); easing.type: Easing.InCubic }

  Flow {
    id: flow
    z: 2
    x: tabs.inset
    y: tabs.inset
    width: tabs.width - tabs.inset * 2
    spacing: tabs.isRail ? 4 : tabs.isUnderline ? 14 : 2
    Repeater {
      id: repeater
      model: tabs.options
      delegate: tabDelegate
    }
  }

  Component {
    id: tabDelegate
    Item {
      id: entry
      required property var modelData
      required property int index
      readonly property bool selected: index === tabs.selectedIndex
      readonly property bool hot: mouse.containsMouse || index === tabs.cursorIndex
      width: tabs.isRail ? flow.width : content.implicitWidth + tabs.padX * 2
      height: content.implicitHeight + tabs.padY * 2
      z: 2
      onWidthChanged: Qt.callLater(tabs.measure)
      onXChanged: Qt.callLater(tabs.placeBlob)
      onYChanged: Qt.callLater(tabs.placeBlob)
      Component.onCompleted: { Qt.callLater(tabs.measure); Qt.callLater(tabs.placeBlob) }

      // A faint hover fill, under the blob.
      Rectangle {
        anchors.fill: parent
        visible: !tabs.isUnderline
        radius: tabs.design.rounding <= 0 ? 0 : tabs.design.controlRadius
        color: tabs.design.hover
        opacity: entry.hot && !entry.selected ? 1 : 0
        z: -1
        Behavior on opacity { NumberAnimation { duration: 140 } }
      }

      // The keyboard cursor.
      Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        visible: index === tabs.cursorIndex
        color: "transparent"
        radius: tabs.design.rounding <= 0 ? 0 : tabs.design.controlRadius + 2
        border.width: 1.5
        border.color: tabs.design.accent
      }

      Row {
        id: content
        x: tabs.padX
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9
        Text {
          visible: text !== ""
          anchors.verticalCenter: parent.verticalCenter
          text: tabs.optionIcon(entry.modelData)
          color: label.color
          font.family: tabs.design.mono
          font.pixelSize: Math.round(tabs.fontSize + 1)
        }
        Text {
          id: label
          anchors.verticalCenter: parent.verticalCenter
          text: tabs.optionLabel(entry.modelData)
          font.family: tabs.optionFamily(entry.modelData)
          font.pixelSize: Math.round(tabs.fontSize)
          font.weight: entry.selected ? Font.DemiBold : Font.Normal
          color: entry.selected && !tabs.isUnderline ? tabs.design.onAccent
               : entry.selected ? tabs.design.accent
               : entry.hot ? tabs.design.foreground : tabs.design.muted
          Behavior on color { ColorAnimation { duration: 180 } }
        }
      }

      // A small squish under the finger, then a jelly spring back.
      scale: mouse.pressed ? 0.94 : 1
      Behavior on scale { enabled: tabs.design.motion; SpringAnimation { spring: 4; damping: 0.18; mass: tabs.design.mass } }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          var v = tabs.optionValue(entry.modelData)
          if (v !== tabs.value) tabs.changed(v)
        }
      }
    }
  }
}
