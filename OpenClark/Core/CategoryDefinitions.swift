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

    /// Keywords als Dictionary (für schnellen Zugriff).
    static let keywordsMap: [String: [String]] = {
        var map: [String: [String]] = [:]
        for cat in all {
            map[cat.name] = cat.keywords
        }
        return map
    }()

    /// Fallback-Kategorie wenn nichts passt.
    static let fallbackCategory = "Dokument"
}
