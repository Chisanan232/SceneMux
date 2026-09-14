private let scene_help = """
    USAGE: scene [-h|--help] list [--json]
       OR: scene [-h|--help] new [--title <title>] [--template (development|empty)]
       OR: scene [-h|--help] rename --title <title> [--scene <scene-number>]
       OR: scene [-h|--help] (<scene-number>|next|prev)
       OR: scene [-h|--help] leave
       OR: scene [-h|--help] close [--scene <scene-number>]
       OR: scene [-h|--help] switcher

    A Scene is one task: "Debug PROD-123", "Review the release notes". Entering one puts its Slots on
    screen; leaving one moves nothing.

    OPTIONS:
      --json             Print the Scene list as JSON instead of a table
      --scene <n>        The Scene the operation applies to, as numbered by 'scene list'.
                         Defaults to the Scene on screen
      --template <name>  Which Slots a new Scene starts with. Defaults to 'development'
      --title <title>    The Scene's name. 'new' without a title opens the switcher so it can be typed
    """

public struct SceneCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .scene,
        allowInConfig: true,
        help: scene_help,
        flags: [
            "--json": trueBoolFlag(\.json),
            "--scene": singleValueSubArgParser(\.sceneNumber, "<scene-number>") { Int($0) },
            "--template": singleValueSubArgParser(\.template, "(development|empty)") { $0 },
            "--title": singleValueSubArgParser(\.title, "<title>") { $0 },
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseSceneTarget, placeholder: sceneTargetPlaceholder)],
    )

    public var target: Lateinit<SceneTarget> = .uninitialized
    public var json: Bool = false
    public var sceneNumber: Int? = nil
    public var template: String? = nil
    public var title: String? = nil
}

/// What `scene` was asked to do. A bare number enters that Scene, which is what `ctrl-alt-1…9` sends.
public enum SceneTarget: Equatable, Sendable {
    case enter(Int)
    case relative(NextPrev)
    case list
    case new
    case rename
    case leave
    case close
    case switcher

    /// Whether this target names a particular Scene by itself, and so cannot also take `--scene`.
    public var isPositional: Bool {
        switch self {
            case .enter, .relative: true
            case .list, .new, .rename, .leave, .close, .switcher: false
        }
    }
}

let sceneTargetPlaceholder = "(<scene-number>|next|prev|list|new|rename|leave|close|switcher)"

func parseSceneCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SceneCmdArgs> {
    parseSpecificCmdArgs(SceneCmdArgs(rawArgs: args), args)
        .filter("--title is mandatory for 'rename'") {
            $0.target.val != .rename || $0.title != nil
        }
        .filter("--title is only allowed for 'new' and 'rename'") {
            $0.title == nil || $0.target.val == .new || $0.target.val == .rename
        }
        .filter("--template is only allowed for 'new'") {
            $0.template == nil || $0.target.val == .new
        }
        .filter("--json is only allowed for 'list'") {
            !$0.json || $0.target.val == .list
        }
        .filter("--scene is only allowed for 'rename' and 'close'") {
            $0.sceneNumber == nil || $0.target.val == .rename || $0.target.val == .close
        }
}

func parseSceneTarget(i: PosArgParserInput) -> ParsedCliArgs<SceneTarget> {
    switch i.arg {
        case "next": return .succ(.relative(.next), advanceBy: 1)
        case "prev": return .succ(.relative(.prev), advanceBy: 1)
        case "list": return .succ(.list, advanceBy: 1)
        case "new": return .succ(.new, advanceBy: 1)
        case "rename": return .succ(.rename, advanceBy: 1)
        case "leave": return .succ(.leave, advanceBy: 1)
        case "close": return .succ(.close, advanceBy: 1)
        case "switcher": return .succ(.switcher, advanceBy: 1)
        default:
            guard let index = Int(i.arg), index > 0 else {
                return .fail("Can't parse scene target '\(i.arg)'. Expected \(sceneTargetPlaceholder)", advanceBy: 1)
            }
            return .succ(.enter(index), advanceBy: 1)
    }
}
