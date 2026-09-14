# HORO-1106 — Scene shell interactive verification

Captures from an interactive pass over the built debug app on a real Mac, kept here because a link in a
pull request outlives the pull request and because the next person changing the switcher should be able
to see what it looked like when it shipped.

Every image is a single-window capture of SceneMux's *own* window — `screencapture -l <windowID>` — taken
against an empty workspace. No full-screen capture was taken, and no other application's window, title or
content appears in any of them. See [`../../../development/ui-verification.md`](../../../development/ui-verification.md).

| Capture | What it proves |
| --- | --- |
| [`01-switcher-active-scene.png`](01-switcher-active-scene.png) | The switcher opened by the global `⌃⌥S`, showing the active Scene expanded with five Slots, their composition chips (`single`, `split ⬌`), the empty-Scene invitation, the *Add slot* role chips, and `⌃⌥1…4` on the Scene rows |
| [`02-switcher-filtered.png`](02-switcher-filtered.png) | Type-to-filter: `review` narrows four Scenes to three and ranks them, matching a Slot label as well as a title |
| [`03-close-confirmation.png`](03-close-confirmation.png) | `⌘⌫` shows the ownership summary and stops. Nothing has been closed at this point — *Close Scene* is the default action, *Cancel* leaves the Scene alone |
| [`04-after-close.png`](04-after-close.png) | After confirming: the closed Scene is no longer a row, the panel stays up, and the active Scene is untouched |
| [`05-no-match.png`](05-no-match.png) | The empty state for a search that matched nothing, and the promise it makes about `⏎` |
| [`06-naming-from-the-search.png`](06-naming-from-the-search.png) | `⏎` on that search keeps the promise: the field becomes the naming field, prefilled with what was typed, with the Slot template chips beside it. Nothing is created until the name is committed |
| [`07-menu-bar-active-scene.png`](07-menu-bar-active-scene.png) | The menu bar item with a Scene on screen: the title as the section header, *Scenes…* with its shortcut, *Switch to Scene*, *Leave Scene*, *Close Scene…* |
| [`08-menu-bar-no-scene.png`](08-menu-bar-no-scene.png) | The same menu with no Scene on screen: *No Scene*, and *Leave*/*Close* disabled rather than present and inert |
| [`09-hud-scene-entered.png`](09-hud-scene-entered.png) | The lifecycle HUD after entering a Scene, showing what was put on screen |
