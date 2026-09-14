import Foundation

/// The SceneMux-owned domain namespace: Scene, Semantic Home, Slot, Attachment, ownership and
/// lifecycle state. Everything in `scene/domain/` is a value type and imports `Foundation` only, so
/// the product's meaning is testable without a window server, a monitor or a running app.
///
/// The namespace is not decoration. `SwiftUI.Scene` is a protocol three inherited files already return
/// (`ui/settings/ShortcutSettingsView.swift`, `ui/menubar/MenuBar.swift`, `ui/hud/MessageView.swift`),
/// and a module-scope `Scene` here would shadow it. Nesting keeps `SwiftUI.Scene` meaning what its
/// authors meant without editing one inherited file.
///
/// See `docs/design/scene-core-architecture.md`, which is canonical for what these words mean.
enum SceneCore {}
