import SwiftUI
import ServiceManagement

/// Allgemein-Tab: Launch at Login, Dry-Run, Sprache.
struct GeneralTab: View {
    @State private var launchAtLogin: Bool
    @State private var dryRun: Bool
    @State private var language: String
    @State private var launchAtLoginError: String?

    private let config = AppConfig.shared

    init() {
        let c = AppConfig.shared.config
        _launchAtLogin = State(initialValue: c.launchAtLogin)
        _dryRun = State(initialValue: c.dryRun)
        _language = State(initialValue: c.language)
    }

    var body: some View {
        Form {
            // Launch at Login
            Section {
                Toggle("Beim Anmelden starten", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                        config.update { $0.launchAtLogin = newValue }
                    }

                if let error = launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Label("Autostart", systemImage: "power")
            }

            // Dry-Run
            Section {
                Toggle("Vorschau-Modus (Dry-Run)", isOn: $dryRun)
                    .onChange(of: dryRun) { _, newValue in
                        config.update { $0.dryRun = newValue }
                    }

                Text("Wenn aktiv, werden Umbenennungen nur simuliert – keine Dateien geändert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Modus", systemImage: "eye")
            }

            // Sprache
            Section {
                Picker("Sprache", selection: $language) {
                    Text("Deutsch").tag("de")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented)
                .onChange(of: language) { _, newValue in
                    LanguageManager.shared.switchLanguage(to: newValue)
                }
            } header: {
                Label("Sprache", systemImage: "globe")
            }

            // Info
            Section {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")
                LabeledContent("Config-Pfad", value: config.configPath)
                    .textSelection(.enabled)
                LabeledContent("Datenbank", value: DatabaseManager.databasePath())
                    .textSelection(.enabled)
            } header: {
                Label("Info", systemImage: "info.circle")
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Fehler: \(error.localizedDescription)"
        }
    }
}
