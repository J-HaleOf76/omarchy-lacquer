import QtQuick

// A set of tabs or choices drawn as one continuous body of goo, the selected
// one a thicker bulge of accent that oozes along inside it.
//
//   style "rail"      a column: Home and the main tabs
//   style "pills"     a row: sub tabs
//   style "underline" a thin strand under a row of words, the selection a drop
//                     hanging from it: the pages of a sub tab
//   style "chips"     choices that wrap onto more lines, one strand per line
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
  // The panel's slow clock, while someone is using Lacquer: the selection
  // swells and settles with it.
  property real breath: 0
  // The rail's own small drip; off when something else catches the drop.
  property bool dripEnabled: true

  // Where the selected option sits, in this item's coordinates.
  function selectedCell() { return goo.cells[selectedIndex] || null }

  // Accepted from Omarchy's ButtonGroup; the kit draws its own colours and type.
  property color foreground: "white"
  property color accent: "white"
  property string fontFamily: ""
  property bool focusable: false

  signal changed(string value)

  readonly property bool isRail: style === "rail"
  readonly property bool isUnderline: style === "underline"
  // Overridable, so a row of tabs can be made to carry more weight.
  property real padX: isRail ? 14 : isUnderline ? 6 : 14
  property real padY: isRail ? 9 : isUnderline ? 7 : 7

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object" && o.label !== undefined) ? String(o.label) : String(o) }
  function optionIcon(o) { return (o && typeof o === "object" && o.icon) ? String(o.icon) : "" }
  function optionFamily(o) { return (o && typeof o === "object" && o.family) ? String(o.family) : design.serif }
  // An entry can carry more weight than the rest, and have a rule under it.
  function optionBig(o) { return !!(o && typeof o === "object" && o.big) }
  function optionRule(o) { return !!(o && typeof o === "object" && o.rule) }

  readonly property int selectedIndex: {
    for (var i = 0; i < options.length; i++) if (optionValue(options[i]) === value) return i
    return -1
  }
  property int hoveredIndex: -1

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
  implicitWidth: isRail ? 186 : naturalWidth
  implicitHeight: flow.implicitHeight + (isUnderline ? 8 : 0)

  // Where each option sits, for the goo to be drawn around.
  function placeCells() {
    var out = []
    for (var i = 0; i < repeater.count; i++) {
      var it = repeater.itemAt(i)
      if (!it) { out.push(null); continue }
      var p = it.mapToItem(tabs, 0, 0)
      out.push(Qt.rect(p.x, p.y, it.width, it.cellHeight !== undefined ? it.cellHeight : it.height))
    }
    goo.cells = out
  }
  onWidthChanged: Qt.callLater(placeCells)
  onOptionsChanged: Qt.callLater(placeCells)
  onSelectedIndexChanged: if (isRail && design.motion && dripEnabled) dripTimer.restart()

  GooTrack {
    id: goo
    z: 1
    vertical: tabs.isRail
    mode: tabs.isUnderline ? "line" : "body"
    selected: tabs.selectedIndex
    hovered: tabs.hoveredIndex
    bodyColor: tabs.isUnderline ? tabs.design.rule : tabs.design.surface
    bulgeColor: tabs.design.accent
    animated: tabs.design.motion
    mass: tabs.design.mass
    breath: tabs.breath
    swell: tabs.isRail ? 2 : 3
    maxRadius: tabs.design.controlRadius
  }

  // On the rail, a small drop gathers under the selection once it arrives and
  // falls away, slowly.
  GooBlob {
    id: drip
    z: 1
    visible: tabs.isRail && tabs.design.motion && tabs.dripEnabled
    color: tabs.design.accent
    radius: 2
    mass: tabs.design.mass * 1.1
    gooiness: 0.5
    opacity: 0
  }
  Timer {
    id: dripTimer
    interval: Math.round(300 * tabs.design.mass)
    onTriggered: {
      var r = goo.cells[tabs.selectedIndex]
      if (!r) return
      var cx = r.x + r.width * 0.5
      drip.opacity = 0.5
      drip.jump(Qt.rect(cx - 8, r.y + r.height - 6, 16, 8))
      drip.target = Qt.rect(cx - 3.5, r.y + r.height + 14, 7, 7)
      dripFade.restart()
    }
  }
  NumberAnimation { id: dripFade; target: drip; property: "opacity"; from: 0.5; to: 0; duration: Math.round(700 * tabs.design.mass); easing.type: Easing.InQuad }

  Flow {
    id: flow
    z: 2
    width: tabs.width
    spacing: tabs.isRail ? 2 : tabs.isUnderline ? 10 : 0
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
      readonly property bool big: tabs.optionBig(modelData)
      readonly property bool ruled: tabs.optionRule(modelData)
      // The entry itself, and under it the band the rule sits in. The ink
      // block covers the entry only, so block and rule line up.
      readonly property real cellHeight: content.implicitHeight + tabs.padY * 2 + (big ? 8 : 0)
      readonly property real ruleBand: ruled ? 15 : 0
      width: tabs.isRail ? flow.width : content.implicitWidth + tabs.padX * 2
      height: cellHeight + ruleBand

      Rectangle {
        visible: entry.ruled
        x: 0
        y: entry.cellHeight + Math.round(entry.ruleBand / 2)
        width: parent.width
        height: 1
        color: tabs.design.rule
      }
      onWidthChanged: { Qt.callLater(tabs.measure); Qt.callLater(tabs.placeCells) }
      onXChanged: Qt.callLater(tabs.placeCells)
      onYChanged: Qt.callLater(tabs.placeCells)
      Component.onCompleted: { Qt.callLater(tabs.measure); Qt.callLater(tabs.placeCells) }

      // The keyboard cursor: a soft ring, as round as everything else.
      Rectangle {
        x: -2
        y: -2
        width: parent.width + 4
        height: entry.cellHeight + 4
        visible: index === tabs.cursorIndex
        color: "transparent"
        radius: tabs.design.controlRadius
        border.width: 1
        border.color: tabs.design.accent
      }

      Row {
        id: content
        x: tabs.padX
        y: Math.round((entry.cellHeight - height) / 2)
        spacing: 9
        Text {
          visible: text !== ""
          anchors.verticalCenter: parent.verticalCenter
          text: tabs.optionIcon(entry.modelData)
          color: label.color
          font.family: tabs.design.mono
          font.pixelSize: Math.round(tabs.fontSize + (entry.big ? 4 : 1))
        }
        Text {
          id: label
          anchors.verticalCenter: parent.verticalCenter
          text: tabs.optionLabel(entry.modelData)
          font.family: tabs.optionFamily(entry.modelData)
          font.pixelSize: Math.round(tabs.fontSize + (entry.big ? 3 : 0))
          font.weight: entry.selected || entry.big ? Font.DemiBold : Font.Normal
          color: entry.selected && !tabs.isUnderline ? tabs.design.onAccent
               : entry.selected ? tabs.design.accent
               : entry.hot ? tabs.design.foreground : tabs.design.muted
          Behavior on color { ColorAnimation { duration: 160 } }
        }
      }

      MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
          if (containsMouse) tabs.hoveredIndex = entry.index
          else if (tabs.hoveredIndex === entry.index) tabs.hoveredIndex = -1
        }
        onClicked: {
          var v = tabs.optionValue(entry.modelData)
          if (v !== tabs.value) tabs.changed(v)
        }
      }
    }
  }
}
