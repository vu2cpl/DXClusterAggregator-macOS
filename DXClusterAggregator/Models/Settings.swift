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

/// One UDP broadcast destination. Replaces the old hardcoded
/// broadcastIP1/Port1/Format1 + broadcastIP2/Port2/Format2 pair with a
/// dynamic list — the user can add as many destinations as they need.
struct BroadcastDestination: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String = ""
    var ip: String = "127.0.0.1"
    var port: Int = 2236
    /// "cluster" (DX cluster text) or "wsjtx" (WSJT-X UDP binary).
    var format: String = "cluster"
    /// Source-name allowlist — empty means all sources.
    var allowedSources: Set<String> = []
    var enabled: Bool = true
    /// When true, this destination receives EVERY classified spot (subject to
    /// the per-destination source allowlist) regardless of the user's display
    /// filters: New Only, Hide /N, Hide Duplicates, Bands, Sources. Useful
    /// when feeding an upstream aggregator (e.g. RBN) that does its own
    /// filtering and expects the raw stream.
    var unfiltered: Bool = false
}

class AppSettings: ObservableObject {
    @AppStorage("callsign") var callsign: String = "VU2CPL"
    @AppStorage("tcpClusterPort") var tcpClusterPort: Int = 7550
    @AppStorage("broadcastIP1") var broadcastIP1: String = "127.0.0.1"
    @AppStorage("broadcastPort1") var broadcastPort1: Int = 2236
    /// Wire format for Broadcast Destination 1: "cluster" (DX cluster text)
    /// or "wsjtx" (WSJT-X binary protocol — Status + Decode pair per spot).
    @AppStorage("broadcastFormat1") var broadcastFormat1: String = "cluster"
    @AppStorage("broadcastIP2") var broadcastIP2: String = "127.0.0.1"
    @AppStorage("broadcastPort2") var broadcastPort2: Int = 2239
    @AppStorage("broadcastFormat2") var broadcastFormat2: String = "cluster"
    @AppStorage("cqOnly") var cqOnly: Bool = false
    @AppStorage("newOnly") var newOnly: Bool = false
    @AppStorage("hideDuplicates") var hideDuplicates: Bool = true
    /// Hide call-area portables like W1AW/4, K1JT/5, OE/3 etc. These are
    /// same-DXCC operations from a different region and rarely useful as DX.
    /// Prefix-override portables (VK7/W3LPL, JA1/G3XYZ) are NOT filtered —
    /// those represent real DX from another entity.
    @AppStorage("hidePortableCallAreas") var hidePortableCallAreas: Bool = true
    @AppStorage("minimizeOnStart") var minimizeOnStart: Bool = false
    @AppStorage("autoStartOnLaunch") var autoStartOnLaunch: Bool = false

    /// Auto-clear spots older than this many minutes (0 = disabled).
    /// Range clamped to 0...120 by the UI.
    @AppStorage("autoClearMinutes") var autoClearMinutes: Int = 60

    var autoClearMinutesString: Binding<String> {
        Binding<String>(
            get: { String(self.autoClearMinutes) },
            set: {
                let v = Int($0) ?? self.autoClearMinutes
                self.autoClearMinutes = max(0, min(120, v))
            }
        )
    }

    @Published var udpSources: [UDPSource] {
        didSet { saveCodable(udpSources, key: "udpSources") }
    }

    @Published var dxClusterSources: [DXClusterSource] {
        didSet { saveCodable(dxClusterSources, key: "dxClusterSources") }
    }

    @Published var broadcastDestinations: [BroadcastDestination] {
        didSet { saveCodable(broadcastDestinations, key: "broadcastDestinations") }
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

    /// Band filter for the spots table (display + alerts).
    /// Empty set = show all bands. Independent from clubLog.importBands
    /// which only controls which QSOs are imported into the log matrix.
    @Published var displayBands: Set<String> {
        didSet { saveCodable(Array(displayBands), key: "displayBands") }
    }

    /// Per-destination source allowlist for the UDP broadcasters.
    /// Empty set = all sources are allowed (current behaviour).
    /// Non-empty = only spots whose sourceName is in the set get
    /// rebroadcast to that destination. Lets the user, e.g., restrict
    /// a WSJT-X-format destination feeding RBN to ONLY their own
    /// WSJT-X / JTDX / SkimSrv spots and never relay other clusters.
    @Published var broadcastSources1: Set<String> {
        didSet { saveCodable(Array(broadcastSources1), key: "broadcastSources1") }
    }
    @Published var broadcastSources2: Set<String> {
        didSet { saveCodable(Array(broadcastSources2), key: "broadcastSources2") }
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
        if let arr: [String] = Self.loadCodable(key: "displayBands") {
            self.displayBands = Set(arr)
        } else {
            self.displayBands = []
        }
        self.broadcastSources1 = Set(Self.loadCodable(key: "broadcastSources1") ?? [])
        self.broadcastSources2 = Set(Self.loadCodable(key: "broadcastSources2") ?? [])

        // Broadcast destinations: load list, or migrate from old paired
        // settings (broadcastIP1/Port1/Format1/etc.) on first launch after
        // upgrade. We do NOT delete the old keys so a downgrade still works.
        if let dests: [BroadcastDestination] = Self.loadCodable(key: "broadcastDestinations") {
            self.broadcastDestinations = dests
        } else {
            // Migrate from paired settings
            let d = UserDefaults.standard
            let ip1   = d.string(forKey: "broadcastIP1")   ?? "127.0.0.1"
            let port1 = d.integer(forKey: "broadcastPort1")
            let fmt1  = d.string(forKey: "broadcastFormat1") ?? "cluster"
            let srcs1 = Set((Self.loadCodable(key: "broadcastSources1") as [String]?) ?? [])

            let ip2   = d.string(forKey: "broadcastIP2")   ?? "127.0.0.1"
            let port2 = d.integer(forKey: "broadcastPort2")
            let fmt2  = d.string(forKey: "broadcastFormat2") ?? "cluster"
            let srcs2 = Set((Self.loadCodable(key: "broadcastSources2") as [String]?) ?? [])

            var migrated: [BroadcastDestination] = []
            if port1 > 0 {
                migrated.append(BroadcastDestination(
                    name: "Destination 1", ip: ip1, port: port1,
                    format: fmt1, allowedSources: srcs1, enabled: true))
            }
            if port2 > 0 {
                migrated.append(BroadcastDestination(
                    name: "Destination 2", ip: ip2, port: port2,
                    format: fmt2, allowedSources: srcs2, enabled: true))
            }
            self.broadcastDestinations = migrated
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

    // Broadcast destination management
    func addBroadcastDestination() {
        let nextPort = (broadcastDestinations.last?.port ?? 2235) + 1
        broadcastDestinations.append(BroadcastDestination(
            name: "Destination \(broadcastDestinations.count + 1)",
            ip: "127.0.0.1",
            port: nextPort
        ))
    }

    func removeBroadcastDestination(at index: Int) {
        guard index < broadcastDestinations.count else { return }
        broadcastDestinations.remove(at: index)
    }

    func broadcastPortString(at index: Int) -> Binding<String> {
        Binding<String>(
            get: {
                guard index < self.broadcastDestinations.count else { return "" }
                return String(self.broadcastDestinations[index].port)
            },
            set: {
                guard index < self.broadcastDestinations.count else { return }
                self.broadcastDestinations[index].port = Int($0) ?? self.broadcastDestinations[index].port
            }
        )
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
