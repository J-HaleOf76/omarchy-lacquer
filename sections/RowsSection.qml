import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."
import "../LookSchema.js" as LookSchema
import "../AnimSchema.js" as AnimSchema
import "../StyleLua.js" as StyleLua
import "../ShellSchema.js" as ShellSchema
import "../TomlEdit.js" as TomlEdit

// The generic row list: headers, look-and-feel options, animation leaves and
// shell.toml tokens, depending on the active section.
Item {
  id: section

  // The Lacquer panel; state and actions all live there or in its stores.
  required property var app

  // The panel's keyboard cursor scrolls rows into view through this.
  function positionAt(index, mode) { rowList.positionViewAtIndex(index, mode) }

  ListView {
    id: rowList
    anchors.fill: parent
    clip: true
    model: app.rows
    boundsBehavior: Flickable.StopAtBounds
    currentIndex: app.cursorIndex
    spacing: 0
    leftMargin: 16
    rightMargin: 16

    delegate: Loader {
      id: rowLoader
      required property var modelData
      required property int index

      // The list's own margins leave room for each group's card to reach
      // past the rows on both sides.
      width: rowList.width - rowList.leftMargin - rowList.rightMargin - Style.spacing.md

      // Each group of rows reads as one card: every row draws its own slice
      // of it, the first with the top corners, the last
      // with the bottom corners, and a hairline between the rest.
      readonly property bool isRow: modelData.kind !== "header"
      readonly property var prevEntry: index > 0 ? app.rows[index - 1] : null
      readonly property var nextEntry: index < app.rows.length - 1 ? app.rows[index + 1] : null
      readonly property bool firstInCard: isRow && (!prevEntry || prevEntry.kind === "header")
      readonly property bool lastInCard: isRow && (!nextEntry || nextEntry.kind === "header")

      Rectangle {
        z: -1
        visible: rowLoader.isRow
        x: -14
        width: parent.width + 28
        height: parent.height
        color: app.design.raised
        topLeftRadius: rowLoader.firstInCard ? app.design.cardRadius : 0
        topRightRadius: rowLoader.firstInCard ? app.design.cardRadius : 0
        bottomLeftRadius: rowLoader.lastInCard ? app.design.cardRadius : 0
        bottomRightRadius: rowLoader.lastInCard ? app.design.cardRadius : 0

        Rectangle {
          visible: !rowLoader.firstInCard
          x: 16
          width: parent.width - 32
          height: 1
          color: app.design.hairline
        }
      }

      // Rows of a page just switched to cascade in; rows scrolled into view
      // later appear as they always did.
      property real appear: 1
      opacity: Math.min(1, appear * 2)
      transform: Translate { y: (1 - rowLoader.appear) * 8 }
      Component.onCompleted: {
        if (!app.motion || !app.cascadeArmed || index > 16) return
        appear = 0
        rowCascade.start()
      }
      SequentialAnimation {
        id: rowCascade
        PauseAnimation { duration: 40 + rowLoader.index * 30 }
        NumberAnimation { target: rowLoader; property: "appear"; to: 1; duration: Math.round(520 * app.design.mass); easing.type: Easing.OutQuint }
      }
      sourceComponent: modelData.kind === "header" ? headerRow
        : modelData.kind === "leaf" ? leafRow
        : modelData.kind === "shell" ? shellRow : configRow

      Component {
        id: headerRow
        Item {
          implicitHeight: headerText.implicitHeight + (index === 0 ? 6 : 26)
          Text {
            id: headerText
            anchors.left: parent.left
            anchors.leftMargin: -10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            text: String(modelData.title || "").toUpperCase()
            color: app.design.muted
            font.family: app.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 1.1
          }
        }
      }

      Component {
        id: configRow
        ConfigRow {
          design: app.design
          item: modelData.item
          value: app.hypr.valueFor(modelData.item)
          modified: app.hypr.isModified(modelData.item.key)
          available: app.hypr.isAvailable(modelData.item)
          hasCursor: app.cursorIndex === index
          foreground: app.foreground
          accent: app.accent
          fontFamily: app.fontFamily
          onEdited: function(v) { app.hypr.setValue(modelData.item, v, false) }
          onCommitted: function(v) { app.hypr.setValue(modelData.item, v, true) }
          onReset: app.hypr.resetKeys([modelData.item.key], modelData.item.label)
          gate: app.pointerGate
          animated: app.motion
          onFocusRequested: app.cursorIndex = index
        }
      }

      Component {
        id: shellRow
        ShellRow {
          design: app.design
          item: modelData.item
          value: app.toml.shellValue(modelData.item)
          themeValue: app.toml.shellDefault(modelData.item)
          modified: app.toml.shellModified(modelData.item)
          hasCursor: app.cursorIndex === index
          foreground: app.foreground
          accent: app.accent
          fontFamily: app.fontFamily
          onEdited: function(v) { app.toml.setShell(modelData.item, v, false) }
          onCommitted: function(v) { app.toml.setShell(modelData.item, v, true) }
          onReset: app.toml.resetShellItem(modelData.item)
          gate: app.pointerGate
          animated: app.motion
          onFocusRequested: app.cursorIndex = index
          onEditingDone: Qt.callLater(function() { app.focusPanel() })
        }
      }

      Component {
        id: leafRow
        LeafRow {
          design: app.design
          leafSpec: modelData.leaf
          value: app.hypr.leafValue(modelData.leaf.name)
          inherited: app.hypr.leafInherited(modelData.leaf.name)
          modified: app.hypr.leafModified(modelData.leaf.name)
          hasCursor: app.cursorIndex === index
          curveNames: app.hypr.curveNames
          foreground: app.foreground
          accent: app.accent
          fontFamily: app.fontFamily
          onEdited: function(v) { app.hypr.setLeaf(modelData.leaf.name, v, false) }
          onCommitted: function(v) { app.hypr.setLeaf(modelData.leaf.name, v, true) }
          onReset: app.hypr.resetLeaf(modelData.leaf.name)
          onTakeOver: app.hypr.setLeaf(modelData.leaf.name, app.hypr.inheritedFrom(modelData.leaf), true)
          gate: app.pointerGate
          animated: app.motion
          onFocusRequested: app.cursorIndex = index
          onEditCurve: function(name) { app.jumpToCurve(name) }
          onPopupOpenChanged: if (!popupOpen) Qt.callLater(function() { app.focusPanel() })
        }
      }
    }

    Rectangle {
      anchors.right: parent.right
      width: Style.space(3)
      radius: width / 2
      color: Qt.rgba(app.foreground.r, app.foreground.g, app.foreground.b, 0.25)
      visible: rowList.contentHeight > rowList.height
      height: Math.max(Style.space(24),
                       rowList.height * (rowList.height / Math.max(1, rowList.contentHeight)))
      y: (rowList.height - height)
         * (rowList.contentY / Math.max(1, rowList.contentHeight - rowList.height))
    }
  }
}
