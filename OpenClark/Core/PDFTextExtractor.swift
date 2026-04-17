import AppKit
import Foundation
import PDFKit
import os.log

/// Extrahiert Text aus PDF-Dateien via PDFKit.
enum PDFTextExtractor {

    private static let logger = Logger(subsystem: "com.openclark", category: "pdf")

    /// Extrahiere Text aus einer PDF-Datei.
    /// - Parameters:
    ///   - path: Dateipfad
    ///   - maxChars: Maximale Zeichenanzahl (Default: 2500)
    /// - Returns: Extrahierter Text oder nil
    static func extract(from path: String, maxChars: Int = 2500) -> String? {
        let url = URL(fileURLWithPath: path)

        guard url.pathExtension.lowercased() == "pdf" else { return nil }

        guard let document = PDFDocument(url: url) else {
            logger.warning("PDF konnte nicht geöffnet werden: \(path)")
            return nil
        }

        var textParts: [String] = []
        var charsCollected = 0

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            guard let pageText = page.string, !pageText.isEmpty else { continue }

            textParts.append(pageText)
            charsCollected += pageText.count

            if charsCollected >= maxChars {
                break
            }
        }

        let fullText = textParts.joined(separator: "\n")
        guard !fullText.isEmpty else { return nil }

        // Auf maxChars begrenzen
        if fullText.count > maxChars {
            return String(fullText.prefix(maxChars))
        }

        return fullText
    }

    /// Prüfe ob eine Datei eine PDF ist.
    static func isPDF(_ path: String) -> Bool {
        URL(fileURLWithPath: path).pathExtension.lowercased() == "pdf"
    }

    /// Renders the first N pages of a PDF as base64-encoded JPEG strings for vision LLM APIs.
    static func renderPagesAsBase64JPEG(from path: String, maxPages: Int = 2) -> [String] {
        guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else { return [] }
        var results: [String] = []
        let count = min(doc.pageCount, maxPages)
        for i in 0..<count {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let scale: CGFloat = 1.5
            let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
            let image = page.thumbnail(of: size, for: .mediaBox)
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
            else { continue }
            results.append(jpeg.base64EncodedString())
        }
        return results
    }
}
