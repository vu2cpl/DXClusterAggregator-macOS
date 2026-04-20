import Foundation

/// A simplified DXCC entity derived from the ClubLog cty.xml file.
struct DXCCEntity {
    let adif: Int      // ADIF/DXCC entity ID
    let name: String   // e.g. "ENGLAND"
    let prefix: String // canonical prefix
    let cqZone: Int
    let continent: String
}

/// Represents a single prefix rule from the cty.xml file.
struct CTYPrefixRule {
    let call: String     // Prefix pattern, e.g. "K", "VU2", or exact call "K1JT"
    let adif: Int
    let isExact: Bool    // true for "exceptions", false for prefix matches
    let startDate: Date? // rule valid from this date (nil = always)
    let endDate: Date?   // rule valid until this date (nil = still active)

    /// True if this rule applies at the given moment (defaults to now).
    func isActive(at date: Date = Date()) -> Bool {
        if let start = startDate, date < start { return false }
        if let end = endDate, date > end { return false }
        return true
    }
}

/// Parses the ClubLog cty.xml file.
/// The file has three main sections:
///   <entities> - list of DXCC entities
///   <exceptions> - exact-call overrides
///   <prefixes> - prefix-to-DXCC mapping
class CTYParser: NSObject, XMLParserDelegate {
    private(set) var entities: [Int: DXCCEntity] = [:]
    private(set) var prefixRules: [CTYPrefixRule] = []

    private var currentElement = ""
    private var currentPath: [String] = []
    private var buffer = ""

    // Temporary parsing state
    private var tmpAdif: Int?
    private var tmpName: String?
    private var tmpPrefix: String?
    private var tmpCQZ: Int?
    private var tmpContinent: String?
    private var tmpCall: String?
    private var tmpDeleted: Bool = false
    private var tmpStart: Date?
    private var tmpEnd: Date?
    private var inExceptions = false
    private var inPrefixes = false
    private var inEntities = false

    // ISO-8601 parser with the timezone format used in ClubLog cty.xml
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parse(data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String]) {
        currentElement = elementName
        currentPath.append(elementName)
        buffer = ""

        let lower = elementName.lowercased()

        // Top-level section flags
        switch lower {
        case "entities": inEntities = true
        case "exceptions": inExceptions = true
        case "prefixes": inPrefixes = true
        default: break
        }

        // Reset temps ONLY when starting a top-level record. Several tag names
        // (entity, prefix) appear both as records and as nested labels inside
        // other records, so we must check the parent element to disambiguate.
        // currentPath at this point: [..., parent, current]
        let parent = currentPath.count >= 2
            ? currentPath[currentPath.count - 2].lowercased()
            : ""

        let isTopLevelRecord =
            (lower == "entity"    && parent == "entities") ||
            (lower == "exception" && parent == "exceptions") ||
            (lower == "prefix"    && parent == "prefixes")

        if isTopLevelRecord {
            tmpAdif = nil
            tmpName = nil
            tmpPrefix = nil
            tmpCQZ = nil
            tmpContinent = nil
            tmpCall = nil
            tmpDeleted = false
            tmpStart = nil
            tmpEnd = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = elementName.lowercased()

        // Determine parent for context-sensitive handling
        let parent = currentPath.count >= 2
            ? currentPath[currentPath.count - 2].lowercased()
            : ""

        switch lower {
        case "adif":
            tmpAdif = Int(value)
        case "name":
            tmpName = value
        case "prefix":
            // <prefix> appears in two contexts:
            //   - Inside <entity>: canonical prefix string for that entity
            //   - Inside <prefixes> as a prefix-record element terminator
            if parent == "entity" {
                tmpPrefix = value
            } else if parent == "prefixes" {
                // End of a top-level <prefix> record
                if let adif = tmpAdif, let call = tmpCall {
                    prefixRules.append(CTYPrefixRule(
                        call: call.uppercased(), adif: adif, isExact: false,
                        startDate: tmpStart, endDate: tmpEnd
                    ))
                }
            }
        case "call":
            tmpCall = value
        case "cqz":
            tmpCQZ = Int(value)
        case "cont":
            tmpContinent = value
        case "deleted":
            tmpDeleted = (value.lowercased() == "true")
        case "start":
            tmpStart = Self.isoFormatter.date(from: value)
        case "end":
            tmpEnd = Self.isoFormatter.date(from: value)
        case "entity":
            // <entity> as a label inside <exception> or <prefix> records is just a
            // human-readable name, not a record terminator. Only process the
            // top-level entity records under <entities>.
            guard parent == "entities" else { break }
            if let adif = tmpAdif, let name = tmpName {
                let entity = DXCCEntity(
                    adif: adif,
                    name: name,
                    prefix: tmpPrefix ?? "",
                    cqZone: tmpCQZ ?? 0,
                    continent: tmpContinent ?? ""
                )
                entities[adif] = entity

                // Also register the entity's canonical prefix as a lookup rule
                // so callsigns with that prefix resolve to this DXCC. Skip
                // deleted entities - they're historical and would shadow
                // active ones (e.g., "EU" vs "EM" for Ukraine).
                if !tmpDeleted, let prefix = tmpPrefix, !prefix.isEmpty {
                    // Treat the entity prefix as exact-match if it looks like a
                    // full callsign (contains a digit), otherwise as a prefix rule.
                    // 4U1UN, 1A0KM etc. are entire callsigns; VE, K, JA are prefixes.
                    let upper = prefix.uppercased()
                    let hasDigit = upper.contains(where: { $0.isNumber })
                    let hasMultipleLetters = upper.filter({ $0.isLetter }).count >= 3
                    let looksLikeFullCall = hasDigit && hasMultipleLetters
                    prefixRules.append(CTYPrefixRule(
                        call: upper, adif: adif, isExact: looksLikeFullCall,
                        startDate: tmpStart, endDate: tmpEnd
                    ))
                }
            }
        case "exception":
            if let adif = tmpAdif, let call = tmpCall {
                prefixRules.append(CTYPrefixRule(
                    call: call.uppercased(), adif: adif, isExact: true,
                    startDate: tmpStart, endDate: tmpEnd
                ))
            }
        case "entities": inEntities = false
        case "exceptions": inExceptions = false
        case "prefixes": inPrefixes = false
        default: break
        }

        if !currentPath.isEmpty {
            currentPath.removeLast()
        }
        buffer = ""
    }
}
