import Foundation

struct LakeWikipediaContent: Codable, Equatable, Sendable {
    let summary: String
    let pageTitle: String
    let pageURL: URL
}
