import CloudKit
import SwiftUI
import UniformTypeIdentifiers

/// iCloud & backup: CloudKit backup of servers + settings into the user's
/// private database, encrypted `.sooodreamy` file export, restore from
/// either. Detects at runtime whether the iCloud entitlements survived
/// signing (sideload often strips them) and degrades honestly.
struct ICloudView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// nil = still checking; `.available` etc. afterwards.
    @State private var ckStatus: CKAccountStatus?
    @State private var ckChecked = false
    @State private var driveAvailable = UbiquityDrive.identityAvailable

    @State private var busy = false
    @State private var lastBackupAt = CloudKitBackup.lastBackupAt
    @State private var confirmRestore = false
    @State private var pendingFilePayload: AppBackupPayload?
    @State private var pendingEncryptedFile: Data?
    @State private var confirmFileRestore = false
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var exportPassphrase = ""
    @State private var exportPassphraseConfirmation = ""
    @State private var importPassphrase = ""
    @State private var askForImportPassphrase = false

    private static let exportContentType = UTType(filenameExtension: "sooodreamy") ?? .data

    private var cloudKitUsable: Bool { ckChecked && ckStatus == .available }

    var body: some View {
        Form {
            statusSection
            backupSection
            exportSection
            importSection
        }
        .navigationTitle(L10n.t("icloud.title"))
        .navigationBarTitleDisplayMode(.inline)
        .disabled(busy)
        .overlay {
            if busy {
                ProgressView()
                    .controlSize(.large)
                    .padding(24)
                    .glassEffect(.regular, in: .rect(cornerRadius: Brand.cardRadius))
            }
        }
        .task { await checkStatus() }
        .confirmationDialog(L10n.t("icloud.restoreConfirmTitle"),
                            isPresented: $confirmRestore, titleVisibility: .visible) {
            Button(L10n.t("icloud.restore"), role: .destructive) { restoreFromCloud() }
        } message: {
            Text(L10n.t("icloud.restoreConfirmMessage"))
        }
        .confirmationDialog(L10n.t("icloud.restoreConfirmTitle"),
                            isPresented: $confirmFileRestore, titleVisibility: .visible) {
            Button(L10n.t("icloud.restore"), role: .destructive) { restoreFromFile() }
            Button(L10n.t("common.cancel"), role: .cancel) { pendingFilePayload = nil }
        } message: {
            Text(L10n.t("icloud.restoreConfirmMessage"))
        }
        .alert(L10n.t("icloud.importPasswordTitle"), isPresented: $askForImportPassphrase) {
            SecureField(L10n.t("icloud.password"), text: $importPassphrase)
            Button(L10n.t("icloud.decrypt")) { decryptImportedFile() }
                .disabled(importPassphrase.count < 12)
            Button(L10n.t("common.cancel"), role: .cancel) {
                pendingEncryptedFile = nil
                importPassphrase = ""
            }
        } message: {
            Text(L10n.t("icloud.importPasswordHint"))
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [Self.exportContentType, .data]) { result in
            handleImport(result)
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section(L10n.t("icloud.status")) {
            LabeledContent {
                statusValue(ok: cloudKitUsable, text: cloudKitDetail)
            } label: {
                Label(L10n.t("icloud.statusCloudKit"), systemImage: "icloud")
            }
            LabeledContent {
                statusValue(ok: driveAvailable,
                            text: L10n.t(driveAvailable ? "icloud.available" : "icloud.unavailable"))
            } label: {
                Label(L10n.t("icloud.statusDrive"), systemImage: "folder.badge.person.crop")
            }
        }
    }

    private func statusValue(ok: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    private var cloudKitDetail: String {
        guard ckChecked else { return L10n.t("server.health.checking") }
        switch ckStatus {
        case .available: return L10n.t("icloud.available")
        case .noAccount: return L10n.t("icloud.noAccount")
        case .restricted, .temporarilyUnavailable: return L10n.t("icloud.restricted")
        default: return L10n.t("icloud.unavailable")
        }
    }

    private var backupSection: some View {
        Section {
            LabeledContent(L10n.t("icloud.lastBackup"),
                           value: lastBackupAt.map { L10n.relativeShort($0) } ?? L10n.t("icloud.never"))
            Button {
                backupNow()
            } label: {
                Label(L10n.t("icloud.backupNow"), systemImage: "icloud.and.arrow.up")
            }
            .disabled(!cloudKitUsable)
            Button {
                confirmRestore = true
            } label: {
                Label(L10n.t("icloud.restore"), systemImage: "icloud.and.arrow.down")
            }
            .disabled(!cloudKitUsable)
        } header: {
            Text(L10n.t("icloud.backup"))
        } footer: {
            Text(L10n.t("icloud.whatsIn"))
        }
    }

    private var exportSection: some View {
        Section {
            SecureField(L10n.t("icloud.password"), text: $exportPassphrase)
                .textContentType(.newPassword)
            SecureField(L10n.t("icloud.passwordConfirm"), text: $exportPassphraseConfirmation)
                .textContentType(.newPassword)
            if let exportURL {
                ShareLink(item: exportURL) {
                    Label(L10n.t("icloud.exportShare"), systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    createExport()
                } label: {
                    Label(L10n.t("icloud.exportCreate"), systemImage: "lock.doc")
                }
                .disabled(!exportPasswordReady)
            }
            if driveAvailable {
                Button {
                    exportToDrive()
                } label: {
                    Label(L10n.t("icloud.exportToDrive"), systemImage: "folder.badge.plus")
                }
                .disabled(!exportPasswordReady)
            }
        } header: {
            Text(L10n.t("icloud.export"))
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("icloud.exportHint"))
                Text(exportPasswordHint)
                    .foregroundStyle(exportPasswordReady ? Color.secondary : Color.orange)
            }
        }
    }

    private var importSection: some View {
        Section {
            Button {
                showImporter = true
            } label: {
                Label(L10n.t("icloud.importFile"), systemImage: "doc.badge.arrow.up")
            }
        } header: {
            Text(L10n.t("icloud.section.import"))
        } footer: {
            Text(L10n.t("icloud.sideloadHint"))
        }
    }

    private var exportPasswordReady: Bool {
        exportPassphrase.count >= 12 && exportPassphrase == exportPassphraseConfirmation
    }

    private var exportPasswordHint: String {
        if exportPassphrase.count < 12 { return L10n.t("icloud.passwordTooShort") }
        if exportPassphrase != exportPassphraseConfirmation { return L10n.t("icloud.passwordMismatch") }
        return L10n.t("icloud.passwordWarning")
    }

    // MARK: Actions

    private func checkStatus() async {
        driveAvailable = UbiquityDrive.identityAvailable
        ckStatus = await CloudKitBackup.accountStatus()
        ckChecked = true
    }

    private func backupNow() {
        busy = true
        Task {
            let payload = await BackupService.makePayload(appState: appState, includeLightData: false)
            do {
                try await CloudKitBackup.save(payload)
                lastBackupAt = CloudKitBackup.lastBackupAt
                Haptics.shared.success()
                appState.notify(L10n.t("icloud.backupDone"), style: .success)
            } catch {
                appState.notify(L10n.t("icloud.backupFailed"), style: .error)
            }
            busy = false
        }
    }

    private func restoreFromCloud() {
        busy = true
        Task {
            do {
                guard let payload = try await CloudKitBackup.fetch() else {
                    appState.notify(L10n.t("icloud.noBackup"), style: .info)
                    busy = false
                    return
                }
                applyRestore(payload)
            } catch {
                appState.notify(L10n.t("icloud.restoreFailed"), style: .error)
            }
            busy = false
        }
    }

    private func applyRestore(_ payload: AppBackupPayload) {
        let count = BackupService.restore(payload, appState: appState)
        Haptics.shared.success()
        appState.notify(L10n.t("icloud.restoreDone", ["n": String(count)]), style: .love)
        Task { await appState.reloadAfterRestore() }
        dismiss()
    }

    private func createExport() {
        busy = true
        Task {
            let payload = await BackupService.makePayload(appState: appState, includeLightData: true)
            do {
                let data = try BackupService.encodeEncrypted(payload, passphrase: exportPassphrase)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("SoooDreamy-Backup.sooodreamy")
                try data.write(to: url, options: .atomic)
                exportURL = url
            } catch {
                appState.notify(L10n.t("icloud.exportFailed"), style: .error)
            }
            busy = false
        }
    }

    private func exportToDrive() {
        busy = true
        Task {
            let payload = await BackupService.makePayload(appState: appState, includeLightData: true)
            do {
                let data = try BackupService.encodeEncrypted(payload, passphrase: exportPassphrase)
                _ = try await UbiquityDrive.writeExport(data)
                Haptics.shared.success()
                appState.notify(L10n.t("icloud.exportDone"), style: .success)
            } catch {
                appState.notify(L10n.t("icloud.exportFailed"), style: .error)
            }
            busy = false
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            pendingEncryptedFile = try Data(contentsOf: url)
            importPassphrase = ""
            askForImportPassphrase = true
        } catch {
            appState.notify(L10n.t("icloud.importFailed"), style: .error)
        }
    }

    private func decryptImportedFile() {
        guard let data = pendingEncryptedFile else { return }
        do {
            pendingFilePayload = try BackupService.decodeEncrypted(data, passphrase: importPassphrase)
            pendingEncryptedFile = nil
            importPassphrase = ""
            confirmFileRestore = true
        } catch {
            appState.notify(L10n.t("icloud.importPasswordFailed"), style: .error)
        }
    }

    private func restoreFromFile() {
        guard let payload = pendingFilePayload else { return }
        pendingFilePayload = nil
        applyRestore(payload)
    }
}
