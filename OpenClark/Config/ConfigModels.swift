import Foundation

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

    enum LLMProviderType: String, Codable, Sendable, CaseIterable {
        case anthropic
        case openai
        case ollama
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
