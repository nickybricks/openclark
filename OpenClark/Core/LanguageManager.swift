import SwiftUI

/// Verwaltet Sprachwechsel zur Laufzeit ohne App-Neustart.
/// Die Sprache wird über .environment(\.locale) an den Root-Views gesetzt.
@MainActor
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    /// Aktuelle Sprache ("de" oder "en")
    @Published var currentLanguage: String

    /// Wird true während des Sprachwechsels (für Overlay)
    @Published var isTransitioning = false

    /// Ändert sich bei jedem Sprachwechsel → erzwingt View-Neuerstellung via .id()
    @Published var refreshID = UUID()

    private init() {
        currentLanguage = AppConfig.shared.config.language
    }

    func switchLanguage(to newLanguage: String) {
        guard newLanguage != currentLanguage else { return }

        // Overlay einblenden
        withAnimation(.easeInOut(duration: 0.25)) {
            isTransitioning = true
        }

        // Config + UserDefaults aktualisieren (für nächsten App-Start)
        AppConfig.shared.update { $0.language = newLanguage }
        UserDefaults.standard.set([newLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()

        // Kurze Verzögerung, dann UI komplett neu aufbauen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.currentLanguage = newLanguage
            self.refreshID = UUID()

            // Overlay nach kurzem Moment ausblenden
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    self.isTransitioning = false
                }
            }
        }
    }
}

// MARK: - Overlay View

/// Halbtransparentes Overlay während des Sprachwechsels.
struct LanguageTransitionOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25)

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Image(systemName: "globe")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .ignoresSafeArea()
    }
}
