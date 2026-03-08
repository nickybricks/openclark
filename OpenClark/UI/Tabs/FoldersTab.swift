import SwiftUI

/// Ordner-Tab: Überwachte Ordner verwalten, Ausschlüsse, Rekursiv.
struct FoldersTab: View {
    @State private var watchedDirectories: [String]
    @State private var recursive: Bool
    @State private var processingDelay: Int
    @State private var pollInterval: Int

    @ObservedObject var processor: FileProcessor

    private let config = AppConfig.shared

    init(processor: FileProcessor) {
        self.processor = processor
        let c = AppConfig.shared.config
        _watchedDirectories = State(initialValue: c.watchedDirectories)
        _recursive = State(initialValue: c.recursive)
        _processingDelay = State(initialValue: c.processingDelay)
        _pollInterval = State(initialValue: c.pollInterval)
    }

    var body: some View {
        Form {
            // Überwachte Ordner
            Section {
                List {
                    ForEach(watchedDirectories, id: \.self) { dir in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.blue)
                            Text(abbreviatePath(dir))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                removeDirectory(dir)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .frame(minHeight: 80)

                HStack {
                    Button {
                        addDirectory()
                    } label: {
                        Label("Ordner hinzufügen", systemImage: "plus.circle.fill")
                    }

                    Spacer()

                    Text("\(watchedDirectories.count) Ordner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Überwachte Ordner", systemImage: "folder.badge.gearshape")
            }

            // Optionen
            Section {
                Toggle("Unterordner einschließen (Rekursiv)", isOn: $recursive)
                    .onChange(of: recursive) { _, newValue in
                        config.update { $0.recursive = newValue }
                    }

                Stepper(
                    "Verarbeitungsverzögerung: \(processingDelay)s",
                    value: $processingDelay,
                    in: 1...30
                )
                .onChange(of: processingDelay) { _, newValue in
                    config.update { $0.processingDelay = newValue }
                }

                Stepper(
                    "Polling-Intervall: \(pollInterval)s",
                    value: $pollInterval,
                    in: 10...120,
                    step: 10
                )
                .onChange(of: pollInterval) { _, newValue in
                    config.update { $0.pollInterval = newValue }
                }
            } header: {
                Label("Optionen", systemImage: "gearshape")
            }

            // Ausschlüsse (nur Info)
            Section {
                Text("Ignorierte Ordner: .Trash, node_modules, .git, __pycache__, .venv")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Ignorierte Dateien: Bilder, Musik, Video, Design, Systemdateien")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Ignorierte Präfixe: IMG_, Screenshot, Bildschirmfoto, .")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Ausschlüsse", systemImage: "eye.slash")
            }

            // Aktion
            Section {
                Button {
                    processExistingFiles()
                } label: {
                    Label("Bestehende Dateien jetzt verarbeiten", systemImage: "arrow.clockwise")
                }
                .help("Verarbeitet alle Dateien in den überwachten Ordnern, die noch nicht umbenannt wurden.")

                Text("Achtung: Dies benennt alle bestehenden Dateien um, die dem Namensschema noch nicht entsprechen.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } header: {
                Label("Aktionen", systemImage: "bolt")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Ordner zum Überwachen auswählen"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            if !watchedDirectories.contains(path) {
                watchedDirectories.append(path)
                config.update { $0.watchedDirectories = watchedDirectories }
            }
        }
    }

    private func removeDirectory(_ dir: String) {
        watchedDirectories.removeAll { $0 == dir }
        config.update { $0.watchedDirectories = watchedDirectories }
    }

    private func processExistingFiles() {
        // Restart mit neuem Snapshot → verarbeitet bestehende Dateien
        processor.stop()
        processor.start()
    }

    private func abbreviatePath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
