import Foundation

/// Prompt-Template für LLM-Analyse (aus Python-Prototyp bewährt).
enum LLMPrompt {

    /// Generiere den Analyse-Prompt.
    static func generate(filename: String, extension ext: String, text: String) -> String {
        // Text auf 2500 Zeichen begrenzen
        let truncatedText = text.count > 2500 ? String(text.prefix(2500)) : text

        return """
        Du bist ein Datei-Benennungs-Assistent. Analysiere den folgenden \
        Dokumententext und generiere einen praezisen Dateinamen.

        ## Namensschema
        YYYY-MM-DD_Kategorie_Beschreibung.ext

        ## Regeln
        - Datum vorne: YYYY-MM-DD (oder YYYY-MM oder YYYY wenn Tag/Monat unbekannt)
        - Trenner zwischen Bloecken: Unterstrich _
        - Woerter innerhalb eines Blocks: Bindestrich -
        - Keine Leerzeichen
        - Keine Umlaute: ae statt ä, oe statt ö, ue statt ü, ss statt ß
        - Keine Sonderzeichen
        - Erster Buchstabe jedes Worts gross

        ## Kategorien (waehle die passendste)
        - Rechnung, Angebot, Vertrag, Arbeitsvertrag, Mietvertrag
        - Gehaltsnachweis, Lebenslauf, Bewerbung
        - Versicherung, Ausweis, Steuererklaerung
        - Wohnungsbewerbung, Kuendigung, Zeugnis, Bescheinigung
        - Dokument (nur wenn nichts anderes passt)

        ## Beschreibung
        - Bei Rechnungen: Firma und ggf. was (z.B. Vodafone-Internet)
        - Bei Vertraegen: Firma und ggf. Person/Adresse
        - Bei Gehalt: Firma
        - Sonst: Kurze, sinnvolle Beschreibung

        ## Originaler Dateiname
        \(filename)

        ## Dateiendung
        \(ext)

        ## Dokumententext (Auszug)
        \(truncatedText)

        ## Antwort
        Antworte NUR mit einem JSON-Objekt, nichts anderes:
        {"date": "YYYY-MM-DD", "category": "Kategorie", "description": "Beschreibung"}
        """
    }
}
