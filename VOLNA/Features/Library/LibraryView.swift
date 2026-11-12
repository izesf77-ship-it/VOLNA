import SwiftUI

struct LibraryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    LibraryCard(
                        icon: "heart.fill",
                        title: "Избранное",
                        subtitle: "Ваши любимые треки",
                        gradient: [.volnaMagenta, .volnaPurple]
                    )
                    
                    LibraryCard(
                        icon: "music.note.list",
                        title: "Плейлисты",
                        subtitle: "Созданные вами",
                        gradient: [.volnaBlue, .volnaCyan]
                    )
                    
                    LibraryCard(
                        icon: "clock.fill",
                        title: "История",
                        subtitle: "Недавно прослушанное",
                        gradient: [.volnaPurple, .volnaBlue]
                    )
                    
                    LibraryCard(
                        icon: "square.stack.fill",
                        title: "Альбомы",
                        subtitle: "Сохранённые альбомы",
                        gradient: [.volnaCyan, .volnaBlue]
                    )
                    
                    LibraryCard(
                        icon: "person.fill",
                        title: "Исполнители",
                        subtitle: "Избранные артисты",
                        gradient: [.volnaMagenta, .volnaPurple]
                    )
                    
                    Spacer(minLength: 80)
                }
                .padding()
            }
            .background(Color.volnaBackground.ignoresSafeArea())
            .navigationTitle("Медиатека")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct LibraryCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
    
    var body: some View {
        Button {
            // TODO: Navigate to section
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.volnaSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
}
