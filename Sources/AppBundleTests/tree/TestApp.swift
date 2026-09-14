@testable import AppBundle
import Common

final class TestApp: AbstractApp {
    let pid: Int32
    let rawAppBundleId: String?
    let name: String?
    let execPath: String? = nil
    let bundlePath: String? = nil
    @MainActor
    static let shared = TestApp()

    /// A second, third, fourth application, for tests about *which* application a window belongs to.
    ///
    /// A Scene addresses windows by bundle id plus ordinal, so a test that only ever has one application
    /// cannot tell a correct resolver from one that ignores the bundle id entirely.
    init(bundleId: String = "com.chisanan232.scenemux.test-app", pid: Int32 = 0) {
        self.pid = pid
        self.rawAppBundleId = bundleId
        self.name = bundleId
    }

    var _windows: [Window] = []
    var windows: [Window] {
        get { _windows }
        set {
            if let focusedWindow {
                check(newValue.contains(focusedWindow))
            }
            _windows = newValue
        }
    }

    private var _focusedWindow: Window? = nil
    var focusedWindow: Window? {
        get { _focusedWindow }
        set {
            if let window = newValue {
                check(windows.contains(window))
            }
            _focusedWindow = newValue
        }
    }
    @MainActor func getFocusedWindow() -> Window? { _focusedWindow }
}
