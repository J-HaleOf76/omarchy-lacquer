import QtQuick

// A small uppercase heading over a group of cards.
Text {
  id: label

  required property var design
  // Accepted from Omarchy's PanelSectionHeader.
  property color foreground: "white"
  property string fontFamily: ""

  color: design.muted
  font.family: design.sans
  font.pixelSize: 11
  font.weight: Font.DemiBold
  font.letterSpacing: 1.1
  font.capitalization: Font.AllUppercase
}
