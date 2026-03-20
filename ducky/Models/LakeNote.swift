import Foundation
import SwiftData

@Model
final class LakeNote {
    var lakeID: String
    var lakeName: String
    var noteText: String
    var createdAt: Date
    var updatedAt: Date

    init(
        lakeID: String,
        lakeName: String,
        noteText: String = ""
    ) {
        self.lakeID = lakeID
        self.lakeName = lakeName
        self.noteText = noteText
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
