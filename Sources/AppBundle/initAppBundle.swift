import AppKit
import Common
import Foundation

@MainActor public func initAppBundle() {
    Task {
        // The windows SceneMux finds while it is coming up were already open, so nobody opened them and no rule
        // may claim them for a Scene that was left on screen. Cleared however this Task ends: a latch stuck
        // closed would be admission switched off for the rest of the session, which is a worse failure than the
        // one it prevents.
        isSceneMuxStartingUp = true
        defer { isSceneMuxStartingUp = false }
        initTerminationHandler()
        isCli = false
        initServerArgs()
        var bootstrappedConfigUrl: URL? = nil
        if isDebug {
            await toggleReleaseServerIfDebug(.off)
            interceptTermination(SIGINT)
            interceptTermination(SIGKILL)
        }
        do {
            bootstrappedConfigUrl = try ensureBootstrapConfigExistsIfNeeded()
        } catch {
            MessageModel.shared.message = Message(
                description: "Config Bootstrap Error",
                body: error.localizedDescription,
            )
        }
        if try await !reloadConfig(forceConfigUrl: bootstrappedConfigUrl) {
            var out = ""
            check(
                try await reloadConfig(forceConfigUrl: defaultConfigUrl, stdout: &out),
                """
                Can't load default config. Your installation is probably corrupted.
                Please don't modify '\(defaultConfigUrl)'

                \(out)
                """,
            )
        }
        MonitorConfigurationObserver.shared.prepareForStartup()

        checkAccessibilityPermissions()
        requestScreenRecordingPermissionsIfNeeded()
        startUnixSocketServer()
        GlobalObserver.initObserver()
        MonitorConfigurationObserver.shared.startObserving()
        Workspace.reconcileWorkspaceState() // init workspaces
        _ = Workspace.all.first?.focusWorkspace()
        let didLoadPersistedFrozenWorld = loadPersistedFrozenWorldForStartupIfPresent()
        try await runRefreshSessionBlocking(.startup, layoutWorkspaces: false)
        try await runLightSession(.startup, .forceRun) {
            if !didLoadPersistedFrozenWorld {
                smartLayoutAtStartup()
            }
            _ = try await config.afterStartupCommand.runCmdSeq(.defaultEnv, .emptyStdin)
        }
        isWinMuxRuntimeReady = true
        // Scene Core's surfaces come up only once the engine underneath them is ready: a Scene entered before
        // the workspaces exist would be projected onto windows the runtime has not seen yet.
        SceneSwitcherPanel.registerAsPresenter()
        SceneMessageHud.observe(SceneCore.SceneRuntime.shared)
        // What reading state found, said once, now that there is somewhere to say it. A refusal posted from the
        // runtime's initializer would have been a message with no HUD to appear on.
        SceneMessageHud.shared.enqueue(SceneCore.SceneRuntime.shared.startupMessages)
        // A Scene that was closing when SceneMux last stopped still owes its borrowed windows a journey home.
        // Inside a session, because sending one back rebinds it in the inherited tree and it is the session
        // that follows which actually moves it — and only now, because a restore aimed at a workspace the
        // runtime has not read yet would find nothing there.
        try await runLightSession(.startup, .forceRun) {
            SceneMessageHud.shared.enqueue(SceneCore.SceneRuntime.shared.resumeUnfinishedTeardowns())
        }
        if bootstrappedConfigUrl != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ShortcutSettingsModel.shared.requestWindowOpen()
            }
        }
    }
}

@MainActor
private func smartLayoutAtStartup() {
    let workspace = focus.workspace
    let root = workspace.rootTilingContainer
    if root.children.count <= 3 {
        root.layout = .tiles
    } else {
        root.layout = .tabGroup
    }
}

@TaskLocal
var _isStartup: Bool? = false
var isStartup: Bool { _isStartup ?? dieT("isStartup is not initialized") }

struct ServerArgs: Sendable {
    var configLocation: String? = nil
    var isReadOnly: Bool = false
}

private let serverHelp = """
    USAGE: \(CommandLine.arguments.first ?? "SceneMux.app/Contents/MacOS/SceneMux") [<options>]

    OPTIONS:
      -h, --help              Print help
      -v, --version           Print SceneMux.app version
      --config-path <path>    Config path. It takes priority over the config SceneMux reads by
                              default, ${XDG_CONFIG_HOME:-~/.config}/scenemux/scenemux.toml
      --read-only             Run without mutating macOS windows.
                              Useful if you want to use only debug-windows or other query commands.
    """

nonisolated(unsafe) private var _serverArgs = ServerArgs()
var serverArgs: ServerArgs { _serverArgs }
private func initServerArgs() {
    let args = CommandLine.arguments.slice(1...) ?? []
    if args.contains(where: { $0 == "-h" || $0 == "--help" }) {
        exit(0, out: serverHelp)
    }
    var index = 0
    while index < args.count {
        let current = args[index]
        index += 1
        switch current {
            case "--version", "-v":
                exit(0, out: "\(sceneMuxAppVersion) \(gitHash)")
            case "--config-path":
                if let arg = args.getOrNil(atIndex: index) {
                    _serverArgs.configLocation = arg
                } else {
                    exit(1, err: "Missing <path> in --config-path flag")
                }
                index += 1
            case "--read-only": // todo rename to '--disabled' and unite with disabled feature
                _serverArgs.isReadOnly = true
            case "-NSDocumentRevisionsDebugMode" where isDebug:
                // Skip Xcode CLI args.
                // Usually it's '-NSDocumentRevisionsDebugMode NO'/'-NSDocumentRevisionsDebugMode YES'
                while args.getOrNil(atIndex: index)?.starts(with: "-") == false { index += 1 }
            default:
                exit(1, err: "Unrecognized flag '\(args.first.orDie())'")
        }
    }
    if let path = serverArgs.configLocation, !FileManager.default.fileExists(atPath: path) {
        exit(1, err: "\(path) doesn't exist")
    }
}
