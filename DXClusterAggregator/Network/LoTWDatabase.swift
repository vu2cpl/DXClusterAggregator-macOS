import Foundation

/// Downloads and caches the community-maintained LoTW user-activity file
/// (a CSV/TSV/text file listing every callsign that has ever uploaded a
/// QSO to ARRL Logbook of The World).
///
/// Used to mark spots where the DX station is known to use LoTW, so the
/// operator can prioritise working them for confirmable DXCC credit.
@MainActor
final class LoTWDatabase: ObservableObject {

    @Published private(set) var userCount: Int = 0
    @Published private(set) var lastRefresh: Date? = nil
    @Published private(set) var isRefreshing = false
    @Published var statusMessage = "Not loaded"

    private var users: Set<String> = []

    // MARK: - Lookup

    /// True if the callsign (or its base callsign after stripping /portable
    /// suffixes) is a known LoTW user.
    func isUser(_ callsign: String) -> Bool {
        guard !users.isEmpty else { return false }
        let upper = callsign.uppercased()
        if users.contains(upper) { return true }

        // Try bare callsign (strip /P, /M, /portable suffixes)
        if let slash = upper.firstIndex(of: "/") {
            let bare = String(upper[..<slash])
            if users.contains(bare) { return true }
            // Also try the other side in case of VP8/K1JT type prefix overrides
            let suffix = String(upper[upper.index(after: slash)...])
            if users.contains(suffix) { return true }
        }
        return false
    }

    var isLoaded: Bool { !users.isEmpty }

    // MARK: - Paths

    private var appSupportDir: URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("DXClusterAggregator", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var rawPath: URL { appSupportDir.appendingPathComponent("lotw-users.txt") }
    private var metaPath: URL { appSupportDir.appendingPathComponent("lotw-meta.json") }

    struct Meta: Codable {
        let lastRefresh: Date
        let userCount: Int
    }

    // MARK: - Cache lifecycle

    func loadCached() {
        if let data = try? Data(contentsOf: rawPath),
           let text = String(data: data, encoding: .utf8) {
            users = Self.parseUsers(text)
            userCount = users.count
        }
        if let data = try? Data(contentsOf: metaPath),
           let meta = try? JSONDecoder().decode(Meta.self, from: data) {
            lastRefresh = meta.lastRefresh
            // trust the parsed count over cached
        }
        updateStatusText()
    }

    // MARK: - Refresh

    /// Load the LoTW users list from the given URL. Supports http://, https://,
    /// and file:// schemes. A plain filesystem path also works (it's treated as
    /// a file:// URL).
    func refresh(url urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            statusMessage = "LoTW URL is empty"
            return
        }

        // Allow the user to paste a local filesystem path directly.
        let resolved: URL? = {
            if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
                let expanded = (trimmed as NSString).expandingTildeInPath
                return URL(fileURLWithPath: expanded)
            }
            return URL(string: trimmed)
        }()
        guard let url = resolved else {
            statusMessage = "Invalid LoTW URL / path"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let data: Data
            if url.isFileURL {
                statusMessage = "Loading LoTW file..."
                data = try Data(contentsOf: url)
            } else {
                statusMessage = "Downloading LoTW users..."
                var req = URLRequest(url: url)
                req.timeoutInterval = 120
                req.setValue("DXClusterAggregator/1.0", forHTTPHeaderField: "User-Agent")

                let (downloaded, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    statusMessage = "LoTW HTTP \(http.statusCode)"
                    return
                }
                data = downloaded
            }

            try data.write(to: rawPath)

            guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                statusMessage = "LoTW file not text-decodable"
                return
            }

            users = Self.parseUsers(text)
            userCount = users.count
            lastRefresh = Date()

            if userCount == 0 {
                statusMessage = "LoTW parse: 0 users - wrong URL/format?"
                return
            }

            let meta = Meta(lastRefresh: Date(), userCount: userCount)
            if let metaData = try? JSONEncoder().encode(meta) {
                try? metaData.write(to: metaPath)
            }

            updateStatusText()
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorServerCertificateUntrusted ||
                ns.code == NSURLErrorSecureConnectionFailed {
                statusMessage = "LoTW TLS failed - try http:// URL or a local file path"
            } else {
                statusMessage = "LoTW failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Parser

    /// Parses a plain-text / CSV file of LoTW users. Each non-empty line is
    /// treated as a callsign (anything after the first comma or whitespace
    /// is ignored — dates, timestamps etc.). Comment lines starting with
    /// '#' are skipped.
    private static func parseUsers(_ text: String) -> Set<String> {
        var set = Set<String>()
        for rawLine in text.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            // Take the first token separated by comma, tab, or space
            let firstToken = line.split(whereSeparator: { $0 == "," || $0 == "\t" || $0 == " " }).first
            guard let token = firstToken else { continue }
            let call = String(token).uppercased()

            // Basic sanity: must contain at least one digit and look like a callsign
            if call.count >= 3,
               call.contains(where: { $0.isNumber }),
               call.contains(where: { $0.isLetter }) {
                set.insert(call)
            }
        }
        return set
    }

    // MARK: - UI helpers

    private func updateStatusText() {
        if let date = lastRefresh {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            statusMessage = "LoTW: \(userCount) users (refreshed \(formatter.string(from: date)))"
        } else if userCount > 0 {
            statusMessage = "LoTW: \(userCount) users"
        } else {
            statusMessage = "LoTW not loaded"
        }
    }
}
