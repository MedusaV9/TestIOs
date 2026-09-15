import SwiftUI

/// Date Night: the planned evening (phases + Live Activity) and the idea
/// deck ("Kocht zusammen etwas, das ihr noch nie gemacht habt").
struct DateNightView: View {
    @Environment(AppState.self) private var appState

    enum Location: String, CaseIterable, Identifiable {
        case any, indoor, outdoor
        var id: String { rawValue }
    }

    @State private var location: Location = .any
    @State private var maxBudget: Int?
    @State private var longDistance = false
    @State private var selectedTags: Set<String> = []
    @State private var idea: DateIdea?
    @State private var rolls = 0
    @State private var showPlan = false
    @State private var planTitle: String?
    @State private var planEmoji: String?
    @State private var sharedIdeaId: Int?
    @State private var bucketIdeaId: Int?

    private static let tags = ["cozy", "adventure", "creative", "food", "outdoor", "romantic", "silly", "athome", "night"]

    private var pool: [DateIdea] {
        ContentPack.dateIdeas.filter { candidate in
            if location == .indoor && !candidate.indoor { return false }
            if location == .outdoor && candidate.indoor { return false }
            if let maxBudget, candidate.budget > maxBudget { return false }
            if longDistance && !candidate.tags.contains("longdistance") { return false }
            if !selectedTags.isEmpty && selectedTags.isDisjoint(with: Set(candidate.tags)) { return false }
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let night = appState.dateNight {
                    PlannedNightCard(night: night)
                }
                ideaSection
                filterSection
            }
            .padding(Brand.screenInset)
        }
        .groupedScreenBackground()
        .navigationTitle(L10n.t("datenight.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appState.dateNight == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        planTitle = nil
                        planEmoji = nil
                        showPlan = true
                    } label: {
                        Label(L10n.t("datenight.plan"), systemImage: "calendar.badge.plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showPlan) {
            DateNightPlanSheet(initialTitle: planTitle, initialEmoji: planEmoji)
        }
        .onAppear {
            if idea == nil, let couple = appState.couple {
                idea = TodayModel.dailyIdea(coupleId: couple.id)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: rolls)
    }

    // MARK: Idea deck

    @ViewBuilder
    private var ideaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("datenight.ideas.title"),
                         subtitle: L10n.t("datenight.ideas.subtitle"))
            if let idea {
                ideaCard(idea)
                    .id(idea.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            } else {
                ContentUnavailableView(L10n.t("games.dateideas.empty.title"),
                                       systemImage: "sparkles",
                                       description: Text(L10n.t("games.dateideas.empty.body")))
                    .cardSurface()
            }
        }
        .animation(.snappy, value: idea?.id)
    }

