import Foundation

/// Benutzerdefinierte Kategorie mit Keywords.
struct CustomCategory: Codable, Sendable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var keywords: [String]

    init(id: UUID = UUID(), name: String, keywords: [String]) {
        self.id = id
        self.name = name
        self.keywords = keywords
    }
}

/// Hauptkonfiguration der App.
struct AppConfiguration: Codable, Sendable {
    var watchedDirectories: [String]
    var recursive: Bool
    var processingDelay: Int // Sekunden
    var pollInterval: Int // Sekunden
    var confidenceThreshold: Double
    var dryRun: Bool
    var language: String // "de" oder "en"

    // LLM
    var llmProvider: LLMProviderType
    var apiKey: String
    var llmModel: String

    // Trial
    var trialStartDate: Date?
    var trialExpired: Bool

    // Onboarding
    var onboardingCompleted: Bool

    // Launch at Login
    var launchAtLogin: Bool

    // Kategorien
    var customCategories: [CustomCategory]?
    var disabledBuiltInCategories: [String]?
    // Keyword-Overrides für Built-in Kategorien
    var additionalBuiltInKeywords: [String: [String]]?  // Kategoriename → zusätzliche Keywords
    var removedBuiltInKeywords: [String: [String]]?      // Kategoriename → entfernte Keywords

    // Ausschlüsse (benutzerdefiniert, zusätzlich zu Built-in)
    var excludedExtensions: [String]?
    var excludedPrefixes: [String]?
    var excludedDirectories: [String]?
    // Built-in Ausschlüsse die der User deaktiviert hat
    var enabledBuiltInExtensions: [String]?
    var disabledBuiltInPrefixes: [String]?
    var disabledBuiltInDirectories: [String]?

    // Komplett gelöschte Built-in Einträge (durch Reset wiederherstellbar)
    var deletedBuiltInCategories: [String]?
    var deletedBuiltInExtensions: [String]?
    var deletedBuiltInPrefixes: [String]?
    var deletedBuiltInDirectories: [String]?

    enum LLMProviderType: String, Codable, Sendable, CaseIterable {
        case anthropic
        case openai
        case ollama
        case qwen
        case custom
        case none
    }
}

/// Zustand der App (nicht persistent).
struct AppState: Sendable {
    var isActive: Bool = true
    var todayCount: Int = 0
    var recentRenames: [RenameRecord] = []
}
