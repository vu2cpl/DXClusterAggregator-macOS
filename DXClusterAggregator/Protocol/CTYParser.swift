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
    private var inExceptions = false
    private var inPrefixes = false
    private var inEntities = false

    func parse(data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentPath.append(elementName)
        buffer = ""

        switch elementName.lowercased() {
        case "entities": inEntities = true
        case "exceptions": inExceptions = true
        case "prefixes": inPrefixes = true
        case "entity", "exception", "prefix":
            tmpAdif = nil
            tmpName = nil
            tmpPrefix = nil
            tmpCQZ = nil
            tmpContinent = nil
            tmpCall = nil
            tmpDeleted = false
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = elementName.lowercased()

        switch lower {
        case "adif":
            tmpAdif = Int(value)
        case "name":
            tmpName = value
        case "prefix":
            // Inside an <entity>, this is the canonical prefix
            // Inside a <prefix> record, this is the prefix pattern (call field)
            if currentPath.count >= 2 && currentPath[currentPath.count - 2].lowercased() == "entity" {
                tmpPrefix = value
            } else if inPrefixes && currentPath.count >= 2 && currentPath[currentPath.count - 2].lowercased() == "prefixes" {
                // End of <prefix> record
                if let adif = tmpAdif, let call = tmpCall {
                    prefixRules.append(CTYPrefixRule(call: call.uppercased(), adif: adif, isExact: false))
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
        case "entity":
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
                        call: upper, adif: adif, isExact: looksLikeFullCall
                    ))
                }
            }
        case "exception":
            if let adif = tmpAdif, let call = tmpCall {
                prefixRules.append(CTYPrefixRule(call: call.uppercased(), adif: adif, isExact: true))
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
