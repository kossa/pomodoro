import AppKit

/// The macOS system alert sounds, discovered at runtime.
enum SoundLibrary {
    static let silentName = ""

    static let names: [String] = {
        let directories = [
            "/System/Library/Sounds",
            (NSHomeDirectory() as NSString).appendingPathComponent("Library/Sounds"),
        ]
        var found: Set<String> = []
        for directory in directories {
            let contents = (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? []
            for file in contents where NSSound(named: (file as NSString).deletingPathExtension) != nil {
                found.insert((file as NSString).deletingPathExtension)
            }
        }
        return found.sorted()
    }()

    static func play(_ name: String?) {
        guard let name, !name.isEmpty, let sound = NSSound(named: name) else { return }
        sound.stop()
        sound.play()
    }
}
