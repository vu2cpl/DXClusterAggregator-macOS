import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var tcpServer = ClusterTCPServer()
    @StateObject private var clubLogClient = ClubLogClient()

    @State private var udpListeners: [UUID: WSJTXUDPListener] = [:]
    @State private var dxClusterClients: [UUID: DXClusterClient] = [:]
    @State private var udpBroadcaster = UDPBroadcaster()
    @State private var spots: [FT8SpotMessage] = []
    @State private var isMonitoring = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                headerSection
                Divider()
                configSection
                Divider()
                sourcesSection
                Divider()
                dxClusterSection
                Divider()
                clubLogSection
                Divider()
                controlSection
                Divider()
                spotsTable
                statusBar
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 750)
        .onAppear {
            clubLogClient.loadCachedData()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("FT8 Cluster Aggregator")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Text("v1.2.0 (macOS)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Configuration

    private var configSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                HStack {
                    Text("Callsign:")
                        .frame(width: 70, alignment: .trailing)
                    TextField("Your callsign", text: $settings.callsign)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .disableAutocorrection(true)
                }

                HStack {
                    Text("TCP Cluster Port:")
                    TextField("7550", text: settings.tcpClusterPortString)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                }
            }

            GroupBox("Broadcast Destination 1") {
                HStack {
                    Text("IP:")
                    TextField("127.0.0.1", text: $settings.broadcastIP1)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .disableAutocorrection(true)
                    Text("Port:")
                    TextField("2236", text: settings.broadcastPort1String)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Button("Save") { saveBroadcast() }
                }
                .padding(.vertical, 4)
            }

            GroupBox("Broadcast Destination 2") {
                HStack {
                    Text("IP:")
                    TextField("127.0.0.1", text: $settings.broadcastIP2)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .disableAutocorrection(true)
                    Text("Port:")
                    TextField("2239", text: settings.broadcastPort2String)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Button("Save") { saveBroadcast() }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - UDP Sources

    private var sourcesSection: some View {
        GroupBox("UDP Sources (WSJT-X / JTDX)") {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Text("Name").frame(width: 120, alignment: .leading)
                    Text("Listen IP").frame(width: 120, alignment: .leading)
                    Text("Port").frame(width: 60, alignment: .leading)
                    Text("Enabled").frame(width: 60)
                    Text("Status").frame(width: 70, alignment: .leading)
                    Spacer()
                }
                .font(.caption.bold())
                .padding(.horizontal, 4)

                Divider()

                ForEach(Array(settings.udpSources.enumerated()), id: \.element.id) { index, source in
                    HStack(spacing: 8) {
                        TextField("Name", text: Binding(
                            get: { settings.udpSources[safe: index]?.name ?? "" },
                            set: { if index < settings.udpSources.count { settings.udpSources[index].name = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .disabled(isMonitoring)

                        TextField("0.0.0.0", text: Binding(
                            get: { settings.udpSources[safe: index]?.ip ?? "" },
                            set: { if index < settings.udpSources.count { settings.udpSources[index].ip = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .disableAutocorrection(true)
                        .disabled(isMonitoring)

                        TextField("Port", text: settings.sourcePortString(at: index))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .disabled(isMonitoring)

                        Toggle("", isOn: Binding(
                            get: { settings.udpSources[safe: index]?.enabled ?? true },
                            set: { if index < settings.udpSources.count { settings.udpSources[index].enabled = $0 } }
                        ))
                        .frame(width: 60)
                        .disabled(isMonitoring)

                        HStack(spacing: 4) {
                            if isMonitoring, let listener = udpListeners[source.id] {
                                Circle()
                                    .fill(listener.isListening ? .green : .orange)
                                    .frame(width: 8, height: 8)
                                Text(listener.isListening ? "Active" : "...")
                                    .font(.caption2)
                            } else if !source.enabled {
                                Text("Off")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("-")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 70, alignment: .leading)

                        Spacer()

                        Button(action: { settings.removeSource(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.udpSources.count <= 1 || isMonitoring)
                    }
                    .padding(.horizontal, 4)
                }

                HStack {
                    Button(action: { settings.addSource() }) {
                        Label("Add UDP Source", systemImage: "plus.circle")
                    }
                    .disabled(isMonitoring)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - DX Cluster Sources

    private var dxClusterSection: some View {
        GroupBox("DX Cluster Nodes (Telnet)") {
            VStack(spacing: 6) {
                if !settings.dxClusterSources.isEmpty {
                    HStack(spacing: 8) {
                        Text("Name").frame(width: 90, alignment: .leading)
                        Text("Address").frame(width: 130, alignment: .leading)
                        Text("Port").frame(width: 50, alignment: .leading)
                        Text("Username").frame(width: 90, alignment: .leading)
                        Text("Password").frame(width: 80, alignment: .leading)
                        Text("On").frame(width: 35)
                        Text("Status").frame(width: 80, alignment: .leading)
                        Spacer()
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 4)

                    Divider()
                }

                ForEach(Array(settings.dxClusterSources.enumerated()), id: \.element.id) { index, source in
                    HStack(spacing: 8) {
                        TextField("Name", text: Binding(
                            get: { settings.dxClusterSources[safe: index]?.name ?? "" },
                            set: { if index < settings.dxClusterSources.count { settings.dxClusterSources[index].name = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .disabled(isMonitoring)

                        TextField("host or IP", text: Binding(
                            get: { settings.dxClusterSources[safe: index]?.address ?? "" },
                            set: { if index < settings.dxClusterSources.count { settings.dxClusterSources[index].address = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                        .disableAutocorrection(true)
                        .disabled(isMonitoring)

                        TextField("Port", text: settings.dxClusterPortString(at: index))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .disabled(isMonitoring)

                        TextField("Callsign", text: Binding(
                            get: { settings.dxClusterSources[safe: index]?.username ?? "" },
                            set: { if index < settings.dxClusterSources.count { settings.dxClusterSources[index].username = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                        .disableAutocorrection(true)
                        .disabled(isMonitoring)

                        SecureField("Password", text: Binding(
                            get: { settings.dxClusterSources[safe: index]?.password ?? "" },
                            set: { if index < settings.dxClusterSources.count { settings.dxClusterSources[index].password = $0 } }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .disabled(isMonitoring)

                        Toggle("", isOn: Binding(
                            get: { settings.dxClusterSources[safe: index]?.enabled ?? true },
                            set: { if index < settings.dxClusterSources.count { settings.dxClusterSources[index].enabled = $0 } }
                        ))
                        .frame(width: 35)
                        .disabled(isMonitoring)

                        HStack(spacing: 4) {
                            if isMonitoring, let client = dxClusterClients[source.id] {
                                Circle()
                                    .fill(client.isConnected ? .green : .orange)
                                    .frame(width: 8, height: 8)
                                Text(client.statusText)
                                    .font(.caption2)
                                    .lineLimit(1)
                            } else if !source.enabled {
                                Text("Off")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("-")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 80, alignment: .leading)

                        Spacer()

                        Button(action: { settings.removeDXCluster(at: index) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                        .disabled(isMonitoring)
                    }
                    .padding(.horizontal, 4)
                }

                HStack {
                    Button(action: { settings.addDXCluster() }) {
                        Label("Add DX Cluster", systemImage: "plus.circle")
                    }
                    .disabled(isMonitoring)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - ClubLog Section

    private var clubLogSection: some View {
        GroupBox("ClubLog Integration") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Callsign:").frame(width: 70, alignment: .trailing)
                    TextField("VU2CPL", text: $settings.clubLog.callsign)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .disableAutocorrection(true)
                        .disabled(clubLogClient.isRefreshing)

                    Text("Email:").frame(width: 50, alignment: .trailing)
                    TextField("you@example.com", text: $settings.clubLog.email)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .disableAutocorrection(true)
                        .disabled(clubLogClient.isRefreshing)

                    Spacer()
                }

                HStack(spacing: 8) {
                    Text("App Pwd:").frame(width: 70, alignment: .trailing)
                    SecureField("ClubLog app password", text: $settings.clubLog.appPassword)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .disabled(clubLogClient.isRefreshing)

                    Text("API Key:").frame(width: 60, alignment: .trailing)
                    SecureField("Developer API key", text: $settings.clubLog.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                        .disabled(clubLogClient.isRefreshing)

                    Spacer()
                }

                HStack {
                    Text("Alerts:").bold()
                    Toggle("New DXCC", isOn: $settings.clubLog.alertNewDXCC)
                    Toggle("New Slot", isOn: $settings.clubLog.alertNewSlot)
                    Toggle("New Band", isOn: $settings.clubLog.alertNewBand)
                    Toggle("New Mode", isOn: $settings.clubLog.alertNewMode)
                    Spacer()
                }
                .font(.caption)

                HStack {
                    Button(action: refreshClubLog) {
                        if clubLogClient.isRefreshing {
                            ProgressView().controlSize(.small).padding(.trailing, 4)
                            Text("Refreshing...")
                        } else {
                            Label("Refresh from ClubLog", systemImage: "arrow.clockwise.circle")
                        }
                    }
                    .disabled(clubLogClient.isRefreshing)

                    Spacer()

                    Text(clubLogClient.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func refreshClubLog() {
        Task {
            await clubLogClient.refresh(config: settings.clubLog)
            // Persist timing info
            settings.clubLog.lastRefresh = clubLogClient.lastRefresh
            settings.clubLog.qsoCount = clubLogClient.qsoCount
        }
    }

    private func alertColor(_ level: AlertLevel) -> Color {
        switch level {
        case .newDXCC: return Color.red.opacity(0.25)
        case .newSlot: return Color.orange.opacity(0.25)
        case .newBand: return Color.yellow.opacity(0.25)
        case .newMode: return Color.yellow.opacity(0.15)
        case .worked:  return Color.clear
        case .none:    return Color.clear
        }
    }

    private func alertIcon(_ level: AlertLevel) -> String {
        switch level {
        case .newDXCC: return "🔴"
        case .newSlot: return "🟠"
        case .newBand: return "🟡"
        case .newMode: return "🟡"
        case .worked:  return "⚪"
        case .none:    return ""
        }
    }

    // MARK: - Controls

    private var controlSection: some View {
        HStack {
            Toggle("CQ Only", isOn: $settings.cqOnly)
            Toggle("Minimize on Start", isOn: $settings.minimizeOnStart)

            Spacer()

            Button(action: clearSpots) {
                Label("Clear Spots", systemImage: "trash")
            }

            Button(action: toggleMonitoring) {
                Label(isMonitoring ? "Stop Monitoring" : "Start Monitoring",
                      systemImage: isMonitoring ? "stop.circle.fill" : "play.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(isMonitoring ? .red : .green)
        }
    }

    // MARK: - Spots Table

    private var spotsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text("").frame(width: 20, alignment: .leading)
                Text("Time").frame(width: 55, alignment: .leading)
                Text("Source").frame(width: 70, alignment: .leading)
                Text("Callsign").frame(width: 90, alignment: .leading)
                Text("DXCC").frame(width: 110, alignment: .leading)
                Text("Freq (MHz)").frame(width: 85, alignment: .trailing)
                Text("Band").frame(width: 45, alignment: .leading)
                Text("SNR").frame(width: 40, alignment: .trailing)
                Text("Mode").frame(width: 50, alignment: .leading)
                Text("Message").frame(minWidth: 150, alignment: .leading)
            }
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.15))

            Divider()

            ScrollViewReader { proxy in
                List(spots) { spot in
                    HStack(spacing: 0) {
                        Text(alertIcon(spot.alertLevel)).frame(width: 20, alignment: .leading)
                        Text(spot.timeString).frame(width: 55, alignment: .leading)
                        Text(spot.sourceName).frame(width: 70, alignment: .leading)
                            .foregroundColor(.secondary)
                        Text(spot.dxCallsign ?? "-").frame(width: 90, alignment: .leading)
                            .bold(spot.alertLevel == .newDXCC || spot.alertLevel == .newSlot)
                        Text(spot.dxccName ?? "").frame(width: 110, alignment: .leading)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(String(format: "%.3f", spot.frequencyMHz)).frame(width: 85, alignment: .trailing)
                        Text(spot.bandName ?? "").frame(width: 45, alignment: .leading)
                            .foregroundColor(.secondary)
                        Text("\(spot.snr)").frame(width: 40, alignment: .trailing)
                        Text(spot.mode).frame(width: 50, alignment: .leading)
                        Text(spot.message).frame(minWidth: 150, alignment: .leading)
                    }
                    .font(.system(.caption, design: .monospaced))
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .background(alertColor(spot.alertLevel))
                    .id(spot.id)
                }
                .listStyle(.plain)
                .onChange(of: spots.count) { _, _ in
                    if let last = spots.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(minHeight: 200)
        .background(Color(nsColor: .textBackgroundColor))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            Circle()
                .fill(isMonitoring ? .green : .gray)
                .frame(width: 8, height: 8)
            Text(isMonitoring ? "Monitoring" : "Stopped")
                .font(.caption)

            Spacer()

            if isMonitoring {
                let activeUDP = udpListeners.values.filter { $0.isListening }.count
                let totalUDP = udpListeners.count
                let activeDX = dxClusterClients.values.filter { $0.isConnected }.count
                let totalDX = dxClusterClients.count

                if totalUDP > 0 {
                    Text("UDP: \(activeUDP)/\(totalUDP)")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                if totalDX > 0 {
                    Text("DXC: \(activeDX)/\(totalDX)")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
            }

            if tcpServer.isRunning {
                Text("TCP: \(tcpServer.clientCount) client(s)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            Spacer()

            Text("\(spots.count) spots")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func saveBroadcast() {
        if isMonitoring {
            configureBroadcaster()
        }
    }

    private func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    private func startMonitoring() {
        settings.callsign = settings.callsign.uppercased()

        // Start UDP listeners
        for source in settings.udpSources where source.enabled {
            let listener = WSJTXUDPListener(name: source.name, sourceId: source.id)

            listener.onDecode = { decode, sourceId in
                DispatchQueue.main.async {
                    self.handleDecode(decode, sourceId: sourceId)
                }
            }

            listener.start(port: UInt16(source.port))
            udpListeners[source.id] = listener
        }

        // Start DX Cluster clients
        for source in settings.dxClusterSources where source.enabled && !source.address.isEmpty {
            let client = DXClusterClient(name: source.name, sourceId: source.id)

            client.onSpot = { spot in
                DispatchQueue.main.async {
                    self.handleClusterSpot(spot)
                }
            }

            client.connect(
                address: source.address,
                port: UInt16(source.port),
                username: source.username,
                password: source.password
            )
            dxClusterClients[source.id] = client
        }

        // Start TCP cluster server
        tcpServer.start(port: UInt16(settings.tcpClusterPort))

        // Configure UDP broadcaster
        configureBroadcaster()

        isMonitoring = true
    }

    private func stopMonitoring() {
        for listener in udpListeners.values { listener.stop() }
        udpListeners.removeAll()

        for client in dxClusterClients.values { client.disconnect() }
        dxClusterClients.removeAll()

        tcpServer.stop()
        udpBroadcaster.stop()
        isMonitoring = false
    }

    private func configureBroadcaster() {
        udpBroadcaster.configure(
            ip1: settings.broadcastIP1,
            port1: UInt16(settings.broadcastPort1),
            ip2: settings.broadcastIP2,
            port2: UInt16(settings.broadcastPort2)
        )
    }

    @MainActor
    private func handleDecode(_ decode: WSJTXDecode, sourceId: UUID) {
        let dialFreq = udpListeners[sourceId]?.dialFrequency ?? 0
        let sourceName = udpListeners[sourceId]?.name ?? "Unknown"

        var spot = FT8SpotMessage(
            time: Self.timeFromMilliseconds(decode.time),
            snr: decode.snr,
            deltaTime: decode.deltaTime,
            deltaFrequency: decode.deltaFrequency,
            mode: decode.mode,
            message: decode.message,
            lowConfidence: decode.lowConfidence,
            offAir: decode.offAir,
            dialFrequency: dialFreq,
            sourceName: sourceName
        )

        if settings.cqOnly && !spot.isCQ { return }

        classifySpot(&spot)
        spots.append(spot)

        let clusterMessage = ClusterFormatter.format(spot: spot, spotter: settings.callsign)
        tcpServer.broadcast(clusterMessage)
        udpBroadcaster.broadcast(clusterMessage)
    }

    @MainActor
    private func handleClusterSpot(_ clusterSpot: DXClusterClient.ClusterSpot) {
        // Convert cluster spot to FT8SpotMessage for unified display
        let freqHz = UInt64(clusterSpot.frequencyKHz * 1000.0)

        // Extract SNR from comment if present (e.g., "FT8 -15 dB")
        var snr: Int32 = 0
        if let dbRange = clusterSpot.comment.range(of: #"-?\d+ dB"#, options: .regularExpression) {
            let dbStr = clusterSpot.comment[dbRange].replacingOccurrences(of: " dB", with: "")
            snr = Int32(dbStr) ?? 0
        }

        // Extract mode from comment
        var mode = ""
        let knownModes = ["FT8", "FT4", "CW", "SSB", "RTTY", "PSK31", "JT65", "JT9", "MSK144", "WSPR"]
        for m in knownModes {
            if clusterSpot.comment.uppercased().contains(m) {
                mode = m
                break
            }
        }

        var spot = FT8SpotMessage(
            time: Date(),
            snr: snr,
            deltaTime: 0,
            deltaFrequency: 0,
            mode: mode,
            message: "CQ \(clusterSpot.dxCall)",
            lowConfidence: false,
            offAir: false,
            dialFrequency: freqHz,
            sourceName: clusterSpot.sourceName
        )

        if settings.cqOnly && !spot.isCQ { return }

        classifySpot(&spot)
        spots.append(spot)

        // Re-broadcast the original spot line
        let clusterMessage = ClusterFormatter.format(spot: spot, spotter: clusterSpot.spotter)
        tcpServer.broadcast(clusterMessage)
        udpBroadcaster.broadcast(clusterMessage)
    }

    @MainActor
    private func classifySpot(_ spot: inout FT8SpotMessage) {
        let classifier = AlertClassifier(
            matrix: clubLogClient.matrix,
            resolver: clubLogClient.resolver,
            config: settings.clubLog
        )
        let result = classifier.classify(
            callsign: spot.dxCallsign,
            frequencyMHz: spot.frequencyMHz,
            mode: spot.mode
        )
        spot.alertLevel = result.level
        spot.dxccName = result.dxccName
        spot.bandName = result.band
    }

    private func clearSpots() {
        spots.removeAll()
    }

    private static func timeFromMilliseconds(_ ms: UInt32) -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: now)
        components.hour = Int(ms / 3_600_000)
        components.minute = Int((ms % 3_600_000) / 60_000)
        components.second = Int((ms % 60_000) / 1_000)
        return calendar.date(from: components) ?? now
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
