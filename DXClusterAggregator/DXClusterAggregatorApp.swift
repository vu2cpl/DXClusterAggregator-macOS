import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// The single SwiftUI WindowGroup window we manage. Other entries in
    /// NSApp.windows (MenuBarExtra status item, SwiftUI auxiliary scenes)
    /// must not be touched — bringing them up was producing two windows
    /// on Dock click.
    fileprivate weak var mainWindow: NSWindow?

    /// Singleton reference so static helpers (WindowManager) can find the
    /// tracked main window without re-scanning NSApp.windows.
    static fileprivate weak var shared: AppDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    /// Closing the last window only hides the app — keep running so the menu bar
    /// item stays available and monitoring continues.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Once SwiftUI has built our WindowGroup window, intercept its close
    /// button so it hides instead of being released. Without this, the
    /// red-X destroys the SwiftUI scene and dock-click / menu-bar "Show
    /// Window" can't bring it back — the window list is empty.
    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.attachToMainWindow()
        }
    }

    @discardableResult
    fileprivate func attachToMainWindow() -> NSWindow? {
        if let existing = mainWindow { return existing }
        // Pick the first "real" content window — has a title bar and can
        // become main. MenuBarExtra status item is borderless / utility.
        guard let win = NSApp.windows.first(where: { window in
            window.canBecomeMain && window.styleMask.contains(.titled)
        }) else {
            return nil
        }
        win.isReleasedWhenClosed = false
        win.delegate = self
        mainWindow = win
        return win
    }

    /// Hide the window instead of letting AppKit close+release it.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    /// Re-show the main window when the user clicks the Dock icon.
    /// Returning `false` suppresses AppKit's default reopen behaviour
    /// (which would create a SECOND new window on top of ours).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            let win = mainWindow ?? attachToMainWindow()
            win?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
}

/// Helpers for showing / hiding the main window from anywhere in the app.
enum WindowManager {
    static func hideMainWindow() {
        NSApp.hide(nil)
    }

    static func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Use the same tracked main-window reference the AppDelegate uses
        // for Dock-click reopen. Filtering NSApp.windows by style flags is
        // unreliable when the window has been order-out'd.
        let win = AppDelegate.shared?.mainWindow ?? AppDelegate.shared?.attachToMainWindow()
        win?.makeKeyAndOrderFront(nil)
    }
}

@main
struct DXClusterAggregatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
        .defaultSize(width: 800, height: 800)

        // Menu bar status item (always present) with custom template icon
        MenuBarExtra {
            Button("Show Window") {
                WindowManager.showMainWindow()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Hide Window") {
                WindowManager.hideMainWindow()
            }
            .keyboardShortcut("h", modifiers: [.command])

            Divider()

            Button("Quit DXClusterAggregator") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        } label: {
            MenuBarLabel()
        }
    }
}

/// Loads the custom menu bar icon with fallback to an SF Symbol.
/// Searches several locations to handle both `swift run` and packaged .app bundles.
struct MenuBarLabel: View {
    var body: some View {
        if let image = Self.loadImage() {
            Image(nsImage: image)
        } else {
            Image(systemName: "dot.radiowaves.up.forward")
        }
    }

    private static func loadImage() -> NSImage? {
        // Try via the SwiftPM resource sub-bundle's own Bundle, which knows
        // its internal layout (Contents/Resources/) regardless of how the
        // outer .app was packaged.
        var subBundleImage: NSImage? = nil
        if let subBundleURL = Bundle.main.url(
                forResource: "DXClusterAggregator_DXClusterAggregator",
                withExtension: "bundle"),
           let subBundle = Bundle(url: subBundleURL),
           let url = subBundle.url(forResource: "MenuBarIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            subBundleImage = img
        }

        let candidates: [URL?] = [
            // Directly in main bundle Resources (if copied loose)
            Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
            // SwiftPM old layout — bundle as a flat directory of files
            Bundle.main.url(
                forResource: "MenuBarIcon", withExtension: "png",
                subdirectory: "DXClusterAggregator_DXClusterAggregator.bundle"
            ),
            // SwiftPM newer layout — bundle is a proper macOS bundle with
            // its own Contents/Resources/
            Bundle.main.url(
                forResource: "MenuBarIcon", withExtension: "png",
                subdirectory: "DXClusterAggregator_DXClusterAggregator.bundle/Contents/Resources"
            ),
            // Fallback: look next to the executable (for `swift run`)
            {
                let exe = Bundle.main.executableURL?.deletingLastPathComponent()
                return exe?.appendingPathComponent(
                    "DXClusterAggregator_DXClusterAggregator.bundle/Contents/Resources/MenuBarIcon.png"
                )
            }(),
            {
                let exe = Bundle.main.executableURL?.deletingLastPathComponent()
                return exe?.appendingPathComponent(
                    "DXClusterAggregator_DXClusterAggregator.bundle/MenuBarIcon.png"
                )
            }()
        ]

        if let img = subBundleImage {
            img.isTemplate = true
            img.size = NSSize(width: 18, height: 18)
            return img
        }

        for url in candidates {
            if let url = url, FileManager.default.fileExists(atPath: url.path),
               let img = NSImage(contentsOf: url) {
                img.isTemplate = true
                // Slightly larger default size for menu bar (macOS will scale)
                img.size = NSSize(width: 18, height: 18)
                return img
            }
        }
        return nil
    }
}
