import Foundation

extension SceneCore {
    /// One thing SceneMux did, said once, in the user's vocabulary.
    ///
    /// The cases are what this build can honestly report. There is deliberately no case for *leaving* a Scene:
    /// nothing happens to any window when a Scene is left, and a toast on every switch teaches the user to
    /// ignore toasts — including the one that says their borrowed chat window went home. A silent leave is the
    /// design, not an omission.
    ///
    /// Admission refusals are the one row of the table this build still cannot honestly report: nothing in
    /// v0.1.0 admits a window it was not told about, so a message about ignoring one would be a promise in the
    /// code with nothing behind it. Everything else here is posted by something.
    enum SceneShellMessage: Equatable, Sendable {
        /// A Scene is now the one on screen, and this is its size.
        case entered(sceneTitle: String, slots: Int, windows: Int)
        /// Windows a Scene used to hold are gone, so it came back smaller than it left.
        case attachmentsDropped(sceneTitle: String, windows: Int)
        /// Borrowed windows are back where they came from — the one thing closing a Scene must confirm.
        ///
        /// One message per Home, and it names the applications. `2 windows went back to Communication` alone
        /// would leave the user checking which two; naming them is what makes the line verifiable at a glance,
        /// and an application name is the only window fact SceneMux is willing to show (invariant I11).
        case windowsRestored(home: SemanticHome, applications: [String])
        /// State could not be read, so there are no Scenes and nothing was moved.
        case stateUnreadable(details: String)

        /// The line the HUD shows.
        var text: String {
            switch self {
                case .entered(let title, let slots, let windows):
                    "\(title) · \(count(slots, "slot")), \(count(windows, "window"))"
                case .windowsRestored(let home, let applications):
                    "\(count(applications.count, "window")) went back to \(home.displayName)"
                        + " — \(applications.joined(separator: ", "))"
                case .attachmentsDropped(let title, let windows):
                    "\(count(windows, "window")) from “\(title)” \(windows == 1 ? "is" : "are") no longer open"
                case .stateUnreadable:
                    "Scene state couldn’t be read — no windows were changed"
            }
        }

        /// The longer explanation behind a *Show details* affordance, when there is one.
        ///
        /// Only the unreadable case has one, and it is the diagnostic itself — the path, the cause, and the
        /// place the original bytes were kept. That belongs behind a disclosure rather than in the HUD line:
        /// a file path in a 2.5-second toast is unreadable in the other sense of the word.
        var details: String? {
            switch self {
                case .stateUnreadable(let details): details
                case .entered, .attachmentsDropped, .windowsRestored: nil
            }
        }

        var showsDetails: Bool { details != nil }

        /// Whether a screen-reader user is told without having to be looking at the HUD.
        ///
        /// Refusals and recoveries announce, because they are about state or windows the user did not ask
        /// about. Entering a Scene does not: the user just pressed the key that did it, and the menu bar title
        /// and the focused window have already changed.
        var announces: Bool {
            switch self {
                case .entered: false
                case .attachmentsDropped, .stateUnreadable, .windowsRestored: true
            }
        }

        /// What the user is owed as soon as SceneMux starts, given how reading state went.
        ///
        /// Ordered refusal first, then one message per Scene that lost windows, because a refusal is about
        /// *all* of their Scenes and cannot be queued behind a note about one of them. Nothing is merged
        /// across Scenes: "2 windows are no longer open" without saying which task they belonged to would
        /// leave the user checking every Scene by hand.
        static func onStartup(
            refusal: SceneStateRefusal?,
            quarantined: [SceneStateQuarantine],
        ) -> [SceneShellMessage] {
            var messages = refusal.map { [SceneShellMessage.stateUnreadable(details: $0.diagnostic)] } ?? []
            var countsByTitle: [String: Int] = [:]
            var titlesInOrder: [String] = []
            for entry in quarantined {
                if countsByTitle[entry.sceneTitle] == nil { titlesInOrder.append(entry.sceneTitle) }
                countsByTitle[entry.sceneTitle, default: 0] += 1
            }
            messages += titlesInOrder.map { title in
                .attachmentsDropped(sceneTitle: title, windows: countsByTitle[title] ?? 0)
            }
            return messages
        }

        private func count(_ n: Int, _ noun: String) -> String {
            "\(n) \(noun)\(n == 1 ? "" : "s")"
        }
    }
}
