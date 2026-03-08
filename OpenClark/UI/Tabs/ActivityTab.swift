import SwiftUI

/// Aktivität-Tab: History-Liste aller Umbenennungen mit Undo.
struct ActivityTab: View {
    @ObservedObject var processor: FileProcessor
    @State private var allRenames: [RenameRecord] = []
    @State private var showClearConfirmation = false
    @State private var filter: ActivityFilter = .all

    private let database: DatabaseManager

    enum ActivityFilter: String, CaseIterable {
        case all = "Alle"
        case actual = "Umbenannt"
        case dryRun = "Vorschau"
    }

    init(processor: FileProcessor, database: DatabaseManager) {
        self.processor = processor
        self.database = database
    }

    private var filteredRenames: [RenameRecord] {
        switch filter {
        case .all: return allRenames
        case .actual: return allRenames.filter { !$0.dryRun }
        case .dryRun: return allRenames.filter { $0.dryRun }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header mit Stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktivität")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Heute: \(processor.todayCount) Umbenennungen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Filter
                Picker("Filter", selection: $filter) {
                    ForEach(ActivityFilter.allCases, id: \.self) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                // Aktionen
                HStack(spacing: 8) {
                    Button {
                        loadHistory()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Aktualisieren")

                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("History löschen")
                    .disabled(allRenames.isEmpty)
                }
            }
            .padding()

            // Fehler-Banner
            if let error = processor.lastError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                    Spacer()
                    Button {
                        processor.lastError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
            }

            Divider()

            // Liste
            if filteredRenames.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: filter == .dryRun ? "eye" : "doc.text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(emptyStateTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(emptyStateSubtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(filteredRenames, id: \.id) { record in
                        RecentRenameRow(
                            record: record,
                            showUndo: !record.dryRun,
                            onUndo: {
                                if let id = record.id {
                                    processor.undoRename(id: id)
                                    loadHistory()
                                }
                            },
                            onReveal: {
                                if !record.dryRun {
                                    let path = record.undone ? record.originalPath : record.newPath
                                    NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                                }
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            loadHistory()
        }
        .alert("History löschen?", isPresented: $showClearConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("Alle \(allRenames.count) Einträge werden unwiderruflich gelöscht. Die Dateien selbst bleiben unverändert.")
        }
    }

    // MARK: - Empty State

    private var emptyStateTitle: String {
        switch filter {
        case .all: return "Noch keine Umbenennungen"
        case .actual: return "Keine echten Umbenennungen"
        case .dryRun: return "Keine Vorschau-Einträge"
        }
    }

    private var emptyStateSubtitle: String {
        switch filter {
        case .all: return "Neue Dateien in überwachten Ordnern werden automatisch umbenannt."
        case .actual: return "Echte Umbenennungen erscheinen hier, wenn der Vorschau-Modus deaktiviert ist."
        case .dryRun: return "Aktiviere den Vorschau-Modus in den Einstellungen, um Umbenennungen zu simulieren."
        }
    }

    // MARK: - Actions

    private func loadHistory() {
        do {
            allRenames = try database.allRenames()
        } catch {
            allRenames = []
        }
    }

    private func clearHistory() {
        do {
            try database.clearHistory()
            allRenames = []
            processor.refreshState()
        } catch {
            // Fehler ignorieren
        }
    }
}
