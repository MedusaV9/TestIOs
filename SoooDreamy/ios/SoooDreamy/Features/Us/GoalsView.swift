import SwiftUI
import Combine

/// Shared goals & savings targets with contributions from both partners.
/// Milestones (25/50/75/100 %) celebrate on both phones.
struct GoalsView: View {
    @Environment(AppState.self) private var appState

    @State private var goals: [SharedGoal] = []
    @State private var loading = true
    @State private var showCompose = false
    @State private var contributeGoal: SharedGoal?
    @State private var deleteTarget: SharedGoal?

    private var active: [SharedGoal] { goals.filter { $0.completedAt == nil } }
    private var done: [SharedGoal] { goals.filter { $0.completedAt != nil } }

    var body: some View {
        List {
            if loading {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .listRowBackground(Color.clear)
            } else if goals.isEmpty {
                ContentUnavailableView {
                    Label(L10n.t("goals.empty.title"), systemImage: "target")
                } description: {
                    Text(L10n.t("goals.empty.subtitle"))
                } actions: {
                    Button(L10n.t("goals.new")) { showCompose = true }
                        .buttonStyle(.glassProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                if !active.isEmpty {
                    Section(L10n.t("goals.activeSection")) {
                        ForEach(active) { goal in GoalRow(goal: goal, onContribute: { contributeGoal = goal }, onDelete: { deleteTarget = goal }) }
                    }
                }
                if !done.isEmpty {
                    Section(L10n.t("goals.doneSection")) {
                        ForEach(done) { goal in GoalRow(goal: goal, onContribute: nil, onDelete: { deleteTarget = goal }) }
                    }
                }
            }
        }
        .navigationTitle(L10n.t("goals.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCompose = true
                } label: {
                    Label(L10n.t("goals.new"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            GoalComposeSheet { goal in apply(goal) }
        }
        .sheet(item: $contributeGoal) { goal in
            GoalContributeSheet(goal: goal) { updated in apply(updated) }
        }
        .confirmationDialog(L10n.t("goals.deleteConfirm"), isPresented: Binding(
            get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }), titleVisibility: .visible) {
            Button(L10n.t("common.delete"), role: .destructive) {
                if let target = deleteTarget { delete(target) }
            }
        }
        .task(id: appState.couple?.id) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .serverEvent)) { note in
            guard let event = note.object as? ServerEvent else { return }
            switch event.type {
            case .goalAdded, .goalUpdated:
                if let goal = event.decode(GoalEventPayload.self)?.goal { apply(goal) }
            case .goalDeleted:
                if let payload = event.decode(IdPayload.self) { goals.removeAll { $0.id == payload.id } }
            default:
                break
            }
        }
    }

    private func apply(_ goal: SharedGoal) {
        withAnimation(.snappy) {
            if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[idx] = goal
            } else {
                goals.insert(goal, at: 0)
            }
        }
    }

    private func reload() async {
        guard let api = appState.api else { loading = false; return }
        if let list = try? await api.goals() { goals = list }
        loading = false
    }

    private func delete(_ goal: SharedGoal) {
        guard let api = appState.api else { return }
        Task {
            do {
                try await api.deleteGoal(id: goal.id)
                withAnimation(.snappy) { goals.removeAll { $0.id == goal.id } }
            } catch {
                appState.handleAPIError(error)
            }
        }
    }
}

/// Locale-aware number without trailing ".0".
func goalValueString(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: L10n.isGerman ? "de_DE" : "en_US")
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = value == value.rounded() ? 0 : 2
    return formatter.string(from: NSNumber(value: value)) ?? String(value)
}

