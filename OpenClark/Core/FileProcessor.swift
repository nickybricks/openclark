import Foundation
import os.log

/// Fehlertypen bei der Dateiverarbeitung.
enum ProcessingError: LocalizedError {
    case permissionDenied(String)
    case fileLocked(String)
    case diskFull
    case fileNotFound(String)
    case renameFailed(String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return "Keine Berechtigung: \(path)"
        case .fileLocked(let path):
            return "Datei gesperrt: \(path)"
        case .diskFull:
            return "Festplatte voll"
        case .fileNotFound(let path):
            return "Datei nicht gefunden: \(path)"
        case .renameFailed(let path, let underlying):
            return "Umbenennung fehlgeschlagen (\(path)): \(underlying.localizedDescription)"
        }
    }
}

/// Orchestriert die 3-Stufen Analyse-Pipeline und führt Umbenennungen durch.
@MainActor
final class FileProcessor: ObservableObject {

    @Published var isActive = true
    @Published var todayCount = 0
    @Published var recentRenames: [RenameRecord] = []
    @Published var lastError: String?

    private let database: DatabaseManager
    private let config: AppConfig
    private var fileWatcher: FileWatcher?
    private let llmService = LLMService()
    private let trialService: TrialService
    private let logger = Logger(subsystem: "com.openclark", category: "processor")

    /// Debounce: verhindere doppelte Verarbeitung
    private var processingPaths: Set<String> = []

    init(database: DatabaseManager, config: AppConfig) {
        self.database = database
        self.config = config
        self.trialService = TrialService(config: config)
        refreshState()
    }

    // MARK: - Start / Stop

    func start() {
        guard isActive else { return }

        // LLM konfigurieren
        Task {
            await llmService.configure(with: config.config)
            await trialService.startTrialIfNeeded()
        }

        // Snapshot beim ersten Start
        Task {
            await createSnapshotIfNeeded()
        }

        // FileWatcher starten
        fileWatcher = FileWatcher(config: config) { [weak self] path in
            guard let self else { return }
            Task { @MainActor in
                await self.handleNewFile(path)
            }
        }
        fileWatcher?.start()
        logger.info("FileProcessor gestartet")
    }

    func stop() {
        fileWatcher?.stop()
        fileWatcher = nil
        logger.info("FileProcessor gestoppt")
    }

    func toggle() {
        if isActive {
            stop()
        } else {
            start()
        }
        isActive.toggle()
    }

    // MARK: - Snapshot

