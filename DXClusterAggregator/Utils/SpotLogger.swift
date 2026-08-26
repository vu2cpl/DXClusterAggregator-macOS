import Foundation

/// Appends spots to "DXC Spots.txt" in the app's Application Support directory.
/// Used before clearing or auto-pruning so no observed spot is lost.
/// The file is size-capped (spotLogMaxMB setting, default 100 MB, 0 = unlimited):
/// when an append pushes it over the cap, the oldest lines are trimmed away.
enum SpotLogger {

    /// File path: ~/Library/Application Support/DXClusterAggregator/DXC Spots.txt
    static var logURL: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("DXClusterAggregator", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("DXC Spots.txt")
    }

    /// Header written at the top of a fresh log file (and restored after a trim).
    private static let header =
        "# DX Cluster Aggregator spot log\n" +
        "# ISO_TIME\tSOURCE\tFREQ_KHZ\tBAND\tMODE\tCALL\tDXCC\tSNR\tALERT\tMESSAGE\n"

    /// Append the given spots to the log file (no-op if list is empty), then
    /// enforce the size cap. Each line is tab-separated:
    ///   ISO_UTC<TAB>SOURCE<TAB>FREQ_KHZ<TAB>BAND<TAB>MODE<TAB>CALL<TAB>DXCC<TAB>SNR<TAB>ALERT<TAB>MESSAGE
    ///
    /// `maxMB` caps the file size (0 = unlimited). When an append pushes the
    /// file over the cap, the oldest lines are trimmed away in place — see
    /// `trimIfNeeded`.
    static func append(_ spots: [SpotMessage], maxMB: Int) {
        guard !spots.isEmpty else { return }

        let url = logURL
        let fm = FileManager.default
        let isNewFile = !fm.fileExists(atPath: url.path)

        var output = ""
        if isNewFile {
            output += header
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        for spot in spots {
            let fields: [String] = [
                isoFormatter.string(from: spot.time),
                spot.sourceName,
                String(format: "%.1f", spot.frequencyKHz),
                spot.bandName ?? "",
                spot.mode,
                spot.dxCallsign ?? "",
                (spot.dxccName ?? "").replacingOccurrences(of: "\t", with: " "),
                "\(spot.snr)",
                spot.alertLevel.rawValue,
                spot.message.replacingOccurrences(of: "\t", with: " ")
            ]
            output += fields.joined(separator: "\t") + "\n"
        }

        guard let data = output.data(using: .utf8) else { return }

        if isNewFile {
            try? data.write(to: url, options: .atomic)
        } else if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                print("SpotLogger append failed: \(error)")
            }
        }

        trimIfNeeded(maxMB: maxMB)
    }

    /// If the log file has grown past `maxMB`, rewrite it keeping only the
    /// newest ~75% of the cap (whole lines, header restored). Trimming to 75%
    /// rather than exactly the cap gives hysteresis, so the rewrite happens
    /// once every several days of accumulation, not on every append.
    private static func trimIfNeeded(maxMB: Int) {
        guard maxMB > 0 else { return }
        let maxBytes = UInt64(maxMB) * 1_048_576
        let url = logURL

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.uint64Value,
              size > maxBytes else { return }

        let keepBytes = maxBytes * 3 / 4
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: size - keepBytes)
            guard var tail = try handle.readToEnd() else { return }
            // The seek almost certainly landed mid-line — drop the partial line.
            if let nl = tail.firstIndex(of: UInt8(ascii: "\n")) {
                tail = tail.subdata(in: (nl + 1)..<tail.endIndex)
            }
            var trimmed = Data(header.utf8)
            trimmed.append(tail)
            try trimmed.write(to: url, options: .atomic)
        } catch {
            print("SpotLogger trim failed: \(error)")
        }
    }
}
