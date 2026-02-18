import Foundation
import SwiftUI

// MARK: - Spotify Playlist ViewModel
// Manages all state for the trip's collaborative Spotify playlist.
// Lives alongside the other War Room features — accessed from a card in the War Room.

@Observable
class SpotifyPlaylistViewModel {
    var appState: AppState
    let authManager: SpotifyAuthManager

    // MARK: - Playlist State
    var playlist: SpotifyPlaylist?
    var tracks: [PlaylistTrackEntry] = []
    var isLoadingPlaylist = false
    var playlistError: String?

    // MARK: - Search State
    var searchQuery = ""
    var searchResults: [SpotifyTrack] = []
    var isSearching = false
    var showingSearch = false

    // MARK: - Add Track State
    var addingTrackId: String?  // Track ID currently being added (for loading indicator)
    var recentlyAddedIds: Set<String> = []  // Track IDs added this session (for checkmark feedback)

    // MARK: - Debounce
    private var searchTask: Task<Void, Never>?
    private let searchDebounceSeconds: Double = 0.4

    init(appState: AppState, authManager: SpotifyAuthManager = SpotifyAuthManager()) {
        self.appState = appState
        self.authManager = authManager
    }

    // MARK: - Computed Properties

    var currentTrip: Trip? { appState.currentTrip }
    var isConnected: Bool { authManager.isConnected }
    var trackCount: Int { tracks.count }

    /// Whether we have a playlist loaded (even if empty)
    var hasPlaylist: Bool { playlist != nil }

    // MARK: - Load Playlist

    /// Fetch the trip's playlist and tracks from the backend
    func loadPlaylist() async {
        guard let tripId = currentTrip?.id else { return }
        guard !isLoadingPlaylist else { return }

        isLoadingPlaylist = true
        playlistError = nil

        do {
            let response = try await SpotifyService.shared.fetchPlaylist(tripId: tripId)
            await MainActor.run {
                self.playlist = response.playlist
                self.tracks = response.tracks
                self.isLoadingPlaylist = false
            }
        } catch {
            await MainActor.run {
                self.playlistError = error.localizedDescription
                self.isLoadingPlaylist = false
            }
        }
    }

    /// Pull-to-refresh handler
    func refresh() async {
        await loadPlaylist()
    }

    // MARK: - Search

    /// Called on every keystroke — debounces the actual API call
    func onSearchQueryChanged() {
        searchTask?.cancel()

        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .seconds(searchDebounceSeconds))
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        await MainActor.run { isSearching = true }

        do {
            let results = try await SpotifyService.shared.searchTracks(query: query)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.isSearching = false
            }
        }
    }

    // MARK: - Add Track

    /// Add a track to the trip's collaborative playlist
    func addTrack(_ track: SpotifyTrack) async {
        guard let tripId = currentTrip?.id else { return }

        await MainActor.run { addingTrackId = track.id }

        do {
            let response = try await SpotifyService.shared.addTrack(tripId: tripId, trackUri: track.uri)
            await MainActor.run {
                if response.success {
                    // Add to the local track list immediately for instant feedback
                    if let entry = response.track {
                        self.tracks.append(entry)
                    }
                    self.recentlyAddedIds.insert(track.id)
                }
                self.addingTrackId = nil
            }
        } catch {
            await MainActor.run {
                self.addingTrackId = nil
                self.playlistError = error.localizedDescription
            }
        }
    }

    /// Check if a track has already been added to the playlist
    func isTrackInPlaylist(_ trackId: String) -> Bool {
        tracks.contains { $0.track.id == trackId } || recentlyAddedIds.contains(trackId)
    }

    // MARK: - Open in Spotify

    /// Open the playlist in the Spotify app (or web as fallback)
    @MainActor
    func openInSpotify() {
        // Try deep link first (opens Spotify app directly)
        if let deepLink = playlist?.spotifyDeepLink,
           UIApplication.shared.canOpenURL(deepLink) {
            UIApplication.shared.open(deepLink)
            return
        }

        // Fall back to web URL
        if let webURL = playlist?.spotifyWebURL {
            UIApplication.shared.open(webURL)
        }
    }

    // MARK: - Auth Convenience

    /// Connect Spotify account
    func connectSpotify() async {
        await authManager.startAuthFlow()
        if authManager.isConnected {
            await loadPlaylist()
        }
    }

    /// Check auth status on appear
    func checkAuthStatus() async {
        await authManager.refreshAuthStatus()
    }
}
