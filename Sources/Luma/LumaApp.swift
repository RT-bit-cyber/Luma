import AppKit
import SwiftUI
import ServiceManagement
import AmbientHardware
import LumaCore
import CoreFoundation
import CoreServices

final class LumaModel: ObservableObject {
    @Published var lux: Double?
    @Published var status = "Reading the light sensor…"
    @Published var issue: String?
    @Published var enabled: Bool
    @Published var darkThreshold: Double
    @Published var lightThreshold: Double
    @Published var delay: Double
    @Published var loginEnabled = false
    @Published var loginMessage: String?
    @Published var current: Appearance = .light
    private var policy = AppearancePolicy()
    private var timer: Timer?
    private var sleeping = false
    private var observers: [NSObjectProtocol] = []
    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: ["enabled": true, "darkThreshold": 40.0, "lightThreshold": 80.0, "delay": 10.0])
        enabled = defaults.bool(forKey: "enabled")
        let d = defaults.double(forKey: "darkThreshold")
        let initialDark = d.isFinite ? min(max(d, 1), 500) : 40
        darkThreshold = initialDark
        let l = defaults.double(forKey: "lightThreshold")
        lightThreshold = l.isFinite ? min(max(l, initialDark + 10), 2000) : max(80, initialDark + 10)
        let t = defaults.double(forKey: "delay")
        delay = t.isFinite ? min(max(t, 4), 60) : 10
        refreshLogin()
        configure()
        if !enabled { restoreSystemSchedule() }
        let centre = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.suspend()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(centre.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.resume()
            })
        }
    }

    func start() {
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.sample() }
        timer.tolerance = 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        sample()
    }

    func configure() {
        darkThreshold = min(max(darkThreshold, 1), 500)
        lightThreshold = min(max(lightThreshold, darkThreshold + 10), 2000)
        delay = min(max(delay, 4), 60)
        defaults.set(darkThreshold, forKey: "darkThreshold")
        defaults.set(lightThreshold, forKey: "lightThreshold")
        defaults.set(delay, forKey: "delay")
        policy = AppearancePolicy(darkThreshold: darkThreshold, lightThreshold: lightThreshold, delay: delay)
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        defaults.set(value, forKey: "enabled")
        issue = nil
        policy.reset()
        if !value { restoreSystemSchedule() }
        sample()
    }

    func suspend() {
        sleeping = true
        policy.reset()
        ambient_reset()
        lux = nil
        status = "Waiting for your Mac to wake"
    }

    func resume() {
        sleeping = false
        policy.reset()
        ambient_reset()
        sample()
    }

    func sample() {
        guard !sleeping else { return }
        current = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
        guard ambient_lid_closed() == 0 else {
            lux = nil
            policy.reset()
            status = "Paused while the lid is closed"
                return
        }
        let reading = ambient_read_lux()
        lux = reading >= 0 ? reading : nil
        guard let lux else {
            policy.reset()
            status = "Sensor unavailable — keeping current appearance"
                return
        }
        guard enabled else {
            policy.reset()
            status = "Automatic switching is paused"
                return
        }
        takeOverSystemSchedule()
        if let target = policy.update(lux: lux, current: current, now: ProcessInfo.processInfo.systemUptime) {
            apply(target)
        }
        if enabled {
            if let pending = policy.pending {
                status = "Waiting for steady light before switching to \(pending.rawValue)"
            } else {
                status = "Following ambient light · \(current.rawValue.capitalized) mode"
            }
        }
    }

    @discardableResult
    func apply(_ appearance: Appearance) -> Bool {
        let source = """
        with timeout of 15 seconds
            tell application "System Events" to tell appearance preferences to set dark mode to \(appearance == .dark ? "true" : "false")
        end timeout
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        let result = script.executeAndReturnError(&error)
        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let detail = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            issue = code == -1743
                ? "Allow Luma to control System Events in System Settings → Privacy & Security → Automation, then resume automatic switching."
                : "Could not change appearance: \(detail) (\(code)). Resume to retry."
            enabled = false
            restoreSystemSchedule()
            defaults.set(false, forKey: "enabled")
            policy.reset()
            status = "Automatic switching needs attention"
                return false
        }
        _ = result
        current = appearance
        issue = nil
        return true
    }

    func manual(_ appearance: Appearance) {
        setEnabled(false)
        if apply(appearance) { status = "\(appearance.rawValue.capitalized) mode · automatic switching paused" }
    }

    // Auto is based on time of day and otherwise competes with the sensor.
    // Persist the restoration marker so it survives an unexpected app exit.
    func takeOverSystemSchedule() {
        let key = "AppleInterfaceStyleSwitchesAutomatically" as CFString
        let original = CFPreferencesCopyValue(key, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Bool ?? false
        if original {
            defaults.set(true, forKey: "restoreSystemAuto")
            CFPreferencesSetValue(key, kCFBooleanFalse, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
            CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        }
    }

    func restoreSystemSchedule() {
        guard defaults.bool(forKey: "restoreSystemAuto") else { return }
        CFPreferencesSetValue("AppleInterfaceStyleSwitchesAutomatically" as CFString, kCFBooleanTrue, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) {
            defaults.removeObject(forKey: "restoreSystemAuto")
        }
    }

    func refreshLogin() {
        loginEnabled = SMAppService.mainApp.status == .enabled
        loginMessage = SMAppService.mainApp.status == .requiresApproval ? "Approve Luma in System Settings → General → Login Items & Extensions." : nil
    }

    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLogin()
        } catch {
            refreshLogin()
            loginMessage = "Could not update launch at login: \(error.localizedDescription)"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: LumaModel!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.lightsaber.Luma").count > 1 {
            NSApp.terminate(nil); return
        }
        model = LumaModel()
        model.start()

        // Login and service launches stay in the background. A deliberate
        // launch from Finder or Spotlight opens the controls instead.
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchKind = event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue
        let launchedInBackground = event?.eventID == kAEOpenApplication &&
            (launchKind == keyAELaunchedAsLogInItem || launchKind == keyAELaunchedAsServiceItem)
        if !launchedInBackground { showSettings() }
    }

    private func showSettings() {
        guard model != nil else { return }
        model.refreshLogin()
        if let window = settingsWindow, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 700)
        let style: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let titleHeight = NSWindow.frameRect(forContentRect: .zero, styleMask: [.titled, .closable]).height
        let size = NSSize(width: min(440, max(1, visible.width - 24)),
                          height: min(600, max(1, visible.height - titleHeight - 24)))
        let windowSize = NSSize(width: size.width, height: size.height + titleHeight)
        let controller = NSHostingController(rootView: SettingsWindowView(model: model, size: size))
        controller.sizingOptions = []
        controller.view.setFrameSize(windowSize)
        controller.preferredContentSize = windowSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: windowSize),
                              styleMask: style, backing: .buffered, defer: false)
        window.title = "Luma Settings"
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentViewController = controller
        window.setContentSize(windowSize)
        window.setFrameOrigin(NSPoint(x: visible.midX - window.frame.width / 2,
                                      y: visible.midY - window.frame.height / 2))
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) { model?.restoreSystemSchedule() }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
}

@main
struct LumaApp {
    static func main() {
        if CommandLine.arguments.contains("--sensor-check") {
            let lux = ambient_read_lux()
            print(lux >= 0 ? String(format: "Ambient light: %.2f lux; lid closed: %d", lux, ambient_lid_closed()) : "Ambient light sensor unavailable")
            exit(lux >= 0 ? 0 : 1)
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
