import Foundation
import SwiftUI

struct UDPSource: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var ip: String
    var port: Int
    var enabled: Bool = true

    static let defaultSources: [UDPSource] = [
        UDPSource(name: "WSJT-X", ip: "0.0.0.0", port: 2237)
    ]
}

struct DXClusterSource: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var address: String
    var port: Int
    var username: String
    var password: String
    var enabled: Bool = true
}

class AppSettings: ObservableObject {
    @AppStorage("callsign") var callsign: String = "VU2CPL"
    @AppStorage("tcpClusterPort") var tcpClusterPort: Int = 7550
    @AppStorage("broadcastIP1") var broadcastIP1: String = "127.0.0.1"
    @AppStorage("broadcastPort1") var broadcastPort1: Int = 2236
    @AppStorage("broadcastIP2") var broadcastIP2: String = "127.0.0.1"
    @AppStorage("broadcastPort2") var broadcastPort2: Int = 2239
    @AppStorage("cqOnly") var cqOnly: Bool = false
    @AppStorage("newOnly") var newOnly: Bool = false
    @AppStorage("hideDuplicates") var hideDuplicates: Bool = true
    @AppStorage("minimizeOnStart") var minimizeOnStart: Bool = false

    @Published var udpSources: [UDPSource] {
        didSet { saveCodable(udpSources, key: "udpSources") }
    }

    @Published var dxClusterSources: [DXClusterSource] {
        didSet { saveCodable(dxClusterSources, key: "dxClusterSources") }
    }

    @Published var clubLog: ClubLogConfig {
        didSet { saveCodable(clubLog, key: "clubLogConfig") }
    }

    @Published var notifications: NotificationConfig {
        didSet { saveCodable(notifications, key: "notificationConfig") }
    }

    /// Source-name filter for the spots table.
    /// Empty set = show all sources.
    @Published var selectedSources: Set<String> {
        didSet { saveCodable(Array(selectedSources), key: "selectedSources") }
    }

    init() {
        self.udpSources = Self.loadCodable(key: "udpSources") ?? UDPSource.defaultSources
        self.dxClusterSources = Self.loadCodable(key: "dxClusterSources") ?? []
        self.clubLog = Self.loadCodable(key: "clubLogConfig") ?? ClubLogConfig()
        self.notifications = Self.loadCodable(key: "notificationConfig") ?? NotificationConfig()
        if let arr: [String] = Self.loadCodable(key: "selectedSources") {
            self.selectedSources = Set(arr)
        } else {
            self.selectedSources = []
        }
    }

    var cooldownMinutesString: Binding<String> {
        Binding<String>(
            get: { String(self.notifications.cooldownMinutes) },
            set: {
                let v = Int($0) ?? self.notifications.cooldownMinutes
                self.notifications.cooldownMinutes = max(5, min(60, v))
            }
        )
    }

    private static func loadCodable<T: Codable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func saveCodable<T: Codable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // UDP source management
    func addSource() {
        let nextPort = (udpSources.last?.port ?? 2236) + 1
        udpSources.append(UDPSource(name: "Source \(udpSources.count + 1)", ip: "0.0.0.0", port: nextPort))
    }

    func removeSource(at index: Int) {
        guard udpSources.count > 1 else { return }
        udpSources.remove(at: index)
    }

    // DX Cluster source management
    func addDXCluster() {
        dxClusterSources.append(DXClusterSource(
            name: "Cluster \(dxClusterSources.count + 1)",
            address: "",
            port: 7300,
            username: callsign,
            password: ""
        ))
    }

    func removeDXCluster(at index: Int) {
        dxClusterSources.remove(at: index)
    }

    // String bindings for text fields that edit Int values
    var tcpClusterPortString: Binding<String> {
        Binding<String>(
            get: { String(self.tcpClusterPort) },
            set: { self.tcpClusterPort = Int($0) ?? self.tcpClusterPort }
        )
    }

    var broadcastPort1String: Binding<String> {
        Binding<String>(
            get: { String(self.broadcastPort1) },
            set: { self.broadcastPort1 = Int($0) ?? self.broadcastPort1 }
        )
    }

    var broadcastPort2String: Binding<String> {
        Binding<String>(
            get: { String(self.broadcastPort2) },
            set: { self.broadcastPort2 = Int($0) ?? self.broadcastPort2 }
        )
    }

    func sourcePortString(at index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard index < self.udpSources.count else { return "" }
                return String(self.udpSources[index].port)
            },
            set: {
                guard index < self.udpSources.count else { return }
                self.udpSources[index].port = Int($0) ?? self.udpSources[index].port
            }
        )
    }

    func dxClusterPortString(at index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard index < self.dxClusterSources.count else { return "" }
                return String(self.dxClusterSources[index].port)
            },
            set: {
                guard index < self.dxClusterSources.count else { return }
                self.dxClusterSources[index].port = Int($0) ?? self.dxClusterSources[index].port
            }
        )
    }
}
