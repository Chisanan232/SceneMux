import Foundation

extension SceneCore {
    /// Every Scene SceneMux knows about, and the rules that hold across all of them.
    ///
    /// A `Scene` validates itself; this validates the things one Scene cannot see. Identities are unique,
    /// and at most one Scene is `active` — v0.1.0 projects one task onto the screen at a time, and that
    /// limit is a property of this value rather than a check some controller remembers to run.
    ///
    /// A value type, so every lifecycle operation is "here is the world afterwards" and the caller decides
    /// when to keep it. There is no partially-applied world: an operation either produces one that satisfies
    /// every rule or throws, which is what lets the orchestrator save after each one and know that what it
    /// saved makes sense.
    struct SceneWorld: Equatable, Sendable {
        /// The Scenes, in the order they were created. Order is the user's, not a set's.
        let scenes: [Scene]

        /// No Scenes at all: a first run, and the fail-safe answer to state this build will not act on.
        static let empty = SceneWorld()

        private init() {
            scenes = []
        }

        init(scenes: [Scene]) throws {
            var seenIds: Set<SceneId> = []
            for scene in scenes {
                if !seenIds.insert(scene.id).inserted {
                    throw SceneLifecycleError.duplicateSceneId(scene.id)
                }
            }
            if scenes.filter({ $0.state.label == .active }).count > 1 {
                throw SceneLifecycleError.moreThanOneActiveScene
            }
            self.scenes = scenes
        }

        /// The Scene with this identity, if the world has it.
        func scene(_ id: SceneId) -> Scene? {
            scenes.first { $0.id == id }
        }

        /// The Scene currently projected onto a substrate, if any. At most one, by construction.
        var activeScene: Scene? {
            scenes.first { $0.state.label == .active }
        }

        /// The Scenes part-way through closing, in world order.
        ///
        /// After a restart this is the work list: each one still holds the attachments whose restores have
        /// not happened yet, and that is the durable record of what the app promised to do.
        var closingScenes: [Scene] {
            scenes.filter { $0.state.label == .ending }
        }

        /// This world with one Scene replaced by a new version of itself.
        ///
        /// Every operation goes through here, so none of them can lose a Scene, reorder the list, or leave
        /// two Scenes active — the rules are re-checked on the way out rather than reasoned about at each
        /// call site.
        func replacing(_ scene: Scene) throws -> Self {
            guard scenes.contains(where: { $0.id == scene.id }) else {
                throw SceneLifecycleError.unknownScene(scene.id)
            }
            return try SceneWorld(scenes: scenes.map { $0.id == scene.id ? scene : $0 })
        }
    }
}
