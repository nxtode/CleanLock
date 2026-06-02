import Foundation
import Security

public enum CleanLockAppCommand {
    public static let openMainWindowArgument = "--open-main-window"
    public static let startCleaningArgument = "--start-cleaning"
    public static let quitMainArgument = "--quit-main"
    public static let launchedAtLoginArgument = "--launched-at-login"
    public static let commandTokenArgument = "--command-token"

    public static let commandTokenUserInfoKey = "commandToken"

    public static let openMainWindowNotification = Notification.Name("dev.nxtode.cleanlock.openMainWindow")
    public static let startCleaningNotification = Notification.Name("dev.nxtode.cleanlock.startCleaning")
    public static let quitMainNotification = Notification.Name("dev.nxtode.cleanlock.quitMain")
    public static let quitMenuBarAgentNotification = Notification.Name("dev.nxtode.cleanlock.quitMenuBarAgent")
}

public enum CleanLockBundleIdentifier {
    public static let main = "dev.nxtode.cleanlock"
    public static let menuBarAgent = "dev.nxtode.cleanlock.menubar"
    public static let loginHelper = "dev.nxtode.cleanlock.loginhelper"
}

public enum CleanLockCommandTokenStore {
    public static func loadOrCreateToken() -> String? {
        do {
            let tokenURL = try commandTokenURL()
            if let existingToken = try readToken(at: tokenURL) {
                return existingToken
            }

            let token = makeToken()
            try FileManager.default.createDirectory(
                at: tokenURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try token.write(to: tokenURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenURL.path)
            return token
        } catch {
            print("CleanLock command token unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    public static func validateToken(_ candidate: String?) -> Bool {
        guard let candidate, !candidate.isEmpty else { return false }
        return loadOrCreateToken() == candidate
    }

    public static func tokenArguments() -> [String] {
        guard let token = loadOrCreateToken() else { return [] }
        return [CleanLockAppCommand.commandTokenArgument, token]
    }

    public static func tokenUserInfo() -> [String: String] {
        guard let token = loadOrCreateToken() else { return [:] }
        return [CleanLockAppCommand.commandTokenUserInfoKey: token]
    }

    private static func commandTokenURL() throws -> URL {
        let supportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return supportURL
            .appendingPathComponent("CleanLock", isDirectory: true)
            .appendingPathComponent("CommandToken", isDirectory: false)
    }

    private static func readToken(at url: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let token = try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    private static func makeToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            return bytes.map { String(format: "%02x", $0) }.joined()
        }

        return UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
}

public extension Array where Element == String {
    func cleanLockArgumentValue(after argument: String) -> String? {
        guard let index = firstIndex(of: argument) else { return nil }
        let valueIndex = self.index(after: index)
        guard valueIndex < endIndex else { return nil }
        return self[valueIndex]
    }
}
