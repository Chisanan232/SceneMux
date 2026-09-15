private let home_help = """
    USAGE: home [-h|--help] list [--json]
       OR: home [-h|--help] show [--app <bundle-id>]

    What each application is *for*: Development, Communication, Observability or Personal. A Semantic Home
    is a category, never a place — nothing here moves a window, and mounting a window into a Scene never
    changes what its application is for.

    Both subcommands only read. Home rules are yours to write, in the '[scene-home]' section of the config
    file, so that the answer to "why is this app Communication?" is a line you can see and edit rather than
    state SceneMux changed behind you.

    OPTIONS:
      --app <bundle-id>  The application to answer for. Defaults to the focused window's application
      --json             Print the rules as JSON instead of a table
    """

public struct HomeCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .home,
        allowInConfig: true,
        help: home_help,
        flags: [
            "--app": singleValueSubArgParser(\.app, "<bundle-id>") { $0 },
            "--json": trueBoolFlag(\.json),
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseHomeTarget, placeholder: homeTargetPlaceholder)],
    )

    public var target: Lateinit<HomeTarget> = .uninitialized
    public var app: String? = nil
    public var json: Bool = false
}

/// What `home` was asked to do. Both are questions: there is no subcommand that assigns a Home, because
/// assigning one is editing the config file, and a command that wrote it back would leave two sources of the
/// same truth to disagree.
public enum HomeTarget: String, CaseIterable, Equatable, Sendable {
    case list
    case show
}

let homeTargetPlaceholder = HomeTarget.unionLiteral

func parseHomeCmdArgs(_ args: StrArrSlice) -> ParsedCmd<HomeCmdArgs> {
    parseSpecificCmdArgs(HomeCmdArgs(rawArgs: args), args)
        .filter("--app is only allowed for 'show'") {
            $0.app == nil || $0.target.val == .show
        }
        .filter("--json is only allowed for 'list'") {
            !$0.json || $0.target.val == .list
        }
}

private func parseHomeTarget(i: PosArgParserInput) -> ParsedCliArgs<HomeTarget> {
    .init(parseEnum(i.arg, HomeTarget.self), advanceBy: 1)
}
