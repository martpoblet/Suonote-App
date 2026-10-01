import SwiftUI
import SwiftData

/// The library — Suonote's home. An editorial page: greeting, a "Continue"
/// card for the song you touched last, then every song as a quiet row
/// with its shape (section colors), key, tempo and status.
struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]

    @State private var searchText = ""
    @State private var selectedStatus: ProjectStatus?
    @State private var selectedTag: String?
    @State private var showingCreateSheet = false
    @State private var showingSettings = false
    @State private var projectToDelete: Project?
    @State private var pushedRoute: LibraryRoute?
    @AppStorage("librarySort") private var sortRaw: String = LibrarySort.recent.rawValue

    // MARK: Derived data

    private var sort: LibrarySort { LibrarySort(rawValue: sortRaw) ?? .recent }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isFiltering: Bool {
        !trimmedSearch.isEmpty || selectedStatus != nil || selectedTag != nil
    }

    private var activeProjects: [Project] {
        allProjects.filter { $0.status != .archived }
    }

    /// The most recently edited song, featured while browsing.
    private var continueProject: Project? {
        isFiltering ? nil : activeProjects.first
    }

    private var listedProjects: [Project] {
        var projects = selectedStatus == .archived ? allProjects : activeProjects

        if let status = selectedStatus {
            projects = projects.filter { $0.status == status }
        }
        if let tag = selectedTag {
            projects = projects.filter { $0.tags.contains(tag) }
        }
        if !trimmedSearch.isEmpty {
            projects = projects.filter { $0.libraryMatches(trimmedSearch) }
        }
        if let hero = continueProject {
            projects.removeAll { $0.id == hero.id }
        }

        switch sort {
        case .recent:
            return projects
        case .created:
            return projects.sorted { $0.createdAt > $1.createdAt }
        case .title:
            return projects.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        }
    }

    private var allTags: [String] {
        Array(Set(allProjects.flatMap(\.tags))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    private var hasArchived: Bool {
        allProjects.contains { $0.status == .archived }
    }

    // MARK: Body

    var body: some View {
        Group {
            if allProjects.isEmpty {
                emptyLibrary
            } else {
                library
            }
        }
        .paperBackground()
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .title)
        .toolbar { toolbarContent }
        .searchable(text: $searchText, prompt: "Titles, lyrics, tags")
        .navigationDestination(for: LibraryRoute.self) { route in
            ProjectDetailView(project: route.project, initialTab: route.tab)
        }
        .navigationDestination(item: $pushedRoute) { route in
            ProjectDetailView(project: route.project, initialTab: route.tab)
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateProjectView { project in
                pushedRoute = LibraryRoute(project: project)
            }
        }
        .sheet(isPresented: $showingSettings) {
            LibrarySettingsView()
        }
        .confirmationDialog(
            "Delete “\(projectToDelete?.title ?? String(localized: "song"))”?",
            isPresented: Binding(
                get: { projectToDelete != nil },
                set: { if !$0 { projectToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: projectToDelete
        ) { project in
            Button("Delete song", role: .destructive) { deleteProject(project) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its sections, lyrics and Studio parts will be removed. This can't be undone.")
        }
        .onOpenURL { url in
            // suonote://project/<id>[/compose|studio|lyrics|record] (widget links)
            let parts = url.pathComponents.dropFirst()
            guard url.scheme == "suonote", url.host == "project",
                  let idString = parts.first,
                  let projectId = UUID(uuidString: idString),
                  let project = allProjects.first(where: { $0.id == projectId }) else { return }
            let tab: ProjectDetailTab
            switch parts.dropFirst().first {
            case "studio": tab = .studio
            case "lyrics": tab = .lyrics
            case "record": tab = .record
            default: tab = .compose
            }
            pushedRoute = LibraryRoute(project: project, tab: tab)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            AppLogoView(height: 20)
                .accessibilityLabel("Suonote")
        }
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }
            .accessibilityLabel("Settings")
        }

        DefaultToolbarItem(kind: .search, placement: .bottomBar)
        ToolbarSpacer(.fixed, placement: .bottomBar)
        ToolbarItem(placement: .bottomBar) {
            Button {
                HapticFeedback.medium.trigger()
                showingCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.glassProminent)
            .tint(DesignSystem.Colors.primary)
            .accessibilityLabel("New song")
        }
    }

    // MARK: Library list

    private var library: some View {
        List {
            Section {
                LibraryGreetingHeader(
                    songCount: activeProjects.count,
                    inProgressCount: activeProjects.filter { $0.status == .inProgress }.count
                )
                .clearLibraryRow(top: DesignSystem.Spacing.xs)
            }

            if let hero = continueProject {
                Section {
                    LibraryContinueCard(project: hero) { tab in
                        HapticFeedback.light.trigger()
                        pushedRoute = LibraryRoute(project: hero, tab: tab)
                    }
                    .contextMenu { contextMenu(for: hero) }
                    .clearLibraryRow()
                }
            }

            Section {
                filterBar
                    .clearLibraryRow()
            }

            Section {
                if listedProjects.isEmpty {
                    noResults
                        .listRowBackground(DesignSystem.Colors.surface)
                } else {
                    ForEach(listedProjects) { project in
                        NavigationLink(value: LibraryRoute(project: project)) {
                            LibraryProjectRow(project: project)
                        }
                        .listRowBackground(DesignSystem.Colors.surface)
                        .listRowSeparatorTint(DesignSystem.Colors.border)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                projectToDelete = project
                            } label: {
                                Label("Delete", systemImage: DesignSystem.Icons.delete)
                            }
                            Button {
                                duplicate(project)
                            } label: {
                                Label("Duplicate", systemImage: DesignSystem.Icons.duplicate)
                            }
                            .tint(DesignSystem.Colors.info)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggleArchive(project)
                            } label: {
                                Label(project.status == .archived ? "Unarchive" : "Archive",
                                      systemImage: project.status == .archived ? "tray.and.arrow.up" : "archivebox")
                            }
                            .tint(DesignSystem.Colors.warning)
                        }
                        .contextMenu { contextMenu(for: project) }
                    }
                }
            } header: {
                songsHeader
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(DesignSystem.Spacing.md)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .animation(DesignSystem.Animations.smoothSpring, value: listedProjects.map(\.id))
        .animation(DesignSystem.Animations.smoothSpring, value: continueProject?.id)
    }

    private var songsHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.xs) {
            Text(isFiltering ? "Results" : (continueProject == nil ? "Songs" : "More songs"))
                .eyebrow()
            Text("\(listedProjects.count)")
                .font(DesignSystem.Typography.caption)
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            Spacer(minLength: 0)
            Menu {
                Picker("Sort by", selection: $sortRaw) {
                    ForEach(LibrarySort.allCases) { option in
                        Label(option.displayName, systemImage: option.icon).tag(option.rawValue)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(sort.displayName)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .font(DesignSystem.Typography.buttonSmall)
                .foregroundStyle(DesignSystem.Colors.primaryDark)
            }
            .accessibilityLabel("Sort songs, currently \(sort.displayName)")
        }
        .textCase(nil)
    }

    // MARK: Filters

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectableChip(title: String(localized: "All"), isSelected: selectedStatus == nil && selectedTag == nil) {
                    withAnimation(DesignSystem.Animations.quickSpring) {
                        selectedStatus = nil
                        selectedTag = nil
                    }
                }

                ForEach(ProjectStatus.allCases.filter { $0 != .archived || hasArchived }, id: \.self) { status in
                    SelectableChip(title: status.libraryDisplayName, dot: status.swiftUIColor, isSelected: selectedStatus == status) {
                        HapticFeedback.selection.trigger()
                        withAnimation(DesignSystem.Animations.quickSpring) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    }
                }

                if !allTags.isEmpty {
                    Rectangle()
                        .fill(DesignSystem.Colors.border)
                        .frame(width: 1, height: 20)
                        .padding(.horizontal, 4)

                    ForEach(allTags, id: \.self) { tag in
                        SelectableChip(title: tag, icon: "number", isSelected: selectedTag == tag) {
                            HapticFeedback.selection.trigger()
                            withAnimation(DesignSystem.Animations.quickSpring) {
                                selectedTag = selectedTag == tag ? nil : tag
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    // MARK: Empty & no results

    private var emptyLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                LibraryGreetingHeader(songCount: 0, inProgressCount: 0)
                LibraryEmptyState {
                    HapticFeedback.medium.trigger()
                    showingCreateSheet = true
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.gutter)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var noResults: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Nothing matches")
                .font(DesignSystem.Typography.title3)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(isFiltering ? "Try another word, or clear the filters." : "Every other song is up there.")
                .font(DesignSystem.Typography.italicSmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if isFiltering {
                Button("Clear filters") {
                    withAnimation(DesignSystem.Animations.quickSpring) {
                        searchText = ""
                        selectedStatus = nil
                        selectedTag = nil
                    }
                }
                .buttonStyle(OutlineButtonStyle(compact: true))
                .padding(.top, DesignSystem.Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    // MARK: Context menu

    @ViewBuilder
    private func contextMenu(for project: Project) -> some View {
        Button {
            pushedRoute = LibraryRoute(project: project, tab: .studio)
        } label: {
            Label("Open in Studio", systemImage: ProjectDetailTab.studio.icon)
        }
        Button {
            pushedRoute = LibraryRoute(project: project, tab: .record)
        } label: {
            Label("Record a take", systemImage: "mic")
        }

        Divider()

        Menu {
            ForEach(ProjectStatus.allCases, id: \.self) { status in
                Button {
                    setStatus(status, for: project)
                } label: {
                    Label(status.libraryDisplayName, systemImage: project.status == status ? "checkmark" : status.icon)
                }
            }
        } label: {
            Label("Status", systemImage: project.status.icon)
        }
        Button {
            duplicate(project)
        } label: {
            Label("Duplicate", systemImage: DesignSystem.Icons.duplicate)
        }
        Button {
            toggleArchive(project)
        } label: {
            Label(project.status == .archived ? "Unarchive" : "Archive",
                  systemImage: project.status == .archived ? "tray.and.arrow.up" : "archivebox")
        }

        Divider()

        Button(role: .destructive) {
            projectToDelete = project
        } label: {
            Label("Delete", systemImage: DesignSystem.Icons.delete)
        }
    }

    // MARK: Actions

    private func deleteProject(_ project: Project) {
        HapticFeedback.warning.trigger()
        withAnimation(DesignSystem.Animations.smoothSpring) {
            modelContext.delete(project)
        }
        try? modelContext.save()
        projectToDelete = nil
    }

    private func toggleArchive(_ project: Project) {
        HapticFeedback.light.trigger()
        withAnimation(DesignSystem.Animations.smoothSpring) {
            project.status = project.status == .archived ? .idea : .archived
            project.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private func setStatus(_ status: ProjectStatus, for project: Project) {
        HapticFeedback.selection.trigger()
        withAnimation(DesignSystem.Animations.smoothSpring) {
            project.status = status
            project.updatedAt = Date()
        }
        try? modelContext.save()
    }

    private func duplicate(_ project: Project) {
        HapticFeedback.success.trigger()
        // Deferred a runloop so the swipe/context-menu animation finishes first.
        DispatchQueue.main.async {
            withAnimation(DesignSystem.Animations.smoothSpring) {
                _ = LibraryProjectCloner.duplicate(project, in: modelContext)
            }
        }
    }
}

// MARK: - Row styling helper

private extension View {
    /// Transparent, edge-to-edge list row (header, hero, filters).
    func clearLibraryRow(top: CGFloat = 0) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Project.self, configurations: config)

    let project1 = Project(title: "Summer Vibes", status: .idea, tags: ["Pop", "Upbeat"], bpm: 128)
    let project2 = Project(title: "Midnight Jazz", status: .inProgress, tags: ["Jazz", "Chill"], keyRoot: "D", keyMode: .minor, bpm: 85)
    container.mainContext.insert(project1)
    container.mainContext.insert(project2)
    LibraryStarter.all[2].apply(to: project2)

    return NavigationStack {
        ProjectsListView()
    }
    .modelContainer(container)
}
