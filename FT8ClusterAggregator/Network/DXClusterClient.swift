import Foundation
import Network

/// Connects to a DX Cluster telnet node, authenticates, and parses incoming spot lines.
/// Spot format: "DX de SPOTTER:    FREQ  DX_CALL  comment  TIME"
class DXClusterClient: ObservableObject {
    private var connection: NWConnection?
    private let queue: DispatchQueue

    let name: String
    let sourceId: UUID

    @Published var isConnected = false
    @Published var statusText = "Disconnected"

    var onSpot: ((ClusterSpot) -> Void)?

    private var address: String = ""
    private var port: UInt16 = 7300
    private var username: String = ""
    private var password: String = ""
    private var buffer = ""
    private var authenticated = false
    private var sentUsername = false
    private var sentPassword = false

    struct ClusterSpot {
        let spotter: String
        let dxCall: String
        let frequencyKHz: Double
        let comment: String
        let time: String
        let sourceName: String
    }

    init(name: String, sourceId: UUID) {
        self.name = name
        self.sourceId = sourceId
        self.queue = DispatchQueue(label: "com.ft8cluster.dxcluster.\(sourceId.uuidString.prefix(8))")
    }

    func connect(address: String, port: UInt16, username: String, password: String) {
        disconnect()

        self.address = address
        self.port = port
        self.username = username
        self.password = password
        self.authenticated = false
        self.sentUsername = false
        self.sentPassword = false
        self.buffer = ""

        let host = NWEndpoint.Host(address)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        connection = NWConnection(host: host, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.statusText = "Connected"
                    print("DX Cluster connected to \(address):\(port)")
                    self?.startReceiving()
                case .failed(let error):
                    self?.isConnected = false
                    self?.statusText = "Failed"
                    print("DX Cluster connection failed: \(error)")
                case .cancelled:
                    self?.isConnected = false
                    self?.statusText = "Disconnected"
                case .waiting(let error):
                    self?.statusText = "Waiting..."
                    print("DX Cluster waiting: \(error)")
                default:
                    break
                }
            }
        }

        connection?.start(queue: queue)
        DispatchQueue.main.async {
            self.statusText = "Connecting..."
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.statusText = "Disconnected"
        }
    }

    private func startReceiving() {
        receiveData()
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                if let text = String(data: data, encoding: .utf8) {
                    self?.processIncoming(text)
                } else if let text = String(data: data, encoding: .ascii) {
                    self?.processIncoming(text)
                }
            }

            if isComplete || error != nil {
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.statusText = error != nil ? "Error" : "Disconnected"
                }
                return
            }

            self?.receiveData()
        }
    }

    private func processIncoming(_ text: String) {
        buffer += text

        // Process complete lines
        while let newlineRange = buffer.rangeOfCharacter(from: .newlines) {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Handle authentication prompts
            if !authenticated {
                handleAuth(trimmed)
            }

            // Parse spot lines regardless of auth state (some clusters send spots immediately)
            if let spot = parseSpotLine(trimmed) {
                onSpot?(spot)
            }
        }
    }

    private func handleAuth(_ line: String) {
        let lower = line.lowercased()

        // Detect login/callsign prompt
        if !sentUsername && (lower.contains("login") || lower.contains("call") ||
            lower.contains("please enter your call") || lower.contains("your callsign") ||
            lower.contains("enter your callsign") || lower.hasSuffix(":") || lower.hasSuffix(">")) {
            sendLine(username)
            sentUsername = true
            return
        }

        // Detect password prompt
        if sentUsername && !sentPassword && (lower.contains("password") || lower.contains("passwd")) {
            if !password.isEmpty {
                sendLine(password)
            }
            sentPassword = true
            return
        }

        // Detect successful login
        if sentUsername && (lower.contains("hello") || lower.contains("welcome") ||
            lower.contains("connected") || lower.contains("cluster")) {
            authenticated = true
            DispatchQueue.main.async {
                self.statusText = "Authenticated"
            }
        }
    }

    private func sendLine(_ text: String) {
        guard let data = (text + "\r\n").data(using: .utf8) else { return }
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("DX Cluster send error: \(error)")
            }
        })
    }

    /// Parse a DX cluster spot line.
    /// Format: "DX de VU2ABC:     14074.0  K1JT         FT8 -15 dB                1423Z"
    /// or:     "DX de VU2ABC:  14074.0  K1JT  FT8 -15 dB  1423Z"
    func parseSpotLine(_ line: String) -> ClusterSpot? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Must start with "DX de " (case insensitive)
        guard trimmed.uppercased().hasPrefix("DX DE ") else { return nil }

        let content = String(trimmed.dropFirst(6)) // Remove "DX de "

        // Extract spotter (ends with ":")
        guard let colonIndex = content.firstIndex(of: ":") else { return nil }
        let spotter = String(content[content.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)

        let afterColon = String(content[content.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

        // Split remaining by whitespace
        let parts = afterColon.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count >= 2 else { return nil }

        // First part: frequency in kHz
        guard let freqKHz = Double(parts[0]) else { return nil }

        // Second part: DX callsign
        let dxCall = parts[1]

        // Rest is comment + time
        var comment = ""
        var time = ""

        if parts.count > 2 {
            // Last element ending with Z is the time
            let lastPart = parts[parts.count - 1]
            if lastPart.hasSuffix("Z") || lastPart.hasSuffix("z") {
                time = lastPart
                comment = parts[2..<(parts.count - 1)].joined(separator: " ")
            } else {
                comment = parts[2...].joined(separator: " ")
            }
        }

        return ClusterSpot(
            spotter: spotter,
            dxCall: dxCall,
            frequencyKHz: freqKHz,
            comment: comment,
            time: time,
            sourceName: name
        )
    }
}