    private func createSnapshotIfNeeded() async {
        do {
            let hasSnapshot = try database.hasSnapshot()
            if !hasSnapshot {
                logger.info("Erster Start: Erstelle Snapshot...")
                SnapshotManager.createSnapshot(
                    directories: config.config.watchedDirectories,
                    database: database,
                    recursive: config.config.recursive
                )
            }
        } catch {
            logger.error("Snapshot-Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - iCloud Handling

    /// Erkennt iCloud-Placeholder und triggert Download.
    private func handleICloudPlaceholder(_ path: String) {
        let filename = (path as NSString).lastPathComponent

        guard FileFilters.isICloudPlaceholder(filename) else { return }
        guard let realName = FileFilters.realNameFromICloudPlaceholder(filename) else { return }

        logger.info("iCloud-Placeholder erkannt: \(realName)")

        let url = URL(fileURLWithPath: path)
        do {
            // Download triggern – die echte Datei wird von FSEvents erkannt
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
            logger.info("iCloud-Download gestartet: \(realName)")
        } catch {
            logger.debug("iCloud-Download nicht möglich (evtl. kein iCloud-Pfad): \(error.localizedDescription)")
        }
    }

    // MARK: - Datei verarbeiten

    private func handleNewFile(_ path: String) async {
        let filename = (path as NSString).lastPathComponent

        // iCloud-Placeholder? → Download triggern, nicht verarbeiten
        if FileFilters.isICloudPlaceholder(filename) {
            handleICloudPlaceholder(path)
            return
        }

        // Doppelte Events ignorieren
        guard !processingPaths.contains(path) else { return }
        processingPaths.insert(path)
        defer { processingPaths.remove(path) }

        // Filter prüfen
        guard !FileFilters.shouldSkip(filename: filename, filePath: path) else { return }

        // In DB prüfen
        do {
            if try database.isProcessed(path) || database.isExistingFile(path) { return }
        } catch {
            return
        }

        logger.info("Neue Datei erkannt: \(filename)")

        // Verarbeitungsverzögerung
        let delay = config.config.processingDelay
        try? await Task.sleep(for: .seconds(delay))

        // Existiert die Datei noch?
        guard FileManager.default.fileExists(atPath: path) else {
            logger.debug("Datei existiert nicht mehr: \(filename)")
            return
        }

        // Berechtigungen prüfen
        guard checkPermissions(path: path) else { return }

        // Stabilitätsprüfung (längerer Timeout für iCloud-Dateien)
        let isICloud = FileFilters.isICloudPath(path)
        let stableTimeout: TimeInterval = isICloud ? 120.0 : 30.0
        let stable = await StabilityChecker.waitForStable(path: path, timeout: stableTimeout)
        guard stable else {
            logger.warning("Datei nicht stabil: \(filename)")
            return
        }

        // 3-Stufen Analyse-Pipeline
        let result = await analyzeFile(path: path, filename: filename)

        guard let newName = result.newName else {
            logger.debug("Keine Umbenennung nötig: \(filename)")
            return
        }

        // Dry-Run Modus: Ergebnis in DB speichern aber nicht umbenennen
        if config.config.dryRun {
            logger.info("[DRY-RUN] Würde umbenennen: \(filename) → \(newName)")

            let directory = (path as NSString).deletingLastPathComponent
            let finalName = NameGenerator.resolveConflict(directory: directory, proposedName: newName)
            let newPath = (directory as NSString).appendingPathComponent(finalName)

            let record = RenameRecord(
                originalPath: path,
                newPath: newPath,
                originalName: filename,
                newName: finalName,
                category: result.category,
                source: result.source,
                renamedAt: Date(),
                undone: false,
                dryRun: true
            )
            do {
                try database.recordRename(record)
                refreshState()
            } catch {
                logger.error("DB-Fehler (Dry-Run): \(error.localizedDescription)")
            }
            return
        }

        // Umbenennen
        let directory = (path as NSString).deletingLastPathComponent
        let finalName = NameGenerator.resolveConflict(directory: directory, proposedName: newName)
        let newPath = (directory as NSString).appendingPathComponent(finalName)

        do {
            // Zielverzeichnis beschreibbar?
            guard FileManager.default.isWritableFile(atPath: directory) else {
                throw ProcessingError.permissionDenied(directory)
            }

            // Datei gesperrt?
            if isFileLocked(path) {
                throw ProcessingError.fileLocked(path)
            }

            try FileManager.default.moveItem(atPath: path, toPath: newPath)
            logger.info("Umbenannt: \(filename) → \(finalName) (via \(result.source))")
            lastError = nil

            // In DB speichern
            let record = RenameRecord(
                originalPath: path,
                newPath: newPath,
                originalName: filename,
                newName: finalName,
                category: result.category,
                source: result.source,
                renamedAt: Date(),
                undone: false,
                dryRun: false
            )
            try database.recordRename(record)
            try database.markProcessed(
                path: newPath,
                originalName: filename,
                newName: finalName,
                category: result.category
            )

            // UI aktualisieren
            refreshState()

        } catch let error as ProcessingError {
            lastError = error.errorDescription
            logger.error("Verarbeitungsfehler: \(error.errorDescription ?? "unbekannt")")
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteOutOfSpaceError {
            lastError = ProcessingError.diskFull.errorDescription
            logger.error("Festplatte voll!")
        } catch {
            lastError = ProcessingError.renameFailed(path, underlying: error).errorDescription
            logger.error("Fehler beim Umbenennen: \(error.localizedDescription)")
        }
    }

    // MARK: - Berechtigungen & Dateistatus

    /// Prüfe Lese- und Schreibberechtigung für eine Datei.
    private func checkPermissions(path: String) -> Bool {
        let fm = FileManager.default

        guard fm.isReadableFile(atPath: path) else {
            logger.warning("Keine Leseberechtigung: \(path)")
            lastError = ProcessingError.permissionDenied(path).errorDescription
            return false
        }

        let directory = (path as NSString).deletingLastPathComponent
        guard fm.isWritableFile(atPath: directory) else {
            logger.warning("Keine Schreibberechtigung: \(directory)")
            lastError = ProcessingError.permissionDenied(directory).errorDescription
            return false
        }

        return true
    }

    /// Prüfe ob eine Datei gesperrt ist (immutable flag).
    private func isFileLocked(_ path: String) -> Bool {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: path)
            if let immutable = attrs[.immutable] as? Bool, immutable {
                return true
            }
        } catch {
            // Im Zweifel: nicht gesperrt
        }
        return false
    }

    // MARK: - 3-Stufen Analyse-Pipeline

    private struct AnalysisResult {
        let newName: String?
        let category: String
        let source: String // "filename", "pdf_keywords", "llm"
    }

    private func analyzeFile(path: String, filename: String) async -> AnalysisResult {
        let ext = (filename as NSString).pathExtension.lowercased()
        let confidenceThreshold = config.config.confidenceThreshold

        // ── Stufe 1: Keyword-Matching auf Dateinamen ──
        if let match = KeywordMatcher.matchFilename(filename) {
            logger.info("  Stufe 1 (Dateiname): \(match.category), Konfidenz=\(String(format: "%.2f", match.confidence))")

            if match.confidence >= confidenceThreshold {
                // Klarer Treffer – aber bei PDFs evtl. LLM für bessere Beschreibung fragen
                if PDFTextExtractor.isPDF(path), await isLLMAvailable() {
                    if let pdfText = PDFTextExtractor.extract(from: path) {
                        let llmResult = await askLLM(filename: filename, ext: ext, text: pdfText)
                        if let llm = llmResult {
                            let newName = buildNameFromLLM(llm, path: path, ext: ext)
                            return AnalysisResult(newName: newName, category: llm.category, source: "llm")
                        }
                    }
                }

                // Keyword-Ergebnis verwenden
                let newName = NameGenerator.generate(
                    originalPath: path, category: match.category, description: match.description
                )
                return AnalysisResult(newName: newName, category: match.category, source: "filename")
            }
        }

        // ── Stufe 2: PDF-Text + Keyword-Matching ──
        if PDFTextExtractor.isPDF(path) {
            logger.info("  Stufe 2: Extrahiere PDF-Text...")
            if let pdfText = PDFTextExtractor.extract(from: path) {
                let (pdfCategory, pdfConfidence) = KeywordMatcher.detectCategory(from: pdfText)
                logger.info("  Stufe 2 (PDF-Keywords): \(pdfCategory ?? "nil"), Konfidenz=\(String(format: "%.2f", pdfConfidence))")

                if let cat = pdfCategory, pdfConfidence >= confidenceThreshold {
                    // Guter PDF-Keyword-Treffer
                    let desc = extractDescriptionFromFilename(filename)
                    let newName = NameGenerator.generate(
                        originalPath: path, category: cat, description: desc
                    )
                    return AnalysisResult(newName: newName, category: cat, source: "pdf_keywords")
                }

                // ── Stufe 3a: LLM mit PDF-Text ──
                if await isLLMAvailable() {
                    logger.info("  Stufe 3: Frage LLM (mit PDF-Text)...")
                    let llmResult = await askLLM(filename: filename, ext: ext, text: pdfText)
                    if let llm = llmResult {
                        let newName = buildNameFromLLM(llm, path: path, ext: ext)
                        return AnalysisResult(newName: newName, category: llm.category, source: "llm")
                    }
                }

                // Fallback auf PDF-Keyword-Ergebnis (auch wenn unter Schwellwert)
                if let cat = pdfCategory {
                    let desc = extractDescriptionFromFilename(filename)
                    let newName = NameGenerator.generate(
                        originalPath: path, category: cat, description: desc
                    )
                    return AnalysisResult(newName: newName, category: cat, source: "pdf_keywords")
                }
            }
        }

        // ── Stufe 3b: LLM nur mit Dateiname (kein PDF) ──
        if await isLLMAvailable() {
            logger.info("  Stufe 3: Frage LLM (nur Dateiname)...")
            let llmResult = await askLLM(
                filename: filename, ext: ext, text: "Dateiname: \(filename)"
            )
            if let llm = llmResult {
                let newName = buildNameFromLLM(llm, path: path, ext: ext)
                return AnalysisResult(newName: newName, category: llm.category, source: "llm")
            }
        }

        // ── Fallback: "Dokument" mit bereinigtem Dateinamen ──
        let stem = (filename as NSString).deletingPathExtension
        let desc = TextSanitizer.sanitize(stem)
        let newName = NameGenerator.generate(
            originalPath: path,
            category: CategoryDefinitions.fallbackCategory,
            description: desc
        )
        return AnalysisResult(
            newName: newName,
            category: CategoryDefinitions.fallbackCategory,
            source: "filename"
        )
    }

    // MARK: - LLM Helpers

    private func isLLMAvailable() async -> Bool {
        let providerType = config.config.llmProvider
        guard providerType != .none else { return false }
        return await trialService.isLLMAvailable()
    }

    private func askLLM(filename: String, ext: String, text: String) async -> LLMAnalysisResult? {
        await llmService.analyze(
            filename: filename,
            extension: ext,
            text: text,
            providerType: config.config.llmProvider
        )
    }

    private func buildNameFromLLM(_ llm: LLMAnalysisResult, path: String, ext: String) -> String? {
        let extSuffix = ext.isEmpty ? "" : ".\(ext)"
        let date = llm.date.isEmpty
            ? DateExtractor.extractBest(filename: (path as NSString).lastPathComponent, filePath: path).dateString
            : llm.date
        let desc = llm.description.isEmpty ? "Unbenannt" : llm.description

        let proposed = "\(date)_\(llm.category)_\(desc)\(extSuffix)"

        // Gleicher Name wie Original?
        if proposed == (path as NSString).lastPathComponent { return nil }
        // Matches Schema schon?
        if FileFilters.matchesSchema((path as NSString).lastPathComponent) { return nil }

        return proposed
    }

    /// Extrahiere Beschreibung aus Dateinamen (Datum/Extension entfernt).
    private func extractDescriptionFromFilename(_ filename: String) -> String {
        var desc = (filename as NSString).deletingPathExtension.lowercased()
        // Datum-Patterns entfernen
        desc = desc.replacingOccurrences(of: #"\d{4}[-_.]\d{2}[-_.]\d{2}"#, with: "", options: .regularExpression)
        desc = desc.replacingOccurrences(of: #"\d{4}[-_.]\d{2}"#, with: "", options: .regularExpression)
        // Trennzeichen normalisieren
        desc = desc.replacingOccurrences(of: #"[-_.\s]+"#, with: "-", options: .regularExpression)
        desc = desc.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return desc
    }

    // MARK: - State Refresh

    func refreshState() {
        do {
            todayCount = try database.todayRenameCount()
            recentRenames = try database.recentRenames(limit: 5)
        } catch {
            logger.error("State-Refresh Fehler: \(error.localizedDescription)")
        }
    }

    // MARK: - Undo

    func undoRename(id: Int64) {
        do {
            guard let record = try database.undoRename(id: id) else { return }

            // Dry-Run Einträge können nicht rückgängig gemacht werden
            if record.dryRun {
                refreshState()
                return
            }

            // Datei zurückbenennen
            if FileManager.default.fileExists(atPath: record.newPath) {
                // Ziel beschreibbar?
                let origDir = (record.originalPath as NSString).deletingLastPathComponent
                guard FileManager.default.isWritableFile(atPath: origDir) else {
                    lastError = "Keine Schreibberechtigung für Undo: \(origDir)"
                    logger.error("Undo-Fehler: Keine Schreibberechtigung für \(origDir)")
                    return
                }

                try FileManager.default.moveItem(atPath: record.newPath, toPath: record.originalPath)
                logger.info("Undo: \(record.newName) → \(record.originalName)")
                lastError = nil
            } else {
                lastError = "Datei nicht gefunden: \(record.newPath)"
                logger.warning("Undo nicht möglich: Datei existiert nicht mehr: \(record.newPath)")
            }

            refreshState()
        } catch {
            lastError = "Undo fehlgeschlagen: \(error.localizedDescription)"
            logger.error("Undo-Fehler: \(error.localizedDescription)")
        }
    }
}
