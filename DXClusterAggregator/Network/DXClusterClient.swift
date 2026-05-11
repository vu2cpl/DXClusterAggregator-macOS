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

    // Auto-reconnect with capped exponential backoff.
    // shouldReconnect is true while the caller expects us to stay connected;
    // disconnect() clears it so an intentional stop doesn't retry.
    private var shouldReconnect = false
    private var reconnectAttempt = 0
    private let reconnectSchedule: [TimeInterval] = [10, 30, 60, 120, 300]  // seconds; last value repeats
    private var reconnectWorkItem: DispatchWorkItem?

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
        self.queue = DispatchQueue(label: "com.dxcluster.dxcluster.\(sourceId.uuidString.prefix(8))")
    }

    func connect(address: String, port: UInt16, username: String, password: String) {
        // Intentional reconnect/initial connect: stop any pending retry and
        // cancel the previous NWConnection without clearing shouldReconnect.
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        connection?.cancel()
        connection = nil

        self.address = address
        self.port = port
        self.username = username
        self.password = password
        self.authenticated = false
        self.sentUsername = false
        self.sentPassword = false
        self.buffer = ""
        self.shouldReconnect = true

        let host = NWEndpoint.Host(address)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        connection = NWConnection(host: host, port: nwPort, using: .tcp)

        connection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.isConnected = true
                    self.statusText = "Connected"
                    // Successful connection: reset backoff so future drops
                    // retry quickly before escalating.
                    self.reconnectAttempt = 0
                    print("DX Cluster connected to \(address):\(port)")
                    self.startReceiving()
                case .failed(let error):
                    self.isConnected = false
                    self.statusText = "Failed"
                    print("DX Cluster connection failed: \(error)")
                    self.scheduleReconnectIfNeeded()
                case .cancelled:
                    self.isConnected = false
                    self.statusText = "Disconnected"
                    self.scheduleReconnectIfNeeded()
                case .waiting(let error):
                    self.statusText = "Waiting..."
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
        // Caller is explicitly stopping us: don't try to reconnect.
        shouldReconnect = false
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        reconnectAttempt = 0

        connection?.cancel()
        connection = nil
        DispatchQueue.main.async {
            self.isConnected = false
            self.statusText = "Disconnected"
        }
    }

    /// If we were still supposed to be connected but lost the connection,
    /// schedule a retry using capped exponential backoff:
    /// 10s, 30s, 60s, 120s, 300s, 300s, ...
    private func scheduleReconnectIfNeeded() {
        guard shouldReconnect, reconnectWorkItem == nil else { return }

        let idx = min(reconnectAttempt, reconnectSchedule.count - 1)
        let delay = reconnectSchedule[idx]
        reconnectAttempt += 1

        statusText = "Reconnect in \(Int(delay))s (try \(reconnectAttempt))"

        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            // Re-enter connect with the saved credentials
            guard self.shouldReconnect else { return }
            self.connect(
                address: self.address, port: self.port,
                username: self.username, password: self.password
            )
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
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

        // Detect login/callsign prompt.
        //
        // Two guards to avoid misfiring on welcome-banner lines that happen
        // to mention "login" or "call" (e.g. N2WQ sends "Last login: ... from"
        // after a successful auth — a `contains("login")` match there would
        // either re-send creds, or — on a fresh reconnect where the banner
        // arrives before the real prompt — latch sentUsername=true against
        // the wrong line and skip the actual prompt):
        //   • length < 40 — real prompts are short; banner lines aren't
        //   • hasSuffix(prompt) — confirms the cluster is waiting for input,
        //     not just mentioning the word mid-sentence
        if !sentUsername && lower.count < 40 && (
            lower.hasSuffix("login:") ||
            lower.hasSuffix("please login") ||
            lower.hasSuffix("please login:") ||
            lower.hasSuffix("call:") ||
            lower.hasSuffix("callsign:") ||
            lower.hasSuffix("callsign please:") ||
            lower.hasSuffix("your callsign:") ||
            lower.hasSuffix("enter your callsign:") ||
            lower.hasSuffix("please enter your call:")
        ) {
            sendLine(username)
            sentUsername = true
            return
        }

        // Detect password prompt — same length+endsWith pattern as login.
        if sentUsername && !sentPassword && lower.count < 40 && (
            lower.hasSuffix("password:") ||
            lower.hasSuffix("password please:") ||
            lower.hasSuffix("passwd:") ||
            lower.hasSuffix("enter password:") ||
            lower.hasSuffix("enter your password:")
        ) {
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
