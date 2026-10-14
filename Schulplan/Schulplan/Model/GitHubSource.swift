import Foundation
import Security

/// Reads files from the (private) scraper repo through the GitHub contents API.
struct GitHubSource {
    var owner: String
    var repo: String
    var branch: String
    var token: String

    enum Failure: LocalizedError {
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case .http(401, _), .http(403, _): return "GitHub lehnt den Token ab (401/403)."
            case .http(404, let path): return "\(path) nicht gefunden – Repo, Branch oder Token-Rechte prüfen."
            case .http(let code, let path): return "\(path): HTTP \(code)"
            }
        }
    }

    /// Returns nil when the file does not exist (homework.json is only written once homework was found).
    func file(_ path: String) async throws -> Data? {
        var comps = URLComponents(string: "https://api.github.com")!
        comps.path = "/repos/\(owner)/\(repo)/contents/\(path)"
        comps.queryItems = [URLQueryItem(name: "ref", value: branch)]
        var req = URLRequest(url: comps.url!, cachePolicy: .reloadIgnoringLocalCacheData)
        req.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 200 { return data }
        if code == 404 && path != "schedule.json" { return nil }
        throw Failure.http(code, path)
    }
}

enum Keychain {
    private static let service = "de.ftrapp.schulplan"

    static func read(_ account: String) -> String {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account,
                                kSecReturnData as String: true]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func write(_ value: String, for account: String) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecAttrAccount as String: account]
        SecItemDelete(q as CFDictionary)
        guard !value.isEmpty else { return }
        var add = q
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
