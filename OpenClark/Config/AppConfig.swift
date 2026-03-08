import Foundation

/// Liest und schreibt die JSON-Konfiguration unter ~/.config/openclark/config.json.
final class AppConfig: @unchecked Sendable {

    static let shared = AppConfig()

    private let configURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "com.openclark.config")

    private(set) var config: AppConfiguration

    private init() {
        let configDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".config/openclark")
        configURL = configDir.appendingPathComponent("config.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Versuche bestehende Config zu laden
        if FileManager.default.fileExists(atPath: configURL.path),
           let data = try? Data(contentsOf: configURL),
           let loaded = try? decoder.decode(AppConfiguration.self, from: data) {
            config = loaded
        } else {
            config = Defaults.defaultConfiguration()
        }
    }

    /// Konfiguration speichern.
    func save() {
        queue.sync {
            let dir = configURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if let data = try? encoder.encode(config) {
                try? data.write(to: configURL)
            }
        }
    }

    /// Konfiguration aktualisieren und speichern.
    func update(_ block: (inout AppConfiguration) -> Void) {
        queue.sync {
            block(&config)
        }
        save()
    }

    /// Config-Pfad für Info-Anzeige.
    var configPath: String {
        configURL.path
    }
}
