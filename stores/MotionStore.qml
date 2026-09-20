import QtQuick
import "../MotionTokens.js" as MotionTokens

// The desktop's motion feel: one pick that sets Hyprland's animation curves and
// speeds, and the pace of Lacquer's own panel.
//
// The feel and the speed live in ui.json next to the Motion toggle (the panel
// owns that file); everything the feel writes goes through HyprStore, so it
// lands in the managed block, previews live, and undoes like any other edit.
// A feel is a starting point, not a lock: the Animations and Curves sections
// still edit every value underneath, and `matches` says when they no longer
// agree with the feel.
Item {
  id: root
  visible: false

  required property var app

  readonly property string feel: root.app.motionFeel
  readonly property real speed: root.app.motionSpeed

  readonly property var feelSpec: MotionTokens.feelFor(root.feel)
  readonly property var tokens: root.feelSpec ? MotionTokens.scaled(root.feelSpec, root.speed) : null

  readonly property var feels: MotionTokens.FEELS

  // Lacquer's own transitions follow the same feel; without one they keep the
  // pace the panel shipped with.
  readonly property int uiDuration: root.tokens ? root.tokens.ui.duration : 380
  readonly property string uiEasing: root.tokens ? root.tokens.ui.easing : "OutQuint"
  readonly property int uiCascade: root.tokens ? root.tokens.ui.cascade : 30

  // False once a curve or leaf the feel owns has been changed somewhere else.
  readonly property bool matches: {
    if (!root.tokens) return false
    var hypr = root.app.hypr
    var name
    for (name in root.tokens.curves)
      if (!MotionTokens.sameCurve(hypr.curveValue(name), root.tokens.curves[name])) return false
    for (name in root.tokens.leaves)
      if (!MotionTokens.leafMatches(hypr.leaves[name], root.tokens.leaves[name])) return false
    return true
  }

  function applyFeel(id) {
    var spec = MotionTokens.feelFor(id)
    if (!spec) return
    root.app.beginEdit()
    root.write(MotionTokens.scaled(spec, root.speed))
    root.app.setMotionFeel(id, root.speed)
    root.app.commitEdit("Motion feel: " + spec.label)
    root.app.statusText = spec.label + " · " + spec.blurb
  }

  function stepSpeed(delta) {
    var next = Math.round((root.speed + delta * MotionTokens.SPEED_STEP) * 10) / 10
    next = Math.max(MotionTokens.SPEED_MIN, Math.min(MotionTokens.SPEED_MAX, next))
    if (next === root.speed) return
    if (!root.feelSpec) { root.app.setMotionFeel(root.feel, next); return }
    root.app.beginEdit()
    root.write(MotionTokens.scaled(root.feelSpec, next))
    root.app.setMotionFeel(root.feel, next)
    root.app.commitEdit("Motion speed " + next.toFixed(1) + "×")
  }

  // Put the feel back over whatever was changed by hand since.
  function reapply() {
    if (root.feelSpec) root.applyFeel(root.feel)
  }

  function write(tokens) {
    var name
    for (name in tokens.curves) root.app.hypr.setCurve(name, tokens.curves[name], false)
    for (name in tokens.leaves) root.app.hypr.setLeaf(name, tokens.leaves[name], false)
    // The companion's bar moves at the same pace, when it is installed.
    root.app.companion.pushDuration(tokens.ui.duration)
  }
}
