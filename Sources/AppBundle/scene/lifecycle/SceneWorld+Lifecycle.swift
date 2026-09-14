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

    /// Begin ending this Scene, and state what ending it means for every window in it.
    ///
    /// Two things happen here, in this order for a reason. The plan is derived first, from the Scene as it
    /// stands, so it names every window — including the ones nothing will happen to. Then the world afterwards
    /// drops the attachments that are already discharged: a window whose effect is `leaveInPlace` or
    /// `untouched` is finished the moment that is said, and leaving it attached would mean a restart deciding
    /// it again.
    ///
    /// A Scene with nothing pending reaches `ended` inside this one operation. There is nobody to report back
    /// about a Scene of only scene-owned and shared windows, so waiting for a report would leave it closing
    /// forever.
    ///
    /// Closing a Scene that is already closing re-derives its plan and changes nothing else, which is what
    /// makes an interrupted teardown resumable: the remaining attachments are the work that is left, and
    /// asking again is always safe. Closing one that has ended returns its now-empty plan.
    func closing(_ id: SceneCore.SceneId) throws -> (world: Self, plan: SceneCore.SceneTeardownPlan) {
        guard let scene = scene(id) else {
            throw SceneCore.SceneLifecycleError.unknownScene(id)
        }
        let plan = SceneCore.SceneTeardownPlan(scene)
        guard scene.state.label != .ended else { return (self, plan) }

        var closing = try scene.transitioning(to: .ending)
        for step in plan.steps where !step.needsWork {
            closing = try closing.detaching(step.windowRef)
        }
        if plan.pending.isEmpty {
            closing = try closing.transitioning(to: .ended)
        }
        return (try replacing(closing), plan)
    }

    /// Record what happened to one window of a closing Scene.
    ///
    /// A final outcome discharges the attachment, so it is dropped — and once the last pending attachment is
    /// gone the Scene reaches `ended` here, in the same operation that discharged it. A `failed` outcome
    /// changes nothing at all: the attachment stays, which is both the record that the restore is still owed
    /// and the instruction to try again, including after a quit and a relaunch.
    ///
    /// That is the whole re-entrancy mechanism, and it is why there is no retry counter and no separate list of
    /// finished steps to keep in step with the Scene. The same report arriving twice is a no-op, because the
    /// attachment it was about is already gone.
    ///
    /// An outcome for a Scene that is not closing is discarded rather than applied. The only ways to get here
    /// are a duplicated report and a report that arrives after the close finished, and neither is a reason to
    /// detach a window from a Scene somebody is using.
    func resolving(
        _ outcome: SceneCore.SceneTeardownOutcome,
        for windowRef: SceneCore.WindowRef,
        in id: SceneCore.SceneId,
    ) throws -> Self {
        guard let scene = scene(id) else {
            throw SceneCore.SceneLifecycleError.unknownScene(id)
        }
        guard scene.state.label == .ending, outcome.isFinal else { return self }

        var closing = try scene.detaching(windowRef)
        if SceneCore.SceneTeardownPlan(closing).pending.isEmpty {
            closing = try closing.transitioning(to: .ended)
        }
        return try replacing(closing)
    }

    /// Every teardown that has not finished, as plans, in world order.
    ///
    /// This is what SceneMux reads at startup. A Scene left `ending` by a quit, a crash or a machine going to
    /// sleep still holds the attachments whose restores never happened, so deriving a plan from it produces
    /// exactly the work that remains — never the work already done. Someone whose laptop died mid-teardown
    /// finds their borrowed chat window sent home on the next launch instead of stranded in a Scene that no
    /// longer exists.
    var unfinishedTeardowns: [SceneCore.SceneTeardownPlan] {
        closingScenes.map(SceneCore.SceneTeardownPlan.init)
    }
}
