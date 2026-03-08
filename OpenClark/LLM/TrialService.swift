import Foundation
import os.log

/// Verwaltet den 14-Tage Trial mit geteiltem API Key.
actor TrialService {

    private let logger = Logger(subsystem: "com.openclark", category: "trial")
    private let config: AppConfig
    private let trialDays = 14

    /// URL zum geteilten Trial-Key (rotierbar via GitHub Gist).
    /// In Produktion: GitHub Gist URL die den Key enthält.
    private let trialKeyURL: URL? = nil // TODO: GitHub Gist URL setzen

    init(config: AppConfig) {
        self.config = config
    }

    // MARK: - Trial Status

    enum TrialStatus: Sendable {
        case active(daysRemaining: Int)
        case expired
        case ownKey
        case noKey
    }

    /// Aktueller Trial-Status.
    func status() -> TrialStatus {
        // Eigener Key vorhanden?
        if !config.config.apiKey.isEmpty && config.config.llmProvider != .none {
            return .ownKey
        }

        // Trial aktiv?
        guard let startDate = config.config.trialStartDate else {
            return .noKey
        }

        let daysSinceStart = Calendar.current.dateComponents(
            [.day], from: startDate, to: Date()
        ).day ?? 0

        if daysSinceStart < trialDays {
            return .active(daysRemaining: trialDays - daysSinceStart)
        } else {
            return .expired
        }
    }

    /// Starte Trial beim ersten App-Start.
    func startTrialIfNeeded() {
        if config.config.trialStartDate == nil && config.config.apiKey.isEmpty {
            config.update { conf in
                conf.trialStartDate = Date()
            }
            logger.info("Trial gestartet: 14 Tage ab heute")
        }
    }

    /// Prüfe ob LLM-Analyse verfügbar ist.
    func isLLMAvailable() -> Bool {
        switch status() {
        case .active:
            return true
        case .ownKey:
            return true
        case .expired, .noKey:
            return false
        }
    }

    /// Status-Text für die UI.
    func statusText() -> String {
        switch status() {
        case .active(let days):
            return "Trial: \(days) Tage verbleibend"
        case .expired:
            return "Trial abgelaufen – eigenen API Key eingeben"
        case .ownKey:
            return "Eigener API Key aktiv"
        case .noKey:
            return "Kein API Key konfiguriert"
        }
    }

    // MARK: - Trial Key (Remote)

    /// Lade Trial-Key von GitHub Gist (falls konfiguriert).
    func fetchTrialKey() async -> String? {
        guard let url = trialKeyURL else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !key.isEmpty else {
                return nil
            }
            logger.info("Trial-Key geladen")
            return key
        } catch {
            logger.error("Trial-Key Fehler: \(error.localizedDescription)")
            return nil
        }
    }
}
