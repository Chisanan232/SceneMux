public let stableSceneMuxAppId: String = "com.chisanan232.scenemux"
#if DEBUG
    public let sceneMuxAppId: String = "com.chisanan232.scenemux.debug"
    public let sceneMuxAppName: String = "SceneMux-Debug"
#else
    public let sceneMuxAppId: String = stableSceneMuxAppId
    public let sceneMuxAppName: String = "SceneMux"
#endif
