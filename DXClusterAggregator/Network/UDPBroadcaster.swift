import Foundation
import Darwin

/// Wire format for a UDP broadcast destination.
enum UDPBroadcastFormat: String, Equatable {
    /// Plain text DX cluster line: `DX de SPOTTER:  freq  call  comment  time`
    case cluster
    /// WSJT-X binary UDP protocol — Status (type 1) + Decode (type 2) pair
    /// per spot, suitable for tools like RBN Aggregator that listen for
    /// WSJT-X-format packets.
    case wsjtx

    init(rawString: String) {
        self = UDPBroadcastFormat(rawValue: rawString) ?? .cluster
    }
}

/// Sends each spot to N UDP destinations.
///
/// Implemented with POSIX sockets (rather than Apple's Network framework)
/// because:
///   1. NWConnection doesn't expose SO_BROADCAST, so packets sent to
///      LAN-broadcast addresses like 192.168.1.255 are silently dropped.
///   2. NWConnection's per-destination connection model is heavier than a
///      simple sendto() call for fire-and-forget UDP.
///
/// SO_BROADCAST is enabled unconditionally so addresses like 192.168.1.255
/// or 255.255.255.255 work. Unicast and multicast destinations also work
/// because the kernel just ignores the flag for those.
final class UDPBroadcaster: ObservableObject {
    private struct Destination {
        let id: UUID
        let host: String
        let port: UInt16
        let fd: Int32
        var addr: sockaddr_in
        var format: UDPBroadcastFormat
        /// Source-name allowlist. Empty = all sources allowed.
        var allowedSources: Set<String>
        /// If true, this destination ignores the caller's `passesFilters`
        /// flag and accepts every spot (still subject to allowedSources).
        /// Used for raw forwarding to upstream aggregators (e.g. RBN) that
        /// do their own dedupe / pattern-matching / SCP.
        var unfiltered: Bool
    }

    private var destinations: [Destination] = []

    /// Per-destination diagnostic counters keyed by destination UUID.
    @Published var sentCounts: [UUID: Int] = [:]
    @Published var failCounts: [UUID: Int] = [:]

    /// Convenience: total sent across all destinations (for the status bar).
    var totalSent: Int { sentCounts.values.reduce(0, +) }
    var totalFail: Int { failCounts.values.reduce(0, +) }

    /// Configure the live destination list. Pass only enabled destinations.
    func configure(destinations dests: [(id: UUID, ip: String, port: UInt16,
                                         format: UDPBroadcastFormat,
                                         allowedSources: Set<String>,
                                         unfiltered: Bool)]) {
        stop()
        var newDests: [Destination] = []
        for d in dests {
            if let made = Self.makeDestination(id: d.id, host: d.ip, port: d.port,
                                               format: d.format,
                                               allowedSources: d.allowedSources,
                                               unfiltered: d.unfiltered) {
                newDests.append(made)
            }
        }
        destinations = newDests
        DispatchQueue.main.async {
            self.sentCounts = [:]
            self.failCounts = [:]
        }
    }

    /// Per-spot broadcast. Each destination is consulted independently and
    /// applies its own source allowlist + wire format.
    /// - Parameter passesFilters: true if the spot passes all the user's
    ///   live display filters (Bands / Sources / New Only / Hide /N /
    ///   Hide Duplicates). Destinations marked `unfiltered` ignore this
    ///   flag and accept every spot.
    func broadcast(clusterLine: String,
                   sourceName: String,
                   callsign: String?,
                   frequencyHz: UInt64,
                   snr: Int32,
                   mode: String,
                   message: String,
                   passesFilters: Bool) {
        let clusterPayload = (clusterLine + "\r\n").data(using: .utf8) ?? Data()

        var attemptedIds: [UUID] = []
        var resultIds: [UUID: Bool] = [:]

        for dest in destinations {
            let allowed = dest.allowedSources.isEmpty
                || dest.allowedSources.contains(sourceName)
            guard allowed else { continue }
            // Filtered destinations require the spot to pass user filters;
            // unfiltered destinations always accept (as long as the source
            // allowlist passes).
            if !dest.unfiltered && !passesFilters { continue }
            attemptedIds.append(dest.id)

            let ok: Bool
            switch dest.format {
            case .cluster:
                ok = send(clusterPayload, to: dest)
            case .wsjtx:
                if let call = callsign, !call.isEmpty {
                    let pair = WSJTXMessageBuilder.encodeSpot(
                        callsign: call,
                        frequencyHz: frequencyHz,
                        snr: snr,
                        mode: mode,
                        message: message
                    )
                    let s1 = send(pair.status, to: dest)
                    let s2 = send(pair.decode, to: dest)
                    ok = s1 && s2
                } else {
                    ok = false
                }
            }
            resultIds[dest.id] = ok
        }

        DispatchQueue.main.async {
            for id in attemptedIds {
                if resultIds[id] == true {
                    self.sentCounts[id, default: 0] += 1
                } else {
                    self.failCounts[id, default: 0] += 1
                }
            }
        }
    }

