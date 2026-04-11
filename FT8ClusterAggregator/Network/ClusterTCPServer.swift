import Foundation
import Network

class ClusterTCPServer: ObservableObject {
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.ft8cluster.tcpserver")
    private let connectionsLock = NSLock()

    @Published var isRunning = false
    @Published var clientCount = 0

    func start(port: UInt16) {
        stop()

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            print("Failed to create TCP listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("TCP cluster server ready on port \(port)")
                case .failed(let error):
                    self?.isRunning = false
                    print("TCP cluster server failed: \(error)")
                case .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connectionsLock.lock()
        for conn in connections {
            conn.cancel()
        }
        connections.removeAll()
        connectionsLock.unlock()
        DispatchQueue.main.async {
            self.isRunning = false
            self.clientCount = 0
        }
    }

    func broadcast(_ message: String) {
        guard let data = (message + "\r\n").data(using: .utf8) else { return }

        connectionsLock.lock()
        let currentConnections = connections
        connectionsLock.unlock()

        for connection in currentConnections {
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("TCP send error: \(error)")
                }
            })
        }
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("TCP client connected")
                self?.updateClientCount()
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }

        connectionsLock.lock()
        connections.append(connection)
        connectionsLock.unlock()

        connection.start(queue: queue)

        // Send welcome message
        let welcome = "DX Cluster Server - FT8ClusterAggregator for macOS\r\n"
        if let data = welcome.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in })
        }

        // Keep reading to detect disconnects
        receiveLoop(connection)
    }

    private func receiveLoop(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] _, _, isComplete, error in
            if isComplete || error != nil {
                self?.removeConnection(connection)
            } else {
                self?.receiveLoop(connection)
            }
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connection.cancel()
        connectionsLock.lock()
        connections.removeAll { $0 === connection }
        connectionsLock.unlock()
        updateClientCount()
    }

    private func updateClientCount() {
        connectionsLock.lock()
        let count = connections.count
        connectionsLock.unlock()
        DispatchQueue.main.async {
            self.clientCount = count
        }
    }
}
