import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Header
                    welcomeSection
                    
                    // Continue Listening
                    continueListeningSection
                    
                    // Quick Access
                    quickAccessSection
                    
                    Spacer(minLength: 80) // Space for mini player
                }
                .padding()
            }
            .background(Color.volnaBackground.ignoresSafeArea())
            .navigationTitle("VOLNA")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Привет!")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
            
            Text("Откройте мир свободной музыки")
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
        }
    }
    
    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Продолжить прослушивание")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            if let currentTrack = appState.playerService.currentTrack {
                TrackCard(track: currentTrack)
            } else {
                EmptyStateView(
                    icon: "music.note",
                    title: "Начните слушать",
                    message: "Ваша музыка появится здесь"
                )
            }
        }
    }
    
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Быстрый доступ")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 16
            ) {
                QuickAccessCard(
                    icon: "magnifyingglass",
                    title: "Поиск музыки",
                    gradient: [.volnaPurple, .volnaBlue]
                ) {
                    appState.selectedTab = .search
                }
                
                QuickAccessCard(
                    icon: "heart.fill",
                    title: "Избранное",
                    gradient: [.volnaMagenta, .volnaPurple]
                ) {
                    appState.selectedTab = .library
                }
                
                QuickAccessCard(
                    icon: "music.note.list",
                    title: "Плейлисты",
                    gradient: [.volnaBlue, .volnaCyan]
                ) {
                    appState.selectedTab = .library
                }
                
                QuickAccessCard(
                    icon: "clock.fill",
                    title: "История",
                    gradient: [.volnaPurple, .volnaMagenta]
                ) {
                    appState.selectedTab = .library
                }
            }
        }
    }
}

struct TrackCard: View {
    let track: Track
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork
            AsyncImage(url: track.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.volnaSurface)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play button
            Button {
                // TODO: Play track
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.volnaPurple)
            }
        }
        .padding()
        .background(Color.volnaSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct QuickAccessCard: View {
    let icon: String
    let title: String
    let gradient: [Color]
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
