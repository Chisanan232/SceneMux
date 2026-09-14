import Foundation

extension SceneCore {
    /// One Scene that was in the state file, parsed as far as its own shape, and then refused by the domain.
    ///
    /// The narrower case the architecture document calls *quarantine*: state that parsed but describes
    /// something impossible — an attachment to a `SlotId` the Scene does not have, a window attached twice.
    /// The rest of the file is fine, so the rest of the file loads, and this Scene is set aside with the
    /// reason instead of being loaded half-formed.
    ///
    /// Why a whole Scene and not the offending attachment: a `Scene` cannot exist in an invalid state at all
    /// — its initialiser refuses one, and its decoder runs the same validation — so there is no partly-valid
    /// Scene to keep. Dropping the attachment instead would silently discard a *permission* record, which is
    /// the accident `Scene.removingSlot` refuses a non-empty Slot to prevent. Either way no window is
    /// touched: a quarantined Scene owns nothing, so nothing is restored, moved or closed on its behalf.
    struct SceneStateQuarantine: Equatable, Sendable {
        /// Which entry of the file's `scenes` array it was. The id is not usable — the Scene did not decode.
        let index: Int
        /// Where the decode gave up, in field names and indices only, when the decoder said.
        let codingPath: String?
        /// The domain's own reason, when it was the domain that refused rather than the shape.
        let refusedBy: SceneCoreError?

        /// One line for the user: which Scene was set aside, and why.
        var diagnostic: String {
            "Scene \(index) in the state file was set aside: \(explanation) Its windows were left alone."
        }

        private var explanation: String {
            if let refusedBy {
                "\(refusedBy)."
            } else if let codingPath {
                "it does not describe a usable Scene, at \(codingPath)."
            } else {
                "it does not describe a usable Scene."
            }
        }
    }
}
