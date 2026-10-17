import AppKit
import ApplicationServices
import ServiceManagement

// Private but long-stable API (used by yabai, AltTab, AutoRaise) that maps an
// AX window element to its CGWindowID.
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Focus-follows-mouse: when the cursor comes to rest over a window that isn't
/// focused, focus (and optionally raise) it.
@MainActor
final class FocusController: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "enabled") }
    }
    @Published var raiseOnFocus: Bool {
        didSet { UserDefaults.standard.set(raiseOnFocus, forKey: "raiseOnFocus") }
    }
    /// How long the cursor must rest before focus switches. Stops windows you
    /// merely sweep across from stealing focus.
    @Published var delayMs: Int {
        didSet { UserDefaults.standard.set(delayMs, forKey: "delayMs") }
    }
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Hover: launch at login failed: \(error)")
            }
        }
    }

    static let delayOptions = [0, 50, 100, 150, 250, 400]

    private var monitor: Any?
    private var pending: DispatchWorkItem?
    private var trustTimer: Timer?
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["enabled": true, "raiseOnFocus": true, "delayMs": 0])
        isEnabled = defaults.bool(forKey: "enabled")
        raiseOnFocus = defaults.bool(forKey: "raiseOnFocus")
        delayMs = defaults.integer(forKey: "delayMs")

        // A hung app shouldn't be able to freeze us for the 6s AX default.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25)

        requestTrust()
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }
    }

    func requestTrust() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isTrusted = AXIsProcessTrustedWithOptions(options)
        guard !isTrusted, trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, AXIsProcessTrusted() else { return }
                self.isTrusted = true
                timer.invalidate()
                self.trustTimer = nil
            }
        }
    }

    // MARK: Mouse tracking

    private func mouseMoved() {
        pending?.cancel()
        guard isEnabled, isTrusted else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.focusWindowUnderCursor() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: work)
    }

    private func focusWindowUnderCursor() {
        // Never switch mid-drag or mid-click.
        guard NSEvent.pressedMouseButtons == 0,
              let point = CGEvent(source: nil)?.location,
              let (pid, windowID) = topWindow(at: point),
              pid != ownPID
        else { return }

        let app = AXUIElementCreateApplication(pid)
        let isFrontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
        if isFrontmost,
           let focused: AXUIElement = attribute(app, kAXFocusedWindowAttribute),
           self.windowID(of: focused) == windowID {
            return
        }

        guard let windows: [AXUIElement] = attribute(app, kAXWindowsAttribute),
              let window = windows.first(where: { self.windowID(of: $0) == windowID })
        else { return }

        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        if raiseOnFocus {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        if !isFrontmost {
            AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        }
    }

    /// Frontmost normal window under `point` (global, top-left origin). Returns
    /// nil if something above the normal window layer — menu bar, Dock, a menu,
    /// Spotlight, a notification — is under the cursor, so those never cause a
    /// focus change.
    private func topWindow(at point: CGPoint) -> (pid_t, CGWindowID)? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return nil }

        for info in list {
            guard let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  bounds.contains(point)
            else { continue }
            // Skip invisible overlays some apps leave on screen.
            if let alpha = info[kCGWindowAlpha as String] as? Double, alpha == 0 { continue }

            let layer = info[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let id = info[kCGWindowNumber as String] as? CGWindowID
            else { return nil }
            return (pid, id)
        }
        return nil
    }

    // MARK: AX helpers

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(element, &id) == .success ? id : nil
    }
}
