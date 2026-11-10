import AuthenticationServices
import Foundation
import UIKit

enum GoogleOAuthError: LocalizedError {
    case notConfigured
    case cancelled
    case missingCode
    case tokenExchangeFailed(String)
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Google Client ID が未設定です（Info.plist または GoogleOAuth.plist）。"
        case .cancelled: "サインインがキャンセルされました。"
        case .missingCode: "認証コードを取得できませんでした。"
        case .tokenExchangeFailed(let msg): msg
        case .refreshFailed(let msg): msg
        }
    }
}

@MainActor
final class GoogleOAuthClient: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleOAuthClient()

    private var authSession: ASWebAuthenticationSession?

    private let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private let authURLBase = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }

    func signIn() async throws -> GoogleOAuthTokens {
        guard let clientID = GoogleOAuthConfig.clientID,
              let redirect = GoogleOAuthConfig.redirectURI,
              let scheme = GoogleOAuthConfig.callbackURLScheme else {
            throw GoogleOAuthError.notConfigured
        }

        var components = URLComponents(url: authURLBase, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleOAuthConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let authURL = components.url else {
            throw GoogleOAuthError.notConfigured
        }

        let callbackURL = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: scheme) { [weak self] url, error in
                self?.authSession = nil
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    cont.resume(throwing: GoogleOAuthError.cancelled)
                    return
                }
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                guard let url else {
                    cont.resume(throwing: GoogleOAuthError.missingCode)
                    return
                }
                cont.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session
            session.start()
        }

        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else {
            throw GoogleOAuthError.missingCode
        }

        return try await exchangeCode(code, clientID: clientID, redirect: redirect)
    }

    func validAccessToken() async throws -> String {
        guard var tokens = try GoogleTokenStorage.load() else {
            throw GoogleOAuthError.notConfigured
        }
        if tokens.expiresAt.timeIntervalSinceNow > 120 {
            return tokens.accessToken
        }
        guard let refresh = tokens.refreshToken else {
            throw GoogleOAuthError.refreshFailed("リフレッシュトークンがありません。再サインインしてください。")
        }
        guard let clientID = GoogleOAuthConfig.clientID else {
            throw GoogleOAuthError.notConfigured
        }
        tokens = try await refreshTokens(refreshToken: refresh, clientID: clientID)
        try GoogleTokenStorage.save(tokens)
        return tokens.accessToken
    }

    func signOut() throws {
        try GoogleTokenStorage.clear()
    }

  var isSignedIn: Bool {
        (try? GoogleTokenStorage.load()) != nil
    }

    private func exchangeCode(_ code: String, clientID: String, redirect: String) async throws -> GoogleOAuthTokens {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirect,
            "grant_type": "authorization_code",
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let tokens = try await performTokenRequest(request)
        try GoogleTokenStorage.save(tokens)
        return tokens
    }

    private func refreshTokens(refreshToken: String, clientID: String) async throws -> GoogleOAuthTokens {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "refresh_token": refreshToken,
            "client_id": clientID,
            "grant_type": "refresh_token",
        ]
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        var tokens = try await performTokenRequest(request)
        if tokens.refreshToken == nil {
            tokens.refreshToken = refreshToken
        }
        return tokens
    }

    private func performTokenRequest(_ request: URLRequest) async throws -> GoogleOAuthTokens {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GoogleOAuthError.tokenExchangeFailed("無効な応答")
        }
        if http.statusCode >= 400 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw GoogleOAuthError.tokenExchangeFailed("HTTP \(http.statusCode): \(text)")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let access = json?["access_token"] as? String,
              let expiresIn = json?["expires_in"] as? Double else {
            throw GoogleOAuthError.tokenExchangeFailed("トークン JSON の解析に失敗")
        }
        let refresh = json?["refresh_token"] as? String
        return GoogleOAuthTokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
    }
}
