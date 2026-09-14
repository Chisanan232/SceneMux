import Foundation

extension SceneCore {
    /// Everything closing one Scene means for the windows in it, stated before anything is done.
    ///
    /// The plan is the whole answer, including the windows nothing happens to. That is deliberate: "SceneMux
    /// will send LINE and Slack home, leave your terminal and your IDE exactly where they are, and not touch
    /// your music player" is a sentence a person can check, and a shell that shows it before acting is the
    /// difference between a tool that closes a task and one that rearranges a desktop.
    ///
    /// It also carries no completion state. What has already happened is recorded where it cannot be lost —
    /// in the Scene's remaining attachments — so a plan is always freshly derived and a restart part-way
    /// through teardown simply derives a shorter one.
    struct SceneTeardownPlan: Equatable, Sendable {
        /// The Scene being closed.
        let sceneId: SceneId
        /// Its title, so a message about this plan can name the task the way its owner does.
        let sceneTitle: String
        /// Every window in the Scene, in the order it was attached.
        let steps: [SceneTeardownStep]

        /// The steps somebody still has to carry out: the borrowed windows, in attachment order.
        var pending: [SceneTeardownStep] {
            steps.filter(\.needsWork)
        }

        /// The windows the Scene created or claimed, which teardown leaves exactly where they are.
        ///
        /// Cleanup of these is a separate, explicitly confirmed, per-window user action — never a teardown
        /// effect (invariant I6). The shell reads this to offer it; nothing here performs it.
        var cleanupCandidates: [SceneTeardownStep] {
            steps.filter { $0.effect == .leaveInPlace }
        }

        init(_ scene: Scene) {
            sceneId = scene.id
            sceneTitle = scene.title
            steps = scene.attachments.map(SceneTeardownStep.init)
        }
    }
}
