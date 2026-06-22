import Foundation

struct DiscoveryContext: Codable, Equatable {
    var prompt: String?
    var selectedPills: [Pill] = []
    var dislikedTrackIDs: [String] = []
    var favoriteTrackIDs: [String] = []
    var recentlyPlayedTrackIDs: [String] = []
    var offlineTrackIDs: Set<String>?
}
