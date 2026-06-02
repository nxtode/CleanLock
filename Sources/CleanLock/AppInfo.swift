import Foundation

enum AppInfo {
    static let name = "CleanLock"
    static let appName = "CleanLock"
    static let version = "0.1.3"
    static let build = "4"
    static let bundleIdentifier = "dev.nxtode.cleanlock"
    static let copyright = "© 2026 NXTode"
    static let latestReleaseAPIURL = URL(string: "https://api.github.com/repos/nxtode/CleanLock/releases/latest")!
    static let releasesLatestURL = URL(string: "https://api.github.com/repos/nxtode/CleanLock/releases/latest")!
    static let appcastURL: URL? = URL(string: "https://nxtode.github.io/CleanLock/appcast.xml")
    static let websiteURL: URL? = nil
    static let repositoryURL: URL? = URL(string: "https://github.com/nxtode/CleanLock")
}

enum UpdateCheckStatus: String {
    case idle = "Idle"
    case checking = "Checking..."
    case upToDate = "CleanLock is up to date."
    case noPublicRelease = "No updates available."
    case failed = "Unable to check for updates."
}
