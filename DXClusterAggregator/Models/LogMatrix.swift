import Foundation

struct DXCCStatus: Codable {
    // All worked (regardless of confirmation status)
    var bands: Set<String> = []
    var modes: Set<String> = []
    var slots: Set<String> = []  // format: "20M-FT8"

    // Confirmed only (LOTW / QSL / eQSL received)
    var confirmedBands: Set<String> = []
    var confirmedModes: Set<String> = []
    var confirmedSlots: Set<String> = []
}

struct LogMatrix: Codable {
    // DXCC entity ID -> status
    var byDXCC: [Int: DXCCStatus] = [:]

    // Callsigns already worked (lowercase) - used as a fast-path check
    // for exact-call "new" detection
    var workedCalls: Set<String> = []

    mutating func record(dxcc: Int, band: String, mode: String, call: String, confirmed: Bool) {
        var s = byDXCC[dxcc] ?? DXCCStatus()
        s.bands.insert(band)
        s.modes.insert(mode)
        s.slots.insert("\(band)-\(mode)")
        if confirmed {
            s.confirmedBands.insert(band)
            s.confirmedModes.insert(mode)
            s.confirmedSlots.insert("\(band)-\(mode)")
        }
        byDXCC[dxcc] = s
        workedCalls.insert(call.lowercased())
    }

    func status(for dxcc: Int) -> DXCCStatus? {
        byDXCC[dxcc]
    }

    var totalDXCCCount: Int { byDXCC.count }
}
