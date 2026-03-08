# OpenClark

**Intelligentes Datei-Umbenennen für macOS.** OpenClark lebt in der Menubar, überwacht Ordner und benennt neue Dateien automatisch nach einem einheitlichen Schema um.

```
rechnung_vodafone_jan.pdf  →  2024-01-15_Rechnung_Vodafone-Januar.pdf
scan0042.pdf               →  2024-03-08_Mietvertrag_Musterstadt.pdf
bewerbung_final_v3.docx    →  2024-02-20_Bewerbung_Software-Engineer.docx
```

## Features

- **Unsichtbar:** Läuft als Menubar-App im Hintergrund
- **3-Stufen Analyse:** Keyword-Matching → PDF-Analyse → KI-Fallback
- **Multi-Provider KI:** Claude, GPT, Ollama oder eigener Endpoint
- **14-Tage Trial:** Sofort loslegen, kein API Key nötig
- **Vorschau-Modus:** Umbenennungen simulieren ohne Dateien zu ändern
- **iCloud-Support:** Erkennt Placeholder, triggert Downloads
- **Undo:** Jede Umbenennung rückgängig machbar
- **CLI:** Auch als Kommandozeilen-Tool nutzbar
- **Zweisprachig:** Deutsch + Englisch
- **Open Source:** MIT Lizenz, keine Telemetrie

## Namensschema

```
YYYY-MM-DD_Kategorie_Beschreibung.ext
```

**Kategorien:** Rechnung, Vertrag, Mietvertrag, Arbeitsvertrag, Gehaltsnachweis, Angebot, Lebenslauf, Bewerbung, Versicherung, Ausweis, Steuererklaerung, Wohnungsbewerbung, Kuendigung, Zeugnis, Bescheinigung, Dokument

**Regeln:**
- Keine Umlaute (ä→ae, ö→oe, ü→ue, ß→ss)
- Keine Sonderzeichen, nur ASCII
- Bindestriche statt Leerzeichen
- Jedes Wort groß geschrieben

## Installation

### App (GUI)

1. [Neueste Version herunterladen](https://github.com/nickybricks/openclark/releases/latest) (`.dmg`)
2. `OpenClark.app` in den Applications-Ordner ziehen
3. App starten – sie erscheint als Icon in der Menubar

### CLI

```bash
# Via Release
tar -xzf openclark-cli-*.tar.gz
sudo mv openclark /usr/local/bin/
openclark --help
```

### Aus Source bauen

```bash
# Voraussetzungen: Xcode 16+, xcodegen
brew install xcodegen

git clone https://github.com/nickybricks/openclark.git
cd openclark
xcodegen generate
xcodebuild -scheme OpenClark build        # App
xcodebuild -scheme OpenClarkCLI build     # CLI
```

## Konfiguration

### Erster Start (Onboarding)

1. **Ordner wählen** – Welche Ordner sollen überwacht werden? (Standard: Documents + Downloads)
2. **KI-Setup** – Optional KI aktivieren für bessere Erkennung
3. **Fertig** – OpenClark arbeitet im Hintergrund

### Einstellungen

Über das Menubar-Icon → "Einstellungen":

| Tab | Beschreibung |
|---|---|
| **Allgemein** | Autostart, Vorschau-Modus, Sprache |
| **Ordner** | Überwachte Ordner verwalten, Ausschlüsse |
| **KI** | Provider, API Key, Modell, Konfidenz |
| **Aktivität** | History, Undo, Filter |

### KI-Provider

| Provider | Modelle | API Key |
|---|---|---|
| **Anthropic** | Claude Haiku/Sonnet/Opus | console.anthropic.com |
| **OpenAI** | GPT-4o Mini/4o | platform.openai.com |
| **Ollama** | Llama, Mistral, etc. | Nicht nötig (lokal) |
| **Custom** | Beliebig | Je nach Endpoint |

Die KI wird nur als Fallback genutzt, wenn Keyword-Matching keine sichere Zuordnung ergibt.

## CLI Nutzung

```bash
# Einzelne Datei umbenennen
openclark rename rechnung_vodafone.pdf

# Nur Vorschau (keine Änderung)
openclark rename --dry-run rechnung_vodafone.pdf

# Alle Dateien in einem Ordner
openclark rename --folder ~/Documents/Rechnungen

# Inkl. Unterordner + Vorschau
openclark rename --folder --recursive --dry-run ~/Documents
```

## Analyse-Pipeline

OpenClark analysiert Dateien in 3 Stufen:

```
Neue Datei erkannt
       │
       ▼
┌──────────────────┐
│ Stufe 1: Keyword │  Dateiname → Kategorie-Keywords abgleichen
│  auf Dateinamen  │  Konfidenz-Score berechnen
└────────┬─────────┘
         │ Score < Schwellwert?
         ▼
┌──────────────────┐
│ Stufe 2: PDF +   │  Text aus PDF extrahieren (PDFKit)
│  Keyword-Match   │  Keywords im PDF-Text suchen
└────────┬─────────┘
         │ Kein Treffer?
         ▼
┌──────────────────┐
│ Stufe 3: LLM     │  KI-API mit Dateiname + PDF-Text
│  API Fallback    │  Strukturiertes JSON zurück
└────────┬─────────┘
         │
         ▼
   Datei umbenennen
```

## Tech Stack

- **Swift 6** / **SwiftUI** / macOS 14+ (Sonoma)
- **GRDB.swift** – SQLite Wrapper (einzige externe Dependency)
- **FSEvents** – File System Events für Ordner-Überwachung
- **PDFKit** – Native PDF-Textextraktion
- **URLSession** – LLM API Calls (kein externes SDK)
- **SMAppService** – Launch at Login

## Projektstruktur

```
OpenClark/
├── Core/               # Geschäftslogik
│   ├── FileWatcher     # FSEvents + Polling
│   ├── FileProcessor   # 3-Stufen Pipeline
│   ├── KeywordMatcher  # Kategorie-Erkennung
│   ├── NameGenerator   # Namensschema-Builder
│   ├── TextSanitizer   # Umlaut + Unicode
│   └── ...
├── LLM/                # KI-Provider
│   ├── AnthropicProvider
│   ├── OpenAIProvider
│   ├── OllamaProvider
│   └── CustomProvider
├── Database/           # GRDB/SQLite
├── Config/             # JSON-Konfiguration
├── UI/                 # SwiftUI Views
│   ├── MenuBarView
│   ├── SettingsWindow
│   ├── Onboarding/
│   └── Components/
└── Localization/       # DE + EN

OpenClarkCLI/
└── main.swift          # CLI Tool
```

## Lizenz

[MIT](LICENSE) – Frei nutzbar, auch kommerziell.

## Mitwirken

Pull Requests willkommen! Bitte:
1. Fork erstellen
2. Feature Branch (`git checkout -b feature/mein-feature`)
3. Änderungen committen
4. PR erstellen

---

Gebaut mit Swift und Claude.
