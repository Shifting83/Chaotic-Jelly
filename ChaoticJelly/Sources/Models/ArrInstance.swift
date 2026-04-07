import Foundation

/// A configured Sonarr or Radarr instance.
struct ArrInstance: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var name: String
    var type: ArrType
    var url: String
    var apiKey: String
    var isEnabled: Bool

    init(name: String = "", type: ArrType = .sonarr, url: String = "", apiKey: String = "", isEnabled: Bool = true) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.url = url
        self.apiKey = apiKey
        self.isEnabled = isEnabled
    }

    var baseURL: String {
        url.trimmingCharacters(in: .init(charactersIn: "/"))
    }
}

enum ArrType: String, Codable, CaseIterable, Sendable {
    case sonarr
    case radarr

    var displayName: String {
        switch self {
        case .sonarr: return "Sonarr"
        case .radarr: return "Radarr"
        }
    }

    var systemImage: String {
        switch self {
        case .sonarr: return "tv"
        case .radarr: return "film"
        }
    }
}
