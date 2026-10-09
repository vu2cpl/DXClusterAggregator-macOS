import Foundation

/// Formats a SpotMessage as a DX cluster announcement line, mirroring the
/// de-facto DX-Spider layout that virtually every cluster client (RUMlog,
/// Logger32, N1MM+, Log4OM, ...) tokenises:
///
///     DX de MSHV:      14074.0  K1JT           -7 dB   6 FT8  CQ FN20 1758 1428Z
///
/// We don't lean on strict column positions — modern parsers tokenise by
/// whitespace runs. We DO use uppercase 'Z' and unpadded freq because some
/// clients regex match `\d{4}Z$` for the time and `\d+\.\d` early in the
/// line for freq; leading freq padding (`%9.1f`) made our freq column drift
/// and caused RUMlog to mis-parse our output (freq landed in the call slot).
struct ClusterFormatter {
    static func format(spot: SpotMessage, spotter: String) -> String {
        let dxCall = (spot.dxCallsign ?? "UNKNOWN").uppercased()
        // The frequency cell is the dial the spot was heard on. For a spot
        // relayed from a cluster node that is its spotted frequency (the
        // ingest builds it with deltaFrequency 0). A decoder's spot used to
        // go out at dial + offset (14075.8 for 14074 + 1758 Hz); in the
        // Aggregator shape below the offset rides in the comment, relative
        // to the dial, so the cell is the dial — the frequency to put the
        // rig on. Both in one line would be counted twice by a logger that
        // reads the comment.
        let freqKHz = Double(spot.dialFrequency) / 1_000.0
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
        let comment  = commentFor(spot)
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

    /// The comment cell.
    ///
    /// A spot relayed from a cluster node keeps its comment exactly as it
    /// came in, even when that is nothing. That text is what the loggers
    /// were written to read — a skimmer's, RBN's, a human's `FT8 1500Hz
    /// BL11` with its grid — and the 1.x rewrite to `FT8 -15 dB` threw the
    /// offset away, while a labelled `DF 1032 Hz` (tried and dropped the
    /// same evening) was a form of this program's invention. Manoj,
    /// 2026-10-09: "keep the original comment and no need for any DF or Hz
    /// in comments. the logging softwares are made to take it that way."
    ///
    /// A decoder's spot has no comment, so one is made in the shape RBN
    /// Aggregator gives an FT8 skimmer spot — VU2OY's node
    /// (`vu2oy.ddns.net:7550`, "de SKIMMER via Aggregator") is one, and that
    /// shape is what the loggers around here read (Manoj: "sequence it
    /// exactly like vu2oy format"):
    ///
    ///     DX de VU2OY-#:   14074.0  YC2VTS         -7 dB   6 FT8          1758  0607Z
    ///     DX de VU2OY-#:   28074.0  UN7LZ          -6 dB   6 FT8  CQ MO13 2332  0607Z
    ///     DX de VU2OY-#:   18100.0  UW5KW         -19 dB   6 FT8  CQ      1364  0607Z
    ///
    /// SNR right-aligned in 3 and ` dB`; the symbol rate in baud
    /// right-aligned in 4, in the column where a CW spot carries its WPM
    /// (FT8 is 6.25 baud, hence the `6`); the mode; two spaces; `CQ` and
    /// the grid the CQ carried, left-aligned in 8, blank for anything but
    /// a CQ; the DX's audio offset in Hz right-aligned in 4. That is 28
    /// columns for a three-letter mode, the cell exactly. Modes Aggregator
    /// never spots get no rate token, which keeps the width within the cell
    /// for every WSJT-X mode name (`MSK144`, the longest, comes to 27).
    /// deltaFrequency 0 means no decoder reported an offset, and the offset
    /// column is then simply absent — never a `0`. Same code, same words,
    /// in dxca's `dxca-core/src/format.rs`.
    static func commentFor(_ spot: SpotMessage) -> String {
        if let original = spot.comment {
            return original.trimmingCharacters(in: .whitespaces)
        }
        var out = rightAligned(String(spot.snr), 3) + " dB"
        if let baud = symbolRateBaud(spot.mode) {
            out += rightAligned(String(baud), 4) + " " + spot.mode
        } else {
            out += " " + spot.mode
        }
        let cq: String
        if spot.isCQ {
            cq = spot.cqGrid.map { "CQ \($0)" } ?? "CQ"
        } else {
            cq = ""
        }
        out += "  " + cq.padding(toLength: 8, withPad: " ", startingAt: 0)
        if spot.deltaFrequency > 0 {
            out += rightAligned(String(spot.deltaFrequency), 4)
        }
        while out.hasSuffix(" ") { out.removeLast() }
        return out
    }

    /// The modulation rate Aggregator prints in its speed column, whole
    /// baud. FT4 is 20.833 baud; `21` is the rounded figure and has not
    /// been read off a live Aggregator line (VU2OY's node spotted no FT4 in
    /// 2,000 spots) — check it against one when an FT4 spot comes through.
    static func symbolRateBaud(_ mode: String) -> Int? {
        switch mode.uppercased() {
        case "FT8": return 6
        case "FT4": return 21
        default: return nil
        }
    }

    /// `%3d`-style: leading spaces up to `width`, never truncated.
    private static func rightAligned(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : String(repeating: " ", count: width - s.count) + s
    }
}
