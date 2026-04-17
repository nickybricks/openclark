import SwiftUI

/// Inhalt des Menubar-Dropdowns.
struct MenuBarView: View {
    @ObservedObject var processor: FileProcessor
    @Environment(\.openWindow) private var openWindow

    private var config: AppConfig { AppConfig.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status Toggle
            Button {
                processor.toggle()
            } label: {
                HStack {
                    Circle()
                        .fill(processor.isActive ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(processor.isActive ? "Aktiv" : "Pausiert")

                    if config.config.dryRun {
                        Text("(Vorschau)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .keyboardShortcut("p")

            // Counter
            Text("Heute: \(processor.todayCount) umbenannt")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)

            // Fehler-Anzeige
            if let error = processor.lastError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .lineLimit(2)
                }
                .font(.caption)
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }

            Divider()

            // Letzte Umbenennungen
            if processor.recentRenames.isEmpty {
                Text("Keine Umbenennungen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
            } else {
                ForEach(processor.recentRenames, id: \.id) { rename in
                    Button {
                        if !rename.dryRun {
                            NSWorkspace.shared.selectFile(
                                rename.newPath,
                                inFileViewerRootedAtPath: ""
                            )
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                if rename.dryRun {
                                    Image(systemName: "eye")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Text(rename.newName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                SourceBadge(source: rename.source)
                            }
                            Text(rename.originalName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .disabled(rename.dryRun)
                }

                Divider()

                Button("Alle anzeigen...") {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Divider()

            // Einstellungen
            Button("Einstellungen...") {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",")

            Divider()

            // Beenden
            Button("Beenden") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .frame(width: 320)
    }
}
