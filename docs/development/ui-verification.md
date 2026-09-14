# Verifying the user interface

SceneMux is a native macOS application built with AppKit and SwiftUI. Its user interface is a menu
bar item, a settings window, HUD panels, the workspace sidebar, and the windows of *other*
applications that SceneMux moves, resizes, tabs and restores.

**A browser automation tool cannot verify any of that.** Playwright, Selenium and friends drive a web
page's DOM. There is no DOM here. A passing browser test says nothing about an AppKit panel, an
`AXUIElement`, or whether a borrowed window was returned to where its owner left it. Do not present
browser automation as UI verification for this repository.

## What counts as verification

In rough order of preference, strongest first:

1. **XCTest / XCUITest** — automated, repeatable, runs in CI. Use it for anything that can be
   asserted programmatically.
2. **Accessibility-API automation** — drive the app the way SceneMux itself drives other apps
   (`AXUIElement` queries and actions). Suitable for asserting real window geometry and state.
3. **AppleScript / `osascript`** — click a menu item, open a window, read a UI element's value.
4. **Manual interaction** — a human, or an agent, operating the built app on a real Mac.
5. **`screencapture`** — the evidence artifact accompanying 3 and 4.

Inspecting the built product also counts, and is often the *strongest* evidence available for
identity and configuration claims, because it reads what ships rather than what the source says:

```shell
/usr/libexec/PlistBuddy -c Print <app>/Contents/Info.plist   # what the bundle declares
codesign -dv <app>                                            # identifier and signing state
assetutil --info <app>/Contents/Resources/Assets.car          # which artwork is compiled in
<app>/Contents/MacOS/SceneMux --version                       # what the binary reports
```

## Running the app

```shell
make run                      # debug build, launches ./.debug/SceneMuxApp
make install                  # Release build into /Applications, then launches it
```

The application requests **Accessibility** permission at startup and terminates itself if it is not
trusted — see `checkAccessibilityPermissions()`. Any interactive pass therefore requires granting
Accessibility to that specific build first. Note that a debug build and a release build have
different bundle identifiers, so they hold separate TCC grants.

Be aware of what launching a tiling window manager means: **it will rearrange every window on the
display.** Do not start an interactive pass on a machine that is mid-presentation, screen-sharing, or
holding unsaved work in windows you cannot afford to have moved.

## Screenshot discipline

Screenshots are required for UI changes and for both release gates. They are also the easiest way to
leak someone else's private information, because a desktop screenshot captures whatever else is on
that desktop.

Rules:

- **Never capture the whole screen.** Capture a window or a region:
  `screencapture -o -l <windowID> out.png`, `screencapture -R x,y,w,h out.png`, or
  `screencapture -w out.png` (interactive window pick).
- Prefer artifact-scoped evidence when it proves the same thing — a rendered asset, an extracted
  `AppIcon.icns`, a `PlistBuddy` dump — over a photograph of a desktop.
- Before attaching, look at the image. Meeting participants, chat windows, dashboards, tokens,
  customer names and file paths all leak this way.
- If a capture picks up something it should not have, delete the file immediately and say so plainly
  in the pull request. A deleted-and-declared mistake is recoverable; a quietly attached one is not.

## Recording the result

Every pull request that touches the UI answers, in the **UI verification** section:

- what was actually built and launched, with the commands;
- what was verified, and by which of the methods above;
- which screenshots or artifacts are attached, and what each one proves;
- what was **not** verified, why, and the ticket that carries it.

Silence is not an acceptable answer for a UI change. Neither is "verified" with no artifact. If an
interactive pass could not be performed, say exactly that and name the follow-up ticket — a stated
gap can be closed, an implied one cannot.

## Phase 1 evidence bar

The `v0.1.0` release gate requires evidence that shows, on a real Mac:

- an active Scene, e.g. `Debug PROD-123`;
- multiple semantic Slots populated at once;
- a Semantic Home shown both unmounted and with a window mounted into a Scene;
- a split and a tab composition inside a Scene;
- lifecycle restore: on Scene end, borrowed windows returned to their owner's arrangement, the
  Semantic Home unchanged, scene-owned windows following explicit cleanup, and shared or persistent
  windows untouched.

That evidence is produced by exercising the golden journey repeatedly, not by a single lucky
screenshot.
