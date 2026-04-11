import Foundation
import Network

class WSJTXUDPListener: ObservableObject {
    private var listener: NWListener?
    private let queue: DispatchQueue

    let name: String
    let sourceId: UUID
    @Published var isListening = false
    @Published var lastStatus: WSJTXStatus?
    @Published var dialFrequency: UInt64 = 0

    var onDecode: ((WSJTXDecode, UUID) -> Void)?
    var onStatus: ((WSJTXStatus) -> Void)?

    init(name: String = "WSJT-X", sourceId: UUID = UUID()) {
        self.name = name
        self.sourceId = sourceId
        self.queue = DispatchQueue(label: "com.ft8cluster.udplistener.\(sourceId.uuidString.prefix(8))")
    }

    func start(port: UInt16) {
        stop()

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.any), port: NWEndpoint.Port(rawValue: port)!)

        do {
            listener = try NWListener(using: params)
        } catch {
            print("Failed to create UDP listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isListening = true
                    print("UDP listener ready on port \(port)")
                case .failed(let error):
                    self?.isListening = false
                    print("UDP listener failed: \(error)")
                case .cancelled:
                    self?.isListening = false
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
        DispatchQueue.main.async {
            self.isListening = false
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveMessage(on: connection)
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data = data, !data.isEmpty {
                self?.processMessage(data)
            }
            if error == nil {
                self?.receiveMessage(on: connection)
            }
        }
    }

    private func processMessage(_ data: Data) {
        let parser = WSJTXMessageParser(data: data)
        guard let (type, payload) = parser.parse() else { return }

        switch type {
        case .status:
            if let status = payload as? WSJTXStatus {
                DispatchQueue.main.async { [weak self] in
                    self?.lastStatus = status
                    self?.dialFrequency = status.dialFrequency
                }
                onStatus?(status)
            }
        case .decode:
            if let decode = payload as? WSJTXDecode {
                onDecode?(decode, sourceId)
            }
        default:
            break
        }
    }
}
