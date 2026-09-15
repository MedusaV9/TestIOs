import SwiftUI

/// Manage servers: add, edit, test, switch active, remove.
/// Every server keeps its own pairing session — switching is instant.
/// Pushed from the profile; `ServerListSheet` wraps it for pairing.
struct ServerListView: View {
    @Environment(AppState.self) private var appState

    @State private var showAdd = false
    @State private var editing: ServerProfile?
    @State private var deleting: ServerProfile?
    @State private var health: [UUID: Bool] = [:]

    private var activeProfile: ServerProfile? { appState.servers.activeProfile }
    private var otherProfiles: [ServerProfile] {
        appState.servers.profiles.filter { $0.id != appState.servers.activeProfileID }
    }

    var body: some View {
        List {
            if let active = activeProfile {
                Section(L10n.t("server.section.active")) {
                    serverRow(active, isActive: true)
                }
            }

            Section {
                ForEach(otherProfiles) { profile in
                    serverRow(profile, isActive: false)
                }
                Button {
                    showAdd = true
                } label: {
                    Label(L10n.t("server.add"), systemImage: "plus.circle.fill")
                }
            } header: {
                if !otherProfiles.isEmpty {
                    Text(L10n.t("server.section.others"))
                }
            } footer: {
                Text(L10n.t("server.hint"))
            }
        }
        .navigationTitle(L10n.t("server.manage"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAdd) {
            ServerSetupSheet()
        }
        .sheet(item: $editing) { profile in
            ServerSetupSheet(existing: profile)
        }
        .confirmationDialog(
            L10n.t("server.deleteConfirm", ["name": deleting?.name ?? ""]),
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button(L10n.t("server.delete"), role: .destructive) {
                if let profile = deleting { remove(profile) }
                deleting = nil
            }
        }
        .task { await checkHealth() }
        .onChange(of: appState.servers.profiles.count) {
            Task { await checkHealth() }
        }
    }

    // MARK: Row

    private func serverRow(_ profile: ServerProfile, isActive: Bool) -> some View {
        HStack(spacing: 12) {
            IconTile(systemImage: "server.rack", tint: isActive ? .accentColor : .gray, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(profile.urlString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Circle()
                        .fill(healthTint(profile))
                        .frame(width: 7, height: 7)
                    Text(healthText(profile))
                    Text("·")
                    Text(L10n.t(profile.isPaired ? "server.paired" : "server.notPaired"))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if !isActive {
                Button(L10n.t("server.switch")) {
                    Task { await appState.activateProfile(profile.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .labelStyle(.titleOnly)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                editing = profile
            } label: {
                Label(L10n.t("common.edit"), systemImage: "pencil")
            }
            if !isActive {
                Button {
                    Task { await appState.activateProfile(profile.id) }
                } label: {
                    Label(L10n.t("server.switch"), systemImage: "arrow.left.arrow.right")
                }
            }
            Button(role: .destructive) {
                deleting = profile
            } label: {
                Label(L10n.t("server.delete"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleting = profile
            } label: {
                Label(L10n.t("server.delete"), systemImage: "trash")
            }
            Button {
                editing = profile
            } label: {
                Label(L10n.t("common.edit"), systemImage: "pencil")
            }
            .tint(.orange)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isActive ? L10n.t("server.active") : "")
    }

    private func healthTint(_ profile: ServerProfile) -> Color {
        switch health[profile.id] {
        case .some(true): return .green
        case .some(false): return .red
        case .none: return .secondary
        }
    }

    private func healthText(_ profile: ServerProfile) -> String {
        switch health[profile.id] {
        case .some(true): return L10n.t("server.health.online")
        case .some(false): return L10n.t("server.health.offline")
        case .none: return L10n.t("server.health.checking")
        }
    }

    // MARK: Actions

    private func checkHealth() async {
        await withTaskGroup(of: (UUID, Bool).self) { group in
            for profile in appState.servers.profiles {
                guard let url = profile.baseURL else { continue }
                group.addTask {
                    let ok = (try? await API(baseURL: url, token: nil).health().ok) ?? false
                    return (profile.id, ok)
                }
            }
            for await (id, ok) in group {
                health[id] = ok
            }
        }
    }

    private func remove(_ profile: ServerProfile) {
        let wasActive = appState.servers.activeProfileID == profile.id
        if wasActive {
            appState.socket.disconnect()
            appState.couple = nil
        }
        appState.servers.remove(id: profile.id)
        if wasActive, appState.phase == .main {
            Task { await appState.refreshAll(); appState.connectSocket() }
        }
    }
}

/// Stand-alone presentation of the server list (pairing screen).
struct ServerListSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ServerListView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("common.done")) { dismiss() }
                    }
                }
        }
    }
}
