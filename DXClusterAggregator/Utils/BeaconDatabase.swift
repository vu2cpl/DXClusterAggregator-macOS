import Foundation

/// Lookup table for known beacon callsigns. Used to label beacon spots
/// clearly so they don't masquerade as DX opportunities.
struct BeaconDatabase {

    struct BeaconInfo {
        let call: String
        let location: String   // e.g. "Tel Aviv, Israel"
        let network: String?   // "NCDXF" if part of the IBP network, else nil
    }

    /// Look up a callsign. Returns nil if not a known beacon.
    /// Match is on the bare callsign with any /portable suffix removed.
    static func lookup(_ call: String) -> BeaconInfo? {
        let upper = call.uppercased()
        // Strip /P, /M, /MM, etc.
        let bare: String
        if let slash = upper.firstIndex(of: "/") {
            bare = String(upper[..<slash])
        } else {
            bare = upper
        }
        return beacons[bare]
    }

    static func displayName(for call: String) -> String? {
        guard let info = lookup(call) else { return nil }
        if let net = info.network {
            return "\(net) Beacon — \(info.location)"
        }
        return "Beacon — \(info.location)"
    }

    /// The 18 NCDXF / IBP beacons + a few other commonly-spotted beacons.
    /// Beacons rotate on 14.100, 18.110, 21.150, 24.930, 28.200 MHz.
    private static let beacons: [String: BeaconInfo] = [
        // --- NCDXF / IBP rotating beacons (18) ---
        "4U1UN":  BeaconInfo(call: "4U1UN",  location: "United Nations, New York", network: "NCDXF"),
        "VE8AT":  BeaconInfo(call: "VE8AT",  location: "Eureka, Canada",            network: "NCDXF"),
        "W6WX":   BeaconInfo(call: "W6WX",   location: "Mt Umunhum, California",    network: "NCDXF"),
        "KH6RS":  BeaconInfo(call: "KH6RS",  location: "Maui, Hawaii",              network: "NCDXF"),
        "KH6WO":  BeaconInfo(call: "KH6WO",  location: "Maui, Hawaii",              network: "NCDXF"),
        "ZL6B":   BeaconInfo(call: "ZL6B",   location: "Masterton, New Zealand",    network: "NCDXF"),
        "VK6RBP": BeaconInfo(call: "VK6RBP", location: "Rolystone, Australia",      network: "NCDXF"),
        "JA2IGY": BeaconInfo(call: "JA2IGY", location: "Mt Asama, Japan",           network: "NCDXF"),
        "RR9O":   BeaconInfo(call: "RR9O",   location: "Novosibirsk, Russia",       network: "NCDXF"),
        "VR2B":   BeaconInfo(call: "VR2B",   location: "Hong Kong",                 network: "NCDXF"),
        "4S7B":   BeaconInfo(call: "4S7B",   location: "Colombo, Sri Lanka",        network: "NCDXF"),
        "ZS6DN":  BeaconInfo(call: "ZS6DN",  location: "Pretoria, South Africa",    network: "NCDXF"),
        "5Z4B":   BeaconInfo(call: "5Z4B",   location: "Nairobi, Kenya",            network: "NCDXF"),
        "4X6TU":  BeaconInfo(call: "4X6TU",  location: "Tel Aviv, Israel",          network: "NCDXF"),
        "OH2B":   BeaconInfo(call: "OH2B",   location: "Espoo, Finland",            network: "NCDXF"),
        "CS3B":   BeaconInfo(call: "CS3B",   location: "Madeira, Portugal",         network: "NCDXF"),
        "LU4AA":  BeaconInfo(call: "LU4AA",  location: "Buenos Aires, Argentina",   network: "NCDXF"),
        "OA4B":   BeaconInfo(call: "OA4B",   location: "Lima, Peru",                network: "NCDXF"),
        "YV5B":   BeaconInfo(call: "YV5B",   location: "Caracas, Venezuela",        network: "NCDXF"),

        // --- Other commonly spotted beacons ---
        "DK0WCY":   BeaconInfo(call: "DK0WCY",   location: "Scheggerott, Germany (HF/aurora)",    network: nil),
        "ZL2VHM":   BeaconInfo(call: "ZL2VHM",   location: "Mt Climie, New Zealand (50/144MHz)",  network: nil),
        "LX0HF":    BeaconInfo(call: "LX0HF",    location: "Luxembourg HF beacon",                network: nil),
        "LX0FOUR":  BeaconInfo(call: "LX0FOUR",  location: "Luxembourg 4M beacon",                network: nil),
        "GB3RAL":   BeaconInfo(call: "GB3RAL",   location: "Didcot, England (LF beacon)",         network: nil),
        "GB3VHF":   BeaconInfo(call: "GB3VHF",   location: "Wrotham, England (144 MHz)",          network: nil),
        "GB3MCB":   BeaconInfo(call: "GB3MCB",   location: "St Austell, England (50/70MHz)",      network: nil),
        "GB3SCS":   BeaconInfo(call: "GB3SCS",   location: "Sandwich, England (28MHz)",           network: nil),
        "OZ7IGY":   BeaconInfo(call: "OZ7IGY",   location: "Tolløse, Denmark (multi-band)",       network: nil),
        "OK0EG":    BeaconInfo(call: "OK0EG",    location: "Praděd, Czech Republic (50MHz)",      network: nil),
        "F5ZCB":    BeaconInfo(call: "F5ZCB",    location: "Saint-Loubès, France (50MHz)",        network: nil),
        "DB0ANN":   BeaconInfo(call: "DB0ANN",   location: "Nuremberg, Germany (HF beacon)",      network: nil),
    ]
}
