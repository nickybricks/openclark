# OpenClark – Kontext für Claude in Xcode

## Was ist OpenClark?
macOS Menubar-App (Swift/SwiftUI) die Dateien automatisch umbenennt.
Überwacht Ordner -> analysiert neue Dateien -> benennt nach Schema um.
Open Source, MIT Lizenz. GitHub: github.com/nickybricks/openclark

## Tech Stack
- Swift 6, SwiftUI, macOS 14+
- SQLite via GRDB.swift (v7.x)
- FSEvents für File Watching + Polling-Fallback
- PDFKit für PDF-Analyse
- URLSession für LLM API Calls
- SMAppService für Launch at Login

## Namensschema
Format: YYYY-MM-DD_Kategorie_Beschreibung.ext
Beispiel: 2024-01-15_Rechnung_Strom-Q4.pdf
Regeln: Keine Umlaute (ae/oe/ue/ss), keine Sonderzeichen, Capitalize, Bindestrich zwischen Wörtern

## Text-Bereinigung
- Umlaute: ä->ae, ö->oe, ü->ue, ß->ss
- Unicode NFKD normalisieren, nur ASCII behalten
- Leerzeichen -> Bindestriche
- Erster Buchstabe jedes Worts groß

## 3-Stufige Analyse-Pipeline
1. Keyword-Matching auf Dateinamen -> source: "filename"
2. PDF-Text + Keyword-Matching -> source: "pdf_keywords"
3. LLM API Fallback -> source: "llm"
Konfidenz-Schwellwert: 0.5 (darunter -> nächste Stufe)

## Datum-Hierarchie
1. Aus PDF-Inhalt (PDFKit)
2. Aus Dateiname (Regex)
3. Erstellungsdatum (Filesystem)

## Kritische Logik
- Snapshot beim ersten Start: bestehende Dateien NICHT umbenennen
- Datei-Stabilitätsprüfung: Größe muss 2x stabil sein bevor Rename
- iCloud: Placeholder erkennen (.filename.ext.icloud), Download triggern, moved-Events verarbeiten. Längerer Stability-Timeout (120s) für iCloud-Dateien.
- Schema-Check: bereits benannte Dateien überspringen
- Dry-Run: Simulation in DB speichern mit dryRun=true, VORSCHAU Badge im UI
- Error Handling: Permission-Check, Lock-Check, Disk-Full-Check vor Rename

## Trial-Logik
- 14 Tage Trial mit geteiltem OpenClark API Key
- Bei Budget-Erschöpfung: Fallback auf Keyword-Modus
- Nach Trial: eigener Key oder Keyword-only Modus

## Lokalisierung
- Localizable.xcstrings mit DE (Quellsprache) + EN
- SwiftUI Text() nutzt automatisch LocalizedStringKey
- Alle UI-Strings in beiden Sprachen verfügbar

## Projektstruktur
- `OpenClark/Core/` - Geschäftslogik (TextSanitizer, DateExtractor, KeywordMatcher, FileWatcher, etc.)
- `OpenClark/LLM/` - LLM-Provider (Anthropic, OpenAI, Ollama, Custom)
- `OpenClark/Database/` - GRDB Models und DatabaseManager (v1_initial + v2_dryRun Migrationen)
- `OpenClark/Config/` - AppConfig, ConfigModels, Defaults
- `OpenClark/UI/` - SwiftUI Views (MenuBar, Settings, Onboarding)
- `OpenClark/Localization/` - Localizable.xcstrings (DE + EN)
- `OpenClarkCLI/` - Kommandozeilen-Tool (teilt Core/LLM/Database/Config mit App)

## Build
- Xcode-Projekt generiert via xcodegen (project.yml)
- App: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme OpenClark build`
- CLI: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme OpenClarkCLI build`

## CLI
- `openclark rename <datei>` – Einzelne Datei umbenennen
- `openclark rename --dry-run <datei>` – Simulation
- `openclark rename --folder <ordner>` – Alle Dateien im Ordner
- `openclark rename --folder --recursive <ordner>` – Inkl. Unterordner

## Release
- GitHub Actions Workflow: `.github/workflows/release.yml`
- Automatischer .dmg + CLI .tar.gz Build bei Git-Tag `v*`
- Homebrew Cask Template: `Homebrew/openclark.rb`
