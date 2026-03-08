import SwiftUI

/// Badge das die Analyse-Quelle anzeigt: 📝 filename, 📄 pdf_keywords, 🤖 llm
struct SourceBadge: View {
    let source: String

    private var icon: String {
        switch source {
        case "filename": return "📝"
        case "pdf_keywords": return "📄"
        case "llm": return "🤖"
        default: return "📝"
        }
    }

    private var label: String {
        switch source {
        case "filename": return "Dateiname"
        case "pdf_keywords": return "PDF"
        case "llm": return "KI"
        default: return source
        }
    }

    private var badgeColor: Color {
        switch source {
        case "filename": return .blue
        case "pdf_keywords": return .orange
        case "llm": return .purple
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
    }
}
