import SwiftUI

/// Regeln-Tab: Kategorien und Ausschlüsse konfigurieren.
struct RulesTab: View {
    @State private var customCategories: [CustomCategory]
    @State private var disabledBuiltInCategories: Set<String>
    @State private var customExcludedExtensions: [String]
    @State private var customExcludedPrefixes: [String]
    @State private var enabledBuiltInExtensions: Set<String>

    // Built-in Keyword-Overrides
    @State private var additionalBuiltInKeywords: [String: [String]]
    @State private var removedBuiltInKeywords: [String: [String]]

    // Deaktivierte Built-in Prefixes
    @State private var disabledBuiltInPrefixes: Set<String>

    // Gelöschte Built-in Einträge
    @State private var deletedBuiltInCategories: Set<String>
    @State private var deletedBuiltInExtensions: Set<String>
    @State private var deletedBuiltInPrefixes: Set<String>

    // Neue Kategorie
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryKeywords = ""

    // Keyword-Editing (Custom per UUID, Built-in per Name)
    @State private var newKeywordText: [UUID: String] = [:]
    @State private var newBuiltInKeywordText: [String: String] = [:]

    // Neue Ausschlüsse
    @State private var newExtension = ""
    @State private var newPrefix = ""

    // Expanded Disclosure Groups
    @State private var expandedCategories: Set<String> = []
    @State private var expandedExtGroups: Set<String> = []

    private let config = AppConfig.shared

    init() {
        let c = AppConfig.shared.config
        _customCategories = State(initialValue: c.customCategories ?? [])
        _disabledBuiltInCategories = State(initialValue: Set(c.disabledBuiltInCategories ?? []))
        _customExcludedExtensions = State(initialValue: c.excludedExtensions ?? [])
        _customExcludedPrefixes = State(initialValue: c.excludedPrefixes ?? [])
        _enabledBuiltInExtensions = State(initialValue: Set(c.enabledBuiltInExtensions ?? []))
        _additionalBuiltInKeywords = State(initialValue: c.additionalBuiltInKeywords ?? [:])
        _removedBuiltInKeywords = State(initialValue: c.removedBuiltInKeywords ?? [:])
        _disabledBuiltInPrefixes = State(initialValue: Set(c.disabledBuiltInPrefixes ?? []))
        _deletedBuiltInCategories = State(initialValue: Set(c.deletedBuiltInCategories ?? []))
        _deletedBuiltInExtensions = State(initialValue: Set(c.deletedBuiltInExtensions ?? []))
        _deletedBuiltInPrefixes = State(initialValue: Set(c.deletedBuiltInPrefixes ?? []))
    }

    var body: some View {
        Form {
            categoriesSection
            exclusionsSection
            resetSection
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAddCategory) {
            addCategorySheet
        }
    }

    // MARK: - Kategorien

