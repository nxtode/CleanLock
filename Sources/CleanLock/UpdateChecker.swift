import Foundation

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let name: String?
    let body: String?
    let publishedAt: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
        case publishedAt = "published_at"
    }
}

enum UpdateCheckResult {
    case updateAvailable(GitHubRelease)
    case upToDate(GitHubRelease?)
    case noPublicRelease
    case failed
}

enum UpdateChecker {
    static func checkLatestRelease(currentVersion: String) async -> UpdateCheckResult {
        var request = URLRequest(url: AppInfo.latestReleaseAPIURL)
        request.setValue("CleanLock/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failed
            }

            if httpResponse.statusCode == 404 {
                return .noPublicRelease
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failed
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.trimmingLeadingVersionPrefix()

            switch SemanticVersion.compare(latestVersion, currentVersion) {
            case .orderedDescending:
                return .updateAvailable(release)
            case .orderedSame, .orderedAscending:
                return .upToDate(release)
            }
        } catch {
            return .failed
        }
    }
}

struct SemanticVersion {
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftParts = versionParts(lhs)
        let rightParts = versionParts(rhs)
        let count = max(leftParts.count, rightParts.count)

        for index in 0..<count {
            let left = index < leftParts.count ? leftParts[index] : 0
            let right = index < rightParts.count ? rightParts[index] : 0

            if left > right {
                return .orderedDescending
            }
            if left < right {
                return .orderedAscending
            }
        }

        return .orderedSame
    }

    private static func versionParts(_ version: String) -> [Int] {
        version
            .trimmingLeadingVersionPrefix()
            .split(separator: ".")
            .map { part in
                let numericPrefix = part.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }
}

private extension String {
    func trimmingLeadingVersionPrefix() -> String {
        guard lowercased().hasPrefix("v") else { return self }
        return String(dropFirst())
    }
}
