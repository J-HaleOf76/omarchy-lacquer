import QtQuick

// Lacquer's own look, in one place. Colours still come from the theme — the
// point of the app is that everything follows it — but the surfaces, type,
// corners and the way things move are Lacquer's.
//
// "Gloss": each group of settings sits on a raised card with a faint sheen
// along its top edge, like a coat of lacquer catching the light, and the
// selected thing is a filled pill in the theme's accent.
QtObject {
  id: design

  property var app: null

  readonly property color background: app ? app.background : "#1e1e2e"
  readonly property color foreground: app ? app.foreground : "#cdd6f4"
  readonly property color accent: app ? app.accent : "#89b4fa"

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

  readonly property bool dark: luminance(background) < 0.5

  // Surfaces step up from the panel's own background towards the text colour.
  readonly property color surface: mix(background, foreground, dark ? 0.045 : 0.035)
  readonly property color raised: mix(background, foreground, dark ? 0.075 : 0.055)
  readonly property color hover: mix(background, foreground, dark ? 0.11 : 0.08)
  readonly property color hairline: alpha(foreground, dark ? 0.09 : 0.12)
  readonly property color muted: mix(foreground, background, 0.42)
  readonly property color faint: mix(foreground, background, 0.62)
  readonly property color sheen: dark ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.65)
  readonly property color shade: dark ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(0.2, 0.05, 0.1, 0.08)

  // Text that sits on the accent: whichever of background and foreground
  // stands further from it.
  readonly property color onAccent: {
    var a = luminance(accent)
    return Math.abs(a - luminance(background)) > Math.abs(a - luminance(foreground)) ? background : foreground
  }
  readonly property color accentSoft: alpha(accent, dark ? 0.2 : 0.16)

  // Window rounding still nudges how round the cards are.
  readonly property real rounding: app ? Math.max(0, Math.min(24, app.windowRounding)) : 8
  // Goo has no corners: controls are always fully round, and cards are round
  // enough never to read as boxes — rounder still when the windows are.
  readonly property real cardRadius: Math.round(16 + rounding * 0.6)
  readonly property real controlRadius: 999
  readonly property real pillRadius: 999

  // Words in a sans, numbers and keys in the theme's own mono.
  readonly property string sans: {
    var want = ["Adwaita Sans", "Inter", "Noto Sans", "Cantarell", "DejaVu Sans"]
    var have = Qt.fontFamilies()
    for (var i = 0; i < want.length; i++) if (have.indexOf(want[i]) >= 0) return want[i]
    return "sans-serif"
  }
  readonly property string mono: app ? app.monoFamily : "monospace"

  // Motion. Lacquer moves like something wet: every edge of a moving blob is
  // on its own spring, so it stretches, pinches and wobbles into place. The
  // desktop's motion speed scales the mass; switching animations off stops it.
  readonly property bool motion: app ? app.motion : true
  readonly property real mass: app && app.uiDuration > 0 ? Math.max(0.55, Math.min(2.2, app.uiDuration / 380)) : 1
}
