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
final class UDPBroadcaster {
    private struct Destination {
        let host: String
        let port: UInt16
        let fd: Int32
        var addr: sockaddr_in
    }

    private var dest1: Destination?
    private var dest2: Destination?

    func configure(ip1: String, port1: UInt16, ip2: String, port2: UInt16) {
        stop()
        dest1 = Self.makeDestination(host: ip1, port: port1)
        dest2 = Self.makeDestination(host: ip2, port: port2)
    }

    func broadcast(_ message: String) {
        let line = message + "\r\n"
        guard let data = line.data(using: .utf8) else { return }

        send(data, to: dest1)
        send(data, to: dest2)
    }

    func stop() {
        if let d = dest1 { Darwin.close(d.fd) }
        if let d = dest2 { Darwin.close(d.fd) }
        dest1 = nil
        dest2 = nil
    }

    // MARK: - Private

    private func send(_ data: Data, to dest: Destination?) {
        guard var dest = dest else { return }
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
            }
        }
    }

    private static func makeDestination(host: String, port: UInt16) -> Destination? {
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

        return Destination(host: host, port: port, fd: fd, addr: addr)
    }
}
