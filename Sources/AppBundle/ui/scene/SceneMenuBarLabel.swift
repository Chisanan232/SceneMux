import SwiftUI

/// The menu bar item's label while a Scene is on screen: the icon, and the task's name beside it.
///
/// This is the only always-visible piece of Scene state, which is why it is worth the menu bar space — the
/// question *which task am I in?* should not require opening a menu. The title is already middle-truncated by
/// the snapshot, because what distinguishes two task names is usually their end: `Debug PROD-123` and
/// `Debug PROD-987`.
///
/// Nothing is added when no Scene is active. The spec's *No Scene* text lives in the menu instead: a permanent
/// *No Scene* in the menu bar of someone who has never made one is noise, and the menu answers the question the
/// moment it is asked.
struct SceneMenuBarLabel<Icon: View>: View {
    @ObservedObject var runtime: SceneCore.SceneRuntime
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        if runtime.snapshot.activeScene != nil {
            HStack(spacing: 4) {
                icon()
                Text(runtime.snapshot.menuBarTitle)
            }
            .accessibilityLabel("SceneMux, scene \(runtime.snapshot.menuBarTitle)")
        } else {
            icon()
        }
    }
}
