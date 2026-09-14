public let stableWinMuxAppId: String = "com.chisanan232.scenemux"
#if DEBUG
    public let winMuxAppId: String = "com.chisanan232.scenemux.debug"
    public let sceneMuxAppName: String = "SceneMux-Debug"
#else
    public let winMuxAppId: String = stableWinMuxAppId
    public let sceneMuxAppName: String = "SceneMux"
#endif
