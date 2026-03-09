import Foundation

// MARK: - CLI für OpenClark

/// Einfaches CLI zum Umbenennen von Dateien nach dem OpenClark-Schema.
/// Usage:
///   openclark rename <datei>
///   openclark rename --dry-run <datei>
///   openclark rename --folder <ordner>
///   openclark rename --folder --dry-run <ordner>
///   openclark --help
///   openclark --version

enum OpenClarkCLI {
    static func run() {
        let args = Array(CommandLine.arguments.dropFirst())

        guard !args.isEmpty else {
            printUsage()
            exit(0)
        }

        // Flags parsen
        if args.contains("--help") || args.contains("-h") {
            printUsage()
            exit(0)
        }

        if args.contains("--version") || args.contains("-v") {
            print("OpenClark CLI v0.1.0")
            exit(0)
        }

        // Erster Befehl muss "rename" sein
        guard args.first == "rename" else {
            printError("Unbekannter Befehl: \(args.first ?? "")")
            printUsage()
            exit(1)
        }

        let remaining = Array(args.dropFirst())
        let dryRun = remaining.contains("--dry-run") || remaining.contains("-n")
        let isFolder = remaining.contains("--folder") || remaining.contains("-f")
        let recursive = remaining.contains("--recursive") || remaining.contains("-r")
        let verbose = remaining.contains("--verbose") || remaining.contains("-V")

        // Pfad extrahieren (letztes Argument das kein Flag ist)
        let flags: Set<String> = ["--dry-run", "-n", "--folder", "-f", "--recursive", "-r", "--verbose", "-V"]
        let paths = remaining.filter { !flags.contains($0) }

        guard let targetPath = paths.first else {
            printError("Kein Pfad angegeben.")
            printUsage()
            exit(1)
        }

        let expandedPath = (targetPath as NSString).expandingTildeInPath
        let absolutePath: String
        if expandedPath.hasPrefix("/") {
            absolutePath = expandedPath
        } else {
            absolutePath = (FileManager.default.currentDirectoryPath as NSString)
                .appendingPathComponent(expandedPath)
        }

        let fm = FileManager.default

        if isFolder {
            // Ordner-Modus
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: absolutePath, isDirectory: &isDir), isDir.boolValue else {
                printError("Ordner nicht gefunden: \(absolutePath)")
                exit(1)
            }
            processFolder(absolutePath, dryRun: dryRun, recursive: recursive, verbose: verbose)
        } else {
            // Einzelne Datei
            guard fm.fileExists(atPath: absolutePath) else {
                printError("Datei nicht gefunden: \(absolutePath)")
                exit(1)
            }
            processFile(absolutePath, dryRun: dryRun, verbose: verbose)
        }
    }

    // MARK: - Datei verarbeiten

    static func processFile(_ path: String, dryRun: Bool, verbose: Bool) {
        let filename = (path as NSString).lastPathComponent

        // Filter prüfen
        if FileFilters.shouldSkip(filename: filename, filePath: path) {
            if verbose {
                printInfo("Übersprungen (Filter): \(filename)")
            }
            return
        }

        // Analyse
        let ext = (filename as NSString).pathExtension.lowercased()
        var category: String?
        var description: String?
        var source = "filename"

        // Stufe 1: Keyword auf Dateiname
        if let match = KeywordMatcher.matchFilename(filename) {
            if verbose {
                printInfo("  Keyword-Match: \(match.category) (Konfidenz: \(String(format: "%.2f", match.confidence)))")
            }
            if match.confidence >= 0.5 {
                category = match.category
                description = match.description
                source = "filename"
            }
        }

        // Stufe 2: PDF-Inhalt
        if category == nil && PDFTextExtractor.isPDF(path) {
            if let pdfText = PDFTextExtractor.extract(from: path) {
                let (pdfCat, pdfConf) = KeywordMatcher.detectCategory(from: pdfText)
                if verbose {
                    printInfo("  PDF-Keywords: \(pdfCat ?? "keine") (Konfidenz: \(String(format: "%.2f", pdfConf)))")
                }
                if let cat = pdfCat, pdfConf >= 0.3 {
                    category = cat
                    source = "pdf_keywords"
                }
            }
        }

        // Fallback
        if category == nil {
            category = CategoryDefinitions.fallbackCategory
            source = "filename"
        }

        // Beschreibung extrahieren
        if description == nil || description!.isEmpty {
            var desc = (filename as NSString).deletingPathExtension.lowercased()
            desc = desc.replacingOccurrences(of: #"\d{4}[-_.]\d{2}[-_.]\d{2}"#, with: "", options: .regularExpression)
            desc = desc.replacingOccurrences(of: #"[-_.\s]+"#, with: "-", options: .regularExpression)
            desc = desc.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            description = desc
        }

        // Name generieren
        let newName = NameGenerator.generate(
            originalPath: path,
            category: category!,
            description: description ?? "Unbenannt"
        )

        guard let proposedName = newName else {
            if verbose {
                printInfo("Keine Änderung nötig: \(filename)")
            }
            return
        }

        // Gleicher Name?
        if proposedName == filename {
            if verbose {
                printInfo("Name bereits korrekt: \(filename)")
            }
            return
        }

        let directory = (path as NSString).deletingLastPathComponent
        let finalName = NameGenerator.resolveConflict(directory: directory, proposedName: proposedName)
        let newPath = (directory as NSString).appendingPathComponent(finalName)

        if dryRun {
            printDryRun(filename, to: finalName, source: source)
        } else {
            do {
                try FileManager.default.moveItem(atPath: path, toPath: newPath)
                printSuccess(filename, to: finalName, source: source)
            } catch {
                printError("Fehler beim Umbenennen von \(filename): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Ordner verarbeiten

    static func processFolder(_ path: String, dryRun: Bool, recursive: Bool, verbose: Bool) {
        let fm = FileManager.default
        let excludedDirs = FileFilters.effectiveExcludedDirectories()

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: recursive ? [] : [.skipsSubdirectoryDescendants]
        ) else {
            printError("Kann Ordner nicht lesen: \(path)")
            return
        }

        var fileCount = 0
        var renamedCount = 0
        var skippedCount = 0

        print("📂 Verarbeite Ordner: \(abbreviatePath(path))")
        if dryRun {
            print("   Modus: DRY-RUN (keine Änderungen)")
        }
        print("")

        for case let fileURL as URL in enumerator {
            // Ordner-Ausschlüsse
            if let isDir = try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory, isDir {
                if excludedDirs.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            fileCount += 1
            let filePath = fileURL.path
            let filename = fileURL.lastPathComponent

            // Filter prüfen
            if FileFilters.shouldSkip(filename: filename, filePath: filePath) {
                skippedCount += 1
                if verbose {
                    printInfo("Übersprungen: \(filename)")
                }
                continue
            }

            processFile(filePath, dryRun: dryRun, verbose: verbose)
            renamedCount += 1
        }

        print("")
        print("─────────────────────────────────────")
        print("  Dateien gesamt:     \(fileCount)")
        print("  Verarbeitet:        \(renamedCount)")
        print("  Übersprungen:       \(skippedCount)")
        if dryRun {
            print("  Modus:              DRY-RUN")
        }
        print("─────────────────────────────────────")
    }

    // MARK: - Output Helpers

    static func printSuccess(_ from: String, to: String, source: String) {
        print("  ✅ \(from)")
        print("     → \(to)  [\(sourceBadge(source))]")
    }

    static func printDryRun(_ from: String, to: String, source: String) {
        print("  👁 \(from)")
        print("     → \(to)  [\(sourceBadge(source))] (Vorschau)")
    }

    static func printError(_ message: String) {
        FileHandle.standardError.write("❌ \(message)\n".data(using: .utf8)!)
    }

    static func printInfo(_ message: String) {
        print("  ℹ️  \(message)")
    }

    static func printUsage() {
        print("""
        OpenClark CLI - Intelligentes Datei-Umbenennen

        USAGE:
          openclark rename <datei>                    Datei umbenennen
          openclark rename --dry-run <datei>          Simulation (keine Änderung)
          openclark rename --folder <ordner>          Alle Dateien im Ordner
          openclark rename --folder -r <ordner>       Inkl. Unterordner

        FLAGS:
          --dry-run, -n       Nur simulieren, nichts umbenennen
          --folder, -f        Ordner statt Einzeldatei
          --recursive, -r     Unterordner einschließen (nur mit --folder)
          --verbose, -V       Detaillierte Ausgabe
          --help, -h          Diese Hilfe anzeigen
          --version, -v       Version anzeigen

        NAMENSSCHEMA:
          YYYY-MM-DD_Kategorie_Beschreibung.ext
          Beispiel: 2024-01-15_Rechnung_Vodafone-Q4.pdf

        BEISPIELE:
          openclark rename rechnung_vodafone.pdf
          openclark rename -n ~/Downloads/scan123.pdf
          openclark rename -f ~/Documents/Rechnungen
          openclark rename -f -r -n ~/Documents
        """)
    }

    static func sourceBadge(_ source: String) -> String {
        switch source {
        case "filename": return "Dateiname"
        case "pdf_keywords": return "PDF"
        case "llm": return "KI"
        default: return source
        }
    }

    static func abbreviatePath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}

// Entry point
OpenClarkCLI.run()
