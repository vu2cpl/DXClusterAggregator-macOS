import Foundation
import Compression

/// Handles downloading the user's ADIF log and the ClubLog cty.xml country file,
/// parsing them, and persisting the resulting LogMatrix and DXCC data locally.
@MainActor
class ClubLogClient: ObservableObject {
    @Published var isRefreshing = false
    @Published var statusMessage = "Not loaded"
    @Published var lastRefresh: Date? = nil
    @Published var qsoCount: Int = 0
    @Published var dxccCount: Int = 0

    private(set) var matrix = LogMatrix()
    private(set) var resolver = DXCCResolver()

    // MARK: - Paths

    private var appSupportDir: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("FT8ClusterAggregator", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var adifPath: URL { appSupportDir.appendingPathComponent("log.adi") }
    private var ctyPath: URL { appSupportDir.appendingPathComponent("cty.xml") }
    private var matrixPath: URL { appSupportDir.appendingPathComponent("matrix.json") }
    private var metaPath: URL { appSupportDir.appendingPathComponent("clublog_meta.json") }

    struct Meta: Codable {
        let lastRefresh: Date
        let qsoCount: Int
        let dxccCount: Int
    }

    // MARK: - Load cached data on startup

    func loadCachedData() {
        // Load cty.xml if present
        if FileManager.default.fileExists(atPath: ctyPath.path) {
            if let data = try? Data(contentsOf: ctyPath) {
                let parser = CTYParser()
                if parser.parse(data: data) {
                    resolver.load(entities: parser.entities, rules: parser.prefixRules)
                }
            }
        }

        // Load cached matrix
        if let data = try? Data(contentsOf: matrixPath),
           let cached = try? JSONDecoder().decode(LogMatrix.self, from: data) {
            matrix = cached
        }

        // Load metadata
        if let data = try? Data(contentsOf: metaPath),
           let meta = try? JSONDecoder().decode(Meta.self, from: data) {
            lastRefresh = meta.lastRefresh
            qsoCount = meta.qsoCount
            dxccCount = meta.dxccCount
        }

        updateStatusText()
    }

    // MARK: - Refresh

    /// Download cty.xml and ADIF log, parse, and save.
    func refresh(config: ClubLogConfig) async {
        isRefreshing = true
        defer { isRefreshing = false }

        statusMessage = "Refreshing..."

        // 1. Download cty.xml (requires API key)
        if !config.apiKey.isEmpty {
            statusMessage = "Downloading country file..."
            do {
                let ctyData = try await downloadCTY(apiKey: config.apiKey)
                try ctyData.write(to: ctyPath)

                let parser = CTYParser()
                if parser.parse(data: ctyData) {
                    resolver.load(entities: parser.entities, rules: parser.prefixRules)
                } else {
                    statusMessage = "CTY parse failed"
                }
            } catch {
                statusMessage = "CTY download failed: \(error.localizedDescription)"
                return
            }
        } else {
            statusMessage = "Note: API key not set - skipping country file"
        }

        // 2. Download ADIF log (requires callsign + email + app password)
        guard !config.callsign.isEmpty, !config.email.isEmpty, !config.appPassword.isEmpty else {
            statusMessage = "Need callsign, email and app password"
            return
        }

        statusMessage = "Downloading log..."
        do {
            let adifData = try await downloadADIF(
                callsign: config.callsign,
                email: config.email,
                password: config.appPassword
            )
            try adifData.write(to: adifPath)

            statusMessage = "Parsing log..."
            let content = String(data: adifData, encoding: .utf8)
                ?? String(data: adifData, encoding: .isoLatin1)
                ?? ""
            let records = ADIFParser.parse(content)

            // Build matrix
            var newMatrix = LogMatrix()
            let bandFilter = config.importBands  // empty = include all
            for record in records {
                guard let call = record.call,
                      let band = record.band,
                      let mode = record.mode else { continue }

                // Apply band filter (empty = all; sentinel "__NONE__" = filter everything out)
                if bandFilter == ["__NONE__"] { continue }
                if !bandFilter.isEmpty && !bandFilter.contains(band) { continue }

                // Prefer explicit DXCC in ADIF, else resolve from callsign
                let dxcc: Int?
                if let d = record.dxcc {
                    dxcc = d
                } else {
                    dxcc = resolver.resolve(call)
                }

                if let d = dxcc {
                    newMatrix.record(
                        dxcc: d, band: band, mode: mode,
                        call: call, confirmed: record.isConfirmed
                    )
                }
            }

            matrix = newMatrix
            qsoCount = records.count
            dxccCount = matrix.totalDXCCCount
            lastRefresh = Date()

            // Save matrix + metadata
            if let data = try? JSONEncoder().encode(matrix) {
                try? data.write(to: matrixPath)
            }

            let meta = Meta(lastRefresh: lastRefresh!, qsoCount: qsoCount, dxccCount: dxccCount)
            if let data = try? JSONEncoder().encode(meta) {
                try? data.write(to: metaPath)
            }

            statusMessage = "Loaded \(qsoCount) QSOs, \(dxccCount) DXCCs"
        } catch {
            statusMessage = "Log download failed: \(error.localizedDescription)"
        }
    }

    // MARK: - HTTP downloads

    private func downloadCTY(apiKey: String) async throws -> Data {
        let urlString = "https://cdn.clublog.org/cty.php?api=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ClubLog", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad CTY URL"])
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "ClubLog", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "CTY HTTP error"])
        }

        // Response is gzipped XML. Decompress if needed.
        if data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b {
            return try gunzip(data)
        }
        return data
    }

    private func downloadADIF(callsign: String, email: String, password: String) async throws -> Data {
        let urlString = "https://clublog.org/getadif.php"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "ClubLog", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bad ADIF URL"])
        }

        let params = [
            "email": email,
            "password": password,
            "call": callsign
        ]
        let body = params.map { key, value in
            let encKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encVal = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encKey)=\(encVal)"
        }.joined(separator: "&")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = body.data(using: .utf8)
        req.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "ClubLog", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "No HTTP response"])
        }
        guard http.statusCode == 200 else {
            throw NSError(domain: "ClubLog", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
        return data
    }

    // MARK: - gzip decompression using Apple Compression framework

    private func gunzip(_ data: Data) throws -> Data {
        // Skip gzip header to get raw deflate stream
        guard data.count > 10 else {
            throw NSError(domain: "gunzip", code: -1, userInfo: [NSLocalizedDescriptionKey: "Data too short"])
        }

        // gzip header: 10 bytes; may include FNAME etc. based on flags byte[3]
        var offset = 10
        let flags = data[3]
        if (flags & 0x08) != 0 {  // FNAME
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if (flags & 0x10) != 0 {  // FCOMMENT
            while offset < data.count && data[offset] != 0 { offset += 1 }
            offset += 1
        }
        if (flags & 0x02) != 0 { offset += 2 } // FHCRC

        // Trim trailing 8 bytes (CRC32 + ISIZE)
        guard data.count > offset + 8 else {
            throw NSError(domain: "gunzip", code: -2, userInfo: [NSLocalizedDescriptionKey: "Malformed gzip"])
        }
        let deflateData = data.subdata(in: offset..<(data.count - 8))

        let bufferSize = max(deflateData.count * 6, 1_000_000)
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { destination.deallocate() }

        let decompressedSize = deflateData.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Int in
            let bound = rawBuffer.bindMemory(to: UInt8.self)
            return compression_decode_buffer(
                destination, bufferSize,
                bound.baseAddress!, deflateData.count,
                nil, COMPRESSION_ZLIB
            )
        }

        guard decompressedSize > 0 else {
            throw NSError(domain: "gunzip", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Decompression failed"])
        }

        return Data(bytes: destination, count: decompressedSize)
    }

    // MARK: - Helpers

    private func updateStatusText() {
        if let date = lastRefresh {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            statusMessage = "Last: \(formatter.string(from: date))  |  \(qsoCount) QSOs, \(dxccCount) DXCCs"
        } else {
            statusMessage = "Not loaded"
        }
    }
}
