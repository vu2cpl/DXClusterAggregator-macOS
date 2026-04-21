import Foundation

/// Appends spots to "DXC Spots.txt" in the app's Application Support directory.
/// Used before clearing or auto-pruning so no observed spot is lost.
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

    /// Append the given spots to the log file (no-op if list is empty).
    /// Each line is tab-separated:
    ///   ISO_UTC<TAB>SOURCE<TAB>FREQ_KHZ<TAB>BAND<TAB>MODE<TAB>CALL<TAB>DXCC<TAB>SNR<TAB>ALERT<TAB>MESSAGE
    static func append(_ spots: [SpotMessage]) {
        guard !spots.isEmpty else { return }

        let url = logURL
        let fm = FileManager.default
        let isNewFile = !fm.fileExists(atPath: url.path)

        var output = ""
        if isNewFile {
            output += "# DX Cluster Aggregator spot log\n"
            output += "# ISO_TIME\tSOURCE\tFREQ_KHZ\tBAND\tMODE\tCALL\tDXCC\tSNR\tALERT\tMESSAGE\n"
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
    }
}