    @ViewBuilder
    private var categoriesSection: some View {
        Section {
            // Built-in Kategorien (ohne gelöschte)
            ForEach(CategoryDefinitions.all.filter { !deletedBuiltInCategories.contains($0.name) }, id: \.name) { category in
                builtInCategoryRow(category: category)
            }

            // Benutzerdefinierte Kategorien
            if !customCategories.isEmpty {
                Divider()
                ForEach(Array(customCategories.enumerated()), id: \.element.id) { index, custom in
                    customCategoryRow(index: index)
                }
            }

            // Hinzufügen Button
            Button {
                showAddCategory = true
            } label: {
                Label("Kategorie hinzufügen", systemImage: "plus.circle.fill")
            }
        } header: {
            Label("Kategorien", systemImage: "tag")
        } footer: {
            Text("Kategorien bestimmen, wie Dateien klassifiziert werden. Deaktivierte Kategorien werden bei der Erkennung ignoriert.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Berechne effektive Keywords für eine Built-in Kategorie.
    private func effectiveBuiltInKeywords(for category: CategoryDefinitions.Category) -> [String] {
        let removed = Set(removedBuiltInKeywords[category.name] ?? [])
        var keywords = category.keywords.filter { !removed.contains($0) }
        if let added = additionalBuiltInKeywords[category.name] {
            for kw in added where !keywords.contains(kw) {
                keywords.append(kw)
            }
        }
        return keywords
    }

    @ViewBuilder
    private func builtInCategoryRow(category: CategoryDefinitions.Category) -> some View {
        let isDisabled = disabledBuiltInCategories.contains(category.name)
        let effectiveKws = effectiveBuiltInKeywords(for: category)
        let addedKws = Set(additionalBuiltInKeywords[category.name] ?? [])

        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCategories.contains(category.name) },
                set: { newValue in
                    if newValue { expandedCategories.insert(category.name) }
                    else { expandedCategories.remove(category.name) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                // Keywords als löschbare Tags
                FlowLayout(spacing: 4) {
                    ForEach(effectiveKws, id: \.self) { keyword in
                        HStack(spacing: 2) {
                            Text(keyword)
                                .font(.caption)
                            Button {
                                removeBuiltInKeyword(categoryName: category.name, keyword: keyword, isUserAdded: addedKws.contains(keyword))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            addedKws.contains(keyword)
                                ? Color.green.opacity(0.15)
                                : (isDisabled ? Color.gray.opacity(0.15) : Color.accentColor.opacity(0.15))
                        )
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                        .clipShape(Capsule())
                    }
                }

                // Keyword hinzufügen
                HStack(spacing: 4) {
                    TextField("Keyword hinzufügen", text: Binding(
                        get: { newBuiltInKeywordText[category.name] ?? "" },
                        set: { newBuiltInKeywordText[category.name] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .onSubmit { addBuiltInKeyword(categoryName: category.name) }

                    Button {
                        addBuiltInKeyword(categoryName: category.name)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled((newBuiltInKeywordText[category.name] ?? "").isEmpty)
                }
            }
        } label: {
            HStack {
                Toggle("", isOn: Binding(
                    get: { !isDisabled },
                    set: { enabled in
                        if enabled { disabledBuiltInCategories.remove(category.name) }
                        else { disabledBuiltInCategories.insert(category.name) }
                        saveCategories()
                    }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()

                Text(category.name)
                    .foregroundStyle(isDisabled ? .secondary : .primary)

                Spacer()

                Text("\(effectiveKws.count) Keywords")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    deletedBuiltInCategories.insert(category.name)
                    disabledBuiltInCategories.remove(category.name)
                    additionalBuiltInKeywords.removeValue(forKey: category.name)
                    removedBuiltInKeywords.removeValue(forKey: category.name)
                    saveCategories()
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func customCategoryRow(index: Int) -> some View {
        let custom = customCategories[index]
        let catId = custom.id

        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedCategories.contains(catId.uuidString) },
                set: { newValue in
                    if newValue { expandedCategories.insert(catId.uuidString) }
                    else { expandedCategories.remove(catId.uuidString) }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 6) {
                // Keywords als löschbare Tags
                FlowLayout(spacing: 4) {
                    ForEach(custom.keywords, id: \.self) { keyword in
                        HStack(spacing: 2) {
                            Text(keyword)
                                .font(.caption)
                            Button {
                                removeKeywordFromCategory(categoryId: catId, keyword: keyword)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }

                // Keyword hinzufügen
                HStack(spacing: 4) {
                    TextField("Keyword hinzufügen", text: Binding(
                        get: { newKeywordText[catId] ?? "" },
                        set: { newKeywordText[catId] = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)

                    Button {
                        addKeywordToCategory(categoryId: catId)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled((newKeywordText[catId] ?? "").isEmpty)
                }
            }
        } label: {
            HStack {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(.green)
                    .font(.caption)

                Text(custom.name)

                Spacer()

                Text("\(custom.keywords.count) Keywords")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    removeCustomCategory(at: index)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Neue Kategorie Sheet

    @ViewBuilder
    private var addCategorySheet: some View {
        VStack(spacing: 16) {
            Text("Neue Kategorie")
                .font(.headline)

            TextField("Name (z.B. Protokoll)", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading) {
                Text("Keywords (kommagetrennt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("z.B. protokoll, minutes, meeting", text: $newCategoryKeywords)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Abbrechen") {
                    resetNewCategory()
                    showAddCategory = false
                }

                Spacer()

                Button("Hinzufügen") {
                    addCustomCategory()
                    showAddCategory = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newCategoryName.isEmpty || newCategoryKeywords.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400)
    }

    // MARK: - Ausschlüsse

    @ViewBuilder
    private var exclusionsSection: some View {
        // Dateiendungen
        Section {
            extensionGroup(
                title: "Bilder",
                extensions: [".jpg", ".jpeg", ".png", ".gif", ".heic", ".heif", ".raw",
                             ".cr2", ".cr3", ".nef", ".arw", ".tiff", ".tif", ".bmp",
                             ".webp", ".svg", ".ico"]
            )
            extensionGroup(
                title: "Musik",
                extensions: [".mp3", ".wav", ".flac", ".aac", ".m4a", ".ogg", ".wma", ".aiff"]
            )
            extensionGroup(
                title: "Video",
                extensions: [".mp4", ".mov", ".avi", ".mkv", ".wmv", ".m4v"]
            )
            extensionGroup(
                title: "Design",
                extensions: [".psd", ".ai", ".indd", ".sketch", ".fig", ".xd"]
            )
            extensionGroup(
                title: "System",
                extensions: [".ds_store", ".tmp", ".crdownload", ".part"]
            )

            // Benutzerdefinierte Extensions
            if !customExcludedExtensions.isEmpty {
                Divider()
                ForEach(Array(customExcludedExtensions.enumerated()), id: \.element) { idx, ext in
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(ext)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            customExcludedExtensions.remove(at: idx)
                            saveExclusions()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Neue Extension
            HStack {
                TextField("z.B. .numbers", text: $newExtension)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                    .onSubmit { addCustomExtension() }
                Button {
                    addCustomExtension()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newExtension.isEmpty)
            }
        } header: {
            Label("Ausgeschlossene Dateiendungen", systemImage: "doc.badge.gearshape")
        }

        // Präfixe
        Section {
            ForEach(FileFilters.builtInExcludedPrefixes.filter { !deletedBuiltInPrefixes.contains($0) }, id: \.self) { prefix in
                let isActive = !disabledBuiltInPrefixes.contains(prefix)
                HStack {
                    Toggle("", isOn: Binding(
                        get: { isActive },
                        set: { enabled in
                            if enabled { disabledBuiltInPrefixes.remove(prefix) }
                            else { disabledBuiltInPrefixes.insert(prefix) }
                            saveExclusions()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                    Text(prefix)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(isActive ? .primary : .secondary)

                    Spacer()

                    Button {
                        deletedBuiltInPrefixes.insert(prefix)
                        disabledBuiltInPrefixes.remove(prefix)
                        saveExclusions()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !customExcludedPrefixes.isEmpty {
                Divider()
                ForEach(Array(customExcludedPrefixes.enumerated()), id: \.element) { idx, prefix in
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(prefix)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            customExcludedPrefixes.remove(at: idx)
                            saveExclusions()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                TextField("z.B. SCAN_", text: $newPrefix)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 150)
                    .onSubmit { addCustomPrefix() }
                Button {
                    addCustomPrefix()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newPrefix.isEmpty)
            }
        } header: {
            Label("Ausgeschlossene Präfixe", systemImage: "textformat")
        }

    }

    // MARK: - Zurücksetzen

    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                resetAll()
            } label: {
                Label("Alle Anpassungen zurücksetzen", systemImage: "arrow.counterclockwise")
            }
        } footer: {
            Text("Entfernt alle benutzerdefinierten Kategorien und Ausschlüsse und stellt die Standardwerte wieder her.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Extension-Gruppen (aufklappbar, einzeln togglebar)

    @ViewBuilder
    private func extensionGroup(title: String, extensions: [String]) -> some View {
        let visible = extensions.filter { !deletedBuiltInExtensions.contains($0) }
        let enabledCount = visible.filter { enabledBuiltInExtensions.contains($0) }.count
        let allExcluded = enabledCount == 0

        if !visible.isEmpty {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedExtGroups.contains(title) },
                    set: { newValue in
                        if newValue { expandedExtGroups.insert(title) }
                        else { expandedExtGroups.remove(title) }
                    }
                )
            ) {
                // Einzelne Extensions
                ForEach(visible, id: \.self) { ext in
                    let isExcluded = !enabledBuiltInExtensions.contains(ext)
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { isExcluded },
                            set: { shouldExclude in
                                if shouldExclude {
                                    enabledBuiltInExtensions.remove(ext)
                                } else {
                                    enabledBuiltInExtensions.insert(ext)
                                }
                                saveExclusions()
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                        Text(ext)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(isExcluded ? .primary : .secondary)

                        Spacer()

                        Button {
                            deletedBuiltInExtensions.insert(ext)
                            enabledBuiltInExtensions.remove(ext)
                            saveExclusions()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, 8)
                }
            } label: {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { allExcluded },
                        set: { shouldExclude in
                            if shouldExclude {
                                for ext in visible { enabledBuiltInExtensions.remove(ext) }
                            } else {
                                for ext in visible { enabledBuiltInExtensions.insert(ext) }
                            }
                            saveExclusions()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .labelsHidden()

                    Text(title)
                        .foregroundStyle(allExcluded ? .primary : .secondary)

                    Spacer()

                    if enabledCount > 0 {
                        Text("\(enabledCount) aktiviert")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(visible.count) ausgeschlossen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        for ext in visible { deletedBuiltInExtensions.insert(ext) }
                        for ext in visible { enabledBuiltInExtensions.remove(ext) }
                        saveExclusions()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Category Actions

    private func addCustomCategory() {
        let name = TextSanitizer.capitalizeWords(TextSanitizer.sanitize(newCategoryName))
        let keywords = newCategoryKeywords
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        guard !name.isEmpty, !keywords.isEmpty else { return }

        let category = CustomCategory(name: name, keywords: keywords)
        customCategories.append(category)
        saveCategories()
        resetNewCategory()
    }

    private func removeCustomCategory(at index: Int) {
        guard index < customCategories.count else { return }
        let catId = customCategories[index].id
        newKeywordText.removeValue(forKey: catId)
        customCategories.remove(at: index)
        saveCategories()
    }

    private func addKeywordToCategory(categoryId: UUID) {
        guard let text = newKeywordText[categoryId],
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let keyword = text.trimmingCharacters(in: .whitespaces).lowercased()

        if let idx = customCategories.firstIndex(where: { $0.id == categoryId }) {
            if !customCategories[idx].keywords.contains(keyword) {
                customCategories[idx].keywords.append(keyword)
                saveCategories()
            }
        }
        newKeywordText[categoryId] = ""
    }

    private func removeKeywordFromCategory(categoryId: UUID, keyword: String) {
        if let idx = customCategories.firstIndex(where: { $0.id == categoryId }) {
            customCategories[idx].keywords.removeAll { $0 == keyword }
            if customCategories[idx].keywords.isEmpty {
                customCategories.remove(at: idx)
            }
            saveCategories()
        }
    }

    private func resetNewCategory() {
        newCategoryName = ""
        newCategoryKeywords = ""
    }

    // MARK: - Built-in Keyword Actions

    private func addBuiltInKeyword(categoryName: String) {
        guard let text = newBuiltInKeywordText[categoryName],
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let keyword = text.trimmingCharacters(in: .whitespaces).lowercased()

        // Falls das Keyword vorher entfernt wurde, einfach aus removed entfernen
        if var removed = removedBuiltInKeywords[categoryName], removed.contains(keyword) {
            removed.removeAll { $0 == keyword }
            removedBuiltInKeywords[categoryName] = removed.isEmpty ? nil : removed
        } else {
            // Sonst als zusätzliches Keyword hinzufügen
            var added = additionalBuiltInKeywords[categoryName] ?? []
            if !added.contains(keyword) {
                added.append(keyword)
                additionalBuiltInKeywords[categoryName] = added
            }
        }

        newBuiltInKeywordText[categoryName] = ""
        saveCategories()
    }

    private func removeBuiltInKeyword(categoryName: String, keyword: String, isUserAdded: Bool) {
        if isUserAdded {
            // User-added Keyword → aus additional entfernen
            if var added = additionalBuiltInKeywords[categoryName] {
                added.removeAll { $0 == keyword }
                additionalBuiltInKeywords[categoryName] = added.isEmpty ? nil : added
            }
        } else {
            // Built-in Keyword → zu removed hinzufügen
            var removed = removedBuiltInKeywords[categoryName] ?? []
            if !removed.contains(keyword) {
                removed.append(keyword)
                removedBuiltInKeywords[categoryName] = removed
            }
        }
        saveCategories()
    }

    // MARK: - Exclusion Actions

    private func addCustomExtension() {
        var ext = newExtension.lowercased().trimmingCharacters(in: .whitespaces)
        if !ext.hasPrefix(".") { ext = ".\(ext)" }
        if !customExcludedExtensions.contains(ext) {
            customExcludedExtensions.append(ext)
            saveExclusions()
        }
        newExtension = ""
    }

    private func addCustomPrefix() {
        let prefix = newPrefix.trimmingCharacters(in: .whitespaces)
        if !prefix.isEmpty, !customExcludedPrefixes.contains(prefix) {
            customExcludedPrefixes.append(prefix)
            saveExclusions()
        }
        newPrefix = ""
    }

    private func resetAll() {
        customCategories = []
        disabledBuiltInCategories = []
        additionalBuiltInKeywords = [:]
        removedBuiltInKeywords = [:]
        deletedBuiltInCategories = []
        customExcludedExtensions = []
        customExcludedPrefixes = []
        enabledBuiltInExtensions = []
        disabledBuiltInPrefixes = []
        deletedBuiltInExtensions = []
        deletedBuiltInPrefixes = []
        newKeywordText = [:]
        newBuiltInKeywordText = [:]
        saveCategories()
        saveExclusions()
    }

    // MARK: - Persistence

    private func saveCategories() {
        config.update { cfg in
            cfg.customCategories = customCategories.isEmpty ? nil : customCategories
            cfg.disabledBuiltInCategories = disabledBuiltInCategories.isEmpty ? nil : Array(disabledBuiltInCategories)
            cfg.additionalBuiltInKeywords = additionalBuiltInKeywords.isEmpty ? nil : additionalBuiltInKeywords
            cfg.removedBuiltInKeywords = removedBuiltInKeywords.isEmpty ? nil : removedBuiltInKeywords
            cfg.deletedBuiltInCategories = deletedBuiltInCategories.isEmpty ? nil : Array(deletedBuiltInCategories)
        }
    }

    private func saveExclusions() {
        config.update { cfg in
            cfg.excludedExtensions = customExcludedExtensions.isEmpty ? nil : customExcludedExtensions
            cfg.excludedPrefixes = customExcludedPrefixes.isEmpty ? nil : customExcludedPrefixes
            cfg.enabledBuiltInExtensions = enabledBuiltInExtensions.isEmpty ? nil : Array(enabledBuiltInExtensions)
            cfg.disabledBuiltInPrefixes = disabledBuiltInPrefixes.isEmpty ? nil : Array(disabledBuiltInPrefixes)
            cfg.deletedBuiltInExtensions = deletedBuiltInExtensions.isEmpty ? nil : Array(deletedBuiltInExtensions)
            cfg.deletedBuiltInPrefixes = deletedBuiltInPrefixes.isEmpty ? nil : Array(deletedBuiltInPrefixes)
        }
    }
}

// MARK: - FlowLayout (für Keyword-Tags)

/// Einfaches FlowLayout das Tags horizontal umbricht.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: bounds.height), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }

    private struct ArrangeResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX)
            totalHeight = currentY + lineHeight
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            positions: positions
        )
    }
}
