import QtQuick

// A small heading over a group, set in the serif in small capitals with the
// letters spaced out, the way a printed page labels a section.
Text {
  id: label

  required property var design
  // Accepted from Omarchy's PanelSectionHeader.
  property color foreground: "white"
  property string fontFamily: ""

  color: design.muted
  font.family: design.serif
  font.pixelSize: 11
  font.weight: Font.DemiBold
  font.letterSpacing: 1.6
  font.capitalization: Font.AllUppercase
}
