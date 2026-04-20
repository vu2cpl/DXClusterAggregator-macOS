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

    var frequencyMHz: Double {
        Double(dialFrequency + UInt64(deltaFrequency)) / 1_000_000.0
    }

    var frequencyKHz: Double {
        Double(dialFrequency + UInt64(deltaFrequency)) / 1_000.0
    }

    var dxCallsign: String? {
        // FT8 message formats:
        // "CQ DX_CALL GRID"
        // "CQ NA DX_CALL GRID"  (directed CQ)
        // "DE_CALL DX_CALL REPORT"
        // "DE_CALL DX_CALL RRR"
        // "DE_CALL DX_CALL 73"
        let parts = message.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { return nil }

        if parts[0].uppercased() == "CQ" {
            // CQ message: "CQ CALL GRID" or "CQ XX CALL GRID"
            if parts.count >= 3, parts[1].count <= 2 || parts[1].allSatisfy({ $0.isNumber }) == false && parts[1].count <= 4 && !looksLikeCallsign(parts[1]) {
                // Directed CQ like "CQ NA K1JT FN20"
                return parts.count >= 3 ? parts[2] : nil
            }
            return parts[1]
        } else if parts.count >= 2 {
            // Standard QSO: "DE_CALL DX_CALL ..."
            return parts[1]
        }
        return nil
    }

    var isCQ: Bool {
        message.uppercased().hasPrefix("CQ ")
    }

    private func looksLikeCallsign(_ s: String) -> Bool {
        // Callsigns have at least one digit and one letter
        s.contains(where: { $0.isNumber }) && s.contains(where: { $0.isLetter }) && s.count >= 3
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: time)
    }
}
