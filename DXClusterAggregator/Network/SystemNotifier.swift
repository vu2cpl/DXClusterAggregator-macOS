import Foundation
import UserNotifications

/// Wraps macOS Notification Center delivery.
final class SystemNotifier {
    private static var didRequestAuth = false

    /// Request authorization once. Safe to call repeatedly.
    static func requestAuthorizationIfNeeded() {
        guard !didRequestAuth else { return }
        didRequestAuth = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error.localizedDescription)")
            } else {
                print("Notification authorization granted: \(granted)")
            }
        }
    }

    /// Post a banner notification.
    static func post(title: String, body: String, identifier: String = UUID().uuidString) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification post error: \(error.localizedDescription)")
            }
        }
    }
}
