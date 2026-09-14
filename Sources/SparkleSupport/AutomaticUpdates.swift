import Foundation
import Sparkle

/// Coordinates application updates from the release appcast.
@MainActor
public enum AutomaticUpdates {
    private static let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil,
    )

    /// Whether this bundle declares an update feed to check.
    ///
    /// SceneMux ships without a feed until it owns a signed release channel, so this
    /// is the single gate that keeps the updater dormant. It is read from the bundle
    /// rather than compiled in so that configuring a feed is enough to enable updates.
    public static var isFeedConfigured: Bool {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        return !(feed ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Starts Sparkle's periodic update checks for the main application bundle.
    public static func start() {
        // Starting the updater with no feed cannot find an update, it can only fail
        // repeatedly in the background. Stay dormant instead.
        guard isFeedConfigured else { return }
        _ = updaterController
    }

    /// Displays Sparkle's standard update-checking interface.
    public static func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
