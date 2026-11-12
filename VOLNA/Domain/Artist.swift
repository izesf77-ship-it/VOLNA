import Foundation

/// Исполнитель
struct Artist: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let artworkURL: URL?
    let biography: String?
    let providerID: String
    
    init(
        id: String,
        name: String,
        artworkURL: URL? = nil,
        biography: String? = nil,
        providerID: String
    ) {
        self.id = id
        self.name = name
        self.artworkURL = artworkURL
        self.biography = biography
        self.providerID = providerID
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id
    }
}
