import AppKit
import Combine
import Common
import SwiftUI

private let sceneMessageHudId = "SceneMux.sceneMessageHud"
private let sceneMessageHudWidth: CGFloat = 380
/// How long a message that needs no reading stays up. Long enough to read one line, short enough that the user
/// does not start moving windows out of its way.
private let sceneMessageHudDwellNanoseconds: UInt64 = 2_500_000_000

/// The transient HUD: one Scene lifecycle message at a time, bottom-centre, gone by itself.
///
/// It never stacks. A second message replaces the panel's contents and queues nothing behind more than the one
/// waiting turn, because two HUDs on screen at once are two windows the user has to dismiss to see the desktop
/// SceneMux just rearranged.
///
/// A message carrying details does *not* time out. The only one that does is the refusal to read state, and a
/// disclosure that disappears two and a half seconds after being opened is a disclosure that cannot be read.
/// Everything else goes on its own, which is the point of a HUD.
@MainActor
final class SceneMessageHud: NSPanelHud {
    static let shared = SceneMessageHud()

    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private var pending: [SceneCore.SceneShellMessage] = []
    private var showing: SceneCore.SceneShellMessage?
    private var dwell: Task<Void, Never>?
    private var escMonitor: Any?
    private var subscription: AnyCancellable?

    override private init() {
        super.init()
        identifier = NSUserInterfaceItemIdentifier(sceneMessageHudId)
        isFloatingPanel = true
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        backgroundColor = .clear
        applyWinMuxLayer(.overlay)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = hostingView
        hostingView.frame = contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]
    }

    /// Start showing what the runtime posts. Called once, at startup.
    static func observe(_ runtime: SceneCore.SceneRuntime) {
        shared.subscription = runtime.$message.sink { message in
            guard let message else { return }
            shared.enqueue([message])
        }
    }

    /// Show these in order, one at a time, each waiting for the one before it to go.
    func enqueue(_ messages: [SceneCore.SceneShellMessage]) {
        pending += messages
        if showing == nil { showNext() }
    }

    /// Take the message off the screen; the next one, if any, takes its place.
    func dismiss() {
        dwell?.cancel()
        dwell = nil
        showing = nil
        if let escMonitor {
            NSEvent.removeMonitor(escMonitor)
            self.escMonitor = nil
        }
        orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
        SceneCore.SceneRuntime.shared.dismissMessage()
        if !pending.isEmpty { showNext() }
    }

    private func showNext() {
        guard !pending.isEmpty else { return }
        let message = pending.removeFirst()
        showing = message
        hostingView.rootView = AnyView(SceneMessageHudView(message: message) { [weak self] in self?.dismiss() })
        let size = hostingView.fittingSize
        let monitorRect = focus.workspace.workspaceMonitor.visibleRect
        let height = max(size.height, 36)
        setFrame(
            NSRect(
                x: monitorRect.topLeftX + (monitorRect.width - sceneMessageHudWidth) / 2,
                y: sceneMessageHudScreenMaxY() - monitorRect.topLeftY - monitorRect.height + 48,
                width: sceneMessageHudWidth,
                height: height,
            ),
            display: true,
            animate: false,
        )
        orderFrontRegardless()
        if message.announces { announce(message.text) }
        // Esc is caught with a local monitor rather than by taking key focus. A HUD that became the key window
        // would take the keyboard away from whatever the user was typing in, to tell them about a window move
        // they can already see — so Esc reaches it when SceneMux is the active app, and the dwell handles the
        // rest.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.dismiss()
            return nil
        }
        guard !message.showsDetails else { return }
        dwell = Task { [weak self] in
            try? await Task.sleep(nanoseconds: sceneMessageHudDwellNanoseconds)
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    /// Say it to VoiceOver as well, for the messages that are about something the user did not just ask for.
    private func announce(_ text: String) {
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSNumber(value: NSAccessibilityPriorityLevel.high.rawValue),
            ],
        )
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
private func sceneMessageHudScreenMaxY() -> CGFloat {
    NSScreen.screens.first?.frame.maxY ?? 0
}
