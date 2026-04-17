import SwiftUI

/// Wiederverwendbare Zeile für eine Umbenennung in History/Menubar.
struct RecentRenameRow: View {
    let record: RenameRecord
    var showUndo: Bool = false
    var onUndo: (() -> Void)?
    var onReveal: (() -> Void)?
    var onReprocess: (() -> Void)?

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: record.renamedAt)
    }

    private var rowIcon: String {
        if record.dryRun { return "eye" }
        if record.undone { return "arrow.uturn.backward.circle" }
        return "doc.text"
    }

    private var rowIconColor: Color {
        if record.dryRun { return .orange }
        if record.undone { return .secondary }
        return Color.accentColor
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Datei-Icon
            Image(systemName: rowIcon)
                .foregroundStyle(rowIconColor)
                .font(.title3)
                .frame(width: 24)

            // Inhalt
            VStack(alignment: .leading, spacing: 3) {
                // Neuer Name + Dry-Run Badge
                HStack(spacing: 4) {
                    Text(record.newName)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .strikethrough(record.undone)
                        .foregroundStyle(record.undone ? .secondary : .primary)

                    if record.dryRun {
                        Text("VORSCHAU")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                // Alter Name
                HStack(spacing: 4) {
                    Text(record.originalName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                // Datum + Source Badge
                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    SourceBadge(source: record.source)
                }
            }

            Spacer()

            // Aktionen
            if !record.dryRun {
                HStack(spacing: 4) {
                    if record.undone {
                        if let onReprocess {
                            Button(action: onReprocess) {
                                Label("Umbenennen", systemImage: "arrow.clockwise")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                            .help("Erneut umbenennen")
                        }
                    } else {
                        if let onReveal {
                            Button {
                                onReveal()
                            } label: {
                                Image(systemName: "folder")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .help("Im Finder anzeigen")
                        }

                        if showUndo, let onUndo {
                            Button {
                                onUndo()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.red)
                            .help("Umbenennung rückgängig")
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
