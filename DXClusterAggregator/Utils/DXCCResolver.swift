import Foundation

/// Maps a callsign to its DXCC entity using data loaded from the ClubLog cty.xml file.
/// Uses longest-prefix matching; exact-call exceptions take priority.
class DXCCResolver {
    private var entities: [Int: DXCCEntity] = [:]
    private var exactMap: [String: Int] = [:]     // full call -> DXCC
    private var prefixMap: [String: Int] = [:]    // prefix -> DXCC

    // Pre-sorted prefix list (longest first) for fast longest-match
    private var sortedPrefixes: [String] = []

    var isLoaded: Bool { !entities.isEmpty }
    var entityCount: Int { entities.count }

    func load(entities: [Int: DXCCEntity], rules: [CTYPrefixRule]) {
        self.entities = entities

        exactMap.removeAll()
        prefixMap.removeAll()

        // Only load rules currently active "now". Historical / deleted entity
        // rules (e.g. KARELO-FINN REP ended 1960) must not contaminate today's
        // lookups.
        let now = Date()
        for rule in rules where rule.isActive(at: now) {
            if rule.isExact {
                exactMap[rule.call] = rule.adif
            } else {
                // Only keep the first seen if duplicates (prefixes are usually unique)
                if prefixMap[rule.call] == nil {
                    prefixMap[rule.call] = rule.adif
                }
            }
        }

        sortedPrefixes = prefixMap.keys.sorted { $0.count > $1.count }
    }

    /// Resolve a callsign to a DXCC entity ID.
    /// Returns nil if no data is loaded, there is no match, or the call is
    /// flagged by ClubLog as a non-DX operation (beacons, satellites, Internet
    /// repeaters — those records have adif=0).
    func resolve(_ callsign: String) -> Int? {
        let call = callsign.uppercased()
        let cleanCall = normalizeCall(call)

        // 1) exact match wins (includes ClubLog exception overrides)
        if let adif = exactMap[cleanCall] {
            return adif > 0 ? adif : nil
        }

        // 2) longest prefix match
        for prefix in sortedPrefixes where cleanCall.hasPrefix(prefix) {
            if let adif = prefixMap[prefix] {
                return adif > 0 ? adif : nil
            }
        }

        return nil
    }

    /// True if the callsign is flagged by ClubLog as a non-DX operation
    /// (beacons like OH2B / 4X6TU, ISS / satellites, Internet gateways).
    /// Used to skip alert classification and highlighting for these spots.
    func isNonDXOperation(_ callsign: String) -> Bool {
        let cleanCall = normalizeCall(callsign.uppercased())
        if let adif = exactMap[cleanCall], adif == 0 { return true }
        return false
    }

    /// Look up entity info by ADIF/DXCC id.
    func entity(for adif: Int) -> DXCCEntity? {
        entities[adif]
    }

    /// Return the entity name for a callsign (convenience).
    func entityName(for callsign: String) -> String? {
        guard let adif = resolve(callsign) else { return nil }
        return entities[adif]?.name
    }

    // MARK: - Callsign normalization

    /// Normalize a slash-portable callsign.
    /// - "K1JT/P", "W1AW/4", "N6XX/M" -> drop the suffix
    /// - "VP8/K1JT", "JA1/W1AW" -> use the DX prefix (the shorter side before slash is typically the override)
    private func normalizeCall(_ call: String) -> String {
        guard call.contains("/") else { return call }
        let parts = call.split(separator: "/").map(String.init)
        guard parts.count == 2 else { return parts.first ?? call }

        let a = parts[0]
        let b = parts[1]

        // Simple portable suffixes (including /B = beacon, /LH = lighthouse, etc.)
        let portableSuffixes: Set<String> = [
            "P", "M", "MM", "AM", "QRP", "A", "B", "LH", "BCN"
        ]
        if portableSuffixes.contains(b) { return a }
        if portableSuffixes.contains(a) { return b }

        // Numeric call-area suffix like "W1AW/4"
        if b.count <= 2, b.allSatisfy({ $0.isNumber || $0.isLetter }), b.contains(where: { $0.isNumber }), !b.contains(where: { $0.isLetter && $0.isUppercase == false }) {
            // Numeric or short -> treat as call-area override, keep main call
            return a
        }

        // Prefix override like "VP8/K1JT" -> use VP8 as location
        // Rule: shorter of the two is usually the location prefix
        return a.count <= b.count ? a : b
    }
}
