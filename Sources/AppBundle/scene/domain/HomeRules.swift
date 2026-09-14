import Foundation

extension SceneCore {
    /// Which Semantic Home an application belongs to: the whole of how that question is answered.
    ///
    /// Two inputs and no others — a table of defaults shipped with SceneMux, and the user's own overrides
    /// from the config file, which win. A window title is not an input, because a category that changed
    /// with what somebody is currently typing would be both useless and the most sensitive thing on their
    /// screen. Process lineage is not an input either: that is admission gate G2, and it does not exist in
    /// v0.1.0.
    ///
    /// Resolution is a pure function of a bundle id, which is what makes the invariant enforceable: nothing
    /// here can see a Scene, an attachment or a workspace, so no amount of mounting can change what an
    /// application is *for*.
    struct HomeRules: Equatable, Sendable {
        /// Which Home to answer with for an application nobody has classified.
        ///
        /// `personal` rather than a fifth "unknown" case, because the four Homes are the vocabulary and an
        /// application SceneMux has never heard of is, as far as it knows, the user's own. It is also the
        /// answer that claims the least: nothing about a Home moves a window, but a wrong guess of
        /// `development` would put a stranger's app in the sentence describing somebody's task.
        static let fallback: SemanticHome = .personal

        /// Where a resolved Home came from, so a surface can say *why* an application is where it is.
        ///
        /// The user's own override is worth distinguishing from a shipped default: "SceneMux thinks Music is
        /// personal" and "you told SceneMux that Music is personal" are different sentences, and only one of
        /// them is worth arguing with.
        enum Source: Equatable, Sendable, CustomStringConvertible {
            /// The user said so, in their config file.
            case userOverride
            /// The table shipped with SceneMux said so.
            case shippedDefault
            /// Nobody said so.
            case fallback

            var description: String {
                switch self {
                    case .userOverride: "your config"
                    case .shippedDefault: "SceneMux’s defaults"
                    case .fallback: "the default for applications SceneMux does not know"
                }
            }
        }

        /// The user's own rules, keyed by lowercased bundle id.
        let overrides: [String: SemanticHome]

        /// The rules shipped with SceneMux, keyed by lowercased bundle id.
        ///
        /// Ordinary desktop applications, deliberately: the golden journey has to work for the tools people
        /// already have open, and a table that only knew SceneMux's own vocabulary would classify every
        /// window as `personal` on a real Mac. It is a starting point and nothing more — every entry is
        /// overridable, and an application that is missing is a config line, not a bug report.
        ///
        /// Browsers are `personal` on purpose. A browser is whatever its user is doing at the time, so
        /// guessing `development` for one would be the loudest wrong guess in the table.
        static let shipped: [String: SemanticHome] = normalising([
            // Terminals and editors — building software.
            "com.apple.Terminal": .development,
            "com.googlecode.iterm2": .development,
            "com.mitchellh.ghostty": .development,
            "io.alacritty": .development,
            "com.github.wez.wezterm": .development,
            "net.kovidgoyal.kitty": .development,
            "dev.warp.Warp-Stable": .development,
            "com.apple.dt.Xcode": .development,
            "com.microsoft.VSCode": .development,
            "com.visualstudio.code.oss": .development,
            "dev.zed.Zed": .development,
            "com.sublimetext.4": .development,
            "org.gnu.Emacs": .development,
            "com.jetbrains.intellij": .development,
            "com.jetbrains.intellij.ce": .development,
            "com.jetbrains.pycharm": .development,
            "com.jetbrains.WebStorm": .development,
            "com.jetbrains.goland": .development,
            "com.jetbrains.rider": .development,
            "com.jetbrains.CLion": .development,
            "com.github.GitHubClient": .development,
            // Talking to people.
            "com.tinyspeck.slackmacgap": .communication,
            "jp.naver.line.mac": .communication,
            "com.linecorp.LINE": .communication,
            "com.hnc.Discord": .communication,
            "ru.keepcoder.Telegram": .communication,
            "net.whatsapp.WhatsApp": .communication,
            "us.zoom.xos": .communication,
            "com.microsoft.teams2": .communication,
            "com.apple.mail": .communication,
            "com.apple.MobileSMS": .communication,
            "com.apple.FaceTime": .communication,
            // Watching systems.
            "com.grafana.grafana": .observability,
            "com.apple.Console": .observability,
            "com.apple.ActivityMonitor": .observability,
            "com.apple.dt.Instruments": .observability,
            "org.wireshark.Wireshark": .observability,
            // The user's own.
            "com.apple.Music": .personal,
            "com.spotify.client": .personal,
            "com.apple.Notes": .personal,
            "com.apple.Photos": .personal,
            "com.apple.podcasts": .personal,
            "md.obsidian": .personal,
            "notion.id": .personal,
            "com.apple.Safari": .personal,
            "com.google.Chrome": .personal,
            "org.mozilla.firefox": .personal,
            "com.microsoft.edgemac": .personal,
            "company.thebrowser.Browser": .personal,
        ])

        /// The shipped table with no overrides at all: what a first run resolves with.
        static let shippedOnly = HomeRules()

        init(overrides: [String: SemanticHome] = [:]) {
            self.overrides = Self.normalising(overrides)
        }

        /// What this application is for.
        ///
        /// The user's override, then the shipped default, then the fallback. Total by construction: there is
        /// no bundle id this cannot answer for, because a resolution that could fail would have every caller
        /// inventing its own answer.
        func home(of bundleId: String) -> SemanticHome {
            let key = Self.key(bundleId)
            return overrides[key] ?? Self.shipped[key] ?? Self.fallback
        }

        /// What the window's application is for. Reads the bundle id and nothing else about the window.
        func home(of windowRef: WindowRef) -> SemanticHome {
            home(of: windowRef.bundleId)
        }

        /// Who decided this application's Home.
        func source(of bundleId: String) -> Source {
            let key = Self.key(bundleId)
            if overrides[key] != nil { return .userOverride }
            return Self.shipped[key] != nil ? .shippedDefault : .fallback
        }

        /// Every application either side of the table has an opinion about, with its Home, ordered by bundle
        /// id so that two runs list them the same way.
        ///
        /// The point of listing the union is that a user checking their configuration wants to see the rule
        /// that will actually apply, not the two halves it came from.
        var effective: [(bundleId: String, home: SemanticHome, source: Source)] {
            let keys = Set(Self.shipped.keys).union(overrides.keys).sorted()
            return keys.map { (bundleId: $0, home: home(of: $0), source: source(of: $0)) }
        }

        /// Bundle ids are matched case-insensitively.
        ///
        /// Reverse-DNS bundle ids are conventionally lowercase but not reliably so — `com.apple.Terminal`
        /// and `com.microsoft.VSCode` both ship capitals — and a config file is typed by hand. A rule that
        /// silently did not apply because of one capital letter is the least debuggable kind of rule.
        private static func key(_ bundleId: String) -> String {
            bundleId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        private static func normalising(_ rules: [String: SemanticHome]) -> [String: SemanticHome] {
            Dictionary(rules.map { (key($0.key), $0.value) }, uniquingKeysWith: { _, last in last })
        }
    }
}
