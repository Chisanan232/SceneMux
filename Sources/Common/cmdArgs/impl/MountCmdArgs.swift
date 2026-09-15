private let mount_help = """
    USAGE: mount [-h|--help] --slot <slot-number> [--own]

    Put the focused window into a Slot of the Scene on screen.

    Mounting borrows the window: it keeps its Semantic Home, and it goes back to the workspace it came
    from when the Scene closes. Nothing about the window's Home changes, now or later.

    OPTIONS:
      --own       Attach instead of borrow: this Scene owns the window, so ending the Scene leaves it
                  where it is rather than sending it back. Still never closes it
      --slot <n>  The Slot to put it in, as numbered by 'slot list'
    """

public struct MountCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    fileprivate init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .mount,
        allowInConfig: true,
        help: mount_help,
        flags: [
            "--own": trueBoolFlag(\.own),
            "--slot": singleValueSubArgParser(\.slotNumber, "<slot-number>") { Int($0) },
        ],
        posArgs: [],
    )

    public var slotNumber: Int? = nil
    /// Whether the Scene owns the window rather than borrowing it.
    ///
    /// A flag rather than an ownership value, because the vocabulary belongs to the Scene domain, which this
    /// module cannot see — and because the two verbs a person has are "borrow" and "own", not three.
    /// `.sharedPersistent` is deliberately unreachable from the command line: it is what unreadable state
    /// degrades to, not something to ask for.
    public var own: Bool = false
}

func parseMountCmdArgs(_ args: StrArrSlice) -> ParsedCmd<MountCmdArgs> {
    parseSpecificCmdArgs(MountCmdArgs(rawArgs: args), args)
        .filter("--slot is mandatory") { $0.slotNumber != nil }
}
