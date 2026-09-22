import QtQuick
import QtQuick.Effects

// Slow goo behind the page, like a lava lamp: a few soft blobs in the theme's
// colours drift, meet and merge, and pull apart again.
//
// The merging is the classic trick, done on the GPU: the blobs are blurred
// together and then cut back to a crisp edge wherever the blur is thick
// enough, so two blobs close together share one outline. It moves on a slow
// clock of its own (about 15 steps a second, far cheaper than every frame) and
// only while `running` — the panel stops it when nobody has touched Lacquer
// for a while.
Item {
  id: ambient

  required property var design
  // The theme's colours, a few of which tint the blobs.
  property var palette: []
  property bool running: true
  property real strength: design.dark ? 0.16 : 0.12

  property real t: 0
  Timer {
    interval: 66
    repeat: true
    running: ambient.running && ambient.visible && ambient.design.motion
    onTriggered: ambient.t += 0.066
  }

  function tint(i) {
    var p = ambient.palette
    if (p && p.length > 0) return p[(i * 2 + 1) % p.length]
    return ambient.design.accent
  }

  // The blobs, as solid discs. Drawn only through the effects below.
  Item {
    id: field
    anchors.fill: parent
    visible: false

    Repeater {
      model: 6
      Rectangle {
        required property int index
        readonly property real size: Math.min(ambient.width, ambient.height) * (0.26 + 0.07 * (index % 3))
        // Each drifts on its own slow loop — 40 to 90 seconds round — so they
        // keep meeting in new ways and never line up.
        readonly property real px: 0.5 + 0.42 * Math.sin(ambient.t * (6.283 / (48 + index * 9)) + index * 1.9)
        readonly property real py: 0.5 + 0.40 * Math.cos(ambient.t * (6.283 / (41 + index * 7)) + index * 1.1)
        width: size
        height: size
        radius: size / 2
        x: px * ambient.width - size / 2
        // A slight droop: they spend a little longer low than high.
        y: (py * py * 0.35 + py * 0.65) * ambient.height - size / 2
        color: ambient.tint(index)
      }
    }
  }

  MultiEffect {
    id: blurred
    anchors.fill: field
    source: field
    blurEnabled: true
    blur: 1.0
    blurMax: 64
    visible: false
    layer.enabled: true
  }

  // Cut the blur back to a crisp outline where it is thick enough: that is
  // where the blobs become one.
  MultiEffect {
    anchors.fill: parent
    source: blurred
    maskEnabled: true
    maskSource: blurred
    maskThresholdMin: 0.42
    maskSpreadAtMin: 0.06
    opacity: ambient.strength
  }
}
