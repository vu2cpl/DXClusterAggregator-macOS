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

    /// When true, only confirmed QSOs (LOTW/QSL/eQSL) count as worked. A worked-but-unconfirmed
    /// slot will then be classified as "new" (so users can re-work for confirmation).
    var alertUnconfirmed: Bool = false

    /// Bands to import from the ClubLog ADIF download. Empty = all bands.
    /// Format matches BandResolver names ("160M", "80M", ...).
    var importBands: Set<String> = []

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
