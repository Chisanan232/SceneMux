private let slot_help = """
    USAGE: slot [-h|--help] list [--json]
       OR: slot [-h|--help] new --role (editor|terminal|preview|observability|communication) [--label <label>]
       OR: slot [-h|--help] compose --slot <slot-number>
       OR: slot [-h|--help] remove --slot <slot-number>

    A Slot is a named place in the Scene on screen — where the editor goes, where the terminal goes — and
    not a rectangle. Every subcommand applies to the Scene on screen and refuses when there is none.

    OPTIONS:
      --json           Print the Slot list as JSON instead of a table
      --label <label>  A name for the Slot, shown instead of its role
      --role <role>    What the Slot is for
      --slot <n>       The Slot the operation applies to, as numbered by 'slot list'
    """

public struct SlotCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .slot,
        allowInConfig: true,
        help: slot_help,
        flags: [
            "--json": trueBoolFlag(\.json),
            "--label": singleValueSubArgParser(\.label, "<label>") { $0 },
            "--role": singleValueSubArgParser(\.role, "<role>") { $0 },
            "--slot": singleValueSubArgParser(\.slotNumber, "<slot-number>") { Int($0) },
        ],
        posArgs: [newMandatoryPosArgParser(\.target, parseSlotTarget, placeholder: slotTargetPlaceholder)],
    )

    public var target: Lateinit<SlotTarget> = .uninitialized
    public var json: Bool = false
    public var label: String? = nil
    /// Kept as a string on purpose: the role vocabulary belongs to the Scene domain, which this module cannot
    /// see. The command validates it against the real roles and lists them when it does not match.
    public var role: String? = nil
    public var slotNumber: Int? = nil
}

/// What `slot` was asked to do.
///
/// Sending a window to a Slot is deliberately absent *here*: it is `mount --slot <n>`, which acts on the
/// focused window and has to record an ownership. Putting it under `slot` would have made the Slot the subject
/// of a sentence whose real subject is the window, and would have needed a second way to say "borrowed".
public enum SlotTarget: String, CaseIterable, Equatable, Sendable {
    case list
    case new
    case compose
    case remove
}

let slotTargetPlaceholder = SlotTarget.unionLiteral

func parseSlotCmdArgs(_ args: StrArrSlice) -> ParsedCmd<SlotCmdArgs> {
    parseSpecificCmdArgs(SlotCmdArgs(rawArgs: args), args)
        .filter("--role is mandatory for 'new'") {
            $0.target.val != .new || $0.role != nil
        }
        .filter("--role and --label are only allowed for 'new'") {
            ($0.role == nil && $0.label == nil) || $0.target.val == .new
        }
        .filter("--slot is mandatory for 'compose' and 'remove'") {
            switch $0.target.val {
                case .compose, .remove: $0.slotNumber != nil
                case .list, .new: true
            }
        }
        .filter("--slot is only allowed for 'compose' and 'remove'") {
            switch $0.target.val {
                case .compose, .remove: true
                case .list, .new: $0.slotNumber == nil
            }
        }
        .filter("--json is only allowed for 'list'") {
            !$0.json || $0.target.val == .list
        }
}

private func parseSlotTarget(i: PosArgParserInput) -> ParsedCliArgs<SlotTarget> {
    .init(parseEnum(i.arg, SlotTarget.self), advanceBy: 1)
}
