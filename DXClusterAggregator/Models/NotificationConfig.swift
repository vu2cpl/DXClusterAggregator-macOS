import Foundation

struct NotificationConfig: Codable, Equatable {
    // Telegram
    var telegramEnabled: Bool = false
    var telegramBotToken: String = ""
    var telegramChatId: String = ""

    // System (macOS Notification Center)
    var systemEnabled: Bool = false

    /// Per-callsign cooldown in minutes (5..60). A second alert for the same
    /// callsign within this window is suppressed for both Telegram and system.
    var cooldownMinutes: Int = 15

    /// Which alert levels should trigger a notification. Mirrors the table-highlight
    /// toggles but kept separate so user can have visual highlight without push spam.
    var notifyNewDXCC: Bool = true
    var notifyNewSlot: Bool = true
    var notifyNewBand: Bool = false
    var notifyNewMode: Bool = false
}
