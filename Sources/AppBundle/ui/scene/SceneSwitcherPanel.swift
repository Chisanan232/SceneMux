import AppKit
import Common
import SwiftUI

private let sceneSwitcherPanelId = "SceneMux.sceneSwitcher"

/// The window the Scene switcher lives in, and the only thing in Scene Core that knows what a key code is.
///
/// A non-activating floating `NSPanel`, like the inherited palette it is modelled on, because a window
/// manager's own UI must be able to appear over another application's window without stealing what the user
/// was doing. It takes key focus while it is up — it has a text field — and gives it straight back.
///
/// It holds no Scene logic. Every key below turns into one call on `SceneSwitcherModel`, which is where the
/// decisions live and where they are tested; this file's job is to be the part that cannot be tested without a
/// window server, and to be small enough that that does not matter.
@MainActor
final class SceneSwitcherPanel: NSPanelHud {
    static let shared = SceneSwitcherPanel()

    private let hostingView = NSHostingView(rootView: AnyView(EmptyView()))
    private let model = SceneSwitcherModel(runtime: SceneCore.SceneRuntime.shared)
    private(set) var isPanelActive = false

    override private init() {
        super.init()
        identifier = NSUserInterfaceItemIdentifier(sceneSwitcherPanelId)
        hasShadow = true
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

    /// Register this panel as the surface commands ask for. Called once, at startup.
    ///
    /// Until this runs, `scenemux scene switcher` refuses with "the app has no interface available", which is
    /// the honest answer for a run without a UI rather than a silent success.
    static func registerAsPresenter() {
        SceneCore.SceneRuntime.shared.presenter = { request in
            SceneSwitcherPanel.shared.present(request)
        }
    }

    /// What a command asked for: `⌃⌥S` toggles, everything else opens the panel on the thing it is about.
    func present(_ request: SceneCore.SceneShellRequest) {
        if request == .switcher, isPanelActive { return dismiss() }
        show()
        model.apply(request)
    }

    func show() {
        guard !isPanelActive else { return }
        isPanelActive = true
        let monitorRect = focus.workspace.workspaceMonitor.visibleRect
        // Centred on the focused monitor with its top edge about a quarter of the way down, matching the
        // inherited palette — the two panels are the same kind of thing and should not appear in two places.
        setFrame(
            NSRect(
                x: monitorRect.topLeftX + (monitorRect.width - sceneSwitcherWidth) / 2,
                y: sceneSwitcherScreenMaxY() - monitorRect.topLeftY - monitorRect.height * 0.25 - sceneSwitcherMaxHeight,
                width: sceneSwitcherWidth,
                height: sceneSwitcherMaxHeight,
            ),
            display: true,
            animate: false,
        )
        hostingView.rootView = AnyView(SceneSwitcherView(model: model, runtime: model.runtime))
        orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        makeKey()
    }

    func dismiss() {
        guard isPanelActive else { return }
        isPanelActive = false
        orderOut(nil)
        hostingView.rootView = AnyView(EmptyView())
    }

    /// Run a change that can reach the engine the way every other surface in this app runs one.
    ///
    /// Entering a Scene and composing a Slot rebind windows in the inherited tree; it is the session that
    /// follows — `layoutWorkspaces()` — that actually moves them, and the session that first cancels any
    /// refresh already in flight. Mutating the tree outside one would leave the screen disagreeing with the
    /// Scene until something unrelated triggered a refresh, and would interleave with a running refresh while
    /// doing it. The body reads the model's own answer, so the panel still decides synchronously whether the
    /// keystroke did anything.
    private func inSession(_ body: @escaping @MainActor () -> Void) {
        guard let token: RunSessionGuard = .isServerEnabled else { return body() }
        Task { @MainActor in
            try await runLightSession(.menuBarButton, token) { body() }
        }
    }

    /// Panel-local keys. Everything else — the typing — goes to the field as usual.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, isPanelActive {
            let isCommand = event.modifierFlags.contains(.command)
            // ⌘1…9 jumps to the Nth row without leaving the field, mirroring the inherited palette.
            if isCommand, let digit = event.charactersIgnoringModifiers.flatMap({ Int($0) }), (1 ... 9).contains(digit) {
                model.select(at: digit - 1)
                return
            }
            switch (event.keyCode, isCommand) {
                case (53, _): // esc — abandon the edit first, dismiss only a panel that is merely browsing
                    if model.escape() { dismiss() }
                    return
                case (51, true): // ⌘⌫ — ask what closing the selected Scene would do
                    model.beginClose()
                    return
                case (36, true), (76, true): // ⌘⏎ — enter, and stay open
                    inSession { self.model.enterSelected() }
                    return
                case (36, false), (76, false): // ⏎
                    if model.mode.isEditingText {
                        inSession { self.model.commitName() }
                    } else {
                        inSession { if self.model.enterSelected() { self.dismiss() } }
                    }
                    return
                case (120, _): // F2 — rename in place
                    model.beginRename()
                    return
                case (125, false) where !model.mode.isEditingText: // ↓
                    model.moveSelection(1)
                    return
                case (126, false) where !model.mode.isEditingText: // ↑
                    model.moveSelection(-1)
                    return
                default:
                    break
            }
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
private func sceneSwitcherScreenMaxY() -> CGFloat {
    NSScreen.screens.first?.frame.maxY ?? 0
}
