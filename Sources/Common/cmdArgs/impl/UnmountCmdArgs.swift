public struct UnmountCmdArgs: CmdArgs {
    /*conforms*/ public var commonState: CmdArgsCommonState
    public init(rawArgs: StrArrSlice) { self.commonState = .init(rawArgs) }
    public static let parser: CmdParser<Self> = .init(
        kind: .unmount,
        allowInConfig: true,
        help: """
            USAGE: unmount [-h|--help]

            Take the focused window out of its Scene and send it back where it came from.

            The explicit half of the borrowed-window promise: what closing a Scene does for every borrowed
            window at once, this does for one, now. It closes nothing, and a window the Scene was never
            allowed to move is refused out loud rather than moved.
            """,
        flags: [:],
        posArgs: [],
    )
}
