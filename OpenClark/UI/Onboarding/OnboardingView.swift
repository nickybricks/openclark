import SwiftUI

/// 3-Schritt Onboarding beim ersten App-Start.
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var selectedFolders: [String] = Defaults.watchedDirectories
    @State private var enableAI = false
    @State private var apiKey = ""

    private let config = AppConfig.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                    Text("OpenClark")
                        .font(.title)
                        .fontWeight(.bold)
                }
                Spacer()
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Steps indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)

            // Content
            Group {
                switch currentStep {
                case 0: step1FolderPicker
                case 1: step2AISetup
                case 2: step3Done
                default: step3Done
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Zurück") {
                        withAnimation { currentStep -= 1 }
                    }
                }

                Spacer()

                if currentStep < 2 {
                    Button("Weiter") {
                        withAnimation { advanceStep() }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Fertig") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 480, height: 420)
    }

    // MARK: - Step 1: Ordner-Picker

    private var step1FolderPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welche Ordner soll ich überwachen?")
                .font(.headline)

            Text("Neue Dateien in diesen Ordnern werden automatisch umbenannt.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(selectedFolders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)
                        Text(folder.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                        Spacer()
                        Button {
                            selectedFolders.removeAll { $0 == folder }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .frame(minHeight: 100)

            Button {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    if !selectedFolders.contains(url.path) {
                        selectedFolders.append(url.path)
                    }
                }
            } label: {
                Label("Ordner hinzufügen", systemImage: "plus.circle")
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 2: KI-Setup

    private var step2AISetup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KI-Analyse aktivieren?")
                .font(.headline)

            Text("Mit KI werden auch komplexe Dateien korrekt erkannt. Ohne KI funktioniert die Keyword-Erkennung trotzdem für ~80% der Fälle.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle("KI-Analyse aktivieren", isOn: $enableAI)
                .toggleStyle(.switch)
                .padding(.vertical, 4)

            if enableAI {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key (optional)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        SecureField("sk-...", text: $apiKey)

                        Text("Du kannst auch erstmal ohne Key starten – die 14-Tage Testphase wird automatisch aktiviert.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
            } else {
                GroupBox {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Keyword-Erkennung funktioniert auch ohne KI. Du kannst KI jederzeit später in den Einstellungen aktivieren.")
                            .font(.caption)
                    }
                    .padding(4)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 3: Fertig

    private var step3Done: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Fertig!")
                .font(.title)
                .fontWeight(.bold)

            Text("OpenClark arbeitet jetzt im Hintergrund.\nNeue Dateien werden automatisch umbenannt.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 4) {
                Label("\(selectedFolders.count) Ordner überwacht", systemImage: "folder")
                Label(enableAI ? "KI-Analyse aktiv" : "Keyword-Modus", systemImage: enableAI ? "cpu" : "text.magnifyingglass")
            }
            .font(.callout)
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Actions

    private func advanceStep() {
        if currentStep == 0 {
            // Ordner speichern
            config.update { $0.watchedDirectories = selectedFolders }
        }
        currentStep += 1
    }

    private func completeOnboarding() {
        config.update { conf in
            conf.watchedDirectories = selectedFolders
            conf.onboardingCompleted = true
            if enableAI {
                conf.llmProvider = .anthropic
                if !apiKey.isEmpty {
                    conf.apiKey = apiKey
                }
            } else {
                conf.llmProvider = .none
            }
        }
        isPresented = false
    }
}