private struct GoalRow: View {
    @Environment(AppState.self) private var appState
    let goal: SharedGoal
    let onContribute: (() -> Void)?
    let onDelete: () -> Void
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Text(goal.emoji ?? "🎯")
                    .font(.title2)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title)
                        .font(.body.weight(.medium))
                    Text(progressLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if let targetDate = goal.targetDate, let date = SharedDates.parse(targetDate) {
                        Text(L10n.t("goals.until", ["date": ritualDateString(date)]))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                if goal.completedAt != nil {
                    Label(L10n.t("goals.completedPill"), systemImage: "checkmark.seal.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.green)
                        .accessibilityLabel(L10n.t("goals.completedPill"))
                } else {
                    Text("\(Int(goal.percent.rounded())) %")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                }
            }
            ProgressView(value: min(100, max(0, goal.percent)), total: 100)
                .tint(goal.completedAt != nil ? Color.green : Color.accentColor)
            if !goal.contributions.isEmpty || onContribute != nil {
                HStack(spacing: 14) {
                    if let onContribute {
                        Button(L10n.t("goals.addProgress"), systemImage: "plus.circle.fill", action: onContribute)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                    if !goal.contributions.isEmpty {
                        Button {
                            withAnimation(.snappy) { showHistory.toggle() }
                        } label: {
                            Label(L10n.t("goals.contributions"), systemImage: showHistory ? "chevron.up" : "list.bullet")
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }
            }
            if showHistory {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(goal.contributions.sorted { $0.createdAt > $1.createdAt }.prefix(12)) { contribution in
                        HStack(spacing: 8) {
                            Text(memberEmoji(contribution.memberId))
                            Text("+\(goalValueString(contribution.amount))\(goal.unit.map { " \($0)" } ?? "")")
                                .font(.footnote.weight(.medium))
                                .monospacedDigit()
                            if let note = contribution.note, !note.isEmpty {
                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text(L10n.relativeShort(contribution.createdAt))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label(L10n.t("common.delete"), systemImage: "trash")
            }
        }
    }

    private var progressLine: String {
        let unit = goal.unit.map { " \($0)" } ?? ""
        return "\(goalValueString(goal.total))\(unit) / \(goalValueString(goal.targetValue))\(unit)"
    }

    private func memberEmoji(_ memberId: String) -> String {
        appState.couple?.members.first { $0.id == memberId }?.avatar ?? "💜"
    }
}

// MARK: - Compose

private struct GoalComposeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let onCreated: (SharedGoal) -> Void

    private static let emojis = ["🎯", "✈️", "🏠", "💍", "🚗", "🌴", "🎓", "🐶", "🏋️", "📚", "🎸", "💰"]

    @State private var title = ""
    @State private var emoji = "🎯"
    @State private var targetText = ""
    @State private var unit = ""
    @State private var useTargetDate = false
    @State private var targetDate = Date().addingTimeInterval(90 * 86400)
    @State private var creating = false

    private var targetValue: Double? {
        guard let value = Double(targetText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.t("goals.compose.titleField"), text: $title)
                    EmojiPickerGrid(emojis: Self.emojis, selection: $emoji, columns: 6)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                }
                Section {
                    LabeledContent(L10n.t("goals.compose.target")) {
                        TextField("0", text: $targetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent(L10n.t("goals.compose.unit")) {
                        TextField("€, km, …", text: $unit)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section {
                    Toggle(L10n.t("goals.compose.targetDate"), isOn: $useTargetDate.animation())
                    if useTargetDate {
                        DatePicker(L10n.t("goals.compose.targetDate"), selection: $targetDate, in: Date()..., displayedComponents: [.date])
                    }
                }
            }
            .navigationTitle(L10n.t("goals.compose.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        create()
                    } label: {
                        if creating { ProgressView() } else { Text(L10n.t("goals.create")) }
                    }
                    .disabled(creating || targetValue == nil || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func create() {
        guard let api = appState.api, let target = targetValue, !creating else { return }
        creating = true
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let goal = try await api.createGoal(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                                    emoji: emoji, targetValue: target,
                                                    unit: trimmedUnit.isEmpty ? nil : trimmedUnit,
                                                    targetDate: useTargetDate ? SharedDates.todayKey(targetDate) : nil)
                SoundEngine.shared.play(.pop)
                appState.notify(L10n.t("goals.createdToast"), style: .success)
                onCreated(goal)
                dismiss()
            } catch {
                creating = false
                appState.handleAPIError(error)
            }
        }
    }
}

// MARK: - Contribute

private struct GoalContributeSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let goal: SharedGoal
    let onBooked: (SharedGoal) -> Void

    @State private var amountText = ""
    @State private var note = ""
    @State private var booking = false

    private var amount: Double? {
        guard let value = Double(amountText.replacingOccurrences(of: ",", with: ".")), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(L10n.t("goals.amountField") + (goal.unit.map { " (\($0))" } ?? "")) {
                        TextField("0", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    TextField(L10n.t("goals.progressNote"), text: $note)
                } header: {
                    Text("\(goal.emoji ?? "🎯") \(goal.title)")
                } footer: {
                    Text("\(goalValueString(goal.total)) / \(goalValueString(goal.targetValue))\(goal.unit.map { " \($0)" } ?? "")")
                }
            }
            .navigationTitle(L10n.t("goals.addProgress"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        book()
                    } label: {
                        if booking { ProgressView() } else { Text(L10n.t("goals.book")) }
                    }
                    .disabled(booking || amount == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func book() {
        guard let api = appState.api, let amount, !booking else { return }
        booking = true
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                let result = try await api.contributeToGoal(id: goal.id, amount: amount,
                                                            note: trimmedNote.isEmpty ? nil : trimmedNote)
                if let milestone = result.milestone {
                    Delight.celebrate(milestone >= 100 ? .epic : .medium, theme: .confetti)
                } else {
                    SoundEngine.shared.play(.pop)
                }
                onBooked(result.goal)
                dismiss()
            } catch {
                booking = false
                appState.handleAPIError(error)
            }
        }
    }
}
