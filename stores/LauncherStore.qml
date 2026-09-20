import QtQuick
import Quickshell
import Quickshell.Io

// The app launcher's entries: what an app is called, its icon, and whether it
// shows up at all.
//
// The packaged .desktop file is never touched. `launcher-entry` copies it into
// ~/.local/share/applications/ — where the desktop looks first — and edits the
// copy, marking it so Lacquer only ever edits its own. Reset deletes the copy
// and the packaged entry takes over again.
Item {
  id: root
  visible: false

  required property var app

  property var apps: []
  property bool scanned: false
  property string picked: ""

  readonly property var current: {
    for (var i = 0; i < root.apps.length; i++)
      if (root.apps[i].id === root.picked) return root.apps[i]
    return null
  }

  readonly property int changedCount: {
    var n = 0
    for (var i = 0; i < root.apps.length; i++) if (root.apps[i].managed) n++
    return n
  }

  function rescan() {
    if (!scanProc.running) scanProc.running = true
  }

  function set(what, value, label) {
    if (!root.picked) return
    runProc.command = ["timeout", "-k", "2", "15", root.app.pluginDir + "/launcher-entry",
                       "set", root.picked, what, String(value)]
    runProc.label = label
    runProc.running = true
  }

  function reset() {
    if (!root.picked) return
    runProc.command = ["timeout", "-k", "2", "15", root.app.pluginDir + "/launcher-entry",
                       "reset", root.picked]
    runProc.label = "Back to how it was packaged"
    runProc.running = true
  }

  // Picking an image is another surface, so the panel steps aside and a
  // detached helper brings it back with the result, the same way fonts and
  // wallpapers are picked.
  readonly property string iconScript:
      'id=$1; dir=$2\n'
    + 'sel=$(omarchy-file-select --title "Pick an icon" --extensions "png svg jpg jpeg webp" | head -n 1)\n'
    + 'status=""\n'
    + 'if [ -n "$sel" ]; then\n'
    + '  if out=$("$dir/launcher-entry" set "$id" icon "$sel" 2>&1); then status="Icon changed"\n'
    + '  else status="$out"; fi\n'
    + 'fi\n'
    + 'payload=$(jq -nc --arg t "$status" \'{section:"launcher", status:$t}\')\n'
    + 'omarchy-shell shell summon io.github.deunnis.lacquer "$payload" >/dev/null\n'

  function pickIcon() {
    if (!root.picked) return
    root.app.dismiss()
    Quickshell.execDetached(["bash", "-c", root.iconScript, "lacquer-icon", root.picked, root.app.pluginDir])
  }

  Process {
    id: runProc
    property string label: ""
    stderr: StdioCollector { id: runErr; waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) root.app.errorText = String(runErr.text || "").trim() || "Could not change that entry"
      else if (runProc.label) root.app.statusText = runProc.label
      root.rescan()
    }
  }

  Process {
    id: scanProc
    command: ["timeout", "-k", "2", "20", "python3", root.app.pluginDir + "/launcher-entry", "scan"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(text)
          root.apps = Array.isArray(parsed.apps) ? parsed.apps : []
        } catch (e) {
          root.apps = []
        }
        root.scanned = true
        if (root.picked === "" && root.apps.length > 0) root.picked = root.apps[0].id
      }
    }
  }
}
