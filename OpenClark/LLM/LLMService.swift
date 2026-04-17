import Foundation
import os.log

/// Ergebnis einer LLM-Analyse.
struct LLMAnalysisResult: Sendable {
    let date: String
    let category: String
    let description: String
}

/// Protocol für LLM-Provider.
protocol LLMProvider: Sendable {
    var name: String { get }

    /// Analysiere Datei und generiere Rename-Vorschlag.
    func analyze(
        filename: String,
        extension ext: String,
        text: String
    ) async throws -> LLMAnalysisResult

    /// Analysiere PDF-Datei direkt (für Scans ohne Text-Layer). Standardimplementierung fällt auf text-basierte Analyse zurück.
    func analyzePDF(
        filename: String,
        pdfPath: String,
        extractedText: String
    ) async throws -> LLMAnalysisResult
}

extension LLMProvider {
    func analyzePDF(filename: String, pdfPath: String, extractedText: String) async throws -> LLMAnalysisResult {
        try await analyze(filename: filename, extension: "pdf", text: extractedText)
    }
}

/// Router: Leitet Anfragen an den aktiven Provider weiter.
actor LLMService {

    private let logger = Logger(subsystem: "com.openclark", category: "llm")

    private var providers: [AppConfiguration.LLMProviderType: LLMProvider] = [:]

    init() {}

    /// Provider registrieren.
    func register(_ provider: LLMProvider, for type: AppConfiguration.LLMProviderType) {
        providers[type] = provider
    }

    /// Konfiguriere alle Provider basierend auf AppConfig.
    func configure(with config: AppConfiguration) {
        // Anthropic
        if !config.apiKey.isEmpty && config.llmProvider == .anthropic {
            providers[.anthropic] = AnthropicProvider(
                apiKey: config.apiKey,
                model: config.llmModel
            )
        }

        // OpenAI
        if !config.apiKey.isEmpty && config.llmProvider == .openai {
            providers[.openai] = OpenAIProvider(
                apiKey: config.apiKey,
                model: config.llmModel
            )
        }

        // Ollama (kein API Key nötig)
        if config.llmProvider == .ollama {
            providers[.ollama] = OllamaProvider(
                model: config.llmModel
            )
        }

        // Qwen lokal via LM Studio (kein API Key nötig)
        if config.llmProvider == .qwen {
            providers[.qwen] = QwenProvider(
                model: config.llmModel
            )
        }

        // Custom
        if !config.apiKey.isEmpty && config.llmProvider == .custom {
            providers[.custom] = CustomProvider(
                apiKey: config.apiKey,
                model: config.llmModel,
                endpoint: "" // Wird später aus Config geladen
            )
        }
    }

    /// Analysiere mit dem aktiven Provider.
    func analyze(
        filename: String,
        extension ext: String,
        text: String,
        providerType: AppConfiguration.LLMProviderType
    ) async -> LLMAnalysisResult? {
        guard let provider = providers[providerType] else {
            logger.warning("Kein Provider konfiguriert für: \(providerType.rawValue)")
            return nil
        }

        logger.info("LLM-Analyse via \(provider.name)...")

        let timeout: TimeInterval = (providerType == .qwen || providerType == .ollama) ? 180 : 30
        do {
            let result = try await withTimeout(seconds: timeout) {
                try await provider.analyze(
                    filename: filename,
                    extension: ext,
                    text: text
                )
            }
            logger.info("LLM-Ergebnis: \(result.category) / \(result.description)")
            return result
        } catch {
            logger.error("LLM-Fehler: \(error.localizedDescription)")
            return nil
        }
    }

    /// Analysiere PDF direkt (für Scans ohne Text-Layer).
    func analyzePDF(
        filename: String,
        pdfPath: String,
        extractedText: String,
        providerType: AppConfiguration.LLMProviderType
    ) async -> LLMAnalysisResult? {
        guard let provider = providers[providerType] else {
            logger.warning("Kein Provider konfiguriert für: \(providerType.rawValue)")
            return nil
        }

        logger.info("LLM PDF-Analyse via \(provider.name)...")

        let timeout: TimeInterval = (providerType == .qwen || providerType == .ollama) ? 240 : 60
        do {
            let result = try await withTimeout(seconds: timeout) {
                try await provider.analyzePDF(
                    filename: filename,
                    pdfPath: pdfPath,
                    extractedText: extractedText
                )
            }
            logger.info("LLM PDF-Ergebnis: \(result.category) / \(result.description)")
            return result
        } catch {
            logger.error("LLM PDF-Fehler: \(error.localizedDescription)")
            return nil
        }
    }

    /// Teste ob der aktive Provider erreichbar ist.
    func testConnection(providerType: AppConfiguration.LLMProviderType) async -> Bool {
        guard let provider = providers[providerType] else { return false }

        do {
            _ = try await provider.analyze(
                filename: "test.pdf",
                extension: "pdf",
                text: "Dies ist ein Test-Dokument."
            )
            return true
        } catch {
            return false
        }
    }

    /// Teste Verbindung und gib detaillierten Fehler zurück.
    func testConnectionDetailed(providerType: AppConfiguration.LLMProviderType) async -> Result<LLMAnalysisResult, Error> {
        guard let provider = providers[providerType] else {
            return .failure(LLMError.noProvider)
        }

        let timeout: TimeInterval = (providerType == .qwen || providerType == .ollama) ? 180 : 15
        do {
            let result = try await withTimeout(seconds: timeout) {
                try await provider.analyze(
                    filename: "test_rechnung.pdf",
                    extension: "pdf",
                    text: "Rechnung Nr. 12345 von Vodafone GmbH, Datum: 15.01.2024, Betrag: 39,99€"
                )
            }
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Timeout Helper

    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw LLMError.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

enum LLMError: Error, LocalizedError {
    case timeout
    case invalidResponse
    case apiError(String)
    case noProvider

    var errorDescription: String? {
        switch self {
        case .timeout: return "LLM-Anfrage Timeout"
        case .invalidResponse: return "Ungültige LLM-Antwort"
        case .apiError(let msg): return "API-Fehler: \(msg)"
        case .noProvider: return "Kein LLM-Provider konfiguriert"
        }
    }
}
