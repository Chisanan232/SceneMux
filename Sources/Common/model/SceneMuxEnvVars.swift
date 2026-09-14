public let SCENEMUX_WINDOW_ID = "SCENEMUX_WINDOW_ID"
public let SCENEMUX_WORKSPACE = "SCENEMUX_WORKSPACE"
public let SCENEMUX_FOCUSED_WORKSPACE = "SCENEMUX_FOCUSED_WORKSPACE"
public let SCENEMUX_PREV_WORKSPACE = "SCENEMUX_PREV_WORKSPACE"

// Inherited WinMux names. SceneMux keeps exporting them next to its own so that a
// config imported from WinMux, which may interpolate $WINMUX_WORKSPACE in an
// exec-and-forget command, does not silently start receiving an empty string. They
// are read as a fallback only, never in preference to the SceneMux names.
public let WINMUX_WINDOW_ID = "WINMUX_WINDOW_ID"
public let WINMUX_WORKSPACE = "WINMUX_WORKSPACE"
public let WINMUX_FOCUSED_WORKSPACE = "WINMUX_FOCUSED_WORKSPACE"
public let WINMUX_PREV_WORKSPACE = "WINMUX_PREV_WORKSPACE"

/// Canonical SceneMux environment variable names paired with the inherited WinMux
/// name that is exported alongside each of them.
public let sceneMuxEnvVarAliases: [(canonical: String, inherited: String)] = [
    (SCENEMUX_WINDOW_ID, WINMUX_WINDOW_ID),
    (SCENEMUX_WORKSPACE, WINMUX_WORKSPACE),
    (SCENEMUX_FOCUSED_WORKSPACE, WINMUX_FOCUSED_WORKSPACE),
    (SCENEMUX_PREV_WORKSPACE, WINMUX_PREV_WORKSPACE),
]
