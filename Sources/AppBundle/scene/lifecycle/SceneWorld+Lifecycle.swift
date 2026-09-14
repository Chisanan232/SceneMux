import Foundation

/// The Scene lifecycle, as the one place it is decided.
///
/// Every transition in the table of `docs/design/scene-core-architecture.md` is a method here, and nothing
/// else in SceneMux may change a Scene's state. That is the point of the file: a lifecycle spread across a
/// menu handler, a hotkey, and a sidebar controller is a lifecycle with three slightly different ideas of
/// what closing a Scene means.
///
/// Nothing here touches a window. These operations produce the world afterwards, and — for a close — the
/// plan describing what the windows are owed. Carrying that plan out is somebody else's job, and it reports
/// back through `resolving(_:for:in:)`.
extension SceneCore.SceneWorld {
    /// A new Scene, `defined` and empty, plus the world containing it.
    ///
    /// It arrives with no substrate and no windows because it cannot arrive any other way: there is no
    /// operation that adds a ready-made Scene to a world, so nothing can enter the world already claiming
    /// to be on screen and skip the one-active-Scene rule.
    func creating(
        title: String,
        slots: [SceneCore.Slot] = [],
    ) throws -> (world: Self, scene: SceneCore.Scene) {
        let scene = try SceneCore.Scene(
            id: .generate(),
            title: title,
            slots: slots,
            attachments: [],
            state: .defined,
        )
        return (try SceneCore.SceneWorld(scenes: scenes + [scene]), scene)
    }

    /// Put this Scene on screen, projected onto `substrate`.
    ///
    /// Entering the Scene that is already there is a no-op, not an error — the same hotkey pressed twice, or
    /// a click on the Scene already showing, must not disturb anything. Entering it onto a *different*
    /// substrate is a re-projection, expressed as a leave and an enter because that is exactly what it is:
    /// the old binding is dropped before the new one is made, and every attachment survives untouched.
    ///
    /// While another Scene is active this refuses rather than swapping them. v0.1.0 shows one task at a
    /// time, and quietly leaving somebody's current Scene as a side effect of entering another is a decision
    /// the user should make and see.
    func entering(_ id: SceneCore.SceneId, on substrate: SceneCore.SubstrateBinding) throws -> Self {
        guard let scene = scene(id) else {
            throw SceneCore.SceneLifecycleError.unknownScene(id)
        }
        if case .active(let current) = scene.state {
            return current == substrate ? self : try leaving(id).entering(id, on: substrate)
        }
        if let active = activeScene {
            throw SceneCore.SceneLifecycleError.anotherSceneIsActive(active.id)
        }
        return try replacing(try scene.transitioning(to: .active(substrate)))
    }

    /// Take this Scene off screen, and do nothing else whatsoever.
    ///
    /// No window is moved, restored or closed — that is the whole design of `leave`. Someone switching away
    /// from a task and back again would otherwise watch their chat window be dragged across the desktop and
    /// back, twice, for nothing. The Scene keeps every attachment: it is still *about* those windows, it is
    /// simply not being drawn.
    ///
    /// Leaving a Scene that is not on screen is the state the caller asked for, so it is a no-op.
    func leaving(_ id: SceneCore.SceneId) throws -> Self {
        guard let scene = scene(id) else {
            throw SceneCore.SceneLifecycleError.unknownScene(id)
        }
        guard scene.state.label == .active else { return self }
        return try replacing(try scene.transitioning(to: .defined))
    }
}
