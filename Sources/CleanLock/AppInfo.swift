import Foundation

enum AppInfo {
    static let name = "CleanLock"
    static let version = "0.1.0"
    static let build = "1"
    static let bundleIdentifier = "dev.asuncion.cleanlock"
    static let copyright = "© 2026 Christopher Asuncion"
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/nxtode/CleanLock/releases/latest")!
    static let githubSponsorsURL: URL? = nil
    static let futureGitHubSponsorsURL = URL(string: "https://github.com/sponsors/maincasuncion")
    static let paypalURL: URL? = nil
    static let koFiURL: URL? = nil
    static let websiteURL: URL? = nil
    static let repositoryURL: URL? = URL(string: "https://github.com/nxtode/CleanLock")
}

enum UpdateCheckStatus: String {
    case idle = "Idle"
    case checking = "Checking..."
    case upToDate = "CleanLock is up to date."
    case noPublicRelease = "No public release found yet."
    case failed = "Failed to check for updates."
}
