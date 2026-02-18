import Foundation

// MARK: - Spotify Service
// Handles all network calls to our backend API, which proxies Spotify Web API requests.
// The backend owns the Spotify access/refresh tokens — the app never stores them directly.
//
// ## Backend API Contract
//
// Authentication:
//   POST /api/spotify/auth/exchange     — Exchange OAuth code for tokens (backend stores them)
//   GET  /api/spotify/auth/status       — Check if current user has connected Spotify
//   POST /api/spotify/auth/disconnect   — Revoke Spotify connection
//
// Playlist:
//   GET  /api/trips/{tripId}/playlist          — Get playlist metadata + tracks (with "added by")
//   POST /api/trips/{tripId}/playlist/tracks   — Add a track to the trip playlist
//
// Search:
//   GET  /api/spotify/search?q={query}         — Search Spotify tracks (proxied through backend)

actor SpotifyService {
    static let shared = SpotifyService()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        // ASSUMPTION: Backend API base URL — replace with your actual backend URL.
        // In production this would come from a config or environment variable.
        #if DEBUG
        self.baseURL = "http://localhost:3000/api"
        #else
        self.baseURL = "https://your-heroku-app.herokuapp.com/api"  // Replace with Heroku URL after deploy
        #endif

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Auth

    /// Exchange the OAuth authorization code for tokens (backend stores tokens server-side)
    func exchangeAuthCode(_ code: String, redirectUri: String) async throws -> SpotifyAuthState {
        let body = SpotifyAuthExchangeRequest(code: code, redirectUri: redirectUri)
        let response: SpotifyAuthExchangeResponse = try await post(
            path: "/spotify/auth/exchange",
            body: body
        )
        guard response.success else {
            throw SpotifyError.authFailed
        }
        return response.authState
    }

    /// Check if the current user has a valid Spotify connection
    func fetchAuthStatus() async throws -> SpotifyAuthState {
        try await get(path: "/spotify/auth/status")
    }

    /// Disconnect Spotify account
    func disconnect() async throws {
        let _: EmptyResponse = try await post(path: "/spotify/auth/disconnect", body: EmptyBody())
    }

    // MARK: - Playlist

    /// Fetch the trip's shared playlist metadata and all tracks
    func fetchPlaylist(tripId: UUID) async throws -> PlaylistResponse {
        try await get(path: "/trips/\(tripId.uuidString)/playlist")
    }

    /// Add a track to the trip's shared playlist
    func addTrack(tripId: UUID, trackUri: String) async throws -> AddTrackResponse {
        let body = AddTrackRequest(trackUri: trackUri)
        return try await post(
            path: "/trips/\(tripId.uuidString)/playlist/tracks",
            body: body
        )
    }

    // MARK: - Search

    /// Search Spotify for tracks matching the query
    func searchTracks(query: String) async throws -> [SpotifyTrack] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let response: SearchResponse = try await get(path: "/spotify/search?q=\(encoded)")
        return response.tracks.items
    }

    // MARK: - Generic Network Helpers

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw SpotifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        addAuthHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(path: String, body: B) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw SpotifyError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        addAuthHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    /// Add user authentication headers.
    /// ASSUMPTION: Your backend uses a session cookie or bearer token for user identity.
    /// This is a placeholder — wire up your actual auth mechanism here.
    private func addAuthHeaders(to request: inout URLRequest) {
        // Example: request.setValue("Bearer \(userToken)", forHTTPHeaderField: "Authorization")
        // In a real app, pull from Keychain or a session manager
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyError.invalidResponse
        }
        switch http.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw SpotifyError.unauthorized
        case 404:
            throw SpotifyError.notFound
        case 429:
            throw SpotifyError.rateLimited
        default:
            throw SpotifyError.serverError(http.statusCode)
        }
    }
}

// MARK: - Error Types

enum SpotifyError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authFailed
    case unauthorized
    case notFound
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL."
        case .invalidResponse:
            return "Unexpected response from server."
        case .authFailed:
            return "Spotify authentication failed. Please try again."
        case .unauthorized:
            return "Your session has expired. Please reconnect Spotify."
        case .notFound:
            return "Playlist not found."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        }
    }
}

// MARK: - Empty Helpers (for POST requests with no meaningful body/response)

private nonisolated struct EmptyBody: Encodable, Sendable {}
private nonisolated struct EmptyResponse: Decodable, Sendable {}
