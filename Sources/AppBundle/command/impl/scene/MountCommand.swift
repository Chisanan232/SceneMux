import AppKit
import Common

/// `mount` — put the focused window into a Slot of the Scene on screen.
///
/// The command that makes the Phase 1 distinction operable rather than merely presentable: until something can
/// attach a window, "borrowed" is a word in a row that will never be drawn. It is also the only path in
/// SceneMux that creates an attachment, so ownership is decided exactly once, from the verb the person used —
/// `mount` borrows, `mount --own` attaches — and never inferred from the window's Home or the Slot's role.
///
/// What it does not do is change what the window is *for*. The Home in the reply is read from the Home rules,
/// which cannot see Scenes at all; the mount is recorded beside it. That is invariant I1, and the reply says
/// both facts in one sentence so the person can see they are separate.
struct MountCommand: Command {
    let args: MountCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false
    /*conforms*/ let canSkipPostCommandRefresh = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let runtime = SceneCore.SceneRuntime.shared
        do {
            let slot = try runtime.slot(numbered: args.slotNumber.orDie())
            let window = try runtime.mount(into: slot.id, ownership: args.own ? .sceneOwned : .borrowed)
            guard args.own else {
                return io.out(
                    "Mounted \(window.applicationName) into the \(slot.title) slot. "
                        + "Its Home is still \(window.home.displayName), and it goes back when the Scene closes.",
                )
            }
            return io.out(
                "Attached \(window.applicationName) to the \(slot.title) slot. "
                    + "This Scene owns it; its Home is still \(window.home.displayName).",
            )
        } catch let error as SceneCore.SceneRuntimeError {
            return io.err(error.description)
        } catch let error as SceneCore.SceneLifecycleError {
            return io.err(error.description)
        } catch let error as SceneCore.SceneCoreError {
            return io.err(error.description)
        }
    }
}
