import Foundation
import Network

class UDPBroadcaster {
    private var connection1: NWConnection?
    private var connection2: NWConnection?
    private let queue = DispatchQueue(label: "com.ft8cluster.udpbroadcast")

    func configure(ip1: String, port1: UInt16, ip2: String, port2: UInt16) {
        stop()

        if !ip1.isEmpty && port1 > 0 {
            let host = NWEndpoint.Host(ip1)
            let port = NWEndpoint.Port(rawValue: port1)!
            connection1 = NWConnection(host: host, port: port, using: .udp)
            connection1?.start(queue: queue)
        }

        if !ip2.isEmpty && port2 > 0 {
            let host = NWEndpoint.Host(ip2)
            let port = NWEndpoint.Port(rawValue: port2)!
            connection2 = NWConnection(host: host, port: port, using: .udp)
            connection2?.start(queue: queue)
        }
    }

    func broadcast(_ message: String) {
        guard let data = (message + "\r\n").data(using: .utf8) else { return }

        connection1?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("UDP broadcast 1 error: \(error)")
            }
        })

        connection2?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("UDP broadcast 2 error: \(error)")
            }
        })
    }

    func stop() {
        connection1?.cancel()
        connection1 = nil
        connection2?.cancel()
        connection2 = nil
    }
}
