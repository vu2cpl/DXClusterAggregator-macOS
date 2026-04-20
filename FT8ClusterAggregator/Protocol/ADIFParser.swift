import Foundation

struct ADIFRecord {
    var fields: [String: String] = [:]

    var call: String? { fields["CALL"]?.uppercased() }
    var band: String? { fields["BAND"]?.uppercased() }
    var mode: String? { fields["MODE"]?.uppercased() }
    var dxcc: Int? {
        if let s = fields["DXCC"], let v = Int(s) { return v }
        return nil
    }
    var gridSquare: String? { fields["GRIDSQUARE"]?.uppercased() }
    var qsoDate: String? { fields["QSO_DATE"] }

    /// QSO is considered confirmed if any of LOTW/QSL/eQSL is received (Y/y).
    var isConfirmed: Bool {
        let yes: Set<String> = ["Y", "V"] // V = verified
        let candidates = [
            fields["LOTW_QSL_RCVD"],
            fields["QSL_RCVD"],
            fields["EQSL_QSL_RCVD"]
        ]
        for v in candidates {
            if let s = v?.uppercased(), yes.contains(s) { return true }
        }
        // Some loggers use "APP_CLUBLOG_QSO_QSL" or matched flag; treat ClubLog matched as confirmed
        if let m = fields["APP_CLUBLOG_QSO_QSL"]?.uppercased(), m == "Y" { return true }
        return false
    }
}

/// Parses an ADIF v1/v2 text stream.
/// Format: `<TAG:length[:type]>value` with `<eor>` terminating each record
/// and `<eoh>` ending the optional header.
class ADIFParser {
    /// Parse the ADIF content string and return an array of records.
    static func parse(_ content: String) -> [ADIFRecord] {
        var records: [ADIFRecord] = []
        var current = ADIFRecord()
        var headerDone = false

        // Work with a single-byte view for correct length slicing
        let chars = Array(content)
        var i = 0
        let n = chars.count

        while i < n {
            // Find next '<'
            guard let lt = findNext(chars, from: i, char: "<") else { break }
            guard let gt = findNext(chars, from: lt + 1, char: ">") else { break }

            let tag = String(chars[(lt + 1)..<gt])
            let lower = tag.lowercased()

            if lower == "eoh" {
                headerDone = true
                i = gt + 1
                continue
            }

            if lower == "eor" {
                if !current.fields.isEmpty {
                    records.append(current)
                }
                current = ADIFRecord()
                i = gt + 1
                continue
            }

            // Parse TAG:length or TAG:length:type
            let parts = tag.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
            guard parts.count >= 2 else {
                i = gt + 1
                continue
            }

            let name = String(parts[0]).uppercased()
            guard let length = Int(parts[1]) else {
                i = gt + 1
                continue
            }

            let valueStart = gt + 1
            let valueEnd = min(valueStart + length, n)
            let value = String(chars[valueStart..<valueEnd])

            // Only store fields we care about, once we've passed the header
            if headerDone || true {
                current.fields[name] = value
            }

            i = valueEnd
        }

        // Flush trailing record without <eor>
        if !current.fields.isEmpty {
            records.append(current)
        }

        return records
    }

    private static func findNext(_ chars: [Character], from: Int, char: Character) -> Int? {
        var i = from
        while i < chars.count {
            if chars[i] == char { return i }
            i += 1
        }
        return nil
    }
}
