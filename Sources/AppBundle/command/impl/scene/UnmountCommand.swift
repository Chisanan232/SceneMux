import AppKit
import Common

/// `unmount` — give the focused window back, one window at a time.
///
/// Reversibility has to be reachable *before* the Scene ends, or "borrowed" is only a promise about the future:
/// somebody who mounted the wrong window needs it back now, and closing the whole task to get it would make the
/// mistake expensive. This is that path, and it goes through the same restorer the lifecycle uses, so the
/// window ends up where closing the Scene would have put it and not somewhere a second implementation guessed.
///
/// It closes nothing, whatever the answer. A restore the application refused stays owed — the window keeps its
/// place in the Scene and asking again is the retry — and a window the Scene was never allowed to move is
/// refused with the reason, on the HUD as well as here.
struct UnmountCommand: Command {
    let args: UnmountCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false
    /*conforms*/ let canSkipPostCommandRefresh = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let runtime = SceneCore.SceneRuntime.shared
        do {
            let (window, outcome) = try runtime.unmountFocusedWindow()
            return switch outcome {
                case .restored:
                    io.out(
                        "\(window.applicationName) went back to where it came from. "
                            + "Its Home is still \(window.home.displayName).",
                    )
                case .windowIsGone:
                    io.out("\(window.applicationName)’s window is gone. It is out of the Scene; nothing was moved.")
                case .leftInPlace(let reason):
                    io.out("\(window.applicationName) was left where it is: \(reason).")
                case .failed(let reason):
                    io.err("\(window.applicationName) could not be moved: \(reason). It is still in the Scene.")
            }
        } catch let error as SceneCore.SceneRuntimeError {
            return io.err(error.description)
        } catch let error as SceneCore.SceneLifecycleError {
            return io.err(error.description)
        } catch let error as SceneCore.SceneCoreError {
            return io.err(error.description)
        }
    }
}
