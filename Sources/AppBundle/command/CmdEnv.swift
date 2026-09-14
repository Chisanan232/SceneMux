import Common

struct CmdEnv: ConvenienceCopyable {
    var windowId: UInt32?
    var workspaceName: String?

    static let defaultEnv: CmdEnv = .init()
    func withFocus(_ focus: LiveFocus) -> CmdEnv {
        switch focus.asLeaf {
            case .window(let wd): .defaultEnv.copy(\.windowId, wd.windowId)
            case .emptyWorkspace(let ws): .defaultEnv.copy(\.workspaceName, ws.name)
        }
    }

    var asMap: [String: String] {
        var result = [String: String]()
        if let windowId {
            result[SCENEMUX_WINDOW_ID] = windowId.description
            result[WINMUX_WINDOW_ID] = windowId.description // Inherited alias
        }
        if let workspaceName {
            result[SCENEMUX_WORKSPACE] = workspaceName.description
            result[WINMUX_WORKSPACE] = workspaceName.description // Inherited alias
        }
        return result
    }
}
