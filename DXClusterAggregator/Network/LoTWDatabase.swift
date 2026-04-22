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

    /// Download the LoTW users list from the given URL.
    /// Default is the widely-used HB9BZA list.
    func refresh(url urlString: String) async {
        guard let url = URL(string: urlString) else {
            statusMessage = "Invalid LoTW URL"
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        statusMessage = "Downloading LoTW users..."

        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 120
            req.setValue("DXClusterAggregator/1.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                statusMessage = "LoTW download HTTP \(code)"
                return
            }

            try data.write(to: rawPath)

            guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                statusMessage = "LoTW file not text"
                return
            }

            users = Self.parseUsers(text)
            userCount = users.count
            lastRefresh = Date()

            let meta = Meta(lastRefresh: Date(), userCount: userCount)
            if let data = try? JSONEncoder().encode(meta) {
                try? data.write(to: metaPath)
            }

            updateStatusText()
        } catch {
            statusMessage = "LoTW download failed: \(error.localizedDescription)"
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
