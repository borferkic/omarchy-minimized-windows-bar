# Minimized Windows Bar

An [Omarchy](https://omarchy.org) shell plugin by [borferkic](https://github.com/borferkic).

<p align="center"><img src="preview.png" alt="Slim bar at the bottom of the screen listing three minimized windows" width="720"></p>

A slim bar at the bottom of each monitor that lists the windows you minimized from that monitor. Click a name to bring the window back to the workspace it came from.

- One bar per monitor, shown only while that monitor has minimized windows.
- App name and window title only, no icons.
- Colors, font and height follow the active Omarchy theme, so it changes with the top bar when you switch themes.

## Requirements

- Omarchy with the shell plugin system (Hyprland, Quickshell).
- `hyprctl` and `jq`.

## Install

```bash
omarchy plugin add https://github.com/borferkic/omarchy-minimized-windows-bar.git --enable
```

## Keybindings

The plugin ships a helper, `bin/minimized-windows-bar`, that does the minimizing. Bind it in `~/.config/hypr/bindings.lua`:

```lua
local mwb = os.getenv("HOME") .. "/.config/omarchy/plugins/io.github.borferkic.minimized-windows-bar/bin/minimized-windows-bar"
o.bind("SUPER + N", "Minimize window", mwb)
o.bind("SUPER + SHIFT + ALT + N", "Restore all windows", mwb .. " restore-all")
```

Helper commands: no argument minimizes the active window, `restore <address>` restores one, `restore-all` restores every window, `list` prints them as JSON.

## Remove

```bash
omarchy plugin remove io.github.borferkic.minimized-windows-bar
```

## License

MIT, see [LICENSE](LICENSE).
