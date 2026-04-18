import Foundation

struct ClubLogConfig: Codable, Equatable {
    var callsign: String = ""
    var email: String = ""
    var appPassword: String = ""
    var apiKey: String = ""
    var autoRefreshOnStart: Bool = false
    var refreshIntervalHours: Int = 0  // 0 = manual only

    // Alert toggles - user selects which alert types to highlight
    var alertNewDXCC: Bool = true
    var alertNewSlot: Bool = true    // new DXCC+band+mode combo
    var alertNewBand: Bool = false   // new band on known DXCC
    var alertNewMode: Bool = false   // new mode on known DXCC

    var lastRefresh: Date? = nil
    var qsoCount: Int = 0
}

enum AlertLevel: String, Codable {
    case none      // not classified (no log data)
    case worked    // already worked this slot
    case newMode
    case newBand
    case newSlot   // new DXCC+band+mode
    case newDXCC   // brand new DXCC entity
}
