import Common
import SwiftUI

/// The Scene part of the menu bar item: which Scene am I in, a quick switch, and the two ways out of one.
///
/// The menu bar is the one always-visible piece of Scene state, so the first line is the answer to the question
/// the user actually has — the active Scene's title, or *No Scene*. It is plain text rather than a button
/// because it is a fact, not an action.
///
/// Every item routes through `SceneSwitcherPanel`, which routes through the switcher's model, which routes
/// through the runtime. The menu bar, `⌃⌥1` and `scenemux scene 1` are therefore three ways to reach one
/// implementation — the alternative is a product with two different ideas of what entering a task means.
///
/// *Close Scene…* opens the confirmation panel and never closes anything by itself. The ellipsis is the macOS
/// convention for exactly that, and closing is the one Scene operation that moves someone's windows.
struct SceneMenuBarSection: View {
    @ObservedObject var runtime: SceneCore.SceneRuntime

    var body: some View {
        Text(runtime.snapshot.menuBarTitle)
        Button("Scenes…") { SceneSwitcherPanel.shared.present(.switcher) }
            .keyboardShortcut("S", modifiers: [.control, .option])
        if !runtime.snapshot.scenes.isEmpty {
            Menu("Switch to Scene") {
                ForEach(runtime.snapshot.scenes) { row in
                    Button(row.title) { SceneSwitcherPanel.shared.enterFromOutside(row.id) }
                }
            }
        }
        Button("Leave Scene") { SceneSwitcherPanel.shared.leaveFromOutside() }
            .disabled(runtime.snapshot.activeScene == nil)
        Button("Close Scene…") {
            guard let active = runtime.snapshot.activeScene else { return }
            SceneSwitcherPanel.shared.present(.confirmClose(active.id))
        }
        .disabled(runtime.snapshot.activeScene == nil)
    }
}
