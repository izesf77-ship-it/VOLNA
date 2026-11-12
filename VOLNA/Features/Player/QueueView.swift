import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var confirmClear = false

    private var player: PlayerService { appState.player }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    if player.queue.isEmpty {
                        EmptyStateView(
                            icon: "list.bullet",
                            title: "Очередь пуста",
                            message: "Выберите трек, и он появится здесь."
                        )
                        .padding(.top, 20)
                    } else {
                        if let current = player.currentTrack {
                            currentCard(current)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Очередь · \(player.queue.count)")
                                .font(.volnaHeadline(16))
                                .foregroundStyle(Color.volnaTextPrimary)

                            VStack(spacing: 0) {
                                ForEach(player.queue.indices, id: \.self) { index in
                                    queueRow(track: player.queue[index], index: index)
                                    if index < player.queue.count - 1 {
                                        Divider()
                                            .overlay(Color.white.opacity(0.05))
                                            .padding(.leading, 38)
                                    }
                                }
                            }
                            .volnaCard(cornerRadius: 18, padding: 7)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(VolnaBackground())
            .navigationTitle("Очередь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.volnaBackground.opacity(0.94), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !player.queue.isEmpty {
                        Button("Очистить") { confirmClear = true }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.volnaError)
                    }
                }
            }
            .confirmationDialog(
                "Очистить очередь?",
                isPresented: $confirmClear,
                titleVisibility: .visible
            ) {
                Button("Очистить", role: .destructive) {
                    player.clearQueue()
                    dismiss()
                }
                Button("Отмена", role: .cancel) {}
            }
        }
    }

    private func currentCard(_ track: Track) -> some View {
        HStack(spacing: 14) {
            ArtworkView(url: track.artworkURL, size: 58, cornerRadius: 14)
            VStack(alignment: .leading, spacing: 4) {
                Text("СЕЙЧАС ИГРАЕТ")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color.volnaPurple)
                Text(track.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Color.volnaAccentGradient)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func queueRow(track: Track, index: Int) -> some View {
        let isCurrent = track.id == player.currentTrack?.id
        return HStack(spacing: 10) {
            Button {
                appState.play(track, in: player.queue)
            } label: {
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextTertiary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 12, weight: isCurrent ? .bold : .semibold, design: .rounded))
                            .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.volnaTextTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if isCurrent {
                        Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.volnaPurple)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                player.removeFromQueue(id: track.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .frame(width: 28, height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
    }
}
