import Foundation

/// Default-Werte für die Konfiguration.
enum Defaults {
    static let watchedDirectories: [String] = [
        "\(NSHomeDirectory())/Documents",
        "\(NSHomeDirectory())/Downloads",
    ]

    static let recursive = true
    static let processingDelay = 3 // Sekunden
    static let pollInterval = 30 // Sekunden
    static let confidenceThreshold = 0.5
    static let dryRun = false
    static let language = "de"

    static let llmProvider = AppConfiguration.LLMProviderType.none
    static let apiKey = ""
    static let llmModel = "claude-haiku-4-20250414"

    static let trialDays = 14
    static let launchAtLogin = false

    static func defaultConfiguration() -> AppConfiguration {
        AppConfiguration(
            watchedDirectories: watchedDirectories,
            recursive: recursive,
            processingDelay: processingDelay,
            pollInterval: pollInterval,
            confidenceThreshold: confidenceThreshold,
            dryRun: dryRun,
            language: language,
            llmProvider: llmProvider,
            apiKey: apiKey,
            llmModel: llmModel,
            trialStartDate: nil,
            trialExpired: false,
            onboardingCompleted: false,
            launchAtLogin: launchAtLogin,
            customCategories: nil,
            disabledBuiltInCategories: nil,
            additionalBuiltInKeywords: nil,
            removedBuiltInKeywords: nil,
            excludedExtensions: nil,
            excludedPrefixes: nil,
            excludedDirectories: nil,
            enabledBuiltInExtensions: nil
        )
    }
}
