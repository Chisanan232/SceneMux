import AppKit
import Common

/// `scene` — the whole Scene lifecycle from a keystroke or a shell.
///
/// Every subcommand goes through `SceneCore.SceneRuntime`, which is also what the panels use, so a Scene entered
/// by `ctrl-alt-1` and a Scene entered by `scenemux scene 1` cannot end up meaning two different things.
///
/// Two rules are enforced here rather than in the model. A subcommand that needs a panel asks for one and fails
/// when there is nobody to ask, instead of reporting success against an unchanged screen. And `close` — the one
/// Scene operation that moves someone's windows — never closes on its own: it opens the confirmation, or, with
/// `--yes` for scripts, prints what it is about to do and does it.
struct SceneCommand: Command {
    let args: SceneCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false
    /*conforms*/ let canSkipPostCommandRefresh = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let runtime = SceneCore.SceneRuntime.shared
        do {
            switch args.target.val {
                case .list:
                    return list(runtime, io)
                case .enter(let number):
                    let row = try runtime.scene(numbered: number)
                    try runtime.enter(row.id)
                    return io.out("Entered \(row.title)")
                case .relative(let direction):
                    return try enterRelative(direction, runtime, io)
                case .new:
                    return try new(runtime, io)
                case .rename:
                    let row = try addressedScene(runtime)
                    try runtime.rename(row.id, to: args.title.orDie())
                    return io.out("Renamed \(row.title) to \(args.title.orDie())")
                case .leave:
                    let left = runtime.snapshot.activeScene?.title
                    try runtime.leave()
                    return io.out("Left \(left ?? "the Scene"). Nothing moved.")
                case .close:
                    return try close(runtime, io)
                case .switcher:
                    return request(.switcher, runtime, io)
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
    private func list(_ runtime: SceneCore.SceneRuntime, _ io: CmdIo) -> Bool {
        let scenes = runtime.snapshot.scenes
        if args.json {
            let payload: [[String: Primitive]] = scenes.map { row in
                [
                    "scene-number": .int(row.index),
                    "scene-title": .string(row.title),
                    "scene-state": .string(row.state.rawValue),
                    "slot-count": .int(row.slots.count),
                    "window-count": .int(row.windowCount),
                ]
            }
            return JSONEncoder.winMuxDefault.encodeToString(payload).map(io.out)
                ?? io.err("Failed to encode JSON")
        }
        guard !scenes.isEmpty else {
            guard let firstRun = runtime.snapshot.firstRunMessage else {
                return io.out(runtime.snapshot.diagnostics)
            }
            return io.out(firstRun)
        }
        let rows: [[String]] = scenes.map { row in
            ["\(row.index)", row.title, row.state.rawValue, row.trailing]
        }
        return io.out(rows.toPaddingTable(columnSeparator: "   "))
    }

    @MainActor
    private func enterRelative(_ direction: NextPrev, _ runtime: SceneCore.SceneRuntime, _ io: CmdIo) throws -> Bool {
        let scenes = runtime.snapshot.scenes
        guard !scenes.isEmpty else { throw SceneCore.SceneRuntimeError.noSceneNumbered(1) }
        let current = scenes.firstIndex { $0.isActive }
        let next: Int = switch (current, direction) {
            case (nil, .next), (nil, .prev): 0
            case (let index?, .next): (index + 1) % scenes.count
            case (let index?, .prev): (index - 1 + scenes.count) % scenes.count
        }
        let row = scenes[next]
        try runtime.enter(row.id)
        return io.out("Entered \(row.title)")
    }

    @MainActor
    private func new(_ runtime: SceneCore.SceneRuntime, _ io: CmdIo) throws -> Bool {
        guard let title = args.title else { return request(.newScene, runtime, io) }
        let template = args.template.flatMap { SceneCore.SlotTemplate(rawValue: $0) }
        if args.template != nil && template == nil {
            return io.err(
                "Can't parse template '\(args.template.orDie())'.\n"
                    + "Possible values: \(SceneCore.SlotTemplate.allCases.map(\.rawValue).joined(separator: "|"))",
            )
        }
        let row = try runtime.createScene(title: title, template: template ?? .development)
        return io.out("Created \(row.title) as Scene \(row.index). Enter it with 'scene \(row.index)'.")
    }

    /// `close` without `--yes` asks a panel; with `--yes` it says what it is doing first, then does it.
    @MainActor
    private func close(_ runtime: SceneCore.SceneRuntime, _ io: CmdIo) throws -> Bool {
        let row = try addressedScene(runtime)
        guard args.yes else {
            if runtime.presenter != nil { return request(.confirmClose(row.id), runtime, io) }
            let summary = try runtime.closeSummary(for: row.id)
            io.out([summary.title] + summary.groups.map(\.headline))
            return io.err("Pass --yes to close it.")
        }
        let summary = try runtime.closeSummary(for: row.id)
        let plan = try runtime.close(row.id)
        var lines = ["Closing \(row.title)."] + summary.groups.map(\.headline)
        if !plan.pending.isEmpty {
            lines.append("\(plan.pending.count) window(s) are still to be restored.")
        }
        return io.out(lines)
    }

    /// The Scene `--scene <n>` names, or the one on screen when it does not.
    @MainActor
    private func addressedScene(_ runtime: SceneCore.SceneRuntime) throws -> SceneCore.SceneShellSceneRow {
        if let number = args.sceneNumber { return try runtime.scene(numbered: number) }
        guard let active = runtime.snapshot.activeScene else {
            throw SceneCore.SceneRuntimeError.noActiveScene
        }
        return active
    }

    @MainActor
    private func request(_ request: SceneCore.SceneShellRequest, _ runtime: SceneCore.SceneRuntime, _ io: CmdIo) -> Bool {
        guard let presenter = runtime.presenter else {
            return io.err("This needs the SceneMux app to be running with its interface available.")
        }
        presenter(request)
        return true
    }
}
