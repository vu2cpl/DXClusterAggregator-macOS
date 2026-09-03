import Foundation
import CryptoKit

/// Remembers that ClubLog answered **403** for a particular set of
/// credentials, so nothing sends them again until they change.
///
/// ClubLog's integration guidance asks that a 403 disable further requests
/// immediately rather than be retried: their reactive firewall watches for
/// repeated bad-credential traffic and blocks the source IP. That would take
/// out cluster-side ClubLog access for the whole shack, not just the one
/// wrong password — and the app has no way to know it happened, because a
/// firewalled host simply stops getting answers.
///
/// What gets stored is a **fingerprint of the credentials, not a flag**, and
/// that is the whole design. A flag needs a reset button: something the user
/// must find and press after fixing the password, and forget to press, and
/// then wonder why nothing downloads. A fingerprint clears itself — edit the
/// key and it no longer matches, so the next Refresh simply goes through. The
/// value is hashed because there is no reason for a second copy of a secret to
/// sit in UserDefaults next to the first.
enum ClubLogRejection {

    /// Which credential set a rejection belongs to. The API key and the log
    /// login fail independently — a wrong app password says nothing about the
    /// key — so they latch separately.
    enum Scope: String {
        case ctyAPIKey = "clubLogRejectedCTYKeyFingerprint"
        case logCredentials = "clubLogRejectedLogFingerprint"
    }

    private static func fingerprint(_ parts: [String]) -> String {
        // The NUL separator keeps ("ab", "c") distinct from ("a", "bc").
        let joined = parts.joined(separator: "\0")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// True when ClubLog has already rejected exactly these credentials.
    static func isRejected(_ scope: Scope, credentials: [String]) -> Bool {
        let fp = fingerprint(credentials)
        guard !fp.isEmpty,
              let stored = UserDefaults.standard.string(forKey: scope.rawValue),
              !stored.isEmpty else { return false }
        return stored == fp
    }

    /// Record a 403 against these exact credentials.
    static func record(_ scope: Scope, credentials: [String]) {
        UserDefaults.standard.set(fingerprint(credentials), forKey: scope.rawValue)
    }

    /// Clear the latch after a download succeeds, so credentials that start
    /// working again (ClubLog side fixed, quota restored) are not held down by
    /// a stale fingerprint.
    static func clear(_ scope: Scope) {
        UserDefaults.standard.removeObject(forKey: scope.rawValue)
    }
}

/// A ClubLog request that failed, with **403 kept separate** from everything
/// else so the caller can tell "these credentials are wrong" from "the network
/// hiccupped" — the first must not be retried, the second may be.
enum ClubLogError: LocalizedError {
    case forbidden(String)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .forbidden(let m), .other(let m): return m
        }
    }

    var isForbidden: Bool {
        if case .forbidden = self { return true }
        return false
    }
}
