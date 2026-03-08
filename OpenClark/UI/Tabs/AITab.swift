import SwiftUI

/// KI-Tab: Provider-Auswahl, API Key, Modell, Test-Button, Trial-Status.
struct AITab: View {
    @State private var provider: AppConfiguration.LLMProviderType
    @State private var apiKey: String
    @State private var model: String
    @State private var confidenceThreshold: Double
    @State private var customEndpoint: String

    @State private var testResult: String?
    @State private var isTesting = false

    private let config = AppConfig.shared

    init() {
        let c = AppConfig.shared.config
        _provider = State(initialValue: c.llmProvider)
        _apiKey = State(initialValue: c.apiKey)
        _model = State(initialValue: c.llmModel)
        _confidenceThreshold = State(initialValue: c.confidenceThreshold)
        _customEndpoint = State(initialValue: "")
    }

    var body: some View {
        Form {
            // Provider
            Section {
                Picker("Provider", selection: $provider) {
                    Text("Aus (nur Keywords)").tag(AppConfiguration.LLMProviderType.none)
                    Text("Anthropic (Claude)").tag(AppConfiguration.LLMProviderType.anthropic)
                    Text("OpenAI (GPT)").tag(AppConfiguration.LLMProviderType.openai)
                    Text("Ollama (Lokal)").tag(AppConfiguration.LLMProviderType.ollama)
                    Text("Custom Endpoint").tag(AppConfiguration.LLMProviderType.custom)
                }
                .onChange(of: provider) { _, newValue in
                    config.update { $0.llmProvider = newValue }
                    updateDefaultModel(for: newValue)
                }
            } header: {
                Label("KI-Provider", systemImage: "cpu")
            }

            // API Key (nicht für Ollama/None)
            if provider != .none && provider != .ollama {
                Section {
                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            config.update { $0.apiKey = newValue }
                        }

                    if provider == .anthropic {
                        Text("Einen Key erhältst du auf console.anthropic.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if provider == .openai {
                        Text("Einen Key erhältst du auf platform.openai.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("API Key", systemImage: "key")
                }
            }

            // Modell
            if provider != .none {
                Section {
                    if provider == .anthropic {
                        Picker("Modell", selection: $model) {
                            Text("Claude Haiku (schnell, günstig)").tag("claude-haiku-4-20250414")
                            Text("Claude Sonnet (ausgewogen)").tag("claude-sonnet-4-20250514")
                            Text("Claude Opus (präzise, teuer)").tag("claude-opus-4-20250414")
                        }
                    } else if provider == .openai {
                        Picker("Modell", selection: $model) {
                            Text("GPT-4o Mini (schnell, günstig)").tag("gpt-4o-mini")
                            Text("GPT-4o (ausgewogen)").tag("gpt-4o")
                        }
                    } else {
                        TextField("Modell", text: $model)
                    }
                } header: {
                    Label("Modell", systemImage: "brain")
                }
            }

            // Konfidenz
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Schwellwert")
                        Spacer()
                        Text(String(format: "%.0f%%", confidenceThreshold * 100))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $confidenceThreshold, in: 0.1...0.9, step: 0.1)
                        .onChange(of: confidenceThreshold) { _, newValue in
                            config.update { $0.confidenceThreshold = newValue }
                        }
                }

                Text("Unter diesem Wert wird die nächste Analyse-Stufe verwendet. Niedrigerer Wert = mehr Keyword-Ergebnisse, höherer Wert = mehr KI-Nutzung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Konfidenz-Schwellwert", systemImage: "gauge.with.dots.needle.33percent")
            }

            // Test
            if provider != .none {
                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Teste Verbindung...")
                            } else {
                                Label("Verbindung testen", systemImage: "bolt")
                            }
                        }
                    }
                    .disabled(isTesting || (apiKey.isEmpty && provider != .ollama))

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("✅") ? .green : .red)
                    }
                } header: {
                    Label("Verbindungstest", systemImage: "antenna.radiowaves.left.and.right")
                }
            }

            // Trial Info
            Section {
                trialInfoView
            } header: {
                Label("Trial", systemImage: "clock")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Trial Info

    @ViewBuilder
    private var trialInfoView: some View {
        if let startDate = config.config.trialStartDate {
            let daysSince = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            let remaining = max(0, 14 - daysSince)

            if remaining > 0 {
                HStack {
                    Image(systemName: "gift")
                        .foregroundStyle(.green)
                    Text("Trial aktiv: noch \(remaining) Tage")
                }
            } else {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text("Trial abgelaufen – eigenen API Key eingeben")
                }
            }
        } else if apiKey.isEmpty {
            Text("Noch kein Trial gestartet. Wird beim ersten Start mit KI-Provider aktiviert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Image(systemName: "key.fill")
                    .foregroundStyle(.green)
                Text("Eigener API Key aktiv")
            }
        }
    }

    // MARK: - Actions

    private func updateDefaultModel(for providerType: AppConfiguration.LLMProviderType) {
        switch providerType {
        case .anthropic:
            model = "claude-haiku-4-20250414"
        case .openai:
            model = "gpt-4o-mini"
        case .ollama:
            model = "llama3.2"
        case .custom, .none:
            break
        }
        config.update { $0.llmModel = model }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let service = LLMService()
            await service.configure(with: config.config)

            let result = await service.analyze(
                filename: "test_rechnung.pdf",
                extension: "pdf",
                text: "Rechnung Nr. 12345 von Vodafone GmbH, Datum: 15.01.2024, Betrag: 39,99€",
                providerType: provider
            )

            await MainActor.run {
                isTesting = false
                if let r = result {
                    testResult = "✅ Verbindung OK: \(r.date)_\(r.category)_\(r.description)"
                } else {
                    testResult = "❌ Verbindung fehlgeschlagen. Prüfe API Key und Provider."
                }
            }
        }
    }
}
