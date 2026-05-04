import Foundation

/// Formats a SpotMessage as a DX cluster announcement line, mirroring the
/// de-facto DX-Spider layout that virtually every cluster client (RUMlog,
/// Logger32, N1MM+, Log4OM, ...) tokenises:
///
///     DX de W3LPL:     14074.0  K1JT          FT8 -10 dB             1428Z
///
/// We don't lean on strict column positions — modern parsers tokenise by
/// whitespace runs. We DO use uppercase 'Z' and unpadded freq because some
/// clients regex match `\d{4}Z$` for the time and `\d+\.\d` early in the
/// line for freq; leading freq padding (`%9.1f`) made our freq column drift
/// and caused RUMlog to mis-parse our output (freq landed in the call slot).
struct ClusterFormatter {
    static func format(spot: SpotMessage, spotter: String) -> String {
        let dxCall = (spot.dxCallsign ?? "UNKNOWN").uppercased()
        let freqKHz = spot.frequencyKHz
        // Spotter must be a SINGLE TOKEN. Source names like "MSHV 2237"
        // contain spaces which RUMlog/Logger32/etc. then tokenise as two
        // fields, shoving the freq into the DX call slot. Strip anything
        // that isn't a callsign character so the line parses cleanly.
        let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-")
        let cleaned = spotter.uppercased().filter { allowed.contains($0) }
        let raw = cleaned.isEmpty ? "NOCALL" : cleaned
        // 13 chars is DX-Spider's spotter-call limit; covers W3LPL/4 etc.
        let spotterTrim = String(raw.prefix(13))

        // Field-by-field with double-space separators. This matches what
        // the user sees from W3LPL / VE7CC / GB7DXC etc. on real clusters.
        let freqStr  = String(format: "%.1f", freqKHz)
        let comment  = "\(spot.mode) \(spot.snr) dB"
        let timeStr  = spot.timeString    // HHmm

        // Pad fields to widths a typical Spider cluster uses, so columnar
        // parsers also work — but rely on whitespace runs for tokenisers.
        let spotterCell = (spotterTrim + ":").padding(toLength: 14, withPad: " ", startingAt: 0)
        let freqCell    = freqStr.padding(toLength: 9,  withPad: " ", startingAt: 0)
        let callCell    = dxCall.padding(toLength: 14, withPad: " ", startingAt: 0)
        let commentCell = String(comment.prefix(28))
            .padding(toLength: 28, withPad: " ", startingAt: 0)

        return "DX de \(spotterCell) \(freqCell) \(callCell)\(commentCell) \(timeStr)Z"
    }
}
