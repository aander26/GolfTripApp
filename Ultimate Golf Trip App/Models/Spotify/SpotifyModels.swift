import Foundation

// MARK: - Spotify API Response Models
// These are Codable structs for JSON mapping — NOT SwiftData models.
// Spotify data lives on the backend + Spotify's servers; we only cache in memory.
// All structs are nonisolated + Sendable so they can be decoded inside the SpotifyService actor.

/// Represents a Spotify track from the Web API
nonisolated struct SpotifyTrack: Identifiable, Codable, Hashable, Sendable {
    let id: String              // Spotify track ID (e.g. "4iV5W9uYEdYUVa79Axb7Rh")
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let durationMs: Int
    let uri: String             // "spotify:track:4iV5W9uYEdYUVa79Axb7Rh"
    let externalUrls: SpotifyExternalUrls?

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, uri
        case durationMs = "duration_ms"
        case externalUrls = "external_urls"
    }

    /// Human-readable duration (e.g. "3:42")
    var formattedDuration: String {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    /// Comma-separated artist names
    var artistNames: String {
        artists.map(\.name).joined(separator: ", ")
    }

    /// Largest available album image URL
    var artworkURL: URL? {
        guard let urlString = album.images.first?.url else { return nil }
        return URL(string: urlString)
    }

    /// Small (64px) album image for lists
    var artworkThumbnailURL: URL? {
        guard let urlString = album.images.last?.url else { return nil }
        return URL(string: urlString)
    }
}

nonisolated struct SpotifyArtist: Codable, Hashable, Sendable {
    let id: String
    let name: String
}

nonisolated struct SpotifyAlbum: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let images: [SpotifyImage]
}

nonisolated struct SpotifyImage: Codable, Hashable, Sendable {
    let url: String
    let height: Int?
    let width: Int?
}

nonisolated struct SpotifyExternalUrls: Codable, Hashable, Sendable {
    let spotify: String?
}

// MARK: - Playlist Models

/// Playlist metadata from our backend (enriched with Spotify data)
nonisolated struct SpotifyPlaylist: Codable, Sendable {
    let id: String              // Spotify playlist ID
    let name: String
    let description: String?
    let images: [SpotifyImage]
    let externalUrls: SpotifyExternalUrls?
    let trackCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description, images
        case externalUrls = "external_urls"
        case trackCount = "track_count"
    }

    /// Cover image URL (largest available)
    var coverImageURL: URL? {
        guard let urlString = images.first?.url else { return nil }
        return URL(string: urlString)
    }

    /// Deep link to open in Spotify app
    var spotifyDeepLink: URL? {
        URL(string: "spotify:playlist:\(id)")
    }

    /// Web fallback URL
    var spotifyWebURL: URL? {
        guard let urlString = externalUrls?.spotify else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Playlist Track (with "added by" info from our backend)

/// A track in the trip playlist, enriched with who added it
nonisolated struct PlaylistTrackEntry: Identifiable, Codable, Sendable {
    let track: SpotifyTrack
    let addedBy: TrackAddedBy
    let addedAt: Date

    // Use track ID + addedAt for uniqueness (same track could theoretically be added twice)
    var id: String { "\(track.id)-\(addedAt.timeIntervalSince1970)" }

    enum CodingKeys: String, CodingKey {
        case track
        case addedBy = "added_by"
        case addedAt = "added_at"
    }
}

/// Lightweight user info for "added by" display
nonisolated struct TrackAddedBy: Codable, Sendable {
    let userId: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case displayName = "display_name"
    }
}

// MARK: - Auth State

/// Tracks whether the current user has connected Spotify
nonisolated struct SpotifyAuthState: Codable, Sendable {
    let isConnected: Bool
    let displayName: String?
    let spotifyUserId: String?

    enum CodingKeys: String, CodingKey {
        case isConnected = "is_connected"
        case displayName = "display_name"
        case spotifyUserId = "spotify_user_id"
    }

    static let disconnected = SpotifyAuthState(isConnected: false, displayName: nil, spotifyUserId: nil)
}

// MARK: - Backend API Response Wrappers

/// GET /api/trips/{tripId}/playlist
nonisolated struct PlaylistResponse: Codable, Sendable {
    let playlist: SpotifyPlaylist
    let tracks: [PlaylistTrackEntry]
}

/// POST /api/trips/{tripId}/playlist/tracks — request
nonisolated struct AddTrackRequest: Codable, Sendable {
    let trackUri: String

    enum CodingKeys: String, CodingKey {
        case trackUri = "track_uri"
    }
}

/// POST /api/trips/{tripId}/playlist/tracks — response
nonisolated struct AddTrackResponse: Codable, Sendable {
    let success: Bool
    let track: PlaylistTrackEntry?
}

/// GET /api/spotify/search?q={query}
nonisolated struct SearchResponse: Codable, Sendable {
    let tracks: SpotifySearchTracks
}

nonisolated struct SpotifySearchTracks: Codable, Sendable {
    let items: [SpotifyTrack]
}

/// POST /api/spotify/auth/exchange — request
nonisolated struct SpotifyAuthExchangeRequest: Codable, Sendable {
    let code: String
    let redirectUri: String

    enum CodingKeys: String, CodingKey {
        case code
        case redirectUri = "redirect_uri"
    }
}

/// POST /api/spotify/auth/exchange — response
nonisolated struct SpotifyAuthExchangeResponse: Codable, Sendable {
    let success: Bool
    let authState: SpotifyAuthState

    enum CodingKeys: String, CodingKey {
        case success
        case authState = "auth_state"
    }
}
