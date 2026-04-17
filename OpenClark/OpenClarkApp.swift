import SwiftUI
import os.log

@main
struct OpenClarkApp: App {
    @StateObject private var processor: FileProcessor
    @State private var showOnboarding: Bool

    private let database: DatabaseManager
    private let logger = Logger(subsystem: "com.openclark", category: "app")

    init() {
        // Sprache aus Config setzen BEVOR UI geladen wird
        let savedLang = AppConfig.shared.config.language
        UserDefaults.standard.set([savedLang], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // Datenbank initialisieren
        let db: DatabaseManager
        do {
            db = try DatabaseManager()
        } catch {
            fatalError("Datenbank konnte nicht initialisiert werden: \(error)")
        }
        self.database = db

        let config = AppConfig.shared
        let proc = FileProcessor(database: db, config: config)
        _processor = StateObject(wrappedValue: proc)
        _showOnboarding = State(initialValue: !config.config.onboardingCompleted)

        // Config beim ersten Start speichern
        if !config.config.onboardingCompleted {
            config.save()
        }

        logger.info("OpenClark gestartet")
    }

    var body: some Scene {
        // Menubar
        MenuBarExtra {
            MenuBarView(processor: processor)
        } label: {
            Image(systemName: "doc.text.magnifyingglass")
                .symbolRenderingMode(.hierarchical)
        }

        // Settings-Fenster
        Window("OpenClark Einstellungen", id: "settings") {
            LocalizedSettingsWrapper(
                processor: processor,
                database: database,
                showOnboarding: $showOnboarding
            )
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// Wrapper der LanguageManager beobachtet, ohne den App-Body zu invalidieren.
/// So bleibt MenuBarExtra stabil bei Sprachwechsel.
private struct LocalizedSettingsWrapper: View {
    @ObservedObject var processor: FileProcessor
    let database: DatabaseManager
    @Binding var showOnboarding: Bool
    @StateObject private var languageManager = LanguageManager.shared

    var body: some View {
        ZStack {
            SettingsView(processor: processor, database: database)
                .id(languageManager.refreshID)
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
                .onAppear {
                    if processor.isActive {
                        processor.start()
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(isPresented: $showOnboarding)
                }

            if languageManager.isTransitioning {
                LanguageTransitionOverlay()
                    .transition(.opacity)
            }
        }
    }
}
