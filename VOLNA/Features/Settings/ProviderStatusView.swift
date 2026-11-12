import SwiftUI

struct ProviderStatusView: View {
    @Environment(AppState.self) private var appState
    @State private var providerStates: [ProviderState] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Проверка провайдеров...")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(providerStates) { state in
                        ProviderStatusRow(state: state)
                    }
                }
            } header: {
                Text("Музыкальные источники")
            } footer: {
                Text("VOLNA использует несколько открытых музыкальных каталогов для максимального покрытия")
            }
            
            Section {
                LabeledContent("Всего провайдеров", value: "\(providerStates.count)")
                LabeledContent("Активных", value: "\(providerStates.filter { $0.isAvailable }.count)")
                LabeledContent("Русский каталог", value: russianSupportText)
            } header: {
                Text("Статистика")
            }
        }
        .navigationTitle("Источники музыки")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await checkProviders()
        }
        .refreshable {
            await checkProviders()
        }
    }
    
    private var russianSupportText: String {
        let withRussian = providerStates.filter { $0.supportsRussian }.count
        return "\(withRussian) из \(providerStates.count)"
    }
    
    private func checkProviders() async {
        isLoading = true
        
        let providers = await appState.providerRegistry.allProviders
        
        var states: [ProviderState] = []
        
        for provider in providers {
            let providerID = await provider.id
            let providerName = await provider.name
            let capabilities = await provider.capabilities
            
            // Check if provider is available
            let isAvailable = await appState.providerRegistry.isAvailable(providerID: providerID)
            
            // Determine Russian support based on provider
            let supportsRussian = providerID == "internet_archive" || 
                                 providerID == "wikimedia_commons"
            
            states.append(ProviderState(
                id: providerID,
                name: providerName,
                isAvailable: isAvailable,
                supportsSearch: capabilities.supportsSearch,
                supportsStreaming: capabilities.supportsStreaming,
                supportsRussian: supportsRussian,
                requiresAuth: capabilities.requiresAuthentication
            ))
        }
        
        await MainActor.run {
            providerStates = states
            isLoading = false
        }
    }
}

struct ProviderStatusRow: View {
    let state: ProviderState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.name)
                    .font(.system(size: 17, weight: .semibold))
                
                Spacer()
                
                StatusBadge(isAvailable: state.isAvailable)
            }
            
            // Capabilities
            HStack(spacing: 12) {
                if state.supportsSearch {
                    CapabilityChip(icon: "magnifyingglass", text: "Поиск")
                }
                
                if state.supportsStreaming {
                    CapabilityChip(icon: "play.circle", text: "Воспр.")
                }
                
                if state.supportsRussian {
                    CapabilityChip(icon: "flag", text: "РУ", color: .volnaSuccess)
                }
                
                if state.requiresAuth {
                    CapabilityChip(icon: "key", text: "Авториз.", color: .volnaWarning)
                }
            }
            
            // Provider ID (for debugging)
            Text(state.id)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isAvailable ? Color.volnaSuccess : Color.volnaTextSecondary)
                .frame(width: 8, height: 8)
            
            Text(isAvailable ? "Активен" : "Неактивен")
                .font(.caption)
                .foregroundStyle(isAvailable ? .volnaSuccess : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.volnaSurface)
        .clipShape(Capsule())
    }
}

struct CapabilityChip: View {
    let icon: String
    let text: String
    var color: Color = .volnaTextSecondary
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.volnaSurface)
        .clipShape(Capsule())
    }
}

struct ProviderState: Identifiable {
    let id: String
    let name: String
    let isAvailable: Bool
    let supportsSearch: Bool
    let supportsStreaming: Bool
    let supportsRussian: Bool
    let requiresAuth: Bool
}

#Preview {
    NavigationStack {
        ProviderStatusView()
            .environment(AppState())
    }
}
