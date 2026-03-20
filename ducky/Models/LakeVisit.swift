import Foundation
import SwiftData

@Model
final class LakeVisit {
    var lakeID: String
    var lakeName: String
    var visitedAt: Date
    /// Snapshot of air temperature at time of visit
    var airTemperature: Double?
    /// Snapshot of water temperature at time of visit
    var waterTemperature: Double?

    init(
        lakeID: String,
        lakeName: String,
        visitedAt: Date = Date(),
        airTemperature: Double? = nil,
        waterTemperature: Double? = nil
    ) {
        self.lakeID = lakeID
        self.lakeName = lakeName
        self.visitedAt = visitedAt
        self.airTemperature = airTemperature
        self.waterTemperature = waterTemperature
    }
}
