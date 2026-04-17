import SwiftUI

/// Aktivität-Tab: History-Liste aller Umbenennungen mit Undo.
struct ActivityTab: View {
    @ObservedObject var processor: FileProcessor
    @State private var allRenames: [RenameRecord] = []
    @State private var totalCount: Int = 0
    @State private var showClearConfirmation = false
    @State private var filter: ActivityFilter = .all
    @State private var selectedIDs: Set<Int64?> = []
    @State private var isDryRun: Bool = AppConfig.shared.config.dryRun

    private let database: DatabaseManager
    private let config = AppConfig.shared
    private let pageSize = 200

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
                    if !selectedIDs.isEmpty {
                        let revertableCount = selectedIDs.compactMap { $0 }.filter { id in
                            filteredRenames.first(where: { $0.id == id }).map { !$0.dryRun && !$0.undone } ?? false
                        }.count
                        Button("Rückgängig (\(revertableCount))") {
                            revertSelected()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .disabled(revertableCount == 0)

                        Button("Abbrechen") {
                            selectedIDs = []
                        }
                        .buttonStyle(.bordered)
                    }

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

            // Dry-Run-Banner
            if isDryRun {
                HStack(spacing: 8) {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.orange)
                    Text("Vorschau-Modus aktiv – Dateien werden nicht wirklich umbenannt.")
                        .font(.caption)
                    Spacer()
                    Button("Deaktivieren") {
                        config.update { $0.dryRun = false }
                        isDryRun = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.12))
            }

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
                List(selection: $selectedIDs) {
                    ForEach(filteredRenames, id: \.id) { record in
                        RecentRenameRow(
                            record: record,
                            showUndo: !record.dryRun && selectedIDs.isEmpty,
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
                            },
                            onReprocess: {
                                processor.redoRename(record: record)
                                loadHistory()
                            }
                        )
                    }
                    if allRenames.count < totalCount {
                        HStack {
                            Spacer()
                            Button("Mehr laden (\(totalCount - allRenames.count) weitere)") {
                                loadMore()
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .onAppear {
            isDryRun = config.config.dryRun
            loadHistory()
        }
        .onChange(of: filter) {
            selectedIDs = []
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
            totalCount = try database.renameCount()
            allRenames = try database.allRenames(limit: pageSize, offset: 0)
        } catch {
            allRenames = []
            totalCount = 0
        }
    }

    private func loadMore() {
        do {
            let next = try database.allRenames(limit: pageSize, offset: allRenames.count)
            allRenames.append(contentsOf: next)
        } catch {}
    }

    private func revertSelected() {
        let ids = selectedIDs.compactMap { $0 }.filter { id in
            filteredRenames.first(where: { $0.id == id }).map { !$0.dryRun && !$0.undone } ?? false
        }
        processor.undoRenames(ids: ids)
        selectedIDs = []
        loadHistory()
    }

    private func clearHistory() {
        do {
            try database.clearHistory()
            allRenames = []
            totalCount = 0
            processor.refreshState()
        } catch {}
    }
}
