@testable import AppBundle
import Foundation

/// Valid Scene Core values, so that a test asserting one thing does not have to spell out the other four.
///
/// Every factory returns something the domain accepts, and every parameter has a default. A test that cares
/// about ownership overrides ownership and nothing else, which keeps what it is testing visible in its own
/// first two lines.
enum SceneCoreFixtures {
    /// The applications of the golden journey, by bundle id. Ordinary desktop applications, deliberately —
    /// the journey has to work for the tools people already have open.
    enum App {
        static let terminal = "com.apple.Terminal"
        static let ide = "com.jetbrains.intellij"
        static let browser = "com.google.Chrome"
        static let grafana = "com.grafana.grafana"
        static let line = "com.linecorp.LINE"
        static let slack = "com.tinyspeck.slackmacgap"
        static let music = "com.apple.Music"
    }

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
        originSurface: SceneCore.SubstrateBinding? = nil,
        origin: SceneCore.AttachmentOrigin = .userAction,
    ) -> SceneCore.Attachment {
        SceneCore.Attachment(
            windowRef: windowRef,
            slotId: slotId,
            ownership: ownership,
            homeAtAttachTime: homeAtAttachTime,
            originSurface: originSurface,
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

    /// Where the journey's borrowed chat windows were living before the Scene borrowed them, and so where
    /// closing it has to put them back.
    static let communicationSurface = SceneCore.SubstrateBinding(workspaceName: "2")

    /// The workspace a Scene is drawn on. The same one `RecordingSceneEnginePort` offers by default, so that a
    /// test about admission and a test about the runtime are talking about the same screen.
    static let activeSubstrate = SceneCore.SubstrateBinding(workspaceName: "3")

    /// A window the engine has just detected, described the way admission is allowed to see it.
    ///
    /// The Home is resolved from the shipped rules rather than passed in, so that a test naming
    /// `App.terminal` is testing what a terminal really resolves to instead of what the test believed it
    /// resolved to — and so that a change to the shipped table is visible here.
    static func admissionCandidate(
        _ bundleId: String = App.terminal,
        ordinal: Int = 0,
        kind: SceneCore.AdmissionWindowKind = .managed,
        surface: SceneCore.SubstrateBinding? = activeSubstrate,
        detectedDuringStartup: Bool = false,
        home: SceneCore.SemanticHome? = nil,
        in activeScene: SceneCore.Scene? = nil,
        isAlreadyInAScene: Bool = false,
    ) throws -> SceneCore.AdmissionCandidate {
        let windowRef = try self.windowRef(bundleId, ordinal: ordinal)
        return SceneCore.AdmissionCandidate(
            subject: SceneCore.AdmissionSubject(
                windowRef: windowRef,
                kind: kind,
                surface: surface,
                detectedDuringStartup: detectedDuringStartup,
            ),
            home: home ?? SceneCore.HomeRules.shippedOnly.home(of: windowRef),
            activeScene: activeScene,
            isAlreadyInAScene: isAlreadyInAScene,
        )
    }

    /// The golden journey of `docs/design/scene-core-ux.md` as one Scene: "Debug PROD-123", five Slots and
    /// six windows. The terminal and the IDE are part of the task, the dashboard and the preview browser were
    /// opened for it, LINE and Slack were lent to it for the duration, and the music player is not in it.
    ///
    /// Shared rather than copied, so that a test about persistence and a test about teardown are talking
    /// about the same journey — and so that changing the journey breaks both of them at once.
    static func debugScene(state: SceneCore.SceneState = .defined) throws -> SceneCore.Scene {
        let terminal = slot(role: .terminal, order: 0)
        let editor = slot(role: .editor, order: 1)
        let preview = slot(role: .preview, order: 2)
        let observability = slot(role: .observability, order: 3)
        let comms = slot(role: .communication, composition: .tabbed, order: 4)

        return try scene(slots: [terminal, editor, preview, observability, comms], state: state)
            .attaching(attachment(
                windowRef: try windowRef(App.terminal),
                slotId: terminal.id,
                ownership: .sceneOwned,
            ))
            .attaching(attachment(
                windowRef: try windowRef(App.ide),
                slotId: editor.id,
                ownership: .sceneOwned,
            ))
            .attaching(attachment(
                windowRef: try windowRef(App.browser),
                slotId: preview.id,
                ownership: .sceneOwned,
                homeAtAttachTime: .personal,
            ))
            .attaching(attachment(
                windowRef: try windowRef(App.grafana),
                slotId: observability.id,
                ownership: .sceneOwned,
                homeAtAttachTime: .observability,
            ))
            .attaching(attachment(
                windowRef: try windowRef(App.line),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
                originSurface: communicationSurface,
            ))
            .attaching(attachment(
                windowRef: try windowRef(App.slack),
                slotId: comms.id,
                ownership: .borrowed,
                homeAtAttachTime: .communication,
                originSurface: communicationSurface,
            ))
    }
}
