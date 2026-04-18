import Foundation

struct DXCCStatus: Codable {
    var bands: Set<String> = []
    var modes: Set<String> = []
    var slots: Set<String> = []  // format: "20M-FT8"
}

struct LogMatrix: Codable {
    // DXCC entity ID -> status
    var byDXCC: [Int: DXCCStatus] = [:]

    // Callsigns already worked (lowercase) - used as a fast-path check
    // for exact-call "new" detection
    var workedCalls: Set<String> = []

    mutating func record(dxcc: Int, band: String, mode: String, call: String) {
        var s = byDXCC[dxcc] ?? DXCCStatus()
        s.bands.insert(band)
        s.modes.insert(mode)
        s.slots.insert("\(band)-\(mode)")
        byDXCC[dxcc] = s
        workedCalls.insert(call.lowercased())
    }

    func status(for dxcc: Int) -> DXCCStatus? {
        byDXCC[dxcc]
    }

    var totalDXCCCount: Int { byDXCC.count }
}
