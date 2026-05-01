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
        let raw = (spotter.isEmpty ? "NOCALL" : spotter).uppercased()
        // Trim spotter to 8 chars max (some clients refuse longer labels)
        let spotterTrim = String(raw.prefix(8))

        // Field-by-field with double-space separators. This matches what
        // the user sees from W3LPL / VE7CC / GB7DXC etc. on real clusters.
        let freqStr  = String(format: "%.1f", freqKHz)
        let comment  = "\(spot.mode) \(spot.snr) dB"
        let timeStr  = spot.timeString    // HHmm

        // Pad fields to widths a typical Spider cluster uses, so columnar
        // parsers also work — but rely on whitespace runs for tokenisers.
        let spotterCell = (spotterTrim + ":").padding(toLength: 9,  withPad: " ", startingAt: 0)
        let freqCell    = freqStr.padding(toLength: 9,  withPad: " ", startingAt: 0)
        let callCell    = dxCall.padding(toLength: 14, withPad: " ", startingAt: 0)
        let commentCell = String(comment.prefix(28))
            .padding(toLength: 28, withPad: " ", startingAt: 0)

        return "DX de \(spotterCell) \(freqCell) \(callCell)\(commentCell) \(timeStr)Z"
    }
}
