public let stableWinMuxAppId: String = "com.chisanan232.scenemux"
#if DEBUG
    public let winMuxAppId: String = "com.chisanan232.scenemux.debug"
    public let winMuxAppName: String = "SceneMux-Debug"
#else
    public let winMuxAppId: String = stableWinMuxAppId
    public let winMuxAppName: String = "SceneMux"
#endif
