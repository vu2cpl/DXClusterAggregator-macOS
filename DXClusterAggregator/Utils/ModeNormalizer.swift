import Foundation

/// Groups the many ADIF mode strings into the three award-recognised buckets
/// (CW / PHONE / DATA) so that, e.g., FT8 and FT4 count as the same "mode"
/// when deciding whether a DXCC slot is new.
///
/// This matches the ADIF spec's top-level MODE classification and the rules
/// used by DXCC, LoTW, ClubLog's matrix, etc.
struct ModeNormalizer {
    /// Returns a canonical bucket: "CW", "PHONE", or "DATA" (default).
    static func canonical(_ raw: String) -> String {
        let mode = raw.uppercased().trimmingCharacters(in: .whitespaces)
        if mode.isEmpty { return "DATA" }

        if cwModes.contains(mode) { return "CW" }
        if phoneModes.contains(mode) { return "PHONE" }
        // Everything else is treated as digital/DATA (FT8, FT4, JT*, MSK*,
        // RTTY, PSK*, OLIVIA, MFSK, HELL, WSPR, THROB, DOMINO, etc.)
        return "DATA"
    }

    private static let cwModes: Set<String> = [
        "CW"
    ]

    private static let phoneModes: Set<String> = [
        "SSB", "USB", "LSB", "AM", "FM",
        "PHONE", "VOICE", "DIGITALVOICE",
        "C4FM", "DMR", "DSTAR"
    ]
}
