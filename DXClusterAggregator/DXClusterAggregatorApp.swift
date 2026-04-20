import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the last window only hides the app — keep running so the menu bar
    /// item stays available and monitoring continues.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Re-show the main window when the user clicks the Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

/// Helpers for showing / hiding the main window from anywhere in the app.
enum WindowManager {
    static func hideMainWindow() {
        NSApp.hide(nil)
    }

    static func showMainWindow() {
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
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
        let candidates: [URL?] = [
            // SwiftPM-generated resource bundle in .app Resources
            Bundle.main.url(
                forResource: "MenuBarIcon",
                withExtension: "png",
                subdirectory: "DXClusterAggregator_DXClusterAggregator.bundle"
            ),
            // Directly in main bundle (if we copied it into Resources/)
            Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
            // Fallback: look next to the executable (for `swift run`)
            {
                let exe = Bundle.main.executableURL?.deletingLastPathComponent()
                return exe?.appendingPathComponent(
                    "DXClusterAggregator_DXClusterAggregator.bundle/MenuBarIcon.png"
                )
            }()
        ]

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
