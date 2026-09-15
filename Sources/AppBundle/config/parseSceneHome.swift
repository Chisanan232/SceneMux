import Common
import TOMLKit

/// The `scene-home` table: which Semantic Home each application belongs to, in the user's own words.
///
/// This is the one piece of Scene Core that belongs in the config file rather than in the state file, and the
/// distinction is the point. Which Home an application belongs to is *intent the user expressed* — declarative,
/// hand-edited, kept in version control, reviewed like every other config key. Scene state is *a record of what
/// happened*, changes on every mount, and is written by SceneMux. Putting the first in the second would make a
/// bug in the state writer capable of destroying somebody's configuration.
///
/// An unparseable Home is an error on that one line, and the other lines still apply. A single typo in a
/// twenty-application table should not silently return every window to the shipped defaults.
func parseSceneHome(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
    _ errors: inout [TomlParseError],
) -> [String: SceneCore.SemanticHome] {
    guard let rawTable = raw.table else {
        errors += [expectedActualTypeError(expected: .table, actual: raw.type, backtrace)]
        return [:]
    }
    var result: [String: SceneCore.SemanticHome] = [:]
    for (bundleId, rawHome) in rawTable {
        guard let home = parseSemanticHome(rawHome, backtrace + .key(bundleId))
            .getOrNil(appendErrorTo: &errors) else { continue }
        result[bundleId] = home
    }
    return result
}

/// The four Homes, by their stable identifiers, listed back at the user when they type a fifth.
private func parseSemanticHome(
    _ raw: TOMLValueConvertible,
    _ backtrace: TomlBacktrace,
) -> ParsedToml<SceneCore.SemanticHome> {
    parseString(raw, backtrace).flatMap { rawValue in
        SceneCore.SemanticHome(rawValue: rawValue).orFailure(.semantic(
            backtrace,
            "Can't parse Semantic Home '\(rawValue)'. Possible values: \(SceneCore.SemanticHome.unionLiteral)",
        ))
    }
}
