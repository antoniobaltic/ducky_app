import SwiftUI

// MARK: - Recent Lakes

struct RecentLake: Codable, Identifiable {
    let id: String
    let name: String

    private static let storageKey = "recentLakes"
    private static let maxCount = 5

    static func load() -> [RecentLake] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([RecentLake].self, from: data)
        else { return [] }
        return items
    }

    static func add(_ lake: RecentLake) {
        var recents = load().filter { $0.id != lake.id }
        recents.insert(lake, at: 0)
        if recents.count > maxCount { recents = Array(recents.prefix(maxCount)) }
        if let data = try? JSONEncoder().encode(recents) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
