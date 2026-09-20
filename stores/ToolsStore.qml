import QtQuick
import Quickshell
import Quickshell.Io

// The command-line tools Omarchy does not retint on its own.
//
// Everything goes through the app-theme helper, which writes a fenced block in
// each tool's own config and takes it out again; the theme-switch hook calls
// its reapply, so a tool that is on keeps following the theme.
Item {
  id: root
  visible: false

  required property var app

  property var tools: []
  property bool scanned: false

  function rescan() {
    if (!scanProc.running) scanProc.running = true
  }

  function set(id, on) {
    runProc.command = ["timeout", "-k", "2", "20", "python3", root.app.pluginDir + "/app-theme",
                       on ? "on" : "off", id]
    runProc.label = id + (on ? " follows the theme" : " left alone")
    runProc.running = true
  }

  Process {
    id: runProc
    property string label: ""
    stderr: StdioCollector { id: runErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) root.app.errorText = String(runErr.text || "").trim() || "Could not change that"
      else root.app.statusText = runProc.label
      root.rescan()
    }
  }

  Process {
    id: scanProc
    command: ["timeout", "-k", "2", "30", "python3", root.app.pluginDir + "/app-theme", "scan"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.tools = Array.isArray(parsed.tools) ? parsed.tools : []
        } catch (e) {
          root.tools = []
        }
        root.scanned = true
      }
    }
  }
}
