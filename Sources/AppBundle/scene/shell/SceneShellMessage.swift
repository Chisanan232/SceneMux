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
        /// A borrowed window was not sent home, and the user is told which one and that nothing broke.
        ///
        /// Covers both ways a restore can not happen: there was nowhere to put the window, or the attempt
        /// failed and is still owed. The sentence is the same either way because from the user's side the fact
        /// is the same — this window did not move, and nothing was closed to make it move. Which of the two it
        /// was is visible where it belongs: a Scene that is still owed a restore stays `restoring…`.
        case restoreDeclined(applicationName: String)
        /// The Scene's own windows are still open, said out loud because the opposite is what people fear.
        ///
        /// "Closing a task closed my editor" is the failure this product would never recover from, so ending a
        /// Scene states the non-event explicitly (invariant I6). Counted rather than named: these are the
        /// windows the user was looking at a moment ago, and listing four application names to say that
        /// nothing happened to them would bury the line that says what did.
        case windowsLeftInPlace(windows: Int)
        /// The user tried to do something to a shared window, and SceneMux did not.
        ///
        /// Posted only on an attempt. A shared window is one the user declared is nobody's task — a music
        /// player, a personal browser — and reporting that it was skipped every time a Scene ends would be a
        /// notification about a window that is deliberately never involved. Silence is correct until somebody
        /// asks, and then a refusal has to be explained or the click looks broken (invariant I7).
        case sharedWindowSkipped(applicationName: String)
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
                case .restoreDeclined(let applicationName):
                    "\(applicationName) could not be found — nothing was closed or moved"
                case .windowsLeftInPlace(let windows):
                    "\(count(windows, "window")) left in place"
                case .sharedWindowSkipped(let applicationName):
                    "\(applicationName) is shared — left untouched"
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
                case .entered, .attachmentsDropped, .windowsRestored, .restoreDeclined,
                     .windowsLeftInPlace, .sharedWindowSkipped: nil
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
                case .attachmentsDropped, .stateUnreadable, .windowsRestored, .restoreDeclined,
                     .windowsLeftInPlace, .sharedWindowSkipped: true
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

        /// What the user is owed when a Scene has just been closed and its steps carried out.
        ///
        /// Ordered the way the outcome matters: what went home first, because reversing the borrow is the thing
        /// closing a Scene promised; then any window that did not go, named; then the count of windows that were
        /// deliberately left alone. A `windowIsGone` says nothing at all — a window the user closed themselves
        /// during a task is not news, and reporting it would make the list unreadable exactly when it matters.
        ///
        /// Restores are grouped by the Home they went back to, and the Home is resolved from the rules rather
        /// than from the attachment: the line says where the windows are now, which is the only claim it can
        /// make that the user can check by looking.
        static func onClose(
            _ plan: SceneTeardownPlan,
            outcomes: [WindowRef: SceneTeardownOutcome],
            homes: HomeRules,
            naming: ApplicationNaming,
        ) -> [SceneShellMessage] {
            func name(_ windowRef: WindowRef) -> String {
                naming(windowRef.bundleId) ?? windowRef.bundleId
            }

            var restoredByHome: [SemanticHome: [String]] = [:]
            var homesInOrder: [SemanticHome] = []
            var messages: [SceneShellMessage] = []
            for step in plan.pending {
                switch outcomes[step.windowRef] {
                    case .restored:
                        let home = homes.home(of: step.windowRef)
                        if restoredByHome[home] == nil { homesInOrder.append(home) }
                        restoredByHome[home, default: []].append(name(step.windowRef))
                    case .leftInPlace, .failed:
                        messages.append(.restoreDeclined(applicationName: name(step.windowRef)))
                    case .windowIsGone, nil:
                        continue
                }
            }
            messages = homesInOrder.map {
                .windowsRestored(home: $0, applications: restoredByHome[$0] ?? [])
            } + messages
            if !plan.cleanupCandidates.isEmpty {
                messages.append(.windowsLeftInPlace(windows: plan.cleanupCandidates.count))
            }
            return messages
        }

        private func count(_ n: Int, _ noun: String) -> String {
            "\(n) \(noun)\(n == 1 ? "" : "s")"
        }
    }
}
