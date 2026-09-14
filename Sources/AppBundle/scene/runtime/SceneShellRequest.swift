import Foundation

extension SceneCore {
    /// Something only a surface can do, asked for by a command.
    ///
    /// A keystroke bound to `scene switcher` and a shell running `scenemux scene switcher` are the same request,
    /// and neither of them should know what a panel is. The runtime holds a presenter that the UI registers at
    /// startup; a command asks through it. Two consequences worth stating: a command never reaches into a
    /// window, and a run with no UI listening — a test, or a headless invocation — gets an honest refusal
    /// instead of a silent success.
    ///
    /// `close` is here rather than being done directly on purpose. Closing a Scene is the one Scene flow that
    /// moves someone's windows, so the confirmation is not a courtesy the caller may skip: the command asks for
    /// the panel, and only `--yes` closes without one.
    enum SceneShellRequest: Equatable, Sendable {
        /// Show the Scene switcher, or hide it if it is already up.
        case switcher
        /// Show the switcher with a new Scene's name field focused and empty.
        case newScene
        /// Show the switcher with this Scene's name field focused and selected.
        case rename(SceneId)
        /// Show what closing this Scene will do, and ask.
        case confirmClose(SceneId)
    }
}
