@testable import AppBundle
import Foundation

/// A `SceneEnginePort` that builds nothing and remembers everything.
///
/// The seam exists partly so that the order of operations can be tested without a desktop: which Slots were
/// offered to the engine, in which order, and what the projector made of the answers. Every reply is
/// configurable because the interesting cases — a workspace that cannot be used, a window that is not there,
/// an engine that normalized the layout into something else — are all things a real Mac does at times of its
/// own choosing.
///
/// The real implementation is `WinMuxSceneEngineAdapter`, verified against a real tree in
/// `WinMuxSceneEngineAdapterTest`. This one deliberately imitates nothing about it beyond the protocol.
@MainActor
final class RecordingSceneEnginePort: SceneCore.SceneEnginePort {
    /// The Slots handed over, in the order they were handed over.
    private(set) var placedGroups: [SceneCore.SceneLayoutGroup] = []
    private(set) var preparedSubstrates: [SceneCore.SubstrateBinding] = []
    private(set) var settledSubstrates: [SceneCore.SubstrateBinding] = []

    /// Whether the substrate is usable at all.
    var substrateIsUsable = true
    /// Windows the engine cannot see — quit, or on another Space.
    var invisibleWindows: Set<SceneCore.WindowRef> = []
    /// What the engine claims each Slot's composition became once it had normalized things.
    var settledCompositions: [SceneCore.SlotId: SceneCore.SlotComposition] = [:]
    /// Slots the engine declines, in its own words.
    var refusals: [SceneCore.SlotId: String] = [:]

    /// Where the engine says a Scene would be drawn, or nothing when it says there is nowhere.
    var substrate: SceneCore.SubstrateBinding? = SceneCore.SubstrateBinding(workspaceName: "3")
    /// The window the engine says the user is looking at. Nothing, unless a test says otherwise — mounting
    /// "the focused window" when there is none has to be a case the caller handles.
    var focused: SceneCore.WindowRef?
    /// Where the engine says each window currently lives. A window absent from this has no surface, which is
    /// the "nothing to go back to" case.
    var surfaces: [SceneCore.WindowRef: SceneCore.SubstrateBinding] = [:]

    func currentSubstrate() -> SceneCore.SubstrateBinding? {
        substrate
    }

    func focusedWindow() -> SceneCore.WindowRef? {
        focused
    }

    func surface(of windowRef: SceneCore.WindowRef) -> SceneCore.SubstrateBinding? {
        surfaces[windowRef]
    }

    func prepareSubstrate(_ binding: SceneCore.SubstrateBinding) -> Bool {
        preparedSubstrates.append(binding)
        return substrateIsUsable
    }

    func place(
        _ group: SceneCore.SceneLayoutGroup,
        on binding: SceneCore.SubstrateBinding,
    ) -> SceneCore.SceneSlotPlacement {
        placedGroups.append(group)
        if let reason = refusals[group.slotId] {
            return .refused(reason)
        }
        let missing = group.windows.filter { invisibleWindows.contains($0) }
        guard missing.count < group.windows.count else { return .windowsMissing(missing) }
        return missing.isEmpty
            ? .realised(group.composition)
            : .partlyRealised(group.composition, missing: missing)
    }

    func settle(_ binding: SceneCore.SubstrateBinding) -> [SceneCore.SlotId: SceneCore.SlotComposition] {
        settledSubstrates.append(binding)
        return settledCompositions
    }
}
