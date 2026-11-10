import Foundation

enum GoogleOAuthConfig {
    private static let calendarScope = "https://www.googleapis.com/auth/calendar"

    static var clientID: String? {
        if let id = Bundle.main.object(forInfoDictionaryKey: "GoogleClientID") as? String, !id.isEmpty, !id.hasPrefix("YOUR_") {
            return id
        }
        if let url = Bundle.main.url(forResource: "GoogleOAuth", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let id = plist["CLIENT_ID"] as? String, !id.isEmpty, !id.hasPrefix("YOUR_") {
            return id
        }
        return nil
    }

    static var scopes: [String] { [calendarScope] }

    static var isConfigured: Bool { clientID != nil }

    /// e.g. `123-abc.apps.googleusercontent.com` → `com.googleusercontent.apps.123-abc`
    static var callbackURLScheme: String? {
        guard let clientID else { return nil }
        guard clientID.hasSuffix(".apps.googleusercontent.com") else { return nil }
        let prefix = String(clientID.dropLast(".apps.googleusercontent.com".count))
        return "com.googleusercontent.apps.\(prefix)"
    }

    static var redirectURI: String? {
        guard let scheme = callbackURLScheme else { return nil }
        return "\(scheme):/oauth2redirect"
    }
}
