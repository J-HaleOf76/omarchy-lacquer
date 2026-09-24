import QtQuick
import QtQuick.Effects

// A tiny moving picture of what a setting does, shown under its explanation:
// a pair of windows whose gap widens as you drag, a corner that rounds, a
// window going see-through, blurring or dimming, a shadow spreading, or a
// window opening at the speed an animation is set to.
//
// It is made of plain shapes and only moves while it is on screen.
Item {
  id: preview

  required property var design
  // gaps, border, corner, opacity, dim, blur, shadow, anim
  property string kind: ""
  property real value: 0
  // For "anim": how long the animation takes, in milliseconds.
  property real duration: 400

  implicitWidth: 150
  implicitHeight: 70
  visible: kind !== ""

  readonly property color win: design.mix(design.background, design.foreground, 0.16)
  readonly property color wall: design.mix(design.background, design.accent, 0.35)

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, isFinite(v) ? v : lo)) }

  // The desktop behind: a band of the accent, so see-through and blur show.
  Rectangle {
    id: desk
    anchors.fill: parent
    radius: preview.design.cardRadius
    color: preview.design.surface
    clip: true
    Repeater {
      model: 5
      Rectangle {
        required property int index
        x: index * 34 - 10
        y: -10
        width: 14
        height: 100
        rotation: 24
        color: preview.wall
        opacity: 0.55
      }
    }
  }

  // ------------------------------------------------------------ gaps / border / corner / shadow
  Item {
    anchors.fill: parent
    visible: preview.kind === "gaps" || preview.kind === "border" || preview.kind === "corner" || preview.kind === "shadow"
    readonly property real gap: preview.kind === "gaps" ? preview.clamp(preview.value, 0, 40) * 0.5 : 4
    readonly property real bw: preview.kind === "border" ? preview.clamp(preview.value, 0, 12) * 0.8 : 1.5
    readonly property real rr: preview.kind === "corner" ? preview.clamp(preview.value, 0, 30) * 0.7 : 4

    Repeater {
      model: 2
      Item {
        required property int index
        readonly property real w: (preview.width - 16 - parent.gap) / 2
        x: 8 + index * (w + parent.gap)
        y: 8
        width: w
        height: preview.height - 16
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        Rectangle {
          visible: preview.kind === "shadow"
          anchors.fill: parent
          anchors.margins: -preview.clamp(preview.value, 0, 40) * 0.2
          anchors.topMargin: 2
          radius: preview.design.cardRadius
          color: "#000000"
          opacity: 0.28
        }
        Rectangle {
          anchors.fill: parent
          radius: parent.parent.rr
          color: preview.win
          border.width: parent.parent.bw
          border.color: index === 0 ? preview.design.accent : preview.design.hairline
          Behavior on radius { NumberAnimation { duration: 180 } }
        }
      }
    }
  }

  // ------------------------------------------------------------ opacity / dim / blur
  Item {
    anchors.fill: parent
    visible: preview.kind === "opacity" || preview.kind === "dim" || preview.kind === "blur"

    Rectangle {
      id: glass
      x: 22
      y: 10
      width: preview.width - 44
      height: preview.height - 20
      radius: preview.design.cardRadius
      color: preview.win
      opacity: preview.kind === "opacity" ? preview.clamp(preview.value, 0.1, 1) : preview.kind === "blur" ? 0.55 : 1
      border.width: 1
      border.color: preview.design.hairline
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }
    // Dimming: a shade laid over the window that is not in use.
    Rectangle {
      visible: preview.kind === "dim"
      anchors.fill: glass
      radius: glass.radius
      color: "#000000"
      opacity: preview.clamp(preview.value, 0, 1) * 0.9
    }
    // Blur: the stripes behind the window seen through frosted glass.
    ShaderEffectSource {
      id: behindGlass
      visible: false
      sourceItem: desk
      sourceRect: Qt.rect(glass.x, glass.y, glass.width, glass.height)
      live: preview.kind === "blur"
    }
    MultiEffect {
      visible: preview.kind === "blur"
      x: glass.x; y: glass.y; width: glass.width; height: glass.height
      source: behindGlass
      blurEnabled: true
      blurMax: 32
      blur: preview.clamp(preview.value / 12, 0, 1)
      opacity: 0.7
    }
  }

  // ------------------------------------------------------------ anim
  Rectangle {
    id: popper
    visible: preview.kind === "anim"
    anchors.centerIn: parent
    width: preview.width * 0.5
    height: preview.height * 0.6
    radius: preview.design.cardRadius
    color: preview.win
    border.width: 1.5
    border.color: preview.design.accent
    transformOrigin: Item.Center

    SequentialAnimation {
      running: popper.visible && preview.visible && preview.design.motion
      loops: Animation.Infinite
      ParallelAnimation {
        NumberAnimation { target: popper; property: "scale"; from: 0.55; to: 1; duration: preview.clamp(preview.duration, 40, 3000); easing.type: Easing.OutCubic }
        NumberAnimation { target: popper; property: "opacity"; from: 0; to: 1; duration: preview.clamp(preview.duration, 40, 3000); easing.type: Easing.OutCubic }
      }
      PauseAnimation { duration: 900 }
      NumberAnimation { target: popper; property: "opacity"; to: 0; duration: 220 }
      PauseAnimation { duration: 260 }
    }
  }
}
