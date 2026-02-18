import SwiftUI

// MARK: - Spotify War Room Card
// A compact card displayed in the War Room between weather and polls.
// Shows playlist status and navigates to the full SpotifyPlaylistView.

struct SpotifyWarRoomCard: View {
    @Bindable var viewModel: SpotifyPlaylistViewModel

    var body: some View {
        NavigationLink {
            SpotifyPlaylistView(viewModel: viewModel)
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .task {
            await viewModel.checkAuthStatus()
            if viewModel.isConnected && !viewModel.hasPlaylist {
                await viewModel.loadPlaylist()
            }
        }
    }

    @ViewBuilder
    private var cardContent: some View {
        if viewModel.isConnected, let playlist = viewModel.playlist {
            // Connected with playlist — show playlist summary
            connectedCard(playlist)
        } else if viewModel.isConnected {
            // Connected but loading / no playlist yet
            loadingCard
        } else {
            // Not connected — show connect prompt
            disconnectedCard
        }
    }

    // MARK: - Connected Card (has playlist)

    private func connectedCard(_ playlist: SpotifyPlaylist) -> some View {
        HStack(spacing: 14) {
            // Mini album art
            AsyncImage(url: playlist.coverImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(spotifyGreen.opacity(0.15))
                        .overlay {
                            Image(systemName: "music.note.list")
                                .font(.title3)
                                .foregroundStyle(spotifyGreen.opacity(0.5))
                        }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.caption2)
                        .foregroundStyle(spotifyGreen)
                    Text("Trip Playlist")
                        .font(.caption.bold())
                        .foregroundStyle(spotifyGreen)
                }

                Text(playlist.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text("\(viewModel.trackCount) song\(viewModel.trackCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .cardStyle(padded: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trip playlist: \(playlist.name), \(viewModel.trackCount) songs")
        .accessibilityHint("Tap to view and add songs")
    }

    // MARK: - Loading Card

    private var loadingCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(spotifyGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Trip Playlist")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Loading...")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            ProgressView()
        }
        .padding()
        .cardStyle(padded: false)
    }

    // MARK: - Disconnected Card

    private var disconnectedCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.title2)
                .foregroundStyle(spotifyGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("Trip Playlist")
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("Connect Spotify to collaborate")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
        }
        .padding()
        .cardStyle(padded: false)
        .accessibilityLabel("Trip Playlist")
        .accessibilityHint("Tap to connect Spotify and start the trip playlist")
    }
}

/// Spotify's brand green — used for Spotify-branded UI elements only
private let spotifyGreen = Color(red: 0.114, green: 0.725, blue: 0.329) // #1DB954

// MARK: - Preview

#Preview("Connected") {
    NavigationStack {
        SpotifyWarRoomCard(
            viewModel: SpotifyPlaylistViewModel(
                appState: SampleData.makeAppState()
            )
        )
        .padding()
    }
}

#Preview("Disconnected") {
    NavigationStack {
        SpotifyWarRoomCard(
            viewModel: SpotifyPlaylistViewModel(
                appState: SampleData.makeAppState()
            )
        )
        .padding()
    }
}
