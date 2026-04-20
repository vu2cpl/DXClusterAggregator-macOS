import Foundation

struct ClusterFormatter {
    /// Formats an FT8 spot into DX cluster spot format.
    /// Example: "DX de VU2CPL:     14074.0  K1JT         FT8 -15 dB                1423Z"
    static func format(spot: SpotMessage, spotter: String) -> String {
        let dxCall = spot.dxCallsign ?? "UNKNOWN"
        let freqKHz = spot.frequencyKHz
        let spotterField = String((spotter.isEmpty ? "NOCALL" : spotter).prefix(10)) + ":"
        let freqStr = String(format: "%9.1f", freqKHz)
        let comment = "\(spot.mode) \(spot.snr) dB"

        return "DX de \(spotterField.padding(toLength: 11, withPad: " ", startingAt: 0))\(freqStr)  \(dxCall.padding(toLength: 12, withPad: " ", startingAt: 0))\(comment.padding(toLength: 30, withPad: " ", startingAt: 0))\(spot.timeString)z"
    }
}
