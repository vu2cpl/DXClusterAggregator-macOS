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
        var isBeacon: Bool = false
    }

    /// Classify a spot. Returns `.none` if we lack data to decide (no matrix, no band, no DXCC).
    func classify(callsign: String?, frequencyMHz: Double, mode: String) -> Classification {
        guard let call = callsign, !call.isEmpty else {
            return Classification(level: .none, dxccId: nil, dxccName: nil, band: nil)
        }

        guard resolver.isLoaded else {
            return Classification(level: .none, dxccId: nil, dxccName: nil, band: nil)
        }

        let band = BandResolver.band(fromMHz: frequencyMHz)

        // Beacons / satellites / Internet gateways: ClubLog marks these with
        // adif=0. Also check our known-beacon database for NCDXF/IBP beacons
        // which have meaningful location info. Never trigger alerts.
        let knownBeacon = BeaconDatabase.displayName(for: call)
        if resolver.isNonDXOperation(call) || knownBeacon != nil {
            let label = knownBeacon ?? "Beacon"
            return Classification(
                level: .none, dxccId: nil, dxccName: label, band: band,
                isBeacon: true
            )
        }

        let dxccId = resolver.resolve(call)
        let dxccName = dxccId.flatMap { resolver.entity(for: $0)?.name }
        // Collapse FT8/FT4/JT*/RTTY/... → DATA so digital modes are treated
        // as one bucket for DXCC-style slot tracking.
        let normalizedMode = ModeNormalizer.canonical(mode)

        // Without DXCC or band we can't classify
        guard let dxcc = dxccId, let bnd = band else {
            return Classification(level: .none, dxccId: dxccId, dxccName: dxccName, band: band)
        }

        // Respect the user's "Import Bands" selection as a filter for ALERTS too.
        // If the user has narrowed their log import to specific bands (e.g. HF
        // only), spots on other bands would otherwise all look like "new band"
        // alerts because nothing was imported for those bands.
        if !isBandOfInterest(bnd) {
            return Classification(level: .none, dxccId: dxcc, dxccName: dxccName, band: bnd)
        }

        // Apply filter toggles to decide the highest-priority applicable level
        let raw = rawLevel(dxcc: dxcc, band: bnd, mode: normalizedMode)
        let filtered = applyFilter(raw)

        return Classification(level: filtered, dxccId: dxcc, dxccName: dxccName, band: bnd)
    }

    /// Is this band one the user wants alerts for?
    /// Empty importBands = all bands. The special "__NONE__" sentinel means
    /// the user explicitly cleared the list (block everything).
    private func isBandOfInterest(_ band: String) -> Bool {
        let selection = config.importBands
        if selection.isEmpty { return true }
        if selection == ["__NONE__"] { return false }
        return selection.contains(band)
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
            // Priority order:
            //   newBand: this band has never been worked for the entity
            //   newMode: this mode has never been worked for the entity
            //   newSlot: both band and mode are individually worked, but not in combination
            //            (the genuine 5BDXCC / 9BDXCC / triple-play scenario)
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
