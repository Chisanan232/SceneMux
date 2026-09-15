import AppKit
import Common

/// `home` — what each application is for, and who decided.
///
/// Read-only on purpose. Home policy is two things and only two: the table SceneMux ships and the
/// `[scene-home]` section of the user's config, which wins. A `home set` would be a third writer of the same
/// truth, and the first time it disagreed with the file the person had open, the honest answer to "why is this
/// app Communication?" would be gone. So this command answers the question and points at the file.
///
/// `show` names the source as well as the Home, because "SceneMux thinks Music is personal" and "you told
/// SceneMux that Music is personal" are different sentences and only one of them is worth arguing with.
struct HomeCommand: Command {
    let args: HomeCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false
    /*conforms*/ let canSkipPostCommandRefresh = true

    func run(_ env: CmdEnv, _ io: CmdIo) async throws -> Bool {
        let runtime = SceneCore.SceneRuntime.shared
        return switch args.target.val {
            case .list: list(runtime.homeRules, io)
            case .show: show(runtime, io)
        }
    }

    @MainActor
    private func list(_ homes: SceneCore.HomeRules, _ io: CmdIo) -> Bool {
        let rules = homes.effective
        if args.json {
            let payload: [[String: Primitive]] = rules.map { rule in
                [
                    "app-bundle-id": .string(rule.bundleId),
                    "home": .string(rule.home.rawValue),
                    "home-source": .string(rule.source == .userOverride ? "config" : "default"),
                ]
            }
            return JSONEncoder.winMuxDefault.encodeToString(payload).map(io.out)
                ?? io.err("Failed to encode JSON")
        }
        let rows: [[String]] = rules.map { rule in
            [rule.bundleId, rule.home.displayName, rule.source == .userOverride ? "your config" : ""]
        }
        return io.out(rows.toPaddingTable(columnSeparator: "   "))
    }

    /// The application `--app` names, or the one the user is looking at.
    ///
    /// An unrecognised bundle id is not an error: every application has a Home, including one SceneMux has never
    /// heard of, and saying so is the answer the person came for.
    @MainActor
    private func show(_ runtime: SceneCore.SceneRuntime, _ io: CmdIo) -> Bool {
        guard let bundleId = args.app ?? runtime.focusedApplication else {
            return io.err("SceneMux can’t tell which application you mean. Pass --app <bundle-id>.")
        }
        let homes = runtime.homeRules
        return io.out(
            "\(bundleId) is \(homes.home(of: bundleId).displayName), according to \(homes.source(of: bundleId)).",
        )
    }
}
