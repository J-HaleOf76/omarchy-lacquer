import QtQuick
import qs.Commons
import qs.Ui
import "../ui"

// A scrollable column of choice groups, shared by the Desktop sections.
//
// Each entry in `groups` describes one group:
//   { id, title, note, kind: "chips" | "icons" | "fonts" | "stepper",
//     options: [{ value, label, sub, icons, family }], current,
//     pinned, pinnedText, unpinLabel, pick(value), unpin(),
//     value, unit, step(delta), reset(), resetLabel }
// Keyboard: up/down moves between groups (and through a font list), left/right
// moves along a group or steps a stepper, Enter picks.
Item {
  id: pane

  required property var app
  readonly property var design: app.design
  property var groups: []

  // A pair of on/off choices is really a switch.
  function isSwitch(g) {
    if (!g || g.kind !== "chips" || !g.options || g.options.length !== 2) return false
    var a = String(g.options[0].value), b = String(g.options[1].value)
    return (a === "on" && b === "off") || (a === "off" && b === "on") || (a === "true" && b === "false") || (a === "false" && b === "true")
  }
  function switchOn(g) { return g.current === "on" || g.current === "true" }
  function flip(g) {
    var want = pane.switchOn(g) ? (g.options[0].value === "on" || g.options[1].value === "on" ? "off" : "false")
                                : (g.options[0].value === "on" || g.options[1].value === "on" ? "on" : "true")
    if (g.pick) g.pick(want)
  }
  // A stepper whose page says its range becomes a slider.
  function isSlider(g) { return g && g.kind === "stepper" && g.min !== undefined && g.max !== undefined && g.num !== undefined }
  // The groups binding can be briefly undefined while the section builds.
  readonly property var list: Array.isArray(groups) ? groups : []

  property int cursorGroup: 0
  property int cursorOption: 0
  property string filterText: ""

  function optionsOf(g) {
    if (!g) return []
    if (g.kind !== "fonts" || pane.filterText === "") return g.options || []
    var needle = pane.filterText.toLowerCase()
    return (g.options || []).filter(function(o) { return String(o.label).toLowerCase().indexOf(needle) !== -1 })
  }

  function currentIndex(g) {
    var opts = optionsOf(g)
    for (var i = 0; i < opts.length; i++) if (opts[i].value === g.current) return i
    return 0
  }

  function enterGroup(index, fromBelow) {
    pane.cursorGroup = Math.max(0, Math.min(pane.list.length - 1, index))
    var g = pane.list[pane.cursorGroup]
    var opts = optionsOf(g)
    if (g && g.kind === "fonts" && opts.length > 0)
      pane.cursorOption = fromBelow ? opts.length - 1 : currentIndex(g)
    else pane.cursorOption = currentIndex(g)
    Qt.callLater(pane.reveal)
  }

  function moveBy(dx, dy) {
    if (pane.list.length === 0) return
    pane.wantTitle = ""
    var g = pane.list[pane.cursorGroup]
    var opts = optionsOf(g)
    if (dx !== 0) {
      if (g.kind === "stepper") { if (g.step) g.step(dx) }
      else if (g.kind !== "fonts") pane.cursorOption = Math.max(0, Math.min(opts.length - 1, pane.cursorOption + dx))
      Qt.callLater(pane.reveal)
      return
    }
    if (g.kind === "fonts") {
      var next = pane.cursorOption + dy
      if (next >= 0 && next < opts.length) { pane.cursorOption = next; Qt.callLater(pane.reveal); return }
    }
    var target = pane.cursorGroup + dy
    if (target < 0 || target >= pane.list.length) return
    enterGroup(target, dy < 0)
  }

  function activate() {
    var g = pane.list[pane.cursorGroup]
    if (!g) return
    // A stray Enter should never throw away a size someone dialled in.
    if (g.kind === "stepper") return
    // A line of text is typed into, not picked from: Enter puts the caret in it.
    if (g.kind === "text") { focusText(pane.cursorGroup); return }
    var opts = optionsOf(g)
    var o = opts[pane.cursorOption]
    if (o && g.pick) g.pick(o.value)
  }

  // Search on Home lands here with a group title to put the cursor on.
  // A group the page was asked to open on, from a search result. It is kept
  // rather than acted on once: the groups are rebuilt as the store finishes
  // rescanning, and every rebuild used to throw the page back to the top.
  property string wantTitle: ""

  function focusGroupTitle(title) {
    pane.wantTitle = String(title || "")
    return honourWanted()
  }

  function focusText(index) {
    var item = groupRepeater.itemAt(index)
    if (item && item.textField) item.textField.forceActiveFocus()
  }

  function honourWanted() {
    if (pane.wantTitle === "") return false
    for (var i = 0; i < pane.list.length; i++) {
      if (pane.list[i].title !== pane.wantTitle) continue
      enterGroup(i, false)
      return true
    }
    return false
  }

  function clearPin() {
    var g = pane.list[pane.cursorGroup]
    if (g && g.pinned && g.unpin) g.unpin()
  }

  function reveal() {
    var item = groupRepeater.itemAt(pane.cursorGroup)
    if (!item) return
    // Show the whole group; a group taller than the view shows from its top.
    var top = item.y
    var bottom = Math.min(item.y + item.height, top + flick.height)
    if (top < flick.contentY) flick.contentY = Math.max(0, top)
    else if (bottom > flick.contentY + flick.height)
      flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), bottom - flick.height)
  }

  signal cascadeRequested()

  function reset() { pane.filterText = ""; pane.seenCount = 0; pane.wantTitle = ""; enterGroup(0, false); flick.contentY = 0; cascadeRequested() }

  onVisibleChanged: if (visible) reset()
  // Groups often arrive after the pane is shown; the first real set places the
  // cursor on the current choice rather than wherever an empty list left it.
  property int seenCount: 0
  onListChanged: {
    var first = pane.seenCount === 0 && pane.list.length > 0
    pane.seenCount = pane.list.length
    if (honourWanted()) return
    if (first || pane.cursorGroup < 0 || pane.cursorGroup >= pane.list.length) enterGroup(0, false)
  }

  Flickable {
    id: flick
    anchors.fill: parent
    clip: true
    contentWidth: width
    contentHeight: column.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: column
      // A printed page keeps a margin: the column never runs the full width.
      width: Math.min(flick.width - Style.spacing.xxl * 2, pane.design.columnWidth)
      x: Math.max(Style.spacing.xxl, (flick.width - width) / 2)
      spacing: 26

      Repeater {
        id: groupRepeater
        // A count, not the array: the groups are rebuilt on every value change,
        // and an array model would tear down every delegate (and the font
        // list's scroll position) each time.
        model: pane.list.length

        LqCard {
          id: groupItem
          required property int index
          readonly property var modelData: pane.list[index] || ({})
          readonly property bool groupHasCursor: index === pane.cursorGroup
          readonly property var shown: pane.optionsOf(modelData)
          // The note opens when the card is hovered for a moment, or when the
          // keyboard is on it; otherwise the page is just titles and controls.
          property bool lingering: false
          readonly property bool open: groupHasCursor || lingering || modelData.noteAlways === true

          design: pane.design
          ruled: index > 0
          active: groupHasCursor
          // So Enter on this group can put the caret in the field.
          property alias textField: groupTextField
          width: column.width
          padding: 14

          HoverHandler {
            id: cardHover
            onHoveredChanged: hovered ? lingerTimer.restart() : (lingerTimer.stop(), groupItem.lingering = false)
          }
          Timer { id: lingerTimer; interval: 120; onTriggered: groupItem.lingering = true }

          // Cards settle in one after another, sinking slowly into place.
          property real appear: 1
          opacity: Math.min(1, appear * 1.6)
          lifted: cardHover.hovered
          transform: Translate { y: (1 - groupItem.appear) * 10 }
          Connections {
            target: pane
            function onCascadeRequested() {
              if (!pane.app.motion || groupItem.index > 10) return
              groupItem.appear = 0
              groupCascade.restart()
            }
          }
          SequentialAnimation {
            id: groupCascade
            PauseAnimation { duration: 20 + groupItem.index * 30 }
            NumberAnimation { target: groupItem; property: "appear"; to: 1; duration: Math.round(340 * pane.design.mass); easing.type: Easing.OutQuint }
          }

          Column {
          id: groupBody
          width: parent.width
          spacing: 14

          Item {
            width: parent.width
            height: Math.max(titleText.implicitHeight, pinChip.visible ? pinChip.implicitHeight : 0,
                             titleSwitch.visible ? titleSwitch.height : 0)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8
              Text {
                id: titleText
                anchors.verticalCenter: parent.verticalCenter
                text: groupItem.modelData.title || ""
                color: groupItem.groupHasCursor ? pane.design.accent : pane.design.ink
                font.family: pane.design.serif
                font.pixelSize: 17
                Behavior on color { ColorAnimation { duration: 180 } }
              }
            }

            LqSwitch {
              id: titleSwitch
              visible: pane.isSwitch(groupItem.modelData)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              design: pane.design
              checked: visible && pane.switchOn(groupItem.modelData)
              hasCursor: groupItem.groupHasCursor
              onToggled: {
                pane.cursorGroup = groupItem.index
                pane.flip(groupItem.modelData)
              }
            }

            Row {
              id: pinChip
              visible: groupItem.modelData.pinned === true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: groupItem.modelData.pinnedText || "pinned — overrides theme"
                color: pane.design.accent
                font.family: pane.design.sans
                font.pixelSize: 13
              }
              LqButton {
                design: pane.design
                compact: true
                text: groupItem.modelData.unpinLabel || "Follow theme"
                onClicked: if (groupItem.modelData.unpin) groupItem.modelData.unpin()
              }
            }
          }

          Item {
            width: parent.width
            height: groupItem.open && !!groupItem.modelData.note ? noteText.implicitHeight + (groupItem.modelData.tech ? 18 : 0) : 0
            visible: height > 0.5
            clip: true
            Behavior on height { enabled: pane.design.motion; NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Text {
              id: noteText
              width: parent.width
              wrapMode: Text.WordWrap
              text: groupItem.modelData.note || ""
              color: pane.design.muted
              font.family: pane.design.sans
              font.pixelSize: 13
              lineHeight: 1.15
              opacity: groupItem.open ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 120 } }
            }
            // The real name, in small print, for anyone following a guide.
            Text {
              anchors.top: noteText.bottom
              anchors.topMargin: 4
              visible: !!groupItem.modelData.tech
              width: parent.width
              text: groupItem.modelData.tech || ""
              color: pane.design.faint
              font.family: pane.design.mono
              font.pixelSize: 11
              elide: Text.ElideRight
              opacity: groupItem.open ? 1 : 0
            }
          }

          // ------------------------------------------------ chips
          LqTabs {
            visible: groupItem.modelData.kind === "chips" && !pane.isSwitch(groupItem.modelData)
            width: Math.min(implicitWidth, parent.width)
            design: pane.design
            style: "chips"
            fontSize: 13.5
            options: {
              if (!visible) return []
              var out = []
              for (var i = 0; i < groupItem.shown.length; i++) {
                var o = groupItem.shown[i]
                out.push({ value: String(o.value), label: o.label, family: groupItem.modelData.id === "mono" ? o.value : "" })
              }
              return out
            }
            value: groupItem.modelData.current === undefined ? "" : String(groupItem.modelData.current)
            cursorIndex: groupItem.groupHasCursor ? pane.cursorOption : -1
            onChanged: function(v) {
              pane.cursorGroup = groupItem.index
              for (var i = 0; i < groupItem.shown.length; i++) {
                if (String(groupItem.shown[i].value) !== v) continue
                pane.cursorOption = i
                if (groupItem.modelData.pick) groupItem.modelData.pick(groupItem.shown[i].value)
                return
              }
            }
          }

          // ------------------------------------------------ stepper
          LqSlider {
            visible: pane.isSlider(groupItem.modelData)
            width: Math.min(parent.width, 460)
            design: pane.design
            value: visible ? Number(groupItem.modelData.num) : 0
            from: visible ? Number(groupItem.modelData.min) : 0
            to: visible ? Number(groupItem.modelData.max) : 1
            stepSize: groupItem.modelData.stepSize || 1
            hasCursor: groupItem.groupHasCursor
            format: function(v) {
              var g = groupItem.modelData
              if (g.format) return g.format(v)
              return (Math.round(v * 100) / 100) + (g.unit ? " " + g.unit : "")
            }
            onCommitted: function(v) {
              var g = groupItem.modelData
              pane.cursorGroup = groupItem.index
              var steps = Math.round((v - Number(g.num)) / (g.stepSize || 1))
              if (steps !== 0 && g.step) g.step(steps)
            }
            onStepped: function(d) { pane.cursorGroup = groupItem.index; if (groupItem.modelData.step) groupItem.modelData.step(d) }
          }

          Row {
            visible: groupItem.modelData.kind === "stepper" && !pane.isSlider(groupItem.modelData)
            spacing: 10
            LqButton {
              design: pane.design
              text: "−"
              hasCursor: groupItem.groupHasCursor
              onClicked: { pane.cursorGroup = groupItem.index; if (groupItem.modelData.step) groupItem.modelData.step(-1) }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(76)
              horizontalAlignment: Text.AlignHCenter
              text: String(groupItem.modelData.value === undefined ? "" : groupItem.modelData.value) + " " + (groupItem.modelData.unit || "")
              color: pane.design.foreground
              font.family: pane.design.mono
              font.pixelSize: 14
              font.weight: Font.Medium
            }
            LqButton {
              design: pane.design
              text: "+"
              hasCursor: groupItem.groupHasCursor
              onClicked: { pane.cursorGroup = groupItem.index; if (groupItem.modelData.step) groupItem.modelData.step(1) }
            }
            LqButton {
              visible: !!groupItem.modelData.reset
              design: pane.design
              compact: true
              text: groupItem.modelData.resetLabel || "Reset"
              anchors.verticalCenter: parent.verticalCenter
              onClicked: groupItem.modelData.reset()
            }
          }

          // The reset beside a slider.
          LqButton {
            visible: pane.isSlider(groupItem.modelData) && !!groupItem.modelData.reset
            design: pane.design
            compact: true
            text: groupItem.modelData.resetLabel || "Reset"
            onClicked: groupItem.modelData.reset()
          }

          // ------------------------------------------------ icon themes
          Flow {
            visible: groupItem.modelData.kind === "icons"
            width: parent.width
            spacing: Style.spacing.md
            Repeater {
              model: groupItem.modelData.kind === "icons" ? groupItem.shown : []
              CursorSurface {
                id: tile
                required property var modelData
                required property int index
                width: Style.space(196)
                height: tileColumn.implicitHeight + Style.spacing.lg * 2
                radius: (app.design.cardRadius * 0.75)
                bordered: true
                current: modelData.value === groupItem.modelData.current
                hasCursor: groupItem.groupHasCursor && index === pane.cursorOption
                foreground: pane.app.foreground
                accent: pane.app.accent

                Column {
                  id: tileColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.spacing.lg
                  spacing: Style.spacing.sm

                  Row {
                    spacing: Style.spacing.xs
                    height: Style.space(26)
                    Repeater {
                      model: tile.modelData.icons || []
                      Image {
                        required property var modelData
                        width: Style.space(26)
                        height: Style.space(26)
                        source: "file://" + encodeURI(modelData)
                        sourceSize.width: 52
                        sourceSize.height: 52
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                      }
                    }
                  }
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: tile.modelData.label
                    color: pane.app.foreground
                    font.family: pane.app.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    pane.cursorGroup = groupItem.index
                    pane.cursorOption = tile.index
                    if (groupItem.modelData.pick) groupItem.modelData.pick(tile.modelData.value)
                  }
                }
              }
            }
          }

          // ------------------------------------------------ art preview
          Rectangle {
            visible: groupItem.modelData.kind === "art"
            width: parent.width
            height: visible ? Math.min(Style.space(180), artText.implicitHeight + Style.spacing.lg * 2) : 0
            radius: (app.design.cardRadius * 0.75)
            color: Qt.rgba(0, 0, 0, 0.85)
            clip: true
            Text {
              id: artText
              anchors.centerIn: parent
              text: groupItem.modelData.kind === "art" ? String(groupItem.modelData.art || "") : ""
              color: "#e8e8e8"
              textFormat: Text.PlainText
              font.family: "monospace"
              // Shrink tall art to fit the box rather than cropping it.
              readonly property int artLines: Math.max(1, text.split("\n").length)
              font.pixelSize: Math.max(3, Math.min(Math.round(Style.space(7)), Math.floor((Style.space(180) - Style.spacing.lg * 2) / (artLines * 0.95))))
              lineHeight: 0.95
            }
          }
          Flow {
            visible: groupItem.modelData.kind === "art"
            width: parent.width
            spacing: Style.spacing.xs
            Repeater {
              model: groupItem.modelData.kind === "art" ? groupItem.shown : []
              LqButton {
                required property var modelData
                required property int index
                design: pane.design
                text: modelData.label
                hasCursor: groupItem.groupHasCursor && index === pane.cursorOption
                onClicked: {
                  pane.cursorGroup = groupItem.index
                  pane.cursorOption = index
                  if (groupItem.modelData.pick) groupItem.modelData.pick(modelData.value)
                }
              }
            }
          }

          // ------------------------------------------------ preview cards
          Flow {
            visible: groupItem.modelData.kind === "cards"
            width: parent.width
            spacing: Style.spacing.md
            Repeater {
              model: groupItem.modelData.kind === "cards" ? groupItem.shown : []
              CursorSurface {
                id: card
                required property var modelData
                required property int index
                width: Style.space(196)
                height: cardColumn.implicitHeight + Style.spacing.md * 2
                radius: (app.design.cardRadius * 0.75)
                bordered: true
                current: modelData.value === groupItem.modelData.current
                hasCursor: groupItem.groupHasCursor && index === pane.cursorOption
                foreground: pane.app.foreground
                accent: pane.app.accent

                Column {
                  id: cardColumn
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: Style.spacing.md
                  spacing: Style.spacing.sm
                  Rectangle {
                    width: parent.width
                    height: Math.round(width * 9 / 16)
                    radius: Math.max(0, (app.design.cardRadius * 0.75) - 2)
                    color: "#000000"
                    clip: true
                    Image {
                      anchors.fill: parent
                      visible: !!card.modelData.preview
                      source: card.modelData.preview ? "file://" + encodeURI(card.modelData.preview) : ""
                      sourceSize.width: 360
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                    }
                  }
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: card.modelData.label + (card.modelData.sub ? "  ·  " + card.modelData.sub : "")
                    color: pane.app.foreground
                    font.family: pane.app.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    pane.cursorGroup = groupItem.index
                    pane.cursorOption = card.index
                    if (groupItem.modelData.pick) groupItem.modelData.pick(card.modelData.value)
                  }
                }
              }
            }
          }

          // ------------------------------------------------ text box
          //
          // A line of text a group owns: the value comes from the group, and
          // Enter (or moving focus away) commits what was typed.
          TextField {
            id: groupTextField
            visible: groupItem.modelData.kind === "text"
            width: Style.space(320)
            foreground: pane.app.foreground
            accent: pane.app.accent
            placeholderText: groupItem.modelData.placeholder || ""
            text: groupItem.modelData.value || ""
            // A field can lose focus because the page under it is being taken
            // down — a look being put on rebuilds every group — and the
            // handler then runs with nothing around it left to talk to.
            onEditingFinished: {
              if (typeof groupItem === "undefined" || !groupItem) return
              var g = groupItem.modelData
              if (g && g.commit && text !== String(g.value || "")) g.commit(text)
              if (typeof pane !== "undefined" && pane && pane.app) pane.app.focusPanel()
            }
          }

          // ------------------------------------------------ font list
          TextField {
            visible: groupItem.modelData.kind === "fonts"
            width: Style.space(300)
            foreground: pane.app.foreground
            accent: pane.app.accent
            placeholderText: "Filter fonts"
            text: pane.filterText
            onTextChanged: if (text !== pane.filterText) { pane.filterText = text; pane.cursorOption = 0 }
            onEditingFinished: pane.app.focusPanel()
          }

          ListView {
            id: fontList
            visible: groupItem.modelData.kind === "fonts"
            width: parent.width
            height: visible ? Style.space(230) : 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: groupItem.modelData.kind === "fonts" ? groupItem.shown : []
            currentIndex: groupItem.groupHasCursor ? pane.cursorOption : -1
            highlightFollowsCurrentItem: false
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            onModelChanged: if (currentIndex >= 0) Qt.callLater(function() { fontList.positionViewAtIndex(fontList.currentIndex, ListView.Contain) })

            delegate: CursorSurface {
              id: fontRow
              required property var modelData
              required property int index
              width: fontList.width
              height: Style.space(34)
              radius: (app.design.cardRadius * 0.75)
              current: modelData.value === groupItem.modelData.current
              hasCursor: groupItem.groupHasCursor && index === pane.cursorOption
              foreground: pane.app.foreground
              accent: pane.app.accent

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.42
                elide: Text.ElideRight
                text: fontRow.modelData.label
                color: pane.app.foreground
                font.family: pane.app.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.spacing.lg
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * 0.52
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                text: fontRow.modelData.sub || "The quick brown fox 0123"
                color: pane.app.foreground
                font.family: fontRow.modelData.value
                font.pixelSize: Style.font.body
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  pane.cursorGroup = groupItem.index
                  pane.cursorOption = fontRow.index
                  if (groupItem.modelData.pick) groupItem.modelData.pick(fontRow.modelData.value)
                }
              }
            }
          }
          }
        }
      }
    }
  }
}
