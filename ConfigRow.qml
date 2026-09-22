import QtQuick
import qs.Commons
import qs.Ui
import "ui"

// One editable look-and-feel option: name and description left, control right,
// so a slider, a switch and a segmented picker all scan as the same kind of
// thing.
//
// Adapted from Omaland's OptionRow.qml — MIT, Copyright (c) 2026 Bobby Nicholas
// (https://github.com/bobby-nicholas/omaland).
//
// Stateless about the value. `edited` fires continuously while a slider is
// dragged and only drives the live preview; `committed` is the point worth
// writing to disk.
Item {
  id: root

  // Lacquer's Motion switch; off makes every fade here instant.
  property bool animated: true

  required property var item
  // Lacquer's design kit, from the panel.
  property var design: null
  // The description opens on the row the keyboard is on, or one the pointer
  // has rested on for a moment.
  property bool lingering: false
  readonly property bool open: hasCursor || lingering

  // Which moving picture shows what this setting does, if any.
  readonly property string previewKind: {
    var k = item.key
    if (["general:gaps_in", "general:gaps_out", "general:float_gaps", "general:gaps_workspaces"].indexOf(k) >= 0) return "gaps"
    if (k === "general:border_size") return "border"
    if (k === "decoration:rounding") return "corner"
    if (["decoration:active_opacity", "decoration:inactive_opacity", "decoration:fullscreen_opacity"].indexOf(k) >= 0) return "opacity"
    if (["decoration:dim_strength", "decoration:dim_special", "decoration:dim_around"].indexOf(k) >= 0) return "dim"
    if (k === "decoration:blur:size") return "blur"
    if (k === "decoration:shadow:range" || k === "decoration:glow:range") return "shadow"
    return ""
  }
  property var value: 0
  property bool modified: false
  property bool available: true
  property bool hasCursor: false
  // The panel's PointerMoveGate, so hover selection ignores synthetic motion.
  property QtObject gate: null
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family

  signal edited(var value)
  signal committed(var value)
  signal reset()
  signal focusRequested()

  readonly property bool isBool: item.type === "bool"
  readonly property bool isEnum: item.type === "enum"
  readonly property bool isSlider: item.type === "int" || item.type === "float"

  // The block is documented as safe to hand-edit, so a slider key may come
  // back as something Number() cannot read. Falling back to the schema
  // minimum keeps the row usable instead of rendering a NaN-wide track.
  readonly property real numValue: {
    var n = Number(value)
    return isFinite(n) ? n : (item.min !== undefined ? Number(item.min) : 0)
  }
  // Widen rather than clamp when the live value sits outside the schema range.
  readonly property real sliderMin: isSlider ? Math.min(item.min, numValue) : 0
  readonly property real sliderMax: isSlider ? Math.max(item.max, numValue) : 1

  function formatted() {
    if (!isSlider) return ""
    var n = Number(value)
    if (!isFinite(n)) return "—"
    var text = item.type === "int"
      ? String(Math.round(n))
      : n.toFixed(item.decimals === undefined ? 2 : item.decimals)
    return text + (item.unit || "")
  }

  implicitHeight: Math.max(labels.implicitHeight, control.implicitHeight) + Style.spacing.xxl
  opacity: available ? 1 : 0.38
  enabled: available

  Behavior on opacity { enabled: root.animated; NumberAnimation { duration: 120 } }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 3
    anchors.bottomMargin: 3
    anchors.leftMargin: -8
    anchors.rightMargin: -8
    radius: root.design ? root.design.controlRadius : Style.cornerRadius
    color: root.hasCursor && root.design ? root.design.hover : "transparent"
    Behavior on color { enabled: root.animated; ColorAnimation { duration: 140 } }
  }

  Timer { id: lingerTimer; interval: 380; onTriggered: root.lingering = true }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    onContainsMouseChanged: containsMouse ? lingerTimer.restart() : (lingerTimer.stop(), root.lingering = false)
    // Only real pointer motion moves the cursor. A row sliding under a mouse
    // that is just resting on the panel — which happens every time the list
    // changes, and the panel opens centred — must not steal keyboard focus.
    onPositionChanged: function(mouse) {
      if (!root.gate || root.gate.moved(this, mouse)) root.focusRequested()
    }
  }

  Column {
    id: labels
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: Math.round(parent.width * 0.42)
    spacing: Style.spacing.xxs

    Row {
      spacing: Style.spacing.sm
      width: parent.width

      Text {
        text: root.item.label
        color: root.hasCursor ? root.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: 15
        font.weight: Font.DemiBold
        Behavior on color { enabled: root.animated; ColorAnimation { duration: 160 } }
      }

      // Filled pip = this key differs from Omarchy's default.
      Rectangle {
        width: Style.space(5)
        height: width
        radius: width / 2
        color: root.accent
        opacity: root.modified ? 1 : 0
        anchors.verticalCenter: parent.verticalCenter
        Behavior on opacity { enabled: root.animated; NumberAnimation { duration: 120 } }
      }
    }

    Text {
      text: root.item.description
      visible: text !== "" && root.open
      color: root.design ? root.design.muted : Qt.darker(root.foreground, 1.55)
      font.family: root.fontFamily
      font.pixelSize: 13
      width: parent.width
      wrapMode: Text.WordWrap
    }

    // What it does, moving: follows the slider while it is dragged.
    LqPreview {
      design: root.design
      kind: root.open && root.design ? root.previewKind : ""
      value: root.numValue
    }
  }

  Row {
    id: control
    anchors.right: parent.right
    anchors.left: labels.right
    anchors.leftMargin: Style.spacing.xxl
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.lg
    layoutDirection: Qt.RightToLeft

    // Reserved even when hidden, so sliders stay aligned down the section.
    Item {
      width: undoButton.width
      height: undoButton.height
      anchors.verticalCenter: parent.verticalCenter

      PanelActionButton {
        id: undoButton
        iconText: "󰕌"
        tooltipText: "Reset to Omarchy default"
        foreground: root.foreground
        opacity: root.modified ? 1 : 0
        enabled: root.modified
        onClicked: root.reset()
        Behavior on opacity { enabled: root.animated; NumberAnimation { duration: 120 } }
      }
    }

    Text {
      visible: root.isSlider
      text: root.formatted()
      color: root.modified ? root.accent : root.foreground
      font.family: root.design ? root.design.mono : root.fontFamily
      font.pixelSize: 14
      font.weight: Font.DemiBold
      horizontalAlignment: Text.AlignRight
      width: Style.space(58)
      anchors.verticalCenter: parent.verticalCenter
    }

    LqSwitch {
      visible: root.isBool
      design: root.design
      checked: root.value === true
      hasCursor: root.hasCursor
      anchors.verticalCenter: parent.verticalCenter
      onToggled: root.committed(!root.value)
    }

    LqSlider {
      visible: root.isSlider
      design: root.design
      showLabel: false
      width: Math.max(Style.space(90), control.width - undoButton.width - Style.space(58) - Style.spacing.lg * 2)
      from: root.sliderMin
      to: root.sliderMax
      stepSize: root.item.step === undefined ? 1 : root.item.step
      value: root.numValue
      hasCursor: root.hasCursor
      anchors.verticalCenter: parent.verticalCenter
      onMoved: function(v) { root.edited(root.item.type === "int" ? Math.round(v) : v) }
      onCommitted: function(v) { root.committed(root.item.type === "int" ? Math.round(v) : v) }
    }

    LqTabs {
      visible: root.isEnum
      design: root.design
      style: "chips"
      fontSize: 13
      width: Math.min(implicitWidth, control.width - undoButton.width - Style.spacing.lg)
      options: root.item.options || []
      value: String(root.value)
      anchors.verticalCenter: parent.verticalCenter
      onChanged: function(v) { root.committed(v) }
    }
  }
}
