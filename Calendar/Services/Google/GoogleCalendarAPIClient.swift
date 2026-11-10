import Foundation

enum GoogleAPIError: LocalizedError {
    case http(Int, String)
    case fullSyncRequired
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): "Google API \(code): \(body)"
        case .fullSyncRequired: "同期トークンが無効です。フル同期します。"
        case .decoding(let msg): msg
        }
    }
}

struct GoogleCalendarAPIClient {
    private let baseURL = URL(string: "https://www.googleapis.com/calendar/v3")!

    /// `ja.japanese#holiday@group...` の `#` / `@` を含む ID をパスに安全に載せる。
    private func percentEncodedCalendarID(_ calendarId: String) -> String {
        calendarId
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "#", with: "%23")
            .replacingOccurrences(of: "@", with: "%40")
    }

    private func calendarEventsURL(calendarId: String) -> URL {
        let encoded = percentEncodedCalendarID(calendarId)
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.percentEncodedPath = "\(baseURL.path)/calendars/\(encoded)/events"
        return components.url!
    }

    private func calendarInsertEventURL(calendarId: String) -> URL {
        let encoded = percentEncodedCalendarID(calendarId)
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.percentEncodedPath = "\(baseURL.path)/calendars/\(encoded)/events"
        return components.url!
    }

    func calendarList(accessToken: String) async throws -> [GCalendarListEntry] {
        var items: [GCalendarListEntry] = []
        var pageToken: String?
        repeat {
            var components = URLComponents(url: baseURL.appendingPathComponent("users/me/calendarList"), resolvingAgainstBaseURL: false)!
            var query = [URLQueryItem(name: "maxResults", value: "250")]
            if let pageToken { query.append(URLQueryItem(name: "pageToken", value: pageToken)) }
            components.queryItems = query
            let response: GCalendarListResponse = try await get(components.url!, accessToken: accessToken)
            items.append(contentsOf: response.items ?? [])
            pageToken = nil // API returns nextPageToken in raw - extend if needed; list rarely paginates for personal
            break
        } while pageToken != nil
        return items
    }

    func events(
        calendarId: String,
        accessToken: String,
        syncToken: String?
    ) async throws -> (events: [GCalendarEvent], nextSyncToken: String?) {
        try await events(
            calendarId: calendarId,
            accessToken: accessToken,
            syncToken: syncToken,
            timeMin: nil,
            timeMax: nil,
            pageToken: nil
        )
    }

    /// 期間指定の一覧（初回・月追撃）。`syncToken` と併用しない。
    func events(
        calendarId: String,
        accessToken: String,
        timeMin: Date,
        timeMax: Date
    ) async throws -> (events: [GCalendarEvent], nextSyncToken: String?) {
        try await events(
            calendarId: calendarId,
            accessToken: accessToken,
            syncToken: nil,
            timeMin: timeMin,
            timeMax: timeMax,
            pageToken: nil
        )
    }

    private func events(
        calendarId: String,
        accessToken: String,
        syncToken: String?,
        timeMin: Date?,
        timeMax: Date?,
        pageToken: String?
    ) async throws -> (events: [GCalendarEvent], nextSyncToken: String?) {
        var components = URLComponents(url: calendarEventsURL(calendarId: calendarId), resolvingAgainstBaseURL: false)!

        var query: [URLQueryItem] = [
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "maxResults", value: "2500"),
        ]
        if let syncToken {
            query.append(URLQueryItem(name: "syncToken", value: syncToken))
        } else {
            guard let timeMin, let timeMax else {
                throw GoogleAPIError.decoding("timeMin と timeMax が必要です。")
            }
            let formatter = ISO8601DateFormatter()
            query.append(URLQueryItem(name: "timeMin", value: formatter.string(from: timeMin)))
            query.append(URLQueryItem(name: "timeMax", value: formatter.string(from: timeMax)))
        }
        if let pageToken {
            query.append(URLQueryItem(name: "pageToken", value: pageToken))
        }
        components.queryItems = query

        do {
            var all: [GCalendarEvent] = []
            var token = pageToken
            var nextSync: String?
            repeat {
                if token != pageToken {
                    components.queryItems = query.filter { $0.name != "pageToken" }
                    if let token { components.queryItems?.append(URLQueryItem(name: "pageToken", value: token)) }
                }
                let response: GEventsListResponse = try await get(components.url!, accessToken: accessToken)
                all.append(contentsOf: response.items ?? [])
                token = response.nextPageToken
                nextSync = response.nextSyncToken ?? nextSync
                if token == nil { break }
            } while true
            return (all, nextSync)
        } catch let GoogleAPIError.http(410, _) {
            throw GoogleAPIError.fullSyncRequired
        }
    }

    func insertEvent(calendarId: String, body: GCalendarEventInsertBody, accessToken: String) async throws -> GCalendarEvent {
        try await post(calendarInsertEventURL(calendarId: calendarId), body: body, accessToken: accessToken)
    }

    func patchEvent(
        calendarId: String,
        eventId: String,
        body: GCalendarEventInsertBody,
        accessToken: String
    ) async throws -> GCalendarEvent {
        try await patch(calendarEventInstanceURL(calendarId: calendarId, eventId: eventId), body: body, accessToken: accessToken)
    }

    func deleteEvent(calendarId: String, eventId: String, accessToken: String) async throws {
        try await delete(calendarEventInstanceURL(calendarId: calendarId, eventId: eventId), accessToken: accessToken)
    }

    private func calendarEventInstanceURL(calendarId: String, eventId: String) -> URL {
        let cal = percentEncodedCalendarID(calendarId)
        let ev = percentEncodedCalendarID(eventId)
        var components = URLComponents()
        components.scheme = baseURL.scheme
        components.host = baseURL.host
        components.percentEncodedPath = "\(baseURL.path)/calendars/\(cal)/events/\(ev)"
        return components.url!
    }

    private func get<T: Decodable>(_ url: URL, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GoogleAPIError.decoding(error.localizedDescription)
        }
    }

    private func patch<T: Decodable, B: Encodable>(_ url: URL, body: B, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func delete(_ url: URL, accessToken: String) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
    }

    private func post<T: Decodable, B: Encodable>(_ url: URL, body: B, accessToken: String) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 410 {
            throw GoogleAPIError.http(410, String(data: data, encoding: .utf8) ?? "")
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GoogleAPIError.http(http.statusCode, body)
        }
    }
}
