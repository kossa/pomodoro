import AppKit
import SwiftUI

/// Checks the GitHub releases API for a newer build and installs it in place.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading
        case failed(String)
    }

    struct Release: Equatable {
        var version: String
        var pageURL: URL
        var zipURL: URL?
    }

    private static let latestReleaseAPI =
        URL(string: "https://api.github.com/repos/kossa/pomodoro/releases/latest")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let lastCheckKey = "lastUpdateCheck"

    @Published private(set) var state: State = .idle
    @Published var checkDaily: Bool {
        didSet {
            defaults.set(checkDaily, forKey: "checkForUpdatesDaily")
            if checkDaily { checkIfDue() }
        }
    }

    let currentVersion: String
    private let defaults: UserDefaults
    private let session: URLSession
    private var timer: Timer?

    init(defaults: UserDefaults = .standard, session: URLSession = .shared) {
        self.defaults = defaults
        self.session = session
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        if defaults.object(forKey: "checkForUpdatesDaily") == nil {
            defaults.set(true, forKey: "checkForUpdatesDaily")
        }
        self.checkDaily = defaults.bool(forKey: "checkForUpdatesDaily")
        self.lastChecked = defaults.object(forKey: Self.lastCheckKey) as? Date

        // Re-evaluate periodically so an app left running for days still checks.
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIfDue() }
        }
    }

    /// Held in memory rather than read from UserDefaults on every layout pass.
    @Published private(set) var lastChecked: Date?

    /// Checks only if daily checking is on and a day has passed.
    func checkIfDue() {
        guard checkDaily else { return }
        if let last = lastChecked, Date().timeIntervalSince(last) < Self.checkInterval { return }
        Task { await check() }
    }

    func check() async {
        guard state != .checking, state != .downloading else { return }
        state = .checking

        do {
            var request = URLRequest(url: Self.latestReleaseAPI)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("Pomodoro/\(currentVersion)", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw UpdateError.message("GitHub returned \(code)")
            }
            let release = try Self.parseRelease(data)
            let now = Date()
            defaults.set(now, forKey: Self.lastCheckKey)
            lastChecked = now

            state = Self.isNewer(release.version, than: currentVersion) ? .available(release) : .upToDate
        } catch {
            state = .failed((error as? UpdateError)?.text ?? error.localizedDescription)
        }
    }

    /// Downloads the release, then hands the swap to a detached script — the app
    /// cannot replace its own bundle while it is running.
    func install(_ release: Release) async {
        guard let zipURL = release.zipURL else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        state = .downloading

        do {
            let (downloaded, response) = try await session.download(from: zipURL)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw UpdateError.message("download failed")
            }

            let staging = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("PomodoroUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let archive = staging.appendingPathComponent("Pomodoro.zip")
            try FileManager.default.moveItem(at: downloaded, to: archive)

            // ditto, not unzip: it unpacks the bundle without ._* files.
            try run("/usr/bin/ditto", ["-x", "-k", archive.path, staging.path])

            let newApp = staging.appendingPathComponent("Pomodoro.app")
            guard FileManager.default.fileExists(atPath: newApp.path) else {
                throw UpdateError.message("the download did not contain Pomodoro.app")
            }
            // Refuse anything that isn't a properly signed Pomodoro.
            try run("/usr/bin/codesign", ["-v", newApp.path])
            let identifier = Bundle(url: newApp)?.bundleIdentifier
            guard identifier == Bundle.main.bundleIdentifier else {
                throw UpdateError.message("unexpected bundle identifier")
            }

            try swapAndRelaunch(newApp: newApp)
        } catch {
            state = .failed((error as? UpdateError)?.text ?? error.localizedDescription)
        }
    }

    private func swapAndRelaunch(newApp: URL) throws {
        let destination = Bundle.main.bundleURL
        let script = """
        #!/bin/sh
        # Wait for Pomodoro to quit, swap the bundle, then start it again.
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(destination.path).old"
        if ! mv "\(destination.path)" "\(destination.path).old"; then
            open "\(destination.path)"
            exit 1
        fi
        if /usr/bin/ditto "\(newApp.path)" "\(destination.path)"; then
            rm -rf "\(destination.path).old"
        else
            mv "\(destination.path).old" "\(destination.path)"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "\(destination.path)" 2>/dev/null
        open "\(destination.path)"
        rm -rf "\(newApp.deletingLastPathComponent().path)"
        """

        let scriptURL = newApp.deletingLastPathComponent().appendingPathComponent("swap.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        try process.run()

        NSApplication.shared.terminate(nil)
    }

    // MARK: - Helpers

    private func run(_ launchPath: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw UpdateError.message("\((launchPath as NSString).lastPathComponent) failed")
        }
    }

    static func parseRelease(_ data: Data) throws -> Release {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let page = json["html_url"] as? String,
              let pageURL = URL(string: page) else {
            throw UpdateError.message("could not read the release feed")
        }

        let assets = json["assets"] as? [[String: Any]] ?? []
        // The unversioned asset is the stable one; fall back to any zip.
        let asset = assets.first { $0["name"] as? String == "Pomodoro.zip" }
            ?? assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
        let zipURL = (asset?["browser_download_url"] as? String).flatMap(URL.init(string:))

        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag,
                       pageURL: pageURL,
                       zipURL: zipURL)
    }

    /// Numeric component comparison — "1.10.0" is newer than "1.9.0".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let left = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let right = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}

enum UpdateError: Error {
    case message(String)

    var text: String {
        switch self {
        case let .message(text): return text
        }
    }
}
