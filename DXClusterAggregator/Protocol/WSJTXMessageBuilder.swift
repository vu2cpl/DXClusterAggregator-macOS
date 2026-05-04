import Foundation

/// Builds WSJT-X UDP wire-format messages so the aggregator can re-emit
/// spots in a format compatible with WSJT-X-aware downstream tools
/// (RBN Aggregator, JTAlert, GridTracker, etc.).
///
/// All multi-byte integers are big-endian (QDataStream / Qt convention).
/// Strings are length-prefixed by a u32 byte count, with 0xFFFFFFFF
/// representing a null string.
///
/// We emit a Type 1 (Status) followed by a Type 2 (Decode) for each spot
/// so the receiver knows the dial frequency the decode is relative to.
/// dialFrequency = exact spot frequency, deltaFrequency = 0 — i.e. "the
/// rig is tuned right on top of this signal." That keeps the math simple
/// for downstream consumers.
struct WSJTXMessageBuilder {
    static let magic: UInt32 = 0xADBCCBDA
    static let schemaVersion: UInt32 = 2
    static let defaultClientId = "DXClusterAggregator"

    /// Pair of bytes (status, decode) ready to send back-to-back via UDP.
    static func encodeSpot(callsign: String,
                           frequencyHz: UInt64,
                           snr: Int32,
                           mode: String,
                           message: String,
                           clientId: String = defaultClientId,
                           timeMillis: UInt32? = nil,
                           deltaTime: Double = 0.0) -> (status: Data, decode: Data) {
        // deCall is "the operator's own call" in WSJT-X's protocol. If we
        // put the DX callsign here, downstream tools like RUMlog see Status
        // saying "I'm RA9ACA" + Decode containing "RA9ACA" and treat the
        // pair as the operator's own loop-back, suppressing the spot. Use a
        // fixed identity so receivers always treat decodes as "heard others."
        let status = encodeStatus(
            clientId: clientId,
            dialFrequency: frequencyHz,
            mode: mode,
            deCall: "DXCAGGR"
        )
        let decode = encodeDecode(
            clientId: clientId,
            timeMillis: timeMillis ?? millisSinceMidnightUTC(),
            snr: snr,
            deltaTime: deltaTime,
            deltaFrequency: 0,
            mode: mode,
            message: message
        )
        return (status, decode)
    }

    // MARK: - Type 1: Status

    static func encodeStatus(clientId: String,
                             dialFrequency: UInt64,
                             mode: String,
                             dxCall: String = "",
                             report: String = "",
                             txMode: String = "",
                             txEnabled: Bool = false,
                             transmitting: Bool = false,
                             decoding: Bool = false,
                             rxDF: UInt32 = 0,
                             txDF: UInt32 = 0,
                             deCall: String = "",
                             deGrid: String = "",
                             dxGrid: String = "") -> Data {
        var w = Writer()
        w.writeHeader(type: 1)
        w.writeString(clientId)
        w.writeU64(dialFrequency)
        w.writeString(mode)
        w.writeString(dxCall)
        w.writeString(report)
        w.writeString(txMode)
        w.writeBool(txEnabled)
        w.writeBool(transmitting)
        w.writeBool(decoding)
        w.writeU32(rxDF)
        w.writeU32(txDF)
        w.writeString(deCall)
        w.writeString(deGrid)
        w.writeString(dxGrid)
        return w.data
    }

    // MARK: - Type 2: Decode

    static func encodeDecode(clientId: String,
                             timeMillis: UInt32,
                             snr: Int32,
                             deltaTime: Double,
                             deltaFrequency: UInt32,
                             mode: String,
                             message: String,
                             isNew: Bool = true,
                             lowConfidence: Bool = false,
                             offAir: Bool = false) -> Data {
        var w = Writer()
        w.writeHeader(type: 2)
        w.writeString(clientId)
        w.writeBool(isNew)
        w.writeU32(timeMillis)
        w.writeI32(snr)
        w.writeDouble(deltaTime)
        w.writeU32(deltaFrequency)
        w.writeString(mode)
        w.writeString(message)
        w.writeBool(lowConfidence)
        w.writeBool(offAir)
        return w.data
    }

    // MARK: - Helpers

    private static func millisSinceMidnightUTC() -> UInt32 {
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let comps = cal.dateComponents([.hour, .minute, .second], from: now)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        let ms = (h * 3_600 + m * 60 + s) * 1_000
        return UInt32(ms)
    }

    // MARK: - Binary writer

    private struct Writer {
        var data = Data()

        mutating func writeHeader(type: UInt32) {
            writeU32(WSJTXMessageBuilder.magic)
            writeU32(WSJTXMessageBuilder.schemaVersion)
            writeU32(type)
        }

        mutating func writeU32(_ v: UInt32) {
            var be = v.bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
        }

        mutating func writeI32(_ v: Int32) {
            writeU32(UInt32(bitPattern: v))
        }

        mutating func writeU64(_ v: UInt64) {
            var be = v.bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
        }

        mutating func writeBool(_ v: Bool) {
            data.append(v ? 1 : 0)
        }

        mutating func writeDouble(_ v: Double) {
            let bits = v.bitPattern
            var be = bits.bigEndian
            withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
        }

        /// QDataStream string: u32 byte count followed by UTF-8 bytes.
        /// 0xFFFFFFFF means null. Empty string is length 0.
        mutating func writeString(_ s: String) {
            let bytes = Array(s.utf8)
            writeU32(UInt32(bytes.count))
            data.append(contentsOf: bytes)
        }
    }
}
