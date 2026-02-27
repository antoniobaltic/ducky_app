import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LakeContentService {
    var wikipediaCache: [String: LakeWikipediaContent] = [:]
    var cacheRevision = 0

    static let shared = LakeContentService()

    private let cacheTTL: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    private var diskEntries: [String: DiskEntry] = [:]
    private var inFlightFetches: [String: Task<LakeWikipediaContent?, Never>] = [:]
    private var saveTask: Task<Void, Never>?

    private init() {
        loadDiskCache()
    }

    func fetchWikipediaContent(for lake: BathingWater, forceRefresh: Bool = false) async -> LakeWikipediaContent? {
        if !forceRefresh, let entry = diskEntries[lake.id], isFresh(entry) {
            if let cached = entry.content {
                wikipediaCache[lake.id] = cached
            }
            return entry.content
        }

        if let inFlight = inFlightFetches[lake.id] {
            return await inFlight.value
        }

        let lakeInput = LakeInput(
            name: lake.name,
            latitude: lake.latitude,
            longitude: lake.longitude
        )
        let task = Task { await Self.resolveConfidentContent(for: lakeInput) }
        inFlightFetches[lake.id] = task
        defer { inFlightFetches[lake.id] = nil }

        let content = await task.value
        let entry = DiskEntry(timestamp: Date().timeIntervalSinceReferenceDate, content: content)
        diskEntries[lake.id] = entry

        if let content {
            wikipediaCache[lake.id] = content
        } else {
            wikipediaCache.removeValue(forKey: lake.id)
        }

        cacheRevision &+= 1
        scheduleSave()
        return content
    }

    private func isFresh(_ entry: DiskEntry) -> Bool {
        Date().timeIntervalSinceReferenceDate - entry.timestamp < cacheTTL
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.saveDiskCache()
        }
    }

    private func saveDiskCache() {
        guard let data = try? JSONEncoder().encode(diskEntries) else { return }
        try? data.write(to: Self.cacheFileURL, options: .atomic)
    }

    private func loadDiskCache() {
        guard let data = try? Data(contentsOf: Self.cacheFileURL),
              let decoded = try? JSONDecoder().decode([String: DiskEntry].self, from: data)
        else { return }

        let now = Date().timeIntervalSinceReferenceDate
        diskEntries = decoded.filter { now - $0.value.timestamp < cacheTTL }
        wikipediaCache = diskEntries.compactMapValues(\.content)
        cacheRevision &+= 1
    }

    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("wikipedia_content_cache_v1.json")
    }
}

// MARK: - Resolver (nonisolated)

extension LakeContentService {
    private struct DiskEntry: Codable {
        let timestamp: TimeInterval
        let content: LakeWikipediaContent?
    }

    private struct WikiPage {
        let title: String
        let extract: String
        let url: URL
        let coordinate: CLLocationCoordinate2D?
        let isDisambiguation: Bool
    }

    private struct LakeInput: Sendable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    nonisolated private static func resolveConfidentContent(for lake: LakeInput) async -> LakeWikipediaContent? {
        for candidateTitle in titleCandidates(for: lake.name) {
            guard let page = await fetchWikipediaPage(title: candidateTitle) else { continue }
            guard isConfidentMatch(lake: lake, page: page) else { continue }

            let summary = summarized(extract: page.extract)
            guard summary.count >= 70 else { continue }

            return LakeWikipediaContent(
                summary: summary,
                pageTitle: page.title,
                pageURL: page.url
            )
        }
        return nil
    }

