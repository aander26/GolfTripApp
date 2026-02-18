import SwiftUI

// MARK: - Track Search View
// Presented as a sheet from SpotifyPlaylistView.
// Provides debounced search with add-to-playlist functionality.

struct TrackSearchView: View {
    @Bindable var viewModel: SpotifyPlaylistViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Results
                if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                    emptySearchState
                } else if viewModel.searchResults.isEmpty {
                    initialSearchState
                } else {
                    searchResultsList
                }
            }
            .background(Theme.background)
            .navigationTitle("Add Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)

            TextField("Search songs, artists...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.onSearchQueryChanged()
                }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.border, lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Results List

    private var searchResultsList: some View {
        List {
            ForEach(viewModel.searchResults) { track in
                SearchTrackRow(
                    track: track,
                    isAdded: viewModel.isTrackInPlaylist(track.id),
                    isAdding: viewModel.addingTrackId == track.id,
                    onAdd: {
                        Task { await viewModel.addTrack(track) }
                    }
                )
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty States

    private var initialSearchState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("Search for songs to add")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textSecondary.opacity(0.5))
            Text("No results found")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Text("Try a different search term")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Search Track Row

struct SearchTrackRow: View {
    let track: SpotifyTrack
    let isAdded: Bool
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Album Art
            AsyncImage(url: track.artworkThumbnailURL) { phase in
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
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Track Info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                Text(track.artistNames)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)

                Text(track.album.name)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            // Add Button
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.success)
                    .accessibilityLabel("Already added")
            } else if isAdding {
                ProgressView()
                    .frame(width: 28, height: 28)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add \(track.name) to playlist")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    TrackSearchView(
        viewModel: SpotifyPlaylistViewModel(
            appState: SampleData.makeAppState()
        )
    )
}
