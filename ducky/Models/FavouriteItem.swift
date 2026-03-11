import Foundation
import SwiftData

@Model
final class FavouriteItem {
    var lakeID: String
    var lakeName: String
    var municipalityName: String?
    var lastKnownTemperature: Double?
    var lastKnownQuality: String?
    var notificationsEnabled: Bool
    var addedAt: Date

    init(
        lakeID: String,
        lakeName: String,
        municipalityName: String? = nil,
        lastKnownTemperature: Double? = nil,
        lastKnownQuality: String? = nil
    ) {
        self.lakeID = lakeID
        self.lakeName = lakeName
        self.municipalityName = municipalityName
        self.lastKnownTemperature = lastKnownTemperature
        self.lastKnownQuality = lastKnownQuality
        self.notificationsEnabled = false
        self.addedAt = Date()
    }
}
