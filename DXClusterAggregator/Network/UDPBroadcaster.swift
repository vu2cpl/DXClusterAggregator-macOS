import Foundation
import Darwin

/// Sends each spot string to up to two UDP destinations.
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

final class UDPBroadcaster: ObservableObject {
    private struct Destination {
        let host: String
        let port: UInt16
        let fd: Int32
        var addr: sockaddr_in
        var format: UDPBroadcastFormat
    }

    private var dest1: Destination?
    private var dest2: Destination?

    /// Diagnostic counters — visible in the status bar so the user can confirm
    /// packets are actually leaving the app (vs. being filtered out upstream).
    @Published var sentDest1: Int = 0
    @Published var sentDest2: Int = 0
    @Published var failDest1: Int = 0
    @Published var failDest2: Int = 0

    func configure(ip1: String, port1: UInt16, format1: UDPBroadcastFormat,
                   ip2: String, port2: UInt16, format2: UDPBroadcastFormat) {
        stop()
        dest1 = Self.makeDestination(host: ip1, port: port1, format: format1)
        dest2 = Self.makeDestination(host: ip2, port: port2, format: format2)
        DispatchQueue.main.async {
            self.sentDest1 = 0
            self.sentDest2 = 0
            self.failDest1 = 0
            self.failDest2 = 0
        }
    }

    /// Send a spot to both broadcast destinations using each one's
    /// configured wire format. Cluster-format destinations get the prebuilt
    /// `clusterLine` (DX cluster text). WSJT-X-format destinations get a
    /// freshly-encoded Status+Decode pair for this specific spot so a
    /// downstream WSJT-X-aware listener (RBN Aggregator etc.) sees a
    /// well-formed binary message stream.
    func broadcast(clusterLine: String,
                   callsign: String?,
                   frequencyHz: UInt64,
                   snr: Int32,
                   mode: String,
                   message: String) {
        let clusterPayload = (clusterLine + "\r\n").data(using: .utf8) ?? Data()

        let ok1 = sendForDestination(dest1, clusterPayload: clusterPayload,
                                     callsign: callsign, frequencyHz: frequencyHz,
                                     snr: snr, mode: mode, message: message)
        let ok2 = sendForDestination(dest2, clusterPayload: clusterPayload,
                                     callsign: callsign, frequencyHz: frequencyHz,
                                     snr: snr, mode: mode, message: message)

        DispatchQueue.main.async {
            if let _ = self.dest1 {
                if ok1 { self.sentDest1 += 1 } else { self.failDest1 += 1 }
            }
            if let _ = self.dest2 {
                if ok2 { self.sentDest2 += 1 } else { self.failDest2 += 1 }
            }
        }
    }

    private func sendForDestination(_ dest: Destination?,
                                    clusterPayload: Data,
                                    callsign: String?,
                                    frequencyHz: UInt64,
                                    snr: Int32,
                                    mode: String,
                                    message: String) -> Bool {
        guard let dest = dest else { return false }
        switch dest.format {
        case .cluster:
            return send(clusterPayload, to: dest)
        case .wsjtx:
            // Need a callsign for WSJT-X to make sense; if missing, skip.
            guard let call = callsign, !call.isEmpty else { return false }
            let pair = WSJTXMessageBuilder.encodeSpot(
                callsign: call,
                frequencyHz: frequencyHz,
                snr: snr,
                mode: mode,
                message: message
            )
            // Send Status first so the receiver knows the dial frequency,
            // then Decode immediately after. UDP doesn't preserve order
            // strictly but back-to-back local sends almost always arrive in
            // sequence, and most receivers tolerate either order anyway.
            let s1 = send(pair.status, to: dest)
            let s2 = send(pair.decode, to: dest)
            return s1 && s2
        }
    }

    func stop() {
        if let d = dest1 { Darwin.close(d.fd) }
        if let d = dest2 { Darwin.close(d.fd) }
        dest1 = nil
        dest2 = nil
    }

    /// Fire a single labelled test packet to the given destination, configuring
    /// the socket on the fly if necessary. Returns nil on success or an error
    /// string. This bypasses the Save flow so the user can probe arbitrary
    /// IP/port combos without wiring them into the live config.
    @discardableResult
    func sendTest(host: String, port: UInt16,
                  format: UDPBroadcastFormat = .cluster) -> String? {
        guard let d = Self.makeDestination(host: host, port: port, format: format) else {
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
            // Send a representative Decode (with prerequisite Status) so the
            // receiver can confirm parsing as well as transport.
            let pair = WSJTXMessageBuilder.encodeSpot(
                callsign: "TEST",
                frequencyHz: 14_074_000,
                snr: 0,
                mode: "FT8",
                message: "CQ TEST"
            )
            payload = pair.status + pair.decode
        }
        let data = payload

        var dest = d
        var ok = false
        var errMsg: String? = nil
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            let n = withUnsafePointer(to: &dest.addr) { addrPtr -> ssize_t in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.sendto(dest.fd, base, data.count, 0, sa,
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
        var dest = dest
        var ok = false
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let base = ptr.baseAddress else { return }
            let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafePointer(to: &dest.addr) { addrPtr -> ssize_t in
                addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Darwin.sendto(dest.fd, base, data.count, 0, sa, addrSize)
                }
            }
            if n < 0 {
                let err = String(cString: strerror(errno))
                print("UDP broadcast to \(dest.host):\(dest.port) failed: \(err)")
            } else {
                ok = true
            }
        }
        return ok
    }

    private static func makeDestination(host: String, port: UInt16,
                                        format: UDPBroadcastFormat) -> Destination? {
        guard !host.isEmpty, port > 0 else { return nil }

        // Resolve dotted-quad to in_addr (we only support IPv4 here, which
        // covers all common DX-cluster broadcast configurations).
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

        // Enable broadcast so x.x.x.255 / 255.255.255.255 work.
        var yes: Int32 = 1
        if setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size)) < 0 {
            print("UDPBroadcaster: SO_BROADCAST setsockopt failed: \(String(cString: strerror(errno)))")
            // continue anyway - unicast still works
        }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr = inaddr
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)

        return Destination(host: host, port: port, fd: fd, addr: addr, format: format)
    }
}
