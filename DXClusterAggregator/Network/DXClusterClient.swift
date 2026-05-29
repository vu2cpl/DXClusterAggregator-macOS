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
                // Telnet-style clusters (e.g. N2WQ) prefix their banner with
                // IAC option-negotiation bytes (0xFF ...). Strip them at the
                // byte level so the resulting String isn't garbage and our
                // prompt suffix-match isn't fighting binary noise.
                let cleaned = Self.stripTelnetIAC(data)
                if cleaned.isEmpty {
                    // All bytes were IAC negotiation — nothing to process.
                } else if let text = String(data: cleaned, encoding: .utf8) {
                    self?.processIncoming(text)
                } else if let text = String(data: cleaned, encoding: .ascii) {
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

    /// Strip Telnet IAC option-negotiation sequences from a byte stream.
    ///
    /// Telnet (RFC 854) signals option negotiation with 0xFF (IAC) followed by
    /// a command byte and, for WILL/WONT/DO/DONT, an option byte. Some DX
    /// cluster front-ends (notably AR-Cluster forks like N2WQ-2) send an IAC
    /// preamble such as `IAC WILL SUPPRESS-GA` + `IAC WILL ECHO` ahead of
    /// their first banner/prompt. Those bytes are not valid UTF-8 and corrupt
    /// the decoded string — and worse, if the prompt itself doesn't end with
    /// a newline (it often doesn't — Telnet prompts hang), the IAC noise can
    /// prevent any meaningful suffix match.
    ///
    /// We don't *respond* to the negotiation (clusters accept silent partners
    /// fine). We just drop the bytes.
    ///
    /// Caveat: if a TCP segment ends mid-IAC-sequence, the trailing bytes are
    /// dropped. In practice clusters emit the entire IAC preamble in one
    /// initial segment, so this hasn't bitten us; revisit if a cluster
    /// interleaves IAC commands later in the session.
    static func stripTelnetIAC(_ data: Data) -> Data {
        var out = Data()
        var i = 0
        while i < data.count {
            let b = data[i]
            if b == 0xFF {
                guard i + 1 < data.count else { break } // incomplete trailing IAC
                let next = data[i + 1]
                switch next {
                case 0xFF:             // IAC IAC → literal 0xFF
                    out.append(0xFF); i += 2
                case 0xFB...0xFE:      // WILL/WONT/DO/DONT + 1 option byte
                    i += 3
                case 0xFA:             // SB ... IAC SE (variable subnegotiation)
                    var j = i + 2
                    while j + 1 < data.count {
                        if data[j] == 0xFF && data[j + 1] == 0xF0 { j += 2; break }
                        j += 1
                    }
                    i = j
                default:               // other 2-byte IAC commands (NOP, GA, etc.)
                    i += 2
                }
            } else {
                out.append(b); i += 1
            }
        }
        return out
    }

    /// Suffix allowlist for prompts that may arrive without a trailing newline.
    /// Used by both the line-based path (after newline trim) and the hanging-
    /// prompt path (residual buffer at end of `processIncoming`).
    private static let promptSuffixes: [String] = [
        "login:", "please login", "please login:",
        "call:", "callsign:", "callsign please:", "your callsign:",
        "enter your callsign:", "please enter your call:"
    ]

    private static let passwordSuffixes: [String] = [
        "password:", "password please:", "passwd:",
        "enter password:", "enter your password:"
    ]

    private func processIncoming(_ text: String) {
        buffer += text

        // Safety cap: the line loop below only drains on a newline, and the
        // hanging-prompt cleanup at the end is gated behind !authenticated. A
        // peer that streams bytes without ever sending an LF would otherwise
        // grow `buffer` without bound for the life of the session. Real cluster
        // lines and prompts are short, so if we've accumulated this much with
        // no newline it's junk — drop all but the tail (long enough to still
        // catch any prompt suffix we match on).
        let maxBufferBytes = 64 * 1024
        if buffer.utf8.count > maxBufferBytes,
           buffer.rangeOfCharacter(from: .newlines) == nil {
            buffer = String(buffer.suffix(256))
        }

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

        // Hanging-prompt path: Telnet-style prompts (e.g. N2WQ's `login: `)
        // arrive without any newline terminator — the cluster expects us to
        // type at a live prompt. The line-based loop above will sit on these
        // forever waiting for an LF that never comes. If the residual buffer
        // is short and ends with a recognized prompt, hand it off and consume.
        if !authenticated && !buffer.isEmpty {
            let pending = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = pending.lowercased()
            if pending.count < 40 && (
                Self.promptSuffixes.contains(where: { lower.hasSuffix($0) }) ||
                Self.passwordSuffixes.contains(where: { lower.hasSuffix($0) })
            ) {
                handleAuth(pending)
                buffer = ""
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
        if !sentUsername && lower.count < 40 &&
            Self.promptSuffixes.contains(where: { lower.hasSuffix($0) }) {
            sendLine(username)
            sentUsername = true
            return
        }

        // Detect password prompt — same length+endsWith pattern as login.
        if sentUsername && !sentPassword && lower.count < 40 &&
            Self.passwordSuffixes.contains(where: { lower.hasSuffix($0) }) {
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
