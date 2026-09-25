import QtQuick

// Lacquer's own look, in one place. Colours still come from the theme — the
// point of the app is that everything follows it — but the surfaces, type,
// corners and the way things move are Lacquer's.
//
// A lithograph: ink on paper. Flat areas of one ink, hairline rules instead of
// boxes, a faint grain over the whole sheet, wide margins, and the accent as a
// second ink for the one thing that is selected.
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

  // Ink on paper. The paper is the theme's background; the first ink is its
  // text colour, and the accent is the second ink — used only for what is
  // selected and what you have changed, the way a two-plate print works.
  readonly property color paper: background
  readonly property color ink: foreground

  // Hairlines do the work boxes used to do.
  readonly property color rule: alpha(foreground, dark ? 0.15 : 0.2)
  readonly property color ruleStrong: alpha(foreground, dark ? 0.3 : 0.38)

  // Faint washes, for the few places something must read as an area rather
  // than a line.
  readonly property color surface: alpha(foreground, dark ? 0.05 : 0.045)
  readonly property color raised: alpha(foreground, dark ? 0.035 : 0.03)
  readonly property color hover: alpha(foreground, dark ? 0.08 : 0.07)
  readonly property color hairline: rule
  readonly property color muted: mix(foreground, background, 0.38)
  readonly property color faint: mix(foreground, background, 0.6)
  readonly property color sheen: "transparent"
  readonly property color shade: "transparent"

  // Text that sits on the accent: whichever of paper and ink stands further
  // from it.
  readonly property color onAccent: {
    var a = luminance(accent)
    return Math.abs(a - luminance(background)) > Math.abs(a - luminance(foreground)) ? background : foreground
  }
  readonly property color accentSoft: alpha(accent, dark ? 0.22 : 0.18)

  // Printed blocks, not pills: barely rounded, whatever the windows do.
  readonly property real rounding: app ? Math.max(0, Math.min(24, app.windowRounding)) : 8
  readonly property real cardRadius: 3
  readonly property real controlRadius: 3
  readonly property real pillRadius: 3

  // Headings and the names of settings are set in a printed serif; what they
  // do is explained in a sans, and numbers and keys stay in the theme's mono.
  readonly property string serif: {
    var want = ["Source Serif 4", "Noto Serif", "Liberation Serif", "DejaVu Serif"]
    var have = Qt.fontFamilies()
    for (var i = 0; i < want.length; i++) if (have.indexOf(want[i]) >= 0) return want[i]
    return "serif"
  }
  readonly property string sans: {
    var wantSans = ["Adwaita Sans", "Inter", "Noto Sans", "Cantarell", "DejaVu Sans"]
    var haveSans = Qt.fontFamilies()
    for (var j = 0; j < wantSans.length; j++) if (haveSans.indexOf(wantSans[j]) >= 0) return wantSans[j]
    return "sans-serif"
  }
  readonly property string mono: app ? app.monoFamily : "monospace"

  // The wordmark is set in a typewriter face, the same one the mark's L is cut
  // from, so the name and the letter are plainly the same object.
  readonly property string typewriter: {
    var wantType = ["Courier Prime", "Courier 10 Pitch", "Nimbus Mono PS", "Liberation Mono"]
    var haveType = Qt.fontFamilies()
    for (var k = 0; k < wantType.length; k++) if (haveType.indexOf(wantType[k]) >= 0) return wantType[k]
    return mono
  }

  // The text column never runs the full width of the window: a printed page
  // keeps a margin.
  readonly property real columnWidth: 680

  // Motion. Lacquer moves like something wet: every edge of a moving blob is
  // on its own spring, so it stretches, pinches and wobbles into place. The
  // desktop's motion speed scales the mass; switching animations off stops it.
  readonly property bool motion: app ? app.motion : true
  readonly property real mass: app && app.uiDuration > 0 ? Math.max(0.55, Math.min(2.2, app.uiDuration / 380)) : 1
}
