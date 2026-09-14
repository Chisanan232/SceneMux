import AppBundle
import SparkleSupport
import SwiftUI

// This file is shared between SPM and xcode project

@main
struct SceneMuxApp: App {
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared
    @StateObject var shortcutSettingsModel = ShortcutSettingsModel.shared
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    init() {
        #if !DEBUG
            AutomaticUpdates.start()
        #endif
        initAppBundle()
    }

    var body: some Scene {
        #if DEBUG
        menuBar(viewModel: viewModel)
        #else
        menuBar(
            viewModel: viewModel,
            // Offering "Check for Updates…" with no feed configured would present a
            // control that can only report a failure.
            checkForUpdates: AutomaticUpdates.isFeedConfigured
                ? { AutomaticUpdates.checkForUpdates() }
                : nil,
        )
        #endif
        getShortcutSettingsWindow(model: shortcutSettingsModel)
            .onChange(of: shortcutSettingsModel.openRequestId) { _ in
                openShortcutSettingsWindow(openWindow)
            }
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
