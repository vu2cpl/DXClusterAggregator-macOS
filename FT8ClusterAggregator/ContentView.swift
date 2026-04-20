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

    // Collapsible state for the configuration sections (settings panel)
    @AppStorage("showSettings") private var showSettings: Bool = true

    // Notification cooldown tracker: callsign -> last-notified Date
    @State private var notificationCooldown: [String: Date] = [:]

    var body: some View {
        VStack(spacing: 12) {
            headerSection
            Divider()
            if showSettings {
                ScrollView {
                    VStack(spacing: 12) {
                        configSection
                        Divider()
                        sourcesSection
                        Divider()
                        dxClusterSection
                        Divider()
                        clubLogSection
                        Divider()
                        notificationsSection
                    }
                }
                .frame(maxHeight: 380)
                Divider()
            }
            controlSection
            Divider()
            spotsTable
            statusBar
        }
        .padding()
        .frame(minWidth: 800, minHeight: showSettings ? 800 : 500)
        .onAppear {
            clubLogClient.loadCachedData()
            if settings.notifications.systemEnabled {
                SystemNotifier.requestAuthorizationIfNeeded()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("FT8 Cluster Aggregator")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button(action: { showSettings.toggle() }) {
                Label(
                    showSettings ? "Hide Settings" : "Show Settings",
                    systemImage: showSettings ? "chevron.up.circle" : "chevron.down.circle"
                )
            }
            .help("Collapse the settings panel for more space")

            Text("v1.5.0 (macOS)")
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
                    Toggle("Inc. Unconfirmed", isOn: $settings.clubLog.alertUnconfirmed)
                        .help("Treat worked-but-unconfirmed (no LOTW/QSL/eQSL) as still needed")
                    Spacer()
                }
                .font(.caption)

                // Band selector for ClubLog import
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Import Bands:").bold().font(.caption)
                        Button("All") {
                            settings.clubLog.importBands = []
                        }
                        .controlSize(.mini)
                        Button("HF Only") {
                            settings.clubLog.importBands = Set(["160M","80M","60M","40M","30M","20M","17M","15M","12M","10M"])
                        }
                        .controlSize(.mini)
                        Button("None") {
                            // Empty selection means "all" by convention; use a sentinel to show "no qsos"
                            // Instead set to a single non-existent band to actually filter out everything
                            settings.clubLog.importBands = ["__NONE__"]
                        }
                        .controlSize(.mini)
                        Spacer()
                        Text(settings.clubLog.importBands.isEmpty ? "All bands" : "\(settings.clubLog.importBands.count) selected")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    bandSelectorGrid
                }
                .padding(.top, 2)

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

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        GroupBox("Notifications (Telegram + macOS)") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Telegram", isOn: $settings.notifications.telegramEnabled)
                    Toggle("macOS Notifications", isOn: $settings.notifications.systemEnabled)
                        .onChange(of: settings.notifications.systemEnabled) { _, enabled in
                            if enabled { SystemNotifier.requestAuthorizationIfNeeded() }
                        }

                    Spacer()

                    Text("Cooldown:")
                        .font(.caption)
                    TextField("15", text: settings.cooldownMinutesString)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Stepper("", value: $settings.notifications.cooldownMinutes, in: 5...60)
                        .labelsHidden()
                    Text("min").font(.caption).foregroundColor(.secondary)
                }

                HStack {
                    Text("Bot Token:").frame(width: 80, alignment: .trailing)
                    SecureField("123456:ABC-DEF...", text: $settings.notifications.telegramBotToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .disabled(!settings.notifications.telegramEnabled)
                }

                HStack {
                    Text("Chat ID:").frame(width: 80, alignment: .trailing)
                    TextField("123456789", text: $settings.notifications.telegramChatId)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                        .disableAutocorrection(true)
                        .disabled(!settings.notifications.telegramEnabled)

                    Spacer()

                    Button("Send Test") { sendTestNotification() }
                        .disabled(!settings.notifications.telegramEnabled && !settings.notifications.systemEnabled)
                }

                HStack {
                    Text("Notify on:").bold().font(.caption)
                    Toggle("New DXCC", isOn: $settings.notifications.notifyNewDXCC)
                    Toggle("New Slot", isOn: $settings.notifications.notifyNewSlot)
                    Toggle("New Band", isOn: $settings.notifications.notifyNewBand)
                    Toggle("New Mode", isOn: $settings.notifications.notifyNewMode)
                    Spacer()
                }
                .font(.caption)

                Text("Cooldown applies per callsign — within the chosen window, repeat spots of the same call do not trigger another notification.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func sendTestNotification() {
        let cfg = settings.notifications
        let title = "FT8ClusterAggregator Test"
        let body = "Notifications wired up. Cooldown \(cfg.cooldownMinutes) min."

        if cfg.systemEnabled {
            SystemNotifier.requestAuthorizationIfNeeded()
            SystemNotifier.post(title: title, body: body)
        }
        if cfg.telegramEnabled {
            TelegramNotifier.send(
                botToken: cfg.telegramBotToken,
                chatId: cfg.telegramChatId,
                text: "<b>\(title)</b>\n\(body)"
            )
        }
    }

    private var bandSelectorGrid: some View {
        let allBands = ["160M","80M","60M","40M","30M","20M","17M","15M","12M","10M","6M","4M","2M","70CM"]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(allBands, id: \.self) { band in
                let isAll = settings.clubLog.importBands.isEmpty
                let isOnlyNone = settings.clubLog.importBands == ["__NONE__"]
                let isSelected = isAll || (settings.clubLog.importBands.contains(band) && !isOnlyNone)
                Toggle(band, isOn: Binding(
                    get: { isSelected },
                    set: { newValue in
                        var current = isAll ? Set(allBands) : settings.clubLog.importBands
                        if isOnlyNone { current = [] }
                        if newValue { current.insert(band) } else { current.remove(band) }
                        // If all selected, normalize to empty (= all)
                        if current == Set(allBands) { current = [] }
                        // If empty, mark as none-sentinel to actually filter everything out
                        if current.isEmpty && !newValue { current = ["__NONE__"] }
                        settings.clubLog.importBands = current
                    }
                ))
                .toggleStyle(.checkbox)
                .font(.caption2)
            }
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
        case .newDXCC: return Color.red.opacity(0.40)
        case .newSlot: return Color.orange.opacity(0.40)
        case .newBand: return Color.blue.opacity(0.35)
        case .newMode: return Color(red: 1.0, green: 0.75, blue: 0.0).opacity(0.45) // amber
        case .worked:  return Color.clear
        case .none:    return Color.clear
        }
    }

    private func alertIcon(_ level: AlertLevel) -> String {
        switch level {
        case .newDXCC: return "🔴"
        case .newSlot: return "🟠"
        case .newBand: return "🔵"
        case .newMode: return "🟡"
        case .worked:  return "⚪"
        case .none:    return ""
        }
    }

    // MARK: - Controls

    private var controlSection: some View {
        HStack {
            Toggle("CQ Only", isOn: $settings.cqOnly)
            Toggle("New Only", isOn: $settings.newOnly)
                .help("Show only spots matching an enabled ClubLog alert (new DXCC/slot/band/mode)")
            Toggle("Hide on Start", isOn: $settings.minimizeOnStart)
                .help("When monitoring starts, hide the main window. Use the menu bar antenna icon to show it again.")

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
                let visible = displayedSpots
                List(visible) { spot in
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
                    .listRowBackground(alertColor(spot.alertLevel))
                    .id(spot.id)
                }
                .listStyle(.plain)
                .onChange(of: visible.count) { _, _ in
                    if let last = visible.last {
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

            Text("\(displayedSpots.count) / \(spots.count) spots")
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

        // Hide window if user wants menu-bar-only mode while monitoring.
        if settings.minimizeOnStart {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                WindowManager.hideMainWindow()
            }
        }
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

        classifySpot(&spot)

        // Always store the spot; filters below apply to display + rebroadcast.
        spots.append(spot)

        // Push notifications (Telegram + system) for matching alerts, with per-call cooldown
        maybeNotify(spot)

        // CQ filter and New filter apply to rebroadcast (gated live by current toggle state).
        if shouldShow(spot) {
            let clusterMessage = ClusterFormatter.format(spot: spot, spotter: settings.callsign)
            tcpServer.broadcast(clusterMessage)
            udpBroadcaster.broadcast(clusterMessage)
        }
    }

    /// If the spot's alert level is one the user wants notified, push to Telegram and/or
    /// macOS Notification Center, respecting per-callsign cooldown.
    @MainActor
    private func maybeNotify(_ spot: FT8SpotMessage) {
        let cfg = settings.notifications

        // Quick exit if nothing is enabled
        guard cfg.telegramEnabled || cfg.systemEnabled else { return }

        // Match on user-selected notification levels (separate from highlight toggles)
        let notify: Bool
        switch spot.alertLevel {
        case .newDXCC: notify = cfg.notifyNewDXCC
        case .newSlot: notify = cfg.notifyNewSlot
        case .newBand: notify = cfg.notifyNewBand
        case .newMode: notify = cfg.notifyNewMode
        case .worked, .none: notify = false
        }
        guard notify else { return }

        guard let call = spot.dxCallsign, !call.isEmpty else { return }

        // Cooldown
        let key = call.uppercased()
        let now = Date()
        let cooldown = TimeInterval(max(5, min(60, cfg.cooldownMinutes)) * 60)
        if let last = notificationCooldown[key], now.timeIntervalSince(last) < cooldown {
            return
        }
        notificationCooldown[key] = now

        // Build message
        let levelLabel: String
        switch spot.alertLevel {
        case .newDXCC: levelLabel = "🔴 NEW DXCC"
        case .newSlot: levelLabel = "🟠 New Slot"
        case .newBand: levelLabel = "🔵 New Band"
        case .newMode: levelLabel = "🟡 New Mode"
        default: levelLabel = "Alert"
        }

        let dxcc = spot.dxccName ?? ""
        let band = spot.bandName ?? ""
        let freq = String(format: "%.3f MHz", spot.frequencyMHz)

        let title = "\(levelLabel): \(call)"
        let body = "\(dxcc.isEmpty ? "" : dxcc + "  ")\(freq)  \(band)  \(spot.mode)  \(spot.snr) dB"

        if cfg.systemEnabled {
            SystemNotifier.post(title: title, body: body, identifier: "spot-\(key)-\(Int(now.timeIntervalSince1970))")
        }

        if cfg.telegramEnabled {
            // Use HTML formatting for Telegram
            let tgText = "<b>\(escapeHTML(title))</b>\n\(escapeHTML(body))\nSource: \(escapeHTML(spot.sourceName))"
            TelegramNotifier.send(
                botToken: cfg.telegramBotToken,
                chatId: cfg.telegramChatId,
                text: tgText
            )
        }
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private func isNewAlert(_ level: AlertLevel) -> Bool {
        switch level {
        case .newDXCC, .newSlot, .newBand, .newMode: return true
        case .worked, .none: return false
        }
    }

    private func shouldShow(_ spot: FT8SpotMessage) -> Bool {
        if settings.cqOnly && !spot.isCQ { return false }
        if settings.newOnly && !isNewAlert(spot.alertLevel) { return false }
        return true
    }

    private var displayedSpots: [FT8SpotMessage] {
        spots.filter { shouldShow($0) }
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

        classifySpot(&spot)
        spots.append(spot)
        maybeNotify(spot)

        if shouldShow(spot) {
            let clusterMessage = ClusterFormatter.format(spot: spot, spotter: clusterSpot.spotter)
            tcpServer.broadcast(clusterMessage)
            udpBroadcaster.broadcast(clusterMessage)
        }
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
