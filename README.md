
<p align="left">
  <img src="resources/scenemux-logo.svg" width="80" alt="SceneMux logo">
</p>

# SceneMux

<p align="left"><strong>Stop managing windows. Start managing work.</strong></p>

<p align="left">A task-oriented desktop application multiplexer for macOS. Every task has a
scene, and every window has a place in it. Native apps stay native.</p>

> **SceneMux is derived from [WinMux](https://github.com/ZimengXiong/winmux)** (MIT),
> which is itself derived from [AeroSpace](https://github.com/nikitabobko/AeroSpace) (MIT).
> SceneMux is a separate project with its own release namespace and direction —
> it is not WinMux, not a WinMux distribution, and not endorsed by the WinMux authors.
> Exact derivation baseline: [`docs/legal/ORIGIN.md`](docs/legal/ORIGIN.md).

> **Current status — v0.0.0, Independent Foundation.** This release establishes SceneMux as
> a standalone, provenance-safe repository with its own identity and its own (currently
> unconfigured) update channel. Everything documented below is the **inherited WinMux
> engine**. The task-oriented layer this project exists for — Semantic Homes, Scenes, Slots
> and Mounts — arrives in v0.1.0 and is not present yet.

## Highlights
### Projects
Projects are collection of workspaces. Think of it like a parent/child hiearchy, you can switch between projects. Each project has it's own set of workspaces.

### Sidebar
The sidebar is a more interactively-performant and useful alternative to [Sketchybar](https://github.com/felixkratz/sketchybar) and traditional workspace menu bar dropdowns for most everyday tasks. It provides better visibility into spaces and spatial awareness on the desktop.

You can drag windows in and out of the sidebar from and to the current workspace. You can rearrange windows across all spaces using the sidebar, including tab groups.

By default the sidebar rests as a compact rail and expands when hovered. To hide the rail
completely until the pointer reaches the left display edge, enable auto-hide. On macOS 26 and
newer, native Liquid Glass is enabled by default. Choose an opaque solid color for greater
contrast across the sidebar, tab groups, and switcher:

```toml
[workspace-sidebar]
    auto-hide = true
    chrome-style = 'solid'
    solid-chrome-color = 'lavender' # Choose any color shown in Appearance, including custom.
```

To keep the full sidebar visible, reserve its expanded width when laying out tiled windows:

```toml
[workspace-sidebar]
    always-expanded = true
    width = 240
```

`always-expanded` takes precedence over `auto-hide`. The configured `gaps.outer.left` remains
the spacing between the sticky sidebar and tiled windows, and monitor selection continues to
control which displays reserve sidebar space.

The sidebar clock can be configured independently:

```toml
[workspace-sidebar]
    show-clock = true
    show-seconds = true
    show-date = true
    show-weekday = true
```

`show-clock` hides the entire clock card. The other settings independently control seconds,
the month and day, and the weekday; for example, `show-date = false` with
`show-weekday = true` leaves a weekday-only calendar label in the expanded sidebar.

### Window and sidebar spacing

The `[gaps]` settings control the visible borders around tiled windows. `inner.horizontal`
and `inner.vertical` set the space between neighboring windows. The outer gaps set the space
at each display edge; when the sidebar is enabled, `outer.left` is the space between the
sidebar and the tiled windows. Any of these values can be reduced or set to zero independently.

For borderless tiling, including no border beside the sidebar:

```toml
[gaps]
    inner.horizontal = 0
    inner.vertical = 0
    outer.left = 0
    outer.bottom = 0
    outer.top = 0
    outer.right = 0
```
### Tab Groups
![](resources/screenshots/tab-groups.png)
Tab groups allow you to have many windows occupy the same footprint, similar to Yabai stacks but with browser-like tab behavior. This is useful when you want to have multiple pieces of reference information next to an editor, multiple tabs in different browser profiles, or, when you simply want multiple fullscreen views without the additional friction and overhead of creating a new workspace.

Unlike stack-only layouts, SceneMux tab groups behave more intuitively like you would expect tabs to in browsers, and don't need a keyboard shortcut to activate. You can drag tabs from tab groups into another window's [intent zone](#managed-tiling-mode), or in between workspaces. You can also rearrange tab order within a tab group, and navigate through them with relative and absolute keybindings.

### Philosophy

#### Automatic tiling

SceneMux tiles newly discovered windows by default. To keep their existing macOS size and position while still using SceneMux's sidebar, workspaces, and manual layout commands, disable automatic tiling:

```toml
automatically-tile-new-windows = false
```

This applies to windows discovered when SceneMux starts and windows opened later. You can still tile an individual floating window with `scenemux layout tiling` or the configured `layout floating tiling` shortcut.

While dragging a window by its title bar, shake it horizontally to toggle between floating and tiling. The gesture requires several deliberate direction changes in quick succession, and does not activate during resize, sidebar, tab-strip, or tab-group drags. Disable it with:

```toml
enable-shake-to-toggle-tiling = false
```

#### Workspaces
You can NOT create workspaces that have no windows in them. Workspaces with no windows are automatically destroyed.

### Multi-Monitors
Monitors share the global project/workspace state. Each monitor can be treated as *independent* from each other. They each just use the sidebar to browse through projects and 'select' a workspace to view. 

Monitors can not be attached to the same workspace at the same time. They can be on the same project at the same time.

#### App Launching
SceneMux supports single-modifer keybindings (e.g. triggering an action on press of `⌘`)

I highly recommend that you configure the apps you use every day to be launch with Left/Right Option+Command, or similar shortcuts, otherwise it might be hard to launch common things into the current workspace (and instead, take you to the other workspace where the app is currently active). Here is some of the apps that I have keybinded:

```toml
[mode.main.binding-tap]
    left-alt = 'exec-and-forget /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --profile-directory="Default"'
    right-cmd = 'exec-and-forget /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --profile-directory="Profile 1"'

[mode.main.binding]
    # Disable the native "Hide App" shortcut.
    cmd-h = []

    cmd-d = 'exec-and-forget osascript ~/Documents/scripts/launchTerminalWindow.scpt'
    cmd-e = 'exec-and-forget osascript ~/Documents/scripts/launchFinderWindow.scpt'
```

```applescript
# ~/Documents/scripts/launchTerminalWindow.scpt
tell application "cmux"
    if it is running
        tell application "System Events" to tell process "cmux"
            click menu item "New Window" of menu "File" of menu bar 1
        end tell
    else
        activate
    end if
end tell

# ~/Documents/scripts/launchFinderWindow.scpt
tell application "Finder"
    if it is running
        tell application "System Events" to tell process "Finder"
            click menu item "New Finder Window" of menu "File" of menu bar 1
        end tell
    else
        activate
    end if
end tell

```

## Installation
SceneMux has no Homebrew tap and no published binary yet. Build and install it from source:

```shell
git clone https://github.com/Chisanan232/SceneMux.git
cd SceneMux
make install
```

`make install` builds a signed Release archive, copies `SceneMux.app` into `/Applications`, and
launches it. Signing uses your own Apple Development certificate; the build is not notarized, so
macOS may require you to right-click the app and choose **Open** the first time you launch it.

SceneMux needs Accessibility permission to move and resize other applications' windows. macOS
prompts for it on first launch.

### Updates

There is no update feed at v0.0.0. SceneMux ships with its update channel deliberately
unconfigured, so it never checks for — and can never install — a build from another project's
release feed. **Check for Updates…** is hidden from the menu bar until SceneMux publishes a feed
of its own. Until then, update by pulling and running `make install` again.

## Migrating
SceneMux reads one config file: `~/.config/scenemux/scenemux.toml` (or
`$XDG_CONFIG_HOME/scenemux/scenemux.toml`). If it already exists, SceneMux uses it as-is and
imports nothing.

If it does not exist, SceneMux creates it on first launch by importing the first config it finds,
in this order:

1. `~/.scenemux.toml` — a SceneMux dotfile, copied verbatim.
2. `~/.config/winmux/winmux.toml`, then `~/.winmux.toml` — an existing WinMux config, copied verbatim.
3. `~/.config/aerospace/aerospace.toml`, then `~/.aerospace.toml` — an AeroSpace config, with shortcuts and key mapping
   carried over and the rest filled in from SceneMux defaults, including the sidebar and window tabs.
4. Nothing — SceneMux writes the bundled starter config.

Every import is a **copy**. SceneMux never writes to, moves, or deletes the file it imported from,
so an installed WinMux or AeroSpace keeps running off its own config afterwards. SceneMux also
keeps accepting the inherited `WINMUX_*` exec variables and the `during-winmux-startup` matcher
key, so an imported WinMux config behaves the same way it did before.

## Credits
[WinMux](https://github.com/ZimengXiong/winmux) — the direct upstream this project is derived from.

[Aerospace](https://github.com/nikitabobko/AeroSpace) — the ancestral upstream WinMux itself derives from.

## License
MIT — see [`LICENSE.txt`](LICENSE.txt).

- [`docs/legal/ORIGIN.md`](docs/legal/ORIGIN.md) — derivation baseline, lineage, and upstream sync policy.
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) — every bundled dependency and its notice.
- [`docs/legal/LICENSE_POLICY.md`](docs/legal/LICENSE_POLICY.md) — how new dependencies and contributions are reviewed.
