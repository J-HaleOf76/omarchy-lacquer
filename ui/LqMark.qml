import QtQuick
import QtQuick.Shapes
import "MarkPath.js" as MarkPath

// The mark: a typewriter L printed twice slightly out of register — the coat
// laid down first in the accent, the letter over it in ink, both taken from
// the theme, so the mark changes with everything else.
Item {
  id: mark

  required property var design
  // How far the first coat sits out of register, in the drawing's own units.
  property real offset: 11

  implicitWidth: 22
  implicitHeight: 22

  // The letter is drawn in a 256 box and scaled down to whatever size the
  // mark is given.
  Item {
    width: 256
    height: 256
    transform: Scale {
      xScale: mark.width / 256
      yScale: mark.height / 256
    }

    Shape {
      width: 256
      height: 256
      x: mark.offset
      y: mark.offset
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: mark.design.accent
        strokeWidth: -1
        PathSvg { path: MarkPath.L }
      }
    }

    Shape {
      width: 256
      height: 256
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillColor: mark.design.ink
        strokeWidth: -1
        PathSvg { path: MarkPath.L }
      }
    }
  }
}
