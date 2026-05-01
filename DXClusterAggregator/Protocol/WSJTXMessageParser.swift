import Foundation

enum WSJTXMessageType: UInt32 {
    case heartbeat = 0
    case status = 1
    case decode = 2
    case clear = 3
    case reply = 4
    case qsoLogged = 5
    case close = 6
    case replay = 7
    case haltTx = 8
    case freeText = 9
    case wspr = 10
    case location = 11
    case loggedADIF = 12
    case highlightCallsign = 13
    case switchConfig = 14
    case configure = 15
}

struct WSJTXStatus {
    let clientId: String
    let dialFrequency: UInt64
    let mode: String
    let dxCall: String
    let report: String
    let txMode: String
    let txEnabled: Bool
    let transmitting: Bool
    let decoding: Bool
    let rxDF: UInt32
    let txDF: UInt32
    let deCall: String
    let deGrid: String
    let dxGrid: String
}

struct WSJTXDecode {
    let clientId: String
    let isNew: Bool
    let time: UInt32       // ms since midnight UTC
    let snr: Int32
    let deltaTime: Double
    let deltaFrequency: UInt32
    let mode: String
    let message: String
    let lowConfidence: Bool
    let offAir: Bool
}

class WSJTXMessageParser {
    static let magic: UInt32 = 0xADBCCBDA

    private var data: Data
    private var offset: Int

    init(data: Data) {
        self.data = data
        self.offset = 0
    }

    // MARK: - Primitive readers (big-endian, QDataStream compatible)

    private func readUInt8() -> UInt8? {
        guard offset + 1 <= data.count else { return nil }
        let value = data[offset]
        offset += 1
        return value
    }

    private func readBool() -> Bool? {
        guard let byte = readUInt8() else { return nil }
        return byte != 0
    }

    private func readInt32() -> Int32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        return Int32(bitPattern: UInt32(bigEndian: value))
    }

    private func readUInt32() -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        let value = data.subdata(in: offset..<offset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
        offset += 4
        return UInt32(bigEndian: value)
    }

    private func readUInt64() -> UInt64? {
        guard offset + 8 <= data.count else { return nil }
        let value = data.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) }
        offset += 8
        return UInt64(bigEndian: value)
    }

    private func readDouble() -> Double? {
        guard offset + 8 <= data.count else { return nil }
        let bits = data.subdata(in: offset..<offset+8).withUnsafeBytes { $0.load(as: UInt64.self) }
        offset += 8
        let swapped = UInt64(bigEndian: bits)
        return Double(bitPattern: swapped)
    }

    private func readUTF8String() -> String? {
        guard let length = readUInt32() else { return nil }
        if length == 0xFFFFFFFF { return "" }  // null string
        guard length > 0, offset + Int(length) <= data.count else {
            if length == 0 { return "" }
            return nil
        }
        let strData = data.subdata(in: offset..<offset+Int(length))
        offset += Int(length)
        return String(data: strData, encoding: .utf8) ?? ""
    }

    // MARK: - Message parsing

    func parse() -> (WSJTXMessageType, Any?)? {
        guard let magicValue = readUInt32(), magicValue == WSJTXMessageParser.magic else {
            return nil
        }
        guard let _ = readUInt32() else { return nil } // schema version
        guard let typeRaw = readUInt32(), let messageType = WSJTXMessageType(rawValue: typeRaw) else {
            return nil
        }

        switch messageType {
        case .status:
            return (.status, parseStatus())
        case .decode:
            return (.decode, parseDecode())
        default:
            return (messageType, nil)
        }
    }

    /// Permissive Status parser. Only the first two fields are critical
    /// (clientId + dialFrequency) — without them the message is useless.
    /// Everything past that is best-effort: emitters like MSHV, JTDX, and
    /// older WSJT-X versions trim or extend the trailing fields, and a
    /// strict guard chain made us drop the whole Status (and thus lose the
    /// dial frequency, which then made every Decode display freq as the
    /// raw audio offset, e.g. 1500 Hz → 0.001 MHz).
    private func parseStatus() -> WSJTXStatus? {
        guard let clientId = readUTF8String() else { return nil }
        guard let dialFreq = readUInt64() else { return nil }

        let mode         = readUTF8String() ?? ""
        let dxCall       = readUTF8String() ?? ""
        let report       = readUTF8String() ?? ""
        let txMode       = readUTF8String() ?? ""
        let txEnabled    = readBool() ?? false
        let transmitting = readBool() ?? false
        let decoding     = readBool() ?? false
        let rxDF         = readUInt32() ?? 0
        let txDF         = readUInt32() ?? 0
        let deCall       = readUTF8String() ?? ""
        let deGrid       = readUTF8String() ?? ""
        let dxGrid       = readUTF8String() ?? ""

        return WSJTXStatus(
            clientId: clientId,
            dialFrequency: dialFreq,
            mode: mode,
            dxCall: dxCall,
            report: report,
            txMode: txMode,
            txEnabled: txEnabled,
            transmitting: transmitting,
            decoding: decoding,
            rxDF: rxDF,
            txDF: txDF,
            deCall: deCall,
            deGrid: deGrid,
            dxGrid: dxGrid
        )
    }

    /// Permissive Decode parser. Required: clientId, time, snr, deltaTime,
    /// deltaFrequency, mode, message. The two trailing flags
    /// (lowConfidence, offAir) and the leading isNew flag are best-effort.
    private func parseDecode() -> WSJTXDecode? {
        guard let clientId = readUTF8String() else { return nil }
        let isNew         = readBool() ?? true
        guard let time       = readUInt32() else { return nil }
        guard let snr        = readInt32() else { return nil }
        guard let deltaTime  = readDouble() else { return nil }
        guard let deltaFreq  = readUInt32() else { return nil }
        guard let mode       = readUTF8String() else { return nil }
        guard let message    = readUTF8String() else { return nil }
        let lowConfidence = readBool() ?? false
        let offAir        = readBool() ?? false

        return WSJTXDecode(
            clientId: clientId,
            isNew: isNew,
            time: time,
            snr: snr,
            deltaTime: deltaTime,
            deltaFrequency: deltaFreq,
            mode: mode,
            message: message,
            lowConfidence: lowConfidence,
            offAir: offAir
        )
    }
}
