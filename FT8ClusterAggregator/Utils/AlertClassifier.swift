import Foundation

/// Classifies a spot against the loaded log matrix + DXCC resolver to determine
/// whether it represents a new DXCC, new slot, new band, new mode, or worked contact.
struct AlertClassifier {
    let matrix: LogMatrix
    let resolver: DXCCResolver
    let config: ClubLogConfig

    struct Classification {
        let level: AlertLevel
        let dxccId: Int?
        let dxccName: String?
        let band: String?
    }

    /// Classify a spot. Returns `.none` if we lack data to decide (no matrix, no band, no DXCC).
    func classify(callsign: String?, frequencyMHz: Double, mode: String) -> Classification {
        guard let call = callsign, !call.isEmpty else {
            return Classification(level: .none, dxccId: nil, dxccName: nil, band: nil)
        }

        guard resolver.isLoaded else {
            return Classification(level: .none, dxccId: nil, dxccName: nil, band: nil)
        }

        let dxccId = resolver.resolve(call)
        let dxccName = dxccId.flatMap { resolver.entity(for: $0)?.name }
        let band = BandResolver.band(fromMHz: frequencyMHz)
        let normalizedMode = mode.uppercased().isEmpty ? "FT8" : mode.uppercased()

        // Without DXCC or band we can't classify
        guard let dxcc = dxccId, let bnd = band else {
            return Classification(level: .none, dxccId: dxccId, dxccName: dxccName, band: band)
        }

        // Apply filter toggles to decide the highest-priority applicable level
        let raw = rawLevel(dxcc: dxcc, band: bnd, mode: normalizedMode)
        let filtered = applyFilter(raw)

        return Classification(level: filtered, dxccId: dxcc, dxccName: dxccName, band: bnd)
    }

    private func rawLevel(dxcc: Int, band: String, mode: String) -> AlertLevel {
        guard let status = matrix.status(for: dxcc) else {
            return .newDXCC
        }

        // If alertUnconfirmed is on, treat unconfirmed as not-worked.
        let bands = config.alertUnconfirmed ? status.confirmedBands : status.bands
        let modes = config.alertUnconfirmed ? status.confirmedModes : status.modes
        let slots = config.alertUnconfirmed ? status.confirmedSlots : status.slots

        // If the entity has no confirmed contacts at all when in unconfirmed mode,
        // treat as new DXCC for the purposes of confirmation hunting.
        if config.alertUnconfirmed && bands.isEmpty && modes.isEmpty && slots.isEmpty {
            return .newDXCC
        }

        let slot = "\(band)-\(mode)"
        if !slots.contains(slot) {
            if !bands.contains(band) && !modes.contains(mode) {
                return .newSlot
            }
            if !bands.contains(band) {
                return .newBand
            }
            if !modes.contains(mode) {
                return .newMode
            }
            return .newSlot
        }

        return .worked
    }

    private func applyFilter(_ level: AlertLevel) -> AlertLevel {
        switch level {
        case .newDXCC: return config.alertNewDXCC ? .newDXCC : .worked
        case .newSlot: return config.alertNewSlot ? .newSlot : .worked
        case .newBand: return config.alertNewBand ? .newBand : .worked
        case .newMode: return config.alertNewMode ? .newMode : .worked
        case .worked:  return .worked
        case .none:    return .none
        }
    }
}