    nonisolated private static func titleCandidates(for lakeName: String) -> [String] {
        let fullName = lakeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = canonicalBaseName(from: fullName)

        var seen: Set<String> = []
        var result: [String] = []

        func add(_ title: String) {
            let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard !seen.contains(trimmed) else { return }
            seen.insert(trimmed)
            result.append(trimmed)
        }

        add(fullName)
        add(baseName)

        let lower = baseName.lowercased()
        if lower.hasSuffix("see"), !lower.hasSuffix(" see") {
            let prefix = String(baseName.dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty {
                add("\(prefix) See")
            }
        }

        return result
    }

    nonisolated private static func canonicalBaseName(from name: String) -> String {
        guard let first = name.split(separator: ",", maxSplits: 1).first else { return name }
        return String(first).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func fetchWikipediaPage(title: String) async -> WikiPage? {
        guard var components = URLComponents(string: "https://de.wikipedia.org/w/api.php") else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "titles", value: title),
            URLQueryItem(name: "prop", value: "extracts|info|coordinates|pageprops"),
            URLQueryItem(name: "inprop", value: "url"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "exsentences", value: "4")
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(wikipediaUserAgent, forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let pages = query["pages"] as? [[String: Any]],
                  let page = pages.first
            else { return nil }

            if page["missing"] != nil { return nil }

            let pageTitle = page["title"] as? String ?? ""
            guard !pageTitle.isEmpty else { return nil }

            guard let fullURL = page["fullurl"] as? String,
                  let pageURL = URL(string: fullURL)
            else { return nil }

            let extract = (page["extract"] as? String ?? "")
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !extract.isEmpty else { return nil }

            let pageProps = page["pageprops"] as? [String: Any]
            let isDisambiguation = pageProps?["disambiguation"] != nil

            var coordinate: CLLocationCoordinate2D?
            if let coordinates = page["coordinates"] as? [[String: Any]],
               let first = coordinates.first,
               let lat = first["lat"] as? Double,
               let lon = first["lon"] as? Double {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }

            return WikiPage(
                title: pageTitle,
                extract: extract,
                url: pageURL,
                coordinate: coordinate,
                isDisambiguation: isDisambiguation
            )
        } catch {
            return nil
        }
    }

    nonisolated private static func isConfidentMatch(lake: LakeInput, page: WikiPage) -> Bool {
        guard !page.isDisambiguation else { return false }
        guard let coordinate = page.coordinate else { return false }

        let pageLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let lakeLocation = CLLocation(latitude: lake.latitude, longitude: lake.longitude)
        let distanceKm = pageLocation.distance(from: lakeLocation) / 1000.0
        guard distanceKm <= 35 else { return false }

        let baseName = canonicalBaseName(from: lake.name)
        let normalizedBase = normalize(baseName)
        let normalizedTitle = normalize(page.title)
        guard !normalizedBase.isEmpty, !normalizedTitle.isEmpty else { return false }

        let strictNameMatch =
            normalizedTitle == normalizedBase ||
            normalizedTitle.hasPrefix(normalizedBase) ||
            normalizedBase.hasPrefix(normalizedTitle)
        guard strictNameMatch else { return false }

        let waterContext = "\(page.title) \(page.extract)".lowercased()
        let waterKeywords = ["see", "badesee", "badeteich", "teich", "stausee", "altarm", "gewässer", "badegewässer", "fluss"]
        guard waterKeywords.contains(where: waterContext.contains) else { return false }

        return true
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_AT"))
            .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    nonisolated private static func summarized(extract: String) -> String {
        let compact = extract
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else { return "" }

        var sentenceEnd: [String.Index] = []
        for idx in compact.indices where ".!?".contains(compact[idx]) {
            sentenceEnd.append(compact.index(after: idx))
            if sentenceEnd.count == 2 { break }
        }

        var summary: String
        if let end = sentenceEnd.last {
            summary = String(compact[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            summary = compact
        }

        if summary.count > 340 {
            let limit = summary.index(summary.startIndex, offsetBy: 340)
            var clipped = String(summary[..<limit])
            if let lastSpace = clipped.lastIndex(of: " ") {
                clipped = String(clipped[..<lastSpace])
            }
            summary = clipped + "…"
        }

        return summary
    }

    nonisolated private static var wikipediaUserAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "fluesseundseen/\(version) (iOS)"
    }
}
