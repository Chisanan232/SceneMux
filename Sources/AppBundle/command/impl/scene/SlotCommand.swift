import AppKit
import Common

/// `slot` — the Slots of the Scene on screen.
///
/// Every subcommand applies to the active Scene and refuses when there is none, because a Slot has no meaning
/// on its own: it is a named place *in a task*. Adding and removing a Slot moves no window; composing one
/// changes how the windows in it share their region and is projected immediately, so the screen and the list
/// never disagree.
///
/// The role is parsed here rather than by the argument parser: the role vocabulary belongs to the Scene domain,
/// which the parser's module cannot see. A wrong role therefore fails with the list of real roles instead of a
/// generic parse error.
struct SlotCommand: Command {
    let args: SlotCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false
    /*conforms*/ let canSkipPostCommandRefresh = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let runtime = SceneCore.SceneRuntime.shared
        do {
            switch args.target.val {
                case .list:
                    return try list(runtime, io)
                case .new:
                    return try new(runtime, io)
                case .compose:
                    let row = try runtime.slot(numbered: args.slotNumber.orDie())
                    let slot = try runtime.cycleComposition(of: row.id)
                    // The composition that was asked for, and then whatever the engine's normalization made of
                    // it. Printing only the first would claim a shape the screen may not have.
                    return io.out(
                        ["\(row.title) slot is now \(slot.composition)."] + runtime.projectionDiagnostics,
                    )
                case .remove:
                    let row = try runtime.slot(numbered: args.slotNumber.orDie())
                    try runtime.removeSlot(row.id)
                    return io.out("Removed the \(row.title) slot. No window moved.")
            }
        } catch let error as SceneCore.SceneRuntimeError {
            return io.err(error.description)
        } catch let error as SceneCore.SceneLifecycleError {
            return io.err(error.description)
        } catch let error as SceneCore.SceneCoreError {
            return io.err(error.description)
        }
    }

    @MainActor
    private func list(_ runtime: SceneCore.SceneRuntime, _ io: CmdIo) throws -> Bool {
        guard let scene = runtime.snapshot.activeScene else {
            throw SceneCore.SceneRuntimeError.noActiveScene
        }
        if args.json {
            let payload: [[String: Primitive]] = scene.slots.map { row in
                [
                    "slot-number": .int(row.index),
                    "slot-title": .string(row.title),
                    "slot-role": .string(row.role.rawValue),
                    "slot-composition": .string(row.composition.description),
                    "window-count": .int(row.windows.count),
                ]
            }
            return JSONEncoder.winMuxDefault.encodeToString(payload).map(io.out)
                ?? io.err("Failed to encode JSON")
        }
        guard !scene.slots.isEmpty else {
            return io.out("\(scene.title) has no slots yet. Add one with 'slot new --role editor'.")
        }
        let rows: [[String]] = scene.slots.map { row in
            ["\(row.index)", row.title, row.trailing]
        }
        // A count is of the windows attached to the Slot, and an attachment can outlive the window — that is the
        // persistence model, not a bug. What is a bug is the person having no way to tell: HORO-1109 quit an
        // application mid-Scene and the table went on saying "2 windows" about a Slot with one window in it.
        return io.out(rows.toPaddingTable(columnSeparator: "   ") + runtime.unseenWindowDiagnostics)
    }

    @MainActor
    private func new(_ runtime: SceneCore.SceneRuntime, _ io: CmdIo) throws -> Bool {
        let raw = args.role.orDie()
        guard let role = SceneCore.SlotRole(rawValue: raw) else {
            return io.err(
                "Can't parse role '\(raw)'.\n"
                    + "Possible values: \(SceneCore.SlotRole.allCases.map(\.rawValue).joined(separator: "|"))",
            )
        }
        let slot = try runtime.addSlot(role: role, label: args.label)
        return io.out("Added a \(slot.displayName) slot to \(runtime.snapshot.activeScene?.title ?? "the Scene").")
    }
}
