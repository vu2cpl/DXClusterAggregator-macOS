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
struct FT8ClusterAggregatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
        }
        .defaultSize(width: 800, height: 800)

        // Menu bar status item (always present)
        MenuBarExtra("FT8ClusterAggregator", systemImage: "antenna.radiowaves.left.and.right") {
            Button("Show Window") {
                WindowManager.showMainWindow()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Hide Window") {
                WindowManager.hideMainWindow()
            }
            .keyboardShortcut("h", modifiers: [.command])

            Divider()

            Button("Quit FT8ClusterAggregator") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
}
