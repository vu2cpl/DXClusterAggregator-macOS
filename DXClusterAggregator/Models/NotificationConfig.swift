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
    var notifyNewBand: Bool = true
    var notifyNewMode: Bool = true

    // Backward-compatible Codable (see ClubLogConfig for rationale)
    private enum CodingKeys: String, CodingKey {
        case telegramEnabled, telegramBotToken, telegramChatId,
             systemEnabled, cooldownMinutes,
             notifyNewDXCC, notifyNewSlot, notifyNewBand, notifyNewMode
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.telegramEnabled  = (try? c.decodeIfPresent(Bool.self, forKey: .telegramEnabled)) ?? false
        self.telegramBotToken = (try? c.decodeIfPresent(String.self, forKey: .telegramBotToken)) ?? ""
        self.telegramChatId   = (try? c.decodeIfPresent(String.self, forKey: .telegramChatId)) ?? ""
        self.systemEnabled    = (try? c.decodeIfPresent(Bool.self, forKey: .systemEnabled)) ?? false
        self.cooldownMinutes  = (try? c.decodeIfPresent(Int.self, forKey: .cooldownMinutes)) ?? 15
        self.notifyNewDXCC    = (try? c.decodeIfPresent(Bool.self, forKey: .notifyNewDXCC)) ?? true
        self.notifyNewSlot    = (try? c.decodeIfPresent(Bool.self, forKey: .notifyNewSlot)) ?? true
        self.notifyNewBand    = (try? c.decodeIfPresent(Bool.self, forKey: .notifyNewBand)) ?? true
        self.notifyNewMode    = (try? c.decodeIfPresent(Bool.self, forKey: .notifyNewMode)) ?? true
    }
}