    func stop() {
        for d in destinations {
            Darwin.close(d.fd)
        }
        destinations.removeAll()
    }

    /// Fire a single labelled test packet using a freshly-created socket.
    /// Doesn't depend on configure() having run.
    @discardableResult
    func sendTest(host: String, port: UInt16,
                  format: UDPBroadcastFormat = .cluster) -> String? {
        guard let d = Self.makeDestination(id: UUID(), host: host, port: port,
                                           format: format, allowedSources: []) else {
            return "Invalid host/port"
        }
        defer { Darwin.close(d.fd) }

        let now = ISO8601DateFormatter().string(from: Date())
        let payload: Data
        switch format {
        case .cluster:
            let text = "TEST DXClusterAggregator \(now) -> \(host):\(port)\r\n"
            guard let data = text.data(using: .utf8) else { return "encode failed" }
            payload = data
        case .wsjtx:
            let pair = WSJTXMessageBuilder.encodeSpot(
                callsign: "TEST",
                frequencyHz: 14_074_000,
                snr: 0,
                mode: "FT8",
                message: "CQ TEST"
            )
            payload = pair.status + pair.decode
        }

        let fd = d.fd
        var addr = d.addr
        var ok = false
        var errMsg: String? = nil
        payload.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            let n = withUnsafePointer(to: &addr) { addrPtr -> ssize_t in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.sendto(fd, base, payload.count, 0, sa,
                                  socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if n < 0 {
                errMsg = String(cString: strerror(errno))
            } else {
                ok = true
            }
        }
        return ok ? nil : (errMsg ?? "unknown error")
    }

    // MARK: - Private

    @discardableResult
    private func send(_ data: Data, to dest: Destination) -> Bool {
        let fd = dest.fd
        var addr = dest.addr
        let host = dest.host
        let port = dest.port
        var ok = false
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafePointer(to: &addr) { addrPtr -> ssize_t in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.sendto(fd, base, data.count, 0, sa, addrSize)
                }
            }
            if n < 0 {
                let err = String(cString: strerror(errno))
                print("UDP broadcast to \(host):\(port) failed: \(err)")
            } else {
                ok = true
            }
        }
        return ok
    }

    private static func makeDestination(id: UUID, host: String, port: UInt16,
                                        format: UDPBroadcastFormat,
                                        allowedSources: Set<String>,
                                        unfiltered: Bool = false) -> Destination? {
        guard !host.isEmpty, port > 0 else { return nil }

        var inaddr = in_addr()
        guard inet_pton(AF_INET, host, &inaddr) == 1 else {
            print("UDPBroadcaster: invalid IPv4 address \(host)")
            return nil
        }

        let fd = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if fd < 0 {
            print("UDPBroadcaster: socket() failed: \(String(cString: strerror(errno)))")
            return nil
        }

        var yes: Int32 = 1
        if setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            print("UDPBroadcaster: SO_BROADCAST setsockopt failed: \(String(cString: strerror(errno)))")
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = inaddr
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        return Destination(id: id, host: host, port: port, fd: fd, addr: addr,
                           format: format, allowedSources: allowedSources,
                           unfiltered: unfiltered)
    }
}
