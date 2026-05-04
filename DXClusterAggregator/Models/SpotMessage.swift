import Foundation

struct SpotMessage: Identifiable {
    let id = UUID()
    let time: Date
    let snr: Int32
    let deltaTime: Double
    let deltaFrequency: UInt32
    let mode: String
    let message: String
    let lowConfidence: Bool
    let offAir: Bool
    let dialFrequency: UInt64
    let sourceName: String

    // Alert classification (set by ContentView before appending)
    var alertLevel: AlertLevel = .none
    var dxccName: String? = nil
    var bandName: String? = nil
    var isBeacon: Bool = false
    var isLoTWUser: Bool = false

    /// Prefix the message with "[BEACON] " if this spot is from a known beacon
    /// so the user sees it at a glance in the Message column.
    var displayMessage: String {
        isBeacon ? "[BEACON] \(message)" : message
    }

    var frequencyMHz: Double {
        Double(dialFrequency + UInt64(deltaFrequency)) / 1_000_000.0
    }

    var frequencyKHz: Double {
        Double(dialFrequency + UInt64(deltaFrequency)) / 1_000.0
    }

    var dxCallsign: String? {
        // FT8 message formats we care about:
        //   "CQ DX_CALL GRID"
        //   "CQ NA DX_CALL GRID"           (directed CQ)
        //   "DE_CALL DX_CALL REPORT|RR73|73|GRID"
        //   "<HASHED> CALL REPORT"         (one side hashed)
        // We spot whichever token in positions 0/1 looks like a real callsign,
        // skipping placeholder tokens like RR73, 73, R+05, grids (LL85), etc.
        let parts = message.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }

        if parts[0].uppercased() == "CQ" {
            // "CQ CALL GRID" or "CQ XX CALL GRID" (XX = directional like NA, DX, EU)
            if parts.count >= 3, !looksLikeCallsign(parts[1]) {
                return looksLikeCallsign(parts[2]) ? Self.stripCallDecoration(parts[2]) : nil
            }
            return looksLikeCallsign(parts[1]) ? Self.stripCallDecoration(parts[1]) : nil
        }

        // Two-station exchange. Prefer parts[1] (the calling/transmitting
        // station — the one this spotter is hearing), fall back to parts[0]
        // if parts[1] is decoration (hashed/placeholder/grid/report).
        if looksLikeCallsign(parts[1]) {
            return Self.stripCallDecoration(parts[1])
        }
        if looksLikeCallsign(parts[0]) {
            return Self.stripCallDecoration(parts[0])
        }
        return nil
    }

    var isCQ: Bool {
        message.uppercased().hasPrefix("CQ ")
    }

    /// Strip `<>` brackets used by WSJT-X for hashed/known callsigns so the
    /// cluster line shows just `K1JT` instead of `<K1JT>`.
    private static func stripCallDecoration(_ s: String) -> String {
        var t = s
        if t.hasPrefix("<") { t.removeFirst() }
        if t.hasSuffix(">") { t.removeLast() }
        return t
    }

    /// Reject FT8 tokens that aren't callsigns: RR73 / RRR / 73 / TU /
    /// signal reports (R+05, -12, +03) / 4-char Maidenhead grids (LL85) /
    /// hashed-call placeholder `<...>`.
    private func looksLikeCallsign(_ s: String) -> Bool {
        let upper = s.uppercased()
        let core: String = {
            var t = upper
            if t.hasPrefix("<") { t.removeFirst() }
            if t.hasSuffix(">") { t.removeLast() }
            return t
        }()
        if core.isEmpty || core == "..." { return false }
        if core.count < 3 || core.count > 11 { return false }

        let blacklist: Set<String> = ["RR73", "RRR", "73", "TU", "TNX", "QSL", "DE", "TEST", "CQ"]
        if blacklist.contains(core) { return false }

        // Signal reports: R+05, R-12, +05, -12
        if core.hasPrefix("R+") || core.hasPrefix("R-") { return false }
        if core.hasPrefix("+") || core.hasPrefix("-") {
            if core.dropFirst().allSatisfy({ $0.isNumber }) { return false }
        }

        // 4-char Maidenhead grid: 2 letters + 2 digits
        if core.count == 4 {
            let c = Array(core)
            if c[0].isLetter && c[1].isLetter && c[2].isNumber && c[3].isNumber {
                return false
            }
        }

        // Real callsigns: letter+digit+letter pattern, allow / for portable.
        let hasDigit = core.contains { $0.isNumber }
        let hasLetter = core.contains { $0.isLetter }
        guard hasDigit && hasLetter else { return false }

        // Reject pure-numeric-suffix tokens like "R549", "R-09" already handled,
        // but also catch "599KW" style by requiring the call form: at most one
        // '/' and only [A-Z0-9/].
        let allowed = core.allSatisfy { $0.isLetter || $0.isNumber || $0 == "/" }
        return allowed
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: time)
    }

    // MARK: - Sortable keys (non-optional, Comparable) for the Table

    var sortCallsign: String { dxCallsign ?? "" }
    var sortDXCC: String { dxccName ?? "" }
    var sortBand: String { bandName ?? "" }
}
