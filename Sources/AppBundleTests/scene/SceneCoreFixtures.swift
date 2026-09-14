@testable import AppBundle
import Foundation

/// Valid Scene Core values, so that a test asserting one thing does not have to spell out the other four.
///
/// Every factory returns something the domain accepts, and every parameter has a default. A test that cares
/// about ownership overrides ownership and nothing else, which keeps what it is testing visible in its own
/// first two lines.
enum SceneCoreFixtures {
    static func windowRef(
        _ bundleId: String = "com.apple.Terminal",
        ordinal: Int = 0,
    ) throws -> SceneCore.WindowRef {
        try SceneCore.WindowRef(bundleId: bundleId, ordinalWithinApp: ordinal)
    }

    static func slot(
        id: SceneCore.SlotId = .generate(),
        role: SceneCore.SlotRole = .terminal,
        label: String? = nil,
        composition: SceneCore.SlotComposition = .single,
        order: Int = 0,
    ) -> SceneCore.Slot {
        SceneCore.Slot(id: id, role: role, label: label, composition: composition, order: order)
    }

    static func attachment(
        windowRef: SceneCore.WindowRef,
        slotId: SceneCore.SlotId,
        ownership: SceneCore.Ownership = .sceneOwned,
        homeAtAttachTime: SceneCore.SemanticHome = .development,
        origin: SceneCore.AttachmentOrigin = .userAction,
    ) -> SceneCore.Attachment {
        SceneCore.Attachment(
            windowRef: windowRef,
            slotId: slotId,
            ownership: ownership,
            homeAtAttachTime: homeAtAttachTime,
            origin: origin,
        )
    }

    static func scene(
        id: SceneCore.SceneId = .generate(),
        title: String = "Debug PROD-123",
        slots: [SceneCore.Slot] = [],
        attachments: [SceneCore.Attachment] = [],
        state: SceneCore.SceneState = .defined,
    ) throws -> SceneCore.Scene {
        try SceneCore.Scene(id: id, title: title, slots: slots, attachments: attachments, state: state)
    }
}
