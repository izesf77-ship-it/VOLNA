import SwiftUI

struct QueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var confirmClear = false

    private var player: PlayerService { appState.player }

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    VStack {
                        Spacer()
                        EmptyStateView(
                            icon: "list.bullet",
                            title: "Очередь пуста",
                            message: "Выберите трек, и он появится здесь."
                        )
                        .padding(.horizontal, 20)
                        Spacer()
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            if let current = player.currentTrack {
                                currentCard(current)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Далее · \(player.queue.count)")
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                                    .foregroundStyle(Color.volnaTextPrimary)

                                VStack(spacing: 0) {
                                    ForEach(player.queue.indices, id: \.self) { index in
                                        queueRow(track: player.queue[index], index: index)
                                        if index < player.queue.count - 1 {
                                            Divider()
                                                .overlay(Color.volnaSeparator)
                                                .padding(.leading, 44)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                                .volnaCard(cornerRadius: 18, padding: 8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(VolnaBackground())
            .navigationTitle("Очередь")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.volnaBackground.opacity(0.96), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Закрыть") { dismiss() }
                        .font(.system(size: 15, weight: .medium, design: .default))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !player.queue.isEmpty {
                        Button("Очистить") { confirmClear = true }
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(Color.volnaError)
                    }
                }
            }
            .confirmationDialog("Очистить очередь?", isPresented: $confirmClear, titleVisibility: .visible) {
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
            ArtworkView(url: track.artworkURL, size: 60, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text("СЕЙЧАС ИГРАЕТ")
                    .font(.system(size: 10, weight: .semibold, design: .default))
                    .tracking(1.0)
                    .foregroundStyle(Color.volnaPurple)
                Text(track.title)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(Color.volnaTextPrimary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundStyle(Color.volnaTextSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.volnaAccentGradient, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .volnaCard(cornerRadius: 20, padding: 0)
    }

    private func queueRow(track: Track, index: Int) -> some View {
        let isCurrent = track.id == player.currentTrack?.id
        return HStack(spacing: 12) {
            Button { appState.play(track, in: player.queue) } label: {
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextTertiary)
                        .frame(width: 20, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 15, weight: isCurrent ? .semibold : .medium, design: .default))
                            .foregroundStyle(isCurrent ? Color.volnaPurple : Color.volnaTextPrimary)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundStyle(Color.volnaTextSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if isCurrent {
                        Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.volnaPurple)
                            .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { player.removeFromQueue(id: track.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.volnaTextTertiary)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}
