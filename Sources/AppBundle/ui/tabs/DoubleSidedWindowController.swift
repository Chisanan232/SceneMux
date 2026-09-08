import AppKit
import QuartzCore

/// Animates snapshots because another app's window cannot host our Core Animation layers.
@MainActor
final class DoubleSidedWindowController {
    static let shared = DoubleSidedWindowController()
    private var candidate: (windowId: UInt32, point: CGPoint)?
    private var animationPanel: NSPanel?
    private let backdropPadding: CGFloat = 64

    func note(type: NSEvent.EventType, modifiers: NSEvent.ModifierFlags, point: CGPoint) {
        switch type {
            case .leftMouseDown:
                candidate = nil
                guard TrayMenuModel.shared.isEnabled,
                      ExperimentalUISettings().doubleSidedWindows,
                      modifiers.intersection([.option, .command, .control, .shift]) == .option,
                      animationPanel == nil,
                      let window = titleBarWindow(at: point),
                      window.nearestWindowTabGroup?.usesDoubleSidedWindows == true
                else { return }
                candidate = (window.windowId, point)
            case .leftMouseDragged:
                if let candidate, hypot(point.x - candidate.point.x, point.y - candidate.point.y) > 4 {
                    self.candidate = nil
                }
            case .leftMouseUp:
                let pending = candidate
                candidate = nil
                guard let pending,
                      hypot(point.x - pending.point.x, point.y - pending.point.y) <= 4,
                      modifiers.contains(.option),
                      let window = Window.get(byId: pending.windowId)
                else { return }
                flip(window)
            default:
                break
        }
    }

    private func titleBarWindow(at point: CGPoint) -> Window? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(point.y), &hit) == .success,
              let hit,
              let id = hit.containingWindowId(),
              let window = Window.get(byId: id),
              let rect = window.lastAppliedLayoutPhysicalRect,
              point.x >= rect.topLeftX, point.x <= rect.topLeftX + rect.width,
              point.y >= rect.topLeftY, point.y <= rect.topLeftY + 28
        else { return nil }
        // Exclude traffic lights, tabs, text fields, and toolbar controls. Custom title bars
        // that expose no window or static-text hit target retain their normal behavior.
        var role: CFTypeRef?
        guard AXUIElementCopyAttributeValue(hit, kAXRoleAttribute as CFString, &role) == .success,
              let role = role as? String,
              role == kAXWindowRole as String || role == kAXStaticTextRole as String
        else { return nil }
        return window
    }

    private func flip(_ window: Window) {
        guard TrayMenuModel.shared.isEnabled,
              let group = window.nearestWindowTabGroup,
              group.usesDoubleSidedWindows,
              group.tabActiveWindow === window,
              let other = group.children.compactMap({ $0 as? Window }).first(where: { $0 !== window }),
              let rect = window.lastAppliedLayoutPhysicalRect
        else { return }
        let canAnimate = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion && CGPreflightScreenCaptureAccess()
        let front = canAnimate ? snapshot(window.windowId) : nil
        let back = canAnimate ? snapshot(other.windowId) : nil
        if let front, let back,
           let background = CGWindowListCreateImage(
               CGRect(x: rect.topLeftX, y: rect.topLeftY, width: rect.width, height: rect.height)
                   .insetBy(dx: -backdropPadding, dy: -backdropPadding),
               .optionOnScreenBelowWindow, window.windowId, [.nominalResolution]
           ) {
            animate(front: front, back: back, background: background, rect: rect)
        }
        focusWindowFromTabStrip(other.windowId, fallbackWorkspace: focus.workspace.name)
    }

    private func snapshot(_ id: UInt32) -> CGImage? {
        guard let image = CGWindowListCreateImage(
            .null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .nominalResolution]
        ) else { return nil }
        // Nominal resolution is one pixel per point. Trim the native one-point outline
        // so it does not become a bright edge when the snapshot rotates.
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard image.width > 2, image.height > 2 else { return image }
        return image.cropping(to: bounds.insetBy(dx: 1, dy: 1))
    }

    private func animate(front: CGImage, back: CGImage, background: CGImage, rect: Rect) {
        let frame = CGRect(x: rect.topLeftX, y: mainMonitor.height - rect.topLeftY - rect.height,
                           width: rect.width, height: rect.height)
            .insetBy(dx: -backdropPadding, dy: -backdropPadding)
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        let root = CALayer()
        // Cover the real windows and their shadows throughout the rotation.
        root.contents = background
        root.contentsGravity = .resize
        view.layer = root
        panel.contentView = view
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / max(rect.width * 2, 1000)
        root.sublayerTransform = perspective
        let duration = 0.48
        for (image, start, end) in [(front, 0.0, Double.pi), (back, -Double.pi, 0.0)] {
            let face = CALayer()
            face.frame = view.bounds.insetBy(dx: backdropPadding, dy: backdropPadding)
            face.contents = image
            face.contentsGravity = .resize
            face.isDoubleSided = false
            face.allowsEdgeAntialiasing = true
            root.addSublayer(face)
            face.transform = CATransform3DMakeRotation(CGFloat(end), 0, 1, 0)
            let rotation = CABasicAnimation(keyPath: "transform.rotation.y")
            rotation.fromValue = start
            rotation.toValue = end
            rotation.duration = duration
            rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            face.add(rotation, forKey: "flip")
        }
        animationPanel = panel
        panel.orderFrontRegardless()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            panel.orderOut(nil)
            if animationPanel === panel { animationPanel = nil }
        }
    }
}
