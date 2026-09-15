import Foundation

extension SceneCore {
    /// The G1 rules: given a detected window and the Scene on screen, what should happen to it.
    ///
    /// One function, and it decides by declining. Every guard below answers `.ignore`, and only the last few
    /// lines can answer anything else — which is the shape "fail safe" has to have if it is going to survive
    /// people adding rules to it. An unrecognised window is not floated, not quarantined and not tiled
    /// somewhere plausible; it is left exactly where the inherited engine left it.
    ///
    /// Precedence is the order of the guards, and it is the part worth reading. In the order they are checked,
    /// `decide` declines:
    ///
    /// 1. anything that is not an ordinary managed window — a dialog, a popup or a minimized window is not
    ///    the work;
    /// 2. anything detected during startup — a Scene is still `active` after a relaunch, and startup is the
    ///    engine taking stock rather than a person opening a window;
    /// 3. a window already in a Scene — invariant I4, and what makes a second look at the same window
    ///    harmless;
    /// 4. every window, when no Scene is on screen — there is no intent to serve, which is the ordinary case;
    /// 5. a window that is not on the Scene's own workspace — somebody switched workspaces with the Scene
    ///    still open, and pulling their new window across would move it out from under them;
    /// 6. a window whose Home no Slot of this Scene serves, including every `personal` window — see below;
    /// 7. a window with nowhere left to go — every serving Slot is full and none of them is a tab group.
    ///
    /// The same seven, and what the two surviving rules do, are published in
    /// `docs/design/scene-core-architecture.md` under "What v0.1.0 decides, in order".
    ///
    /// Two of the architecture document's stated rules fall out of guard 6 rather than being special cases,
    /// which is why they are hard to break by accident:
    ///
    /// - **A Chrome window is not a Playwright window.** Browsers are `personal` in the Home rules, `personal`
    ///   is served by no Slot role, so no rule here can put a browser window into a Scene. SceneMux has no
    ///   browser-session ownership in v0.1.0 and this is what "has none" looks like in code.
    /// - **An unrecognised normal user window is `ignore`.** An application nobody has classified resolves to
    ///   `HomeRules.fallback`, which is `personal`, which guard 6 declines.
    ///
    /// What it does *not* do is decide finely. A Home says a window is for development; it does not say whether
    /// it is an editor or a terminal, because nothing SceneMux is allowed to read does. So a development window
    /// fills the first empty development Slot in Slot order, and a person who cares which window goes where
    /// mounts it explicitly — an explicit action always outranks a rule.
    enum AdmissionRules {
        /// The rules by name, because a rule id ends up recorded on an attachment and read back by a person
        /// asking why their window moved. Spelled once, here, so the string in the state file and the string in
        /// the test are the same string.
        enum Rule {
            /// The Scene has a place for this kind of window and nothing is in it yet.
            static let emptySlotServingHome = "empty-slot-serving-home"
            /// Every place for this kind of window is taken, but one of them is a tab group, and a tab group is
            /// a place that says "more of these are welcome".
            static let tabGroupServingHome = "tab-group-serving-home"
        }

        /// Which Slot roles serve a Home.
        ///
        /// A switch rather than a table so that adding a fifth Home does not compile until somebody has said
        /// what it serves. `personal` serving nothing is the load-bearing row: it is both the answer for the
        /// applications SceneMux knows are the user's own and the answer for every application it has never
        /// heard of, since `HomeRules.fallback` is `personal`.
        ///
        /// `preview` is deliberately absent. The windows that belong in a preview Slot are browser windows,
        /// browsers are `personal`, and so a preview Slot is filled by an explicit mount and never by a rule.
        /// Guessing otherwise would mean a rule deciding that somebody's browser is part of a task.
        static func roles(serving home: SemanticHome) -> [SlotRole] {
            switch home {
                case .development: [.editor, .terminal]
                case .communication: [.communication]
                case .observability: [.observability]
                case .personal: []
            }
        }

        /// What should happen to this window.
        static func decide(_ candidate: AdmissionCandidate) -> AdmissionDecision {
            let subject = candidate.subject
            guard subject.kind.isEligibleForASlot else { return .ignore }
            guard !subject.detectedDuringStartup else { return .ignore }
            guard !candidate.isAlreadyInAScene else { return .ignore }
            guard let scene = candidate.activeScene,
                  case .active(let substrate) = scene.state
            else { return .ignore }
            guard subject.surface == substrate else { return .ignore }

            let serving = servingSlots(of: scene, for: candidate.home)
            if let empty = serving.first(where: { scene.attachments(in: $0.id).isEmpty }) {
                return .route(slotId: empty.id, ruleId: Rule.emptySlotServingHome)
            }
            if let tabbed = serving.first(where: { $0.composition == .tabbed }) {
                return .tab(slotId: tabbed.id, ruleId: Rule.tabGroupServingHome)
            }
            return .ignore
        }

        /// The Scene's Slots that serve this Home, in the order the person sees them.
        ///
        /// Ordered the way `SceneLayoutPlan` orders them — by `order`, ties keeping the order the Scene stored
        /// them in — because "the first empty development Slot" has to mean the same Slot as the first one on
        /// screen, and two different orderings of the same Slots would eventually disagree.
        private static func servingSlots(of scene: Scene, for home: SemanticHome) -> [Slot] {
            let roles = roles(serving: home)
            return scene.slots.enumerated()
                .filter { roles.contains($0.element.role) }
                .sorted { ($0.element.order, $0.offset) < ($1.element.order, $1.offset) }
                .map(\.element)
        }
    }
}
