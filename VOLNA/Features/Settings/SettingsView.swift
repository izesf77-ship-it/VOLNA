import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Источники музыки") {
                    NavigationLink {
                        ProviderStatusView()
                    } label: {
                        Label("Музыкальные провайдеры", systemImage: "music.note.list")
                    }
                    
                    ProviderRow(
                        name: "Jamendo",
                        icon: "music.note",
                        isEnabled: true
                    )
                    
                    ProviderRow(
                        name: "Internet Archive",
                        icon: "archivebox.fill",
                        isEnabled: true
                    )
                    
                    ProviderRow(
                        name: "Wikimedia Commons",
                        icon: "book.fill",
                        isEnabled: true
                    )
                }
                
                Section("Воспроизведение") {
                    NavigationLink {
                        Text("Качество звука")
                    } label: {
                        Label("Качество звука", systemImage: "waveform")
                    }
                }
                
                Section("Хранилище") {
                    NavigationLink {
                        Text("Кэш")
                    } label: {
                        Label("Кэш", systemImage: "internaldrive")
                    }
                    
                    Button(role: .destructive) {
                        // TODO: Clear cache
                    } label: {
                        Label("Очистить кэш", systemImage: "trash")
                    }
                }
                
                Section("О приложении") {
                    LabeledContent("Версия", value: "0.2.0")
                    
                    NavigationLink {
                        Text("Лицензии")
                    } label: {
                        Label("Лицензии", systemImage: "doc.text")
                    }
                    
                    NavigationLink {
                        Text("Приватность")
                    } label: {
                        Label("Приватность", systemImage: "hand.raised")
                    }
                    
                    Link(destination: URL(string: "https://github.com/yourusername/VOLNA")!) {
                        Label("GitHub", systemImage: "link")
                    }
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProviderRow: View {
    let name: String
    let icon: String
    let isEnabled: Bool
    
    var body: some View {
        HStack {
            Label {
                Text(name)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(isEnabled ? .volnaPurple : .secondary)
            }
            
            Spacer()
            
            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.volnaSuccess)
            } else {
                Text("Скоро")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.volnaSurface)
                    .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    SettingsView()
}
