import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var searchResults: CombinedSearchResult?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.volnaBackground.ignoresSafeArea()
                
                if searchQuery.isEmpty {
                    searchPlaceholder
                } else if isSearching {
                    loadingView
                } else if let results = searchResults {
                    resultsView(results)
                }
            }
            .navigationTitle("Поиск")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $searchQuery,
                prompt: "Исполнители, песни, альбомы"
            )
            .onChange(of: searchQuery) { _, newValue in
                Task {
                    await performSearch(newValue)
                }
            }
        }
    }
    
    private var searchPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Найдите свою музыку")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("Поиск по тысячам треков из открытых источников")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    private var loadingView: Some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.volnaPurple)
            
            Text("Поиск...")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }
    
    private func resultsView(_ results: CombinedSearchResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if results.isEmpty {
                    EmptyStateView(
                        icon: "music.note.slash",
                        title: "Ничего не найдено",
                        message: "Попробуйте изменить запрос"
                    )
                } else {
                    // Results summary
                    Text("\(results.totalResults) результатов")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    // Tracks
                    if !results.tracks.isEmpty {
                        resultSection(
                            title: "Треки",
                            count: results.tracks.count
                        ) {
                            ForEach(results.tracks) { track in
                                TrackRow(track: track)
                            }
                        }
                    }
                    
                    // Albums
                    if !results.albums.isEmpty {
                        resultSection(
                            title: "Альбомы",
                            count: results.albums.count
                        ) {
                            ForEach(results.albums) { album in
                                AlbumRow(album: album)
                            }
                        }
                    }
                    
                    // Artists
                    if !results.artists.isEmpty {
                        resultSection(
                            title: "Исполнители",
                            count: results.artists.count
                        ) {
                            ForEach(results.artists) { artist in
                                ArtistRow(artist: artist)
                            }
                        }
                    }
                }
                
                Spacer(minLength: 80)
            }
            .padding(.vertical)
        }
    }
    
    private func resultSection<Content: View>(
        title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                
                Text("\(count)")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            content()
        }
    }
    
    private func performSearch(_ query: String) async {
        guard !query.isEmpty else {
            searchResults = nil
            return
        }
        
        isSearching = true
        
        do {
            // Add debounce delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            let results = try await appState.searchService.search(query: query)
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        } catch {
            print("❌ Search error: \(error)")
            await MainActor.run {
                isSearching = false
            }
        }
    }
}

struct TrackRow: View {
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: track.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.volnaSurface)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(track.artist)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    if track.explicit {
                        Text("E")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.volnaTextSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
            }
            
            Spacer()
            
            if let duration = track.durationFormatted {
                Text(duration)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct AlbumRow: View {
    let album: Album
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: album.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.volnaSurface)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(album.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                if let year = album.releaseYear {
                    Text(year)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

struct ArtistRow: View {
    let artist: Artist
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: artist.artworkURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.volnaSurface)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            Text(artist.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

#Preview {
    SearchView()
        .environment(AppState())
}
