import Foundation

/// Alle Kategorien mit ihren Keywords, geordnet nach Priorität (spezifischere zuerst).
enum CategoryDefinitions {

    struct Category: Sendable {
        let name: String
        let keywords: [String]
    }

    /// Kategorien in Prioritätsreihenfolge (spezifischere zuerst).
    static let all: [Category] = [
        Category(name: "Arbeitsvertrag", keywords: [
            "arbeitsvertrag", "employment contract", "anstellungsvertrag",
        ]),
        Category(name: "Mietvertrag", keywords: [
            "mietvertrag", "untermietvertrag", "lease agreement", "rental contract",
        ]),
        Category(name: "Vertrag", keywords: [
            "vertrag", "contract", "agreement", "vereinbarung",
        ]),
        Category(name: "Rechnung", keywords: [
            "rechnung", "invoice", "receipt", "quittung", "beleg",
        ]),
        Category(name: "Gehaltsnachweis", keywords: [
            "gehaltsnachweis", "gehalt", "lohnabrechnung", "payslip",
            "salary", "entgeltabrechnung", "verdienstbescheinigung",
        ]),
        Category(name: "Angebot", keywords: [
            "angebot", "angebots-nr", "offer", "proposal", "kostenvoranschlag",
        ]),
        Category(name: "Lebenslauf", keywords: [
            "lebenslauf", "cv", "resume", "curriculum vitae",
        ]),
        Category(name: "Bewerbung", keywords: [
            "bewerbung", "application", "anschreiben", "motivationsschreiben",
        ]),
        Category(name: "Versicherung", keywords: [
            "versicherung", "insurance", "haftpflicht",
            "krankenversicherung", "hausrat", "police",
        ]),
        Category(name: "Ausweis", keywords: [
            "ausweis", "personalausweis", "reisepass", "passport",
            "fuehrerschein", "id card",
        ]),
        Category(name: "Steuererklaerung", keywords: [
            "steuererklaerung", "steuerbescheid", "einkommensteuerbescheid",
            "tax return", "elster",
        ]),
        Category(name: "Wohnungsbewerbung", keywords: [
            "wohnungsbewerbung", "mieterselbstauskunft", "schufa",
        ]),
        Category(name: "Kuendigung", keywords: [
            "kuendigung", "termination", "cancellation",
        ]),
        Category(name: "Zeugnis", keywords: [
            "zeugnis", "arbeitszeugnis", "zwischenzeugnis", "certificate",
        ]),
        Category(name: "Bescheinigung", keywords: [
            "bescheinigung", "nachweis", "bestaetigung", "confirmation",
        ]),
    ]

    /// Keywords als Dictionary (für schnellen Zugriff) – nur Built-in.
    static let keywordsMap: [String: [String]] = {
        var map: [String: [String]] = [:]
        for cat in all {
            map[cat.name] = cat.keywords
        }
        return map
    }()

    /// Fallback-Kategorie wenn nichts passt.
    static let fallbackCategory = "Dokument"

    // MARK: - Konfigurierbare Kategorien

    /// Built-in Kategorie-Namen (für UI-Unterscheidung).
    static let builtInCategoryNames: Set<String> = {
        Set(all.map(\.name))
    }()

    /// Effektive Kategorien unter Berücksichtigung der Konfiguration.
    /// - Built-in minus deaktivierte
    /// - Plus benutzerdefinierte
    static func effectiveCategories(config: AppConfiguration? = nil) -> [Category] {
        let cfg = config ?? AppConfig.shared.config
        let disabled = Set(cfg.disabledBuiltInCategories ?? [])
        let deleted = Set(cfg.deletedBuiltInCategories ?? [])

        // Built-in Kategorien filtern + Keyword-Overrides anwenden
        let added = cfg.additionalBuiltInKeywords ?? [:]
        let removed = cfg.removedBuiltInKeywords ?? [:]

        var result: [Category] = []
        for cat in all {
            guard !disabled.contains(cat.name) && !deleted.contains(cat.name) else { continue }
            var keywords = cat.keywords

            // Entfernte Keywords rausfiltern
            if let removedKws = removed[cat.name] {
                keywords = keywords.filter { !removedKws.contains($0) }
            }
            // Zusätzliche Keywords hinzufügen
            if let addedKws = added[cat.name] {
                for kw in addedKws where !keywords.contains(kw) {
                    keywords.append(kw)
                }
            }

            result.append(Category(name: cat.name, keywords: keywords))
        }

        // Benutzerdefinierte Kategorien hinzufügen
        if let custom = cfg.customCategories {
            for c in custom {
                result.append(Category(name: c.name, keywords: c.keywords))
            }
        }

        return result
    }

    /// Effektive Keywords-Map unter Berücksichtigung der Konfiguration.
    static func effectiveKeywordsMap(config: AppConfiguration? = nil) -> [String: [String]] {
        var map: [String: [String]] = [:]
        for cat in effectiveCategories(config: config) {
            map[cat.name] = cat.keywords
        }
        return map
    }
}
