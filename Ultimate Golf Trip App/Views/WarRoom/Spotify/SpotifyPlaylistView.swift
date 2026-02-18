import SwiftUI

// MARK: - Spotify Playlist View
// Full-screen view showing the trip's collaborative Spotify playlist.
// Accessed via NavigationLink from the War Room's Spotify card.

struct SpotifyPlaylistView: View {
    @Bindable var viewModel: SpotifyPlaylistViewModel

    var body: some View {
        Group {
            if !viewModel.isConnected {
                connectSpotifyView
            } else if viewModel.isLoadingPlaylist && !viewModel.hasPlaylist {
                ProgressView("Loading playlist...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let playlist = viewModel.playlist {
                playlistContent(playlist)
            } else if let error = viewModel.playlistError {
                errorView(error)
            } else {
                emptyPlaylistView
            }
        }
        .navigationTitle("Trip Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isConnected && viewModel.hasPlaylist {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingSearch = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add song")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSearch) {
            TrackSearchView(viewModel: viewModel)
        }
        .task {
            await viewModel.checkAuthStatus()
            if viewModel.isConnected {
                await viewModel.loadPlaylist()
            }
        }
    }

    // MARK: - Playlist Content

    private func playlistContent(_ playlist: SpotifyPlaylist) -> some View {
        List {
            // Playlist Header
            playlistHeader(playlist)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())

            // Tracks
            if viewModel.tracks.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.title)
                            .foregroundStyle(Theme.textSecondary)
                        Text("No songs yet")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                        Text("Tap + to add the first track")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(viewModel.tracks) { entry in
                        PlaylistTrackRow(entry: entry)
                    }
                } header: {
                    Text("\(viewModel.trackCount) song\(viewModel.trackCount == 1 ? "" : "s")")
                        .sectionHeader()
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Playlist Header

    private func playlistHeader(_ playlist: SpotifyPlaylist) -> some View {
        VStack(spacing: 16) {
            // Cover Art
            AsyncImage(url: playlist.coverImageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    playlistPlaceholderArt
                case .empty:
                    playlistPlaceholderArt
                        .overlay(ProgressView())
                @unknown default:
                    playlistPlaceholderArt
                }
            }
            .frame(width: 200, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

            // Playlist Name
            Text(playlist.name)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            // Open in Spotify Button
            Button {
                viewModel.openInSpotify()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                    Text("Open in Spotify")
                        .font(.subheadline.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(spotifyGreen)
                .clipShape(Capsule())
            }
            .accessibilityLabel("Open playlist in Spotify app")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal)
        .background(Theme.background)
    }

    private var playlistPlaceholderArt: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Theme.primaryMuted)
            .overlay {
                Image(systemName: "music.note.list")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary.opacity(0.5))
            }
    }

    // MARK: - Connect Spotify

    private var connectSpotifyView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundStyle(spotifyGreen)

            Text("Trip Playlist")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Connect your Spotify account to collaborate on the trip playlist with your group.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                Task { await viewModel.connectSpotify() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("Connect Spotify")
                }
            }
            .buttonStyle(SpotifyButtonStyle())
            .disabled(viewModel.authManager.isAuthenticating)

            if viewModel.authManager.isAuthenticating {
                ProgressView()
            }

            if let error = viewModel.authManager.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }

    // MARK: - Error / Empty States

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.warning)
            Text("Couldn't load playlist")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try Again") {
                Task { await viewModel.loadPlaylist() }
            }
            .buttonStyle(BoldSecondaryButtonStyle())
            Spacer()
        }
    }

    private var emptyPlaylistView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary)
            Text("No playlist yet")
                .font(.headline)
            Text("The trip playlist will be created when the trip starts.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
    }
}

// MARK: - Playlist Track Row

struct PlaylistTrackRow: View {
    let entry: PlaylistTrackEntry

    var body: some View {
        HStack(spacing: 12) {
            // Album Art
            AsyncImage(url: entry.track.artworkThumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.primaryMuted)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(entry.track.artistNames)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Added by
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.track.formattedDuration)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)

                Text(entry.addedBy.displayName)
                    .font(.caption2)
                    .foregroundStyle(Theme.primary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.track.name) by \(entry.track.artistNames), added by \(entry.addedBy.displayName)")
    }
}

// MARK: - Spotify Brand Color

/// Spotify's brand green — used only for Spotify-specific UI elements
private let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954

// MARK: - Spotify Button Style

struct SpotifyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(spotifyGreen)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SpotifyPlaylistView(
            viewModel: SpotifyPlaylistViewModel(
                appState: SampleData.makeAppState()
            )
        )
    }
}