    private func ideaCard(_ idea: DateIdea) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color.accentColor.opacity(0.85), .purple.opacity(0.9)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(idea.emoji)
                    .font(.system(size: 72))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityHidden(true)
                HStack(spacing: 6) {
                    ideaBadge(L10n.t(idea.indoor ? "games.dateideas.location.indoor" : "games.dateideas.location.outdoor"),
                              systemImage: idea.indoor ? "house" : "sun.max")
                    ideaBadge(idea.budget == 0 ? L10n.t("games.dateideas.budget.free") : String(repeating: "€", count: idea.budget),
                              systemImage: "eurosign")
                }
                .padding(12)
            }
            .frame(height: 170)

            VStack(alignment: .leading, spacing: 10) {
                Text(idea.title.resolved(L10n.lang))
                    .font(.title3.weight(.bold))
                Text(idea.details.resolved(L10n.lang))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        planTitle = idea.title.resolved(L10n.lang)
                        planEmoji = idea.emoji
                        showPlan = true
                    } label: {
                        Text(L10n.t("datenight.letsGo"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)

                    Button {
                        roll()
                    } label: {
                        Image(systemName: "shuffle")
                            .frame(width: 24)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(pool.count < 2)
                    .accessibilityLabel(L10n.t("games.dateideas.regenerate"))
                }
                .padding(.top, 4)

                HStack(spacing: 16) {
                    Button {
                        share(idea)
                    } label: {
                        Label(L10n.t(sharedIdeaId == idea.id ? "games.sharedToChat" : "common.share"),
                              systemImage: sharedIdeaId == idea.id ? "checkmark" : "paperplane")
                    }
                    .disabled(sharedIdeaId == idea.id)
                    Button {
                        addToBucket(idea)
                    } label: {
                        Label(L10n.t(bucketIdeaId == idea.id ? "games.dateideas.bucketDone" : "games.dateideas.bucket"),
                              systemImage: bucketIdeaId == idea.id ? "checkmark" : "star")
                    }
                    .disabled(bucketIdeaId == idea.id)
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.borderless)
            }
            .padding(16)
        }
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
    }

    private func ideaBadge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
    }

    // MARK: Filters

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: L10n.t("datenight.filters"))
            VStack(alignment: .leading, spacing: 14) {
                Picker(L10n.t("games.dateideas.location"), selection: $location) {
                    ForEach(Location.allCases) { option in
                        Text(L10n.t("games.dateideas.location.\(option.rawValue)")).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text(L10n.t("games.dateideas.budget"))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Picker(L10n.t("games.dateideas.budget"), selection: $maxBudget) {
                        Text(L10n.t("games.dateideas.budget.any")).tag(Int?.none)
                        Text(L10n.t("games.dateideas.budget.free")).tag(Int?.some(0))
                        Text("€").tag(Int?.some(1))
                        Text("€€").tag(Int?.some(2))
                        Text("€€€").tag(Int?.some(3))
                    }
                    .pickerStyle(.menu)
                }

                Toggle(L10n.t("games.dateideas.longdistance"), isOn: $longDistance)
                    .font(.subheadline.weight(.medium))

                Text(L10n.t("games.dateideas.mood"))
                    .font(.subheadline.weight(.medium))
                FlowTags(tags: Self.tags, selected: $selectedTags) { L10n.t("games.dateideas.tag.\($0)") }
            }
            .cardSurface()
            Text(L10n.t("datenight.poolCount", ["n": String(pool.count)]))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: pool.map(\.id)) { _, ids in
            if let current = idea, !ids.contains(current.id) { idea = pool.first }
            if idea == nil { idea = pool.first }
        }
    }

    // MARK: Actions

    private func roll() {
        let choices = pool
        guard choices.count > 1 else { return }
        var next = choices.randomElement()
        while next?.id == idea?.id { next = choices.randomElement() }
        rolls += 1
        SoundEngine.shared.play(.whoosh)
        withAnimation(.snappy) { idea = next }
    }

    private func share(_ idea: DateIdea) {
        guard let api = appState.api else { return }
        Task {
            do {
                let text = L10n.t("games.dateideas.shareHeader") + "\n\(idea.emoji) \(idea.title.resolved(L10n.lang))\n\(idea.details.resolved(L10n.lang))"
                _ = try await api.sendMessage(type: .text, text: text)
                sharedIdeaId = idea.id
                appState.notify(L10n.t("games.sharedToChat"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }

    private func addToBucket(_ idea: DateIdea) {
        guard let api = appState.api else { return }
        Task {
            do {
                _ = try await api.addBucketItem(text: idea.title.resolved(L10n.lang), emoji: idea.emoji)
                bucketIdeaId = idea.id
                appState.notify(L10n.t("games.dateideas.bucketAdded"), style: .success)
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

/// Wrapping tag chips (multi-select).
struct FlowTags: View {
    let tags: [String]
    @Binding var selected: Set<String>
    let title: (String) -> String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Button {
                    if selected.contains(tag) { selected.remove(tag) } else { selected.insert(tag) }
                } label: {
                    Text(title(tag))
                        .font(.footnote.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(selected.contains(tag) ? Color.accentColor : Color.secondary)
                .accessibilityAddTraits(selected.contains(tag) ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Planned night

struct PlannedNightCard: View {
    @Environment(AppState.self) private var appState
    let night: DateNight
    @State private var advancing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text(night.emoji ?? "🌙")
                    .font(.system(size: 34))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(night.title ?? L10n.t("datenight.card.title"))
                        .font(.headline)
                    Text(L10n.t("datenight.phase.\(night.phase.rawValue)"))
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                if night.phase == .anticipation {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L10n.t("datenight.startsIn"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if night.startsAt > Date() {
                            Text(timerInterval: Date()...night.startsAt, countsDown: true)
                                .font(.headline.monospacedDigit())
                        } else {
                            Text(L10n.t("home.todayBang"))
                                .font(.headline)
                        }
                    }
                }
            }

            PhaseTrack(phase: night.phase)

            HStack(spacing: 10) {
                if let next = night.phase.next {
                    Button {
                        advance()
                    } label: {
                        Label(L10n.t("datenight.phase.\(next.rawValue)"), systemImage: "chevron.right.2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(advancing)
                }
                Button(role: .destructive) {
                    Task { await appState.cancelDateNight() }
                } label: {
                    Label(L10n.t("datenight.cancel"), systemImage: "xmark")
                        .frame(maxWidth: night.phase.next == nil ? .infinity : nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            Text(L10n.t("datenight.liveActivityHint"))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private func advance() {
        guard !advancing else { return }
        advancing = true
        Task {
            await appState.advanceDateNightPhase()
            advancing = false
        }
    }
}

/// Three-step phase indicator: Vorfreude → Live → Afterglow.
struct PhaseTrack: View {
    let phase: DateNightPhase

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(DateNightPhase.allCases.enumerated()), id: \.offset) { index, item in
                Capsule()
                    .fill(index <= current ? Color.accentColor : Color.tertiaryCardBackground)
                    .frame(height: 6)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(L10n.t("datenight.phase.\(phase.rawValue)"))
    }

    private var current: Int {
        DateNightPhase.allCases.firstIndex(of: phase) ?? 0
    }
}

// MARK: - Plan sheet

struct DateNightPlanSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String? = nil
    var initialEmoji: String? = nil

    private static let emojis = ["🌙", "🍝", "🎬", "🕯️", "🍷", "🎲", "🌃", "🛁", "🎶", "🍿", "🧑‍🍳", "💃"]

    @State private var title = ""
    @State private var emoji = "🌙"
    @State private var startsAt = Self.defaultStart
    @State private var saving = false

    private static var defaultStart: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 20
        comps.minute = 0
        let tonight = cal.date(from: comps) ?? Date()
        return tonight > Date() ? tonight : cal.date(byAdding: .day, value: 1, to: tonight) ?? tonight
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("datenight.titlePlaceholder"), text: $title)
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji, columns: 6)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section {
                    DatePicker(L10n.t("datenight.when"), selection: $startsAt, in: Date()...,
                               displayedComponents: [.date, .hourAndMinute])
                } footer: {
                    Text(L10n.t("datenight.liveActivityHint"))
                }
            }
            .navigationTitle(L10n.t("datenight.plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("datenight.plan")) { save() }
                        .disabled(saving)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if let initialTitle { title = initialTitle }
            if let initialEmoji { emoji = initialEmoji }
        }
    }

    private func save() {
        guard !saving else { return }
        saving = true
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await appState.planDateNight(title: trimmed.isEmpty ? nil : trimmed, emoji: emoji, startsAt: startsAt)
            saving = false
            dismiss()
        }
    }
}
