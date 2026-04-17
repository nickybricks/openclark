import SwiftUI

/// KI-Tab: Provider-Auswahl, API Key, Modell, Test-Button, Trial-Status.
struct AITab: View {
    @State private var provider: AppConfiguration.LLMProviderType
    @State private var apiKey: String
    @State private var model: String
    @State private var confidenceThreshold: Double

    @State private var testResult: String?
    @State private var isTesting = false

    // Qwen / Ollama setup state
    @State private var ollamaAvailable = false
    @State private var serverRunning = false
    @State private var modelInstalled = false
    @State private var qwenBusy = false
    @State private var qwenStatusText = ""
    @State private var qwenError: String?

    private let config = AppConfig.shared

    init() {
        let c = AppConfig.shared.config
        _provider = State(initialValue: c.llmProvider)
        _apiKey = State(initialValue: c.apiKey)
        _model = State(initialValue: c.llmModel)
        _confidenceThreshold = State(initialValue: c.confidenceThreshold)
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
                    Text("Qwen (Lokal)").tag(AppConfiguration.LLMProviderType.qwen)
                    Text("Custom Endpoint").tag(AppConfiguration.LLMProviderType.custom)
                }
                .onChange(of: provider) { _, newValue in
                    config.update { $0.llmProvider = newValue }
                    updateDefaultModel(for: newValue)
                    if newValue == .qwen { refreshQwenStatus() }
                }
            } header: {
                Label("KI-Provider", systemImage: "cpu")
            }

            // API Key (nicht für Ollama/Qwen/None)
            if provider != .none && provider != .ollama && provider != .qwen {
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
                            Text("Claude Haiku (schnell, günstig)").tag("claude-haiku-4-5-20251001")
                            Text("Claude Sonnet (ausgewogen)").tag("claude-sonnet-4-6")
                            Text("Claude Opus (präzise, teuer)").tag("claude-opus-4-5")
                        }
                        .onChange(of: model) { _, newValue in
                            config.update { $0.llmModel = newValue }
                        }
                    } else if provider == .openai {
                        Picker("Modell", selection: $model) {
                            Text("GPT-4o Mini (schnell, günstig)").tag("gpt-4o-mini")
                            Text("GPT-4o (ausgewogen)").tag("gpt-4o")
                        }
                        .onChange(of: model) { _, newValue in
                            config.update { $0.llmModel = newValue }
                        }
                    } else if provider == .ollama {
                        Picker("Modell", selection: $model) {
                            Text("Llama 3.2 3B (schnell)").tag("llama3.2")
                            Text("Llama 3.2 8B").tag("llama3.2:8b")
                            Text("Llama 3.1 8B").tag("llama3.1:8b")
                            Text("Mistral 7B").tag("mistral")
                            Text("Gemma 3 4B").tag("gemma3:4b")
                            Text("Phi-4 14B").tag("phi4")
                            Text("Qwen 2.5 7B").tag("qwen2.5:7b")
                            Text("LLaVA 7B (Vision)").tag("llava:7b")
                            Text("Llama 3.2 Vision 11B").tag("llama3.2-vision:11b")
                        }
                        .onChange(of: model) { _, newValue in
                            config.update { $0.llmModel = newValue }
                        }
                    } else if provider == .qwen {
                        Picker("Modell", selection: $model) {
                            Text("Qwen2.5-VL 7B (~15 GB)").tag("qwen2.5vl:7b")
                            Text("Qwen2.5-VL 32B (~20 GB)").tag("qwen2.5vl:32b")
                        }
                        .onChange(of: model) { _, newValue in
                            config.update { $0.llmModel = newValue }
                            modelInstalled = false
                            refreshQwenStatus()
                        }
                    } else {
                        TextField("Modell", text: $model)
                            .onChange(of: model) { _, newValue in
                                config.update { $0.llmModel = newValue }
                            }
                    }
                } header: {
                    Label("Modell", systemImage: "brain")
                }
            }

            // Qwen Setup-Status
            if provider == .qwen {
                qwenSetupSection
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

                Text("Unter diesem Wert wird die nächste Analyse-Stufe verwendet.")
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
                                ProgressView().controlSize(.small)
                                Text("Teste Verbindung...")
                            } else {
                                Label("Verbindung testen", systemImage: "bolt")
                            }
                        }
                    }
                    .disabled(isTesting || (apiKey.isEmpty && provider != .ollama && provider != .qwen))

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
        .task {
            if provider == .qwen { refreshQwenStatus() }
        }
    }

    // MARK: - Qwen Setup Section

    @ViewBuilder
    private var qwenSetupSection: some View {
        Section {
            Text("Einmalige Einrichtung – danach läuft alles lokal & offline.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Step 1: Ollama binary
            HStack {
                Image(systemName: ollamaAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(ollamaAvailable ? .green : .red)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ollamaAvailable ? "Ollama installiert" : "Ollama nicht installiert")
                    if !ollamaAvailable {
                        Text("~60 MB, einmalig")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !ollamaAvailable {
                    Button("Herunterladen") { downloadOllama() }
                        .disabled(qwenBusy)
                }
            }

            // Step 2: Server
            if ollamaAvailable {
                HStack {
                    Image(systemName: serverRunning ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(serverRunning ? .green : .secondary)
                    Text(serverRunning ? "Lokaler Server läuft" : "Lokaler Server gestoppt")

                    Spacer()

                    if serverRunning {
                        Button("Stoppen") { stopServer() }
                            .buttonStyle(.borderless)
                    } else {
                        Button("Starten") { startServer() }
                            .disabled(qwenBusy)
                    }
                }
            }

            // Step 3: Model
            if serverRunning {
                HStack {
                    Image(systemName: modelInstalled ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(modelInstalled ? .green : .secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(modelInstalled ? "Modell bereit" : "Modell nicht geladen")
                        if !modelInstalled {
                            Text("Wird lokal gespeichert, kein Internet nach Download")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !modelInstalled {
                        Button("Herunterladen") { pullModel() }
                            .disabled(qwenBusy)
                    }
                }
            }

            // Progress / error
            if qwenBusy {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text(qwenStatusText.isEmpty ? "Bitte warten…" : qwenStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let error = qwenError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Label("Einrichtung", systemImage: "gearshape.2")
        }
    }

    // MARK: - Trial Info

    @ViewBuilder
    private var trialInfoView: some View {
        if let startDate = config.config.trialStartDate {
            let daysSince = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            let remaining = max(0, 14 - daysSince)

            if remaining > 0 {
                HStack {
                    Image(systemName: "gift").foregroundStyle(.green)
                    Text("Trial aktiv: noch \(remaining) Tage")
                }
            } else {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
                    Text("Trial abgelaufen – eigenen API Key eingeben")
                }
            }
        } else if apiKey.isEmpty {
            Text("Noch kein Trial gestartet. Wird beim ersten Start mit KI-Provider aktiviert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Image(systemName: "key.fill").foregroundStyle(.green)
                Text("Eigener API Key aktiv")
            }
        }
    }

    // MARK: - Default Models

    private func updateDefaultModel(for providerType: AppConfiguration.LLMProviderType) {
        switch providerType {
        case .anthropic:
            model = "claude-haiku-4-5-20251001"
        case .openai:
            model = "gpt-4o-mini"
        case .ollama:
            model = "llama3.2"
        case .qwen:
            model = "qwen2.5vl:7b"
        case .custom, .none:
            break
        }
        config.update { $0.llmModel = model }
    }

    // MARK: - Qwen Actions

    private func refreshQwenStatus() {
        Task {
            let available = await OllamaManager.shared.isOllamaAvailable
            let running = await OllamaManager.shared.isServerRunning()
            let installed = running ? await OllamaManager.shared.isModelInstalled(model) : false
            await MainActor.run {
                ollamaAvailable = available
                serverRunning = running
                modelInstalled = installed
            }
        }
    }

    private func downloadOllama() {
        qwenBusy = true
        qwenError = nil
        Task {
            do {
                try await OllamaManager.shared.downloadOllama { status in
                    Task { @MainActor in qwenStatusText = status }
                }
                await MainActor.run {
                    ollamaAvailable = true
                    qwenBusy = false
                    qwenStatusText = ""
                }
            } catch {
                await MainActor.run {
                    qwenBusy = false
                    qwenError = error.localizedDescription
                }
            }
        }
    }

    private func startServer() {
        qwenBusy = true
        qwenStatusText = "Server wird gestartet…"
        qwenError = nil
        Task {
            do {
                try await OllamaManager.shared.ensureServerRunning()
                let installed = await OllamaManager.shared.isModelInstalled(model)
                await MainActor.run {
                    serverRunning = true
                    modelInstalled = installed
                    qwenBusy = false
                    qwenStatusText = ""
                }
            } catch {
                await MainActor.run {
                    qwenBusy = false
                    qwenError = error.localizedDescription
                }
            }
        }
    }

    private func stopServer() {
        Task {
            await OllamaManager.shared.stopServer()
            await MainActor.run {
                serverRunning = false
                modelInstalled = false
            }
        }
    }

    private func pullModel() {
        qwenBusy = true
        qwenStatusText = "Modell wird heruntergeladen…"
        qwenError = nil
        Task {
            do {
                try await OllamaManager.shared.pullModel(model) { status in
                    Task { @MainActor in qwenStatusText = status }
                }
                await MainActor.run {
                    modelInstalled = true
                    qwenBusy = false
                    qwenStatusText = ""
                }
            } catch {
                await MainActor.run {
                    qwenBusy = false
                    qwenError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Connection Test

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let service = LLMService()
            await service.configure(with: config.config)

            let outcome = await service.testConnectionDetailed(providerType: provider)

            await MainActor.run {
                isTesting = false
                switch outcome {
                case .success(let r):
                    testResult = "✅ Verbindung OK: \(r.date)_\(r.category)_\(r.description)"
                case .failure(let error):
                    let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    testResult = "❌ \(detail)"
                }
            }
        }
    }
}
