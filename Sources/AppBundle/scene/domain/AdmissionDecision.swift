import Foundation

extension SceneCore {
    /// What should happen to a window SceneMux has just become aware of — as a value, never as a side effect.
    ///
    /// Admission is a decision, and keeping it a *returned value* is what makes it reviewable: a rule that
    /// moved a window itself could only be tested by watching a screen, and a rule that returns `.ignore` can
    /// be proved to do nothing. The decision and the carrying out of it are two steps on purpose.
    ///
    /// All seven cases exist even though v0.1.0 produces three of them, because the shape of the abstraction
    /// is the part later phases extend — `docs/design/scene-core-architecture.md` records the full set under
    /// "Admission". A partial enum would turn G2's arrival into a source change in every `switch` that reads
    /// one, which is exactly the kind of churn that makes a later phase look like a rewrite.
    ///
    /// What a v0.1.0 rule may actually answer is narrower, and deliberately so:
    ///
    /// | Case | v0.1.0 |
    /// | --- | --- |
    /// | `route`, `tab`, `ignore` | Produced by the G1 rules |
    /// | `mount` | Produced by an explicit user action — `scenemux mount` — not by a rule |
    /// | `claim` | Needs ownership established before the window exists. That is G2 |
    /// | `float` | The inherited engine's own behaviour; no SceneMux decision makes it happen |
    /// | `quarantine` | Reachable from corrupt persisted state, never from a normal user window |
    enum AdmissionDecision: Equatable, Sendable, CustomStringConvertible {
        /// SceneMux takes responsibility for this window's placement and lifecycle in the current Scene,
        /// before anything else has placed it. Requires pre-creation containment, which is admission gate G2.
        case claim(slotId: SlotId, ruleId: String)
        /// Place it in that Slot of the active Scene, as a window the Scene brought into being.
        case route(slotId: SlotId, ruleId: String)
        /// Attach it as `.borrowed`, leaving its Semantic Home alone. What an explicit mount means.
        case mount(slotId: SlotId, ruleId: String)
        /// Add it to that Slot's tab group. The same attachment as `route`; a different shape to arrive in.
        case tab(slotId: SlotId, ruleId: String)
        /// Leave it floating, and do not tile it.
        case float
        /// Not SceneMux's business. The default, and the answer to every question it cannot answer safely.
        case ignore
        /// Something is wrong with what is recorded about this window. Touch nothing, and say so.
        ///
        /// The persistence side of the same idea is `SceneStateQuarantine`, which is the spelling that
        /// actually occurs in v0.1.0: it names the attachment it set aside and the Scene it came from,
        /// because a state file can be read carefully. A window admission cannot make sense of has no such
        /// record to name, so the reason is a sentence.
        case quarantine(reason: String)

        /// Everything recording an attachment needs, or nothing when the decision is to leave the window
        /// alone. One accessor rather than three, so that a caller cannot take the Slot from the decision and
        /// the ownership from somewhere else.
        ///
        /// This is the one place the attaching decisions differ in *ownership*, so that whatever carries a
        /// decision out cannot invent a different answer. `route` and `tab` are `.sceneOwned` because a window
        /// SceneMux first saw while the Scene was open has no earlier place to be sent back to — its own Slot
        /// is where it started — and `.sceneOwned` is the ownership that leaves a window exactly where it is
        /// when the task ends. `mount` is `.borrowed`, which is the whole point of mounting.
        ///
        /// The rule id travels with them because a placement somebody did not expect has to be traceable back
        /// to the rule that caused it: it is recorded as `AttachmentOrigin.admission(ruleId:)` and shown by
        /// the surfaces that explain why a window is where it is.
        ///
        /// `claim` attaches too, in the phase that can produce it. It answers here so that the mapping is
        /// stated once, rather than being rediscovered by whoever implements G2.
        var attachment: (slotId: SlotId, ownership: Ownership, ruleId: String)? {
            switch self {
                case .claim(let slotId, let ruleId): (slotId, .sceneOwned, ruleId)
                case .route(let slotId, let ruleId): (slotId, .sceneOwned, ruleId)
                case .tab(let slotId, let ruleId): (slotId, .sceneOwned, ruleId)
                case .mount(let slotId, let ruleId): (slotId, .borrowed, ruleId)
                case .float, .ignore, .quarantine: nil
            }
        }

        /// Whether carrying this decision out would move a window. Every decision that does not attach also
        /// does not touch anything — which is the property worth being able to assert.
        var movesAWindow: Bool { attachment != nil }

        var description: String {
            switch self {
                case .claim(let slotId, let ruleId): "claim \(slotId) by \(ruleId)"
                case .route(let slotId, let ruleId): "route to \(slotId) by \(ruleId)"
                case .mount(let slotId, let ruleId): "mount into \(slotId) by \(ruleId)"
                case .tab(let slotId, let ruleId): "tab into \(slotId) by \(ruleId)"
                case .float: "float"
                case .ignore: "ignore"
                case .quarantine(let reason): "quarantine (\(reason))"
            }
        }
    }
}
