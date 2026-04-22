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

    /// URL to the LoTW user-activity file (CSV of every callsign that has
    /// ever uploaded a QSO to ARRL Logbook of The World). Default is ARRL's
    /// own authoritative file. Local filesystem paths or file:// URLs are
    /// also accepted if you'd rather point to a downloaded copy.
    var lotwUsersURL: String = "https://lotw.arrl.org/lotw-user-activity.csv"
    /// Mark LoTW users in the Callsign column with a trailing dot.
    var markLoTWUsers: Bool = true

    // MARK: - Backward-compatible Codable
    //
    // Swift's auto-synthesized init(from:) throws if a key is missing from
    // the JSON, which means adding a new non-optional field to this struct
    // would cause the decoder to fail on older UserDefaults data and the
    // entire configuration would reset to defaults (wiping callsign, email,
    // passwords, etc.). To prevent that, we decode every field via
    // decodeIfPresent and fall back to the property's default value when
    // the key isn't present.

    private enum CodingKeys: String, CodingKey {
        case callsign, email, appPassword, apiKey, autoRefreshOnStart,
             refreshIntervalHours, alertNewDXCC, alertNewSlot, alertNewBand,
             alertNewMode, alertUnconfirmed, importBands, lastRefresh,
             qsoCount, lotwUsersURL, markLoTWUsers
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.callsign            = (try? c.decodeIfPresent(String.self, forKey: .callsign)) ?? ""
        self.email               = (try? c.decodeIfPresent(String.self, forKey: .email)) ?? ""
        self.appPassword         = (try? c.decodeIfPresent(String.self, forKey: .appPassword)) ?? ""
        self.apiKey              = (try? c.decodeIfPresent(String.self, forKey: .apiKey)) ?? ""
        self.autoRefreshOnStart  = (try? c.decodeIfPresent(Bool.self, forKey: .autoRefreshOnStart)) ?? false
        self.refreshIntervalHours = (try? c.decodeIfPresent(Int.self, forKey: .refreshIntervalHours)) ?? 0
        self.alertNewDXCC        = (try? c.decodeIfPresent(Bool.self, forKey: .alertNewDXCC)) ?? true
        self.alertNewSlot        = (try? c.decodeIfPresent(Bool.self, forKey: .alertNewSlot)) ?? true
        self.alertNewBand        = (try? c.decodeIfPresent(Bool.self, forKey: .alertNewBand)) ?? false
        self.alertNewMode        = (try? c.decodeIfPresent(Bool.self, forKey: .alertNewMode)) ?? false
        self.alertUnconfirmed    = (try? c.decodeIfPresent(Bool.self, forKey: .alertUnconfirmed)) ?? false
        self.importBands         = (try? c.decodeIfPresent(Set<String>.self, forKey: .importBands)) ?? []
        self.lastRefresh         = try? c.decodeIfPresent(Date.self, forKey: .lastRefresh)
        self.qsoCount            = (try? c.decodeIfPresent(Int.self, forKey: .qsoCount)) ?? 0
        self.lotwUsersURL        = (try? c.decodeIfPresent(String.self, forKey: .lotwUsersURL))
            ?? "https://lotw.arrl.org/lotw-user-activity.csv"
        self.markLoTWUsers       = (try? c.decodeIfPresent(Bool.self, forKey: .markLoTWUsers)) ?? true
    }
}

enum AlertLevel: String, Codable {
    case none      // not classified (no log data)
    case worked    // already worked this slot
    case newMode
    case newBand
    case newSlot   // new DXCC+band+mode
    case newDXCC   // brand new DXCC entity
}
