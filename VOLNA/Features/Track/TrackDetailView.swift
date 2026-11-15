import SwiftUI

/// Страница композиции с информацией, похожими треками и радиостанциями страны
struct TrackDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let track: Track
    
    @State private var similarTracks: [Track] = []
    @State private var countryStations: [RadioStation] = []
    @State private var isLoadingSimilar = false
    @State private var isLoadingStations = false
    @State private var errorMessage: String?
    
    private var player: PlayerService { appState.player }
    private var isCurrent: Bool {
        player.mode == .music && player.currentTrack?.id == track.id
    }
    
    var body: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 24) {
                header
                
                mainInfo
                
                if !similarTracks.isEmpty || isLoadingSimilar {
                    similarTracksSection
                }
                
                if !countryStations.isEmpty || isLoadingStations {
                    countryRadioSection
                }
            }
            .padding(.horizontal, VolnaLayout.horizontalPadding)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
        .volnaScreenLayout()
        .navigationTitle(track.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadSimilarTracks()
            await loadCountryStations()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            ZStack {
                ArtworkView(url: track.artworkURL, size: 132, cornerRadius: 22)
                    .shadow(color: Color.volnaPurple.opacity(0.26), radius: 22, y: 10)
                
                if isCurrent {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.black.opacity(0.5))
                        .frame(width: 132, height: 132)
                    Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.volnaDisplay(23))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(3)
                
                Text(track.artist)
                    .font(.volnaBody(14))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    ProviderBadge(providerID: track.providerID, compact: false)
                    
                    if let duration = track.durationFormatted {
                        Text(duration)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.volnaTextTertiary)
                    }
                }
                
                HStack(spacing: 8) {
                    Button {
                        appState.play(track, in: [track])
                    } label: {
                        Label(isCurrent ? "Слушаю" : "Слушать", systemImage: "play.fill")
                    }
                    .buttonStyle(VolnaPrimaryButtonStyle())
                    .disabled(isCurrent && player.isPlaying)
                    
                    Button {
                        _ = appState.toggleFavorite(track)
                    } label: {
                        Image(systemName: appState.library.isFavorite(track) ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                appState.library.isFavorite(track)
                                    ? Color.volnaMagenta
                                    : Color.volnaTextSecondary
                            )
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Main info
    
    private var mainInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("О композиции")
                    .font(VolnaFont.custom(16, weight: .semibold, relativeTo: .headline))
                    .foregroundStyle(Color.volnaTextPrimary)
                Spacer()
                ProviderBadge(providerID: track.providerID, compact: false)
            }
            
            SourceDetailRow(
                icon: "music.note",
                title: "Название",
                value: track.title,
                tint: .volnaPurple
            )
            
            SourceDetailRow(
                icon: "person.fill",
                title: "Исполнитель",
                value: track.artist,
                tint: .volnaBlue
            )
            
            if let album = track.album {
                SourceDetailRow(
                    icon: "square.stack",
                    title: "Альбом",
                    value: album,
                    tint: .volnaCyan
                )
            }
            
            if let duration = track.durationFormatted {
                SourceDetailRow(
                    icon: "timer",
                    title: "Длительность",
                    value: duration,
                    tint: .volnaMint
                )
            }
            
            if let page = track.sourcePageURL {
                Link(destination: page) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("Открыть на источнике")
                    }
                    .font(VolnaFont.custom(14, weight: .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.volnaBlue)
                }
            }
        }
        .volnaCard(cornerRadius: 20, padding: 16)
    }
    
    // MARK: - Similar tracks
    
    private var similarTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Похожая музыка")
            
            if isLoadingSimilar {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.volnaPurple)
                    Text("Ищем похожие композиции…")
                        .font(.volnaBody(13))
                        .foregroundStyle(Color.volnaTextSecondary)
                }
                .padding(.vertical, 18)
            } else if similarTracks.isEmpty {
                Text("Рекомендации недоступны")
                    .font(.volnaBody(13))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(similarTracks.prefix(10)) { similar in
                        TrackRow(
                            track: similar,
                            queue: similarTracks,
                            showArtwork: true,
                            showProvider: true
                        )
                        if similar.id != similarTracks.prefix(10).last?.id {
                            Divider()
                                .overlay(Color.white.opacity(0.055))
                                .padding(.leading, 62)
                        }
                    }
                }
                .volnaCard(cornerRadius: 20, padding: 8)
            }
        }
    }
    
    // MARK: - Country radio
    
    private var countryRadioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Радио этой страны")
            
            if isLoadingStations {
                HStack(spacing: 10) {
                    ProgressView().tint(Color.volnaPurple)
                    Text("Загружаем радиостанции…")
                        .font(.volnaBody(13))
                        .foregroundStyle(Color.volnaTextSecondary)
                }
                .padding(.vertical, 18)
            } else if countryStations.isEmpty {
                Text("Радиостанции не найдены")
                    .font(.volnaBody(13))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .padding(.vertical, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(countryStations.prefix(8)) { station in
                            RadioStationCard(station: station)
                                .frame(width: 160)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -VolnaLayout.horizontalPadding)
                .padding(.leading, VolnaLayout.horizontalPadding)
            }
        }
    }
    
    // MARK: - Loading
    
    private func loadSimilarTracks() async {
        guard let provider = appState.providerRegistry.provider(for: track.providerID) else {
            return
        }
        
        isLoadingSimilar = true
        defer { isLoadingSimilar = false }
        
        // Search by artist to find similar tracks
        if let results = try? await provider.search(query: track.artist, type: .track) {
            similarTracks = results.tracks
                .filter { $0.id != track.id } // exclude current track
                .prefix(15)
                .shuffled() // randomize for variety
                .map { $0 }
        }
    }
    
    private func loadCountryStations() async {
        // Extract country from track metadata or provider
        // For now, try to parse from track.artist or use a default approach
        let countryCode = await extractCountryCode()
        
        guard !countryCode.isEmpty else { return }
        
        isLoadingStations = true
        defer { isLoadingStations = false }
        
        do {
            let stations = try await appState.radio.fetchStations(filter: .country(countryCode, limit: 20))
            countryStations = stations
                .filter { $0.isPlayable }
                .shuffled()
                .prefix(8)
                .map { $0 }
        } catch {
            // Silent failure — country radio is optional
        }
    }
    
    private func extractCountryCode() async -> String {
        // Try to infer country from provider or artist metadata
        // This is a simple heuristic — could be enhanced with a metadata service
        
        // For Russian artists (Cyrillic), default to RU
        if track.artist.range(of: "[А-Яа-яЁё]", options: .regularExpression) != nil {
            return "RU"
        }
        
        // Otherwise use a common default or empty
        return ""
    }
}

// MARK: - Radio station card

private struct RadioStationCard: View {
    @Environment(AppState.self) private var appState
    let station: RadioStation
    
    var body: some View {
        Button {
            appState.player.playRadio(station)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ArtworkView(
                    url: station.favicon,
                    size: 160,
                    cornerRadius: 16,
                    placeholderIcon: "dot.radiowaves.left.and.right"
                )
                .frame(height: 160)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(station.displayName)
                        .font(.volnaBody(14, weight: .semibold))
                        .foregroundStyle(Color.volnaTextPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let genre = station.genreDisplay {
                        Text(genre)
                            .font(.volnaBody(11))
                            .foregroundStyle(Color.volnaTextSecondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        TrackDetailView(
            track: Track(
                id: "preview",
                title: "Test Track",
                artist: "Test Artist",
                album: "Test Album",
                artworkURL: nil,
                streamURL: URL(string: "https://example.com")!,
                duration: 180,
                providerID: "mock"
            )
        )
        .environment(AppState())
    }
}
