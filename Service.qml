import QtQuick
import Quickshell
import Quickshell.Io
import "stores"

// Installs the launcher entry, so the panel is reachable from SUPER+SPACE
// without the user wiring up a keybind first. Omarchy has no install hook and
// no manifest field for registering one, so it happens here instead.
//
// Only a file carrying the X-Lacquer-Managed marker is ever written or
// deleted: if something else already owns that path, it is left alone.
QtObject {
  id: root

  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  // The theme shuffle runs here rather than in the panel: the panel only exists
  // once it has been opened, and a shuffle has to act on boot and at sunset
  // whether or not anyone opens Lacquer.
  readonly property ShuffleEngine shuffle: ShuffleEngine { }

  readonly property string pluginId: (manifest && manifest.id) ? String(manifest.id)
                                                               : "io.github.deunnis.lacquer"

  // Lacquer's IPC lives here rather than in the panel, because the panel only
  // exists once it has been opened: a keybinding or a script that asks Lacquer
  // to do something should not depend on someone having opened it first.
  //
  //   omarchy-shell lacquer open '{"section":"theme"}'
  //   omarchy-shell lacquer applyTheme gruvbox
  //   omarchy-shell lacquer currentTheme
  //   omarchy-shell lacquer shuffleStatus
  //
  // Opening and closing go through the host (shell.summon/hide), which is what
  // `omarchy-shell shell summon io.github.deunnis.lacquer` does too.
  // A QtObject has no default property, so the handler is held by name.
  readonly property IpcHandler ipc: IpcHandler {
    target: "lacquer"

    function open(payload: string): string {
      if (!root.shell) return "the shell did not hand Lacquer its panel api"
      root.shell.summon(root.pluginId, payload && payload.length > 0 ? payload : "{}")
      return "ok"
    }

    function close(): string {
      if (!root.shell) return "the shell did not hand Lacquer its panel api"
      root.shell.hide(root.pluginId)
      return "ok"
    }

    function toggle(): string {
      if (!root.shell) return "the shell did not hand Lacquer its panel api"
      root.shell.toggle(root.pluginId, "{}")
      return "ok"
    }

    // Open on one page. The name is the section's id, as listed in the README.
    function showSection(id: string): string {
      if (!/^[a-z]+$/.test(String(id))) return "no section called " + id
      return open(JSON.stringify({ section: String(id) }))
    }

    function currentTheme(): string {
      return root.shuffle ? root.shuffle.currentThemeSlug : ""
    }

    // A theme by its folder name, the way `omarchy theme set` takes it.
    function applyTheme(slug: string): string {
      if (!/^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$/.test(String(slug))) return "no theme called " + slug
      Quickshell.execDetached(["omarchy-theme-set", String(slug)])
      return "ok"
    }

    // Only a wallpaper of the theme that is on: anything else is refused, so a
    // stray call cannot point the desktop at an arbitrary file.
    function setWallpaper(path: string): string {
      var backgrounds = Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/backgrounds/"
      var real = String(path)
      if (real.indexOf(backgrounds) !== 0 || real.indexOf("..") >= 0) return "not a wallpaper of the current theme"
      Quickshell.execDetached(["omarchy-theme-bg-set", real])
      return "ok"
    }

    function shuffleStatus(): string {
      var e = root.shuffle
      if (!e) return JSON.stringify({ engine: null })
      return JSON.stringify({ dormant: e.dormant, active: e.active, stateLoaded: e.stateLoaded,
                              bootEnabled: e.st.enabled, dayNight: e.st.schedule.enabled,
                              pool: (e.st.pool || []).length, themes: e.themes.length,
                              lastBootId: e.st.lastBootId, currentBootId: e.currentBootId })
    }
  }

  // 4.0.3 strips __sourceDir from every third-party manifest
  // (shell.qml publicPluginManifest), so the plugin's own directory has to come
  // from the QML file's own URL rather than from the host.
  readonly property string pluginDir: {
    var url = String(Qt.resolvedUrl("."))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return decodeURIComponent(url).replace(/\/+$/, "")
  }

  readonly property string dest: Quickshell.env("HOME") + "/.local/share/applications/lacquer.desktop"
  readonly property string marker: "^X-Lacquer-Managed=true$"

  readonly property string installScript:
      '[ -f "$1" ] || exit 0\n'
    + 'if [ -e "$2" ] && ! grep -q "$3" "$2"; then exit 0; fi\n'
    + 'mkdir -p "${2%/*}" || exit 0\n'
    + 'tmp=$2.lacquer.new\n'
    + 'sed "s|@ICON@|$4|" "$1" > "$tmp" || exit 0\n'
    + 'if cmp -s "$tmp" "$2"; then rm -f "$tmp"; else mv -f "$tmp" "$2"; fi\n'

  // Same ownership rule as the launcher entry, copied verbatim.
  readonly property string hookScript:
      'mkdir -p "$4" && chmod 700 "$4"\n'
    + '[ -f "$1" ] || exit 0\n'
    + 'if [ -e "$2" ] && ! grep -q "$3" "$2"; then exit 0; fi\n'
    + 'mkdir -p "${2%/*}" || exit 0\n'
    + 'if cmp -s "$1" "$2"; then exit 0; fi\n'
    + 'cp -f "$1" "$2.lacquer.new" && mv -f "$2.lacquer.new" "$2"\n'

  readonly property string removeScript:
    'grep -q "$2" "$1" 2>/dev/null && rm -f "$1"\n'

  property bool installed: false

  // Pinned GTK, colour-scheme and icon choices are put back after every theme
  // switch by a hook, so they hold even while Lacquer is closed. The hook
  // removes itself if Lacquer is ever uninstalled.
  readonly property string hookDest: Quickshell.env("HOME") + "/.config/omarchy/hooks/theme-set.d/lacquer-reapply"
  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/omarchy/io.github.deunnis.lacquer"

  // Setting a monospace font restarts the shell. The panel leaves a marker
  // naming its section; a fresh one reopens Lacquer right where it was.
  readonly property string reopenScript:
      'f=$1; [ -f "$f" ] && [ ! -L "$f" ] || exit 0\n'
    + 'age=$(( $(date +%s) - $(stat -c %Y "$f") ))\n'
    + 'sec=$(timeout 2 head -c 40 "$f" | tr -cd "a-z-")\n'
    + 'rm -f "$f"\n'
    + '[ "$age" -lt 120 ] && [ -n "$sec" ] || exit 0\n'
    + 'for i in 1 2 3 4 5 6 7 8 9 10; do\n'
    + '  sleep 1\n'
    + '  [ "$(omarchy-shell shell summon io.github.deunnis.lacquer "{\\"section\\":\\"$sec\\"}" 2>/dev/null)" = ok ] && exit 0\n'
    + 'done\n'

  // Installing on completion rather than on a manifest signal: the directory
  // no longer comes from the host, so there is nothing to wait for.
  Component.onCompleted: {
    installed = true
    Quickshell.execDetached(["sh", "-c", installScript, "sh",
                             pluginDir + "/lacquer.desktop", dest, marker, pluginDir + "/icon.png"])
    Quickshell.execDetached(["sh", "-c", hookScript, "sh",
                             pluginDir + "/lacquer-reapply.hook", hookDest, "^# X-Lacquer-Managed=true$", stateDir])
    Quickshell.execDetached(["sh", "-c", reopenScript, "sh", stateDir + "/reopen"])
  }

  // Reached on disable and on remove alike: omarchy-plugin-remove disables
  // first, so the service is torn down while the entry is still ours.
  Component.onDestruction: {
    if (!installed) return
    Quickshell.execDetached(["sh", "-c", removeScript, "sh", dest, marker])
  }
}
