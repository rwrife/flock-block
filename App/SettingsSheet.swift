import FlockKit
import UniformTypeIdentifiers
import SwiftUI

/// Plain JSON document exported to the system share sheet / file exporter.
struct ProgressDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// Settings and data-management sheet: user-owned export, validated import,
/// and explicit delete-all. All writes are atomic and local.
struct SettingsSheet: View {
    @Bindable var session: WaveSession
    @Environment(\.dismiss) private var dismiss

    @State private var showingExport = false
    @State private var exportDocument = ProgressDocument()
    @State private var showingImportPicker = false
    @State private var pendingImportSave: ProgressSave?
    @State private var showingImportConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptic feedback", isOn: Binding(
                        get: { session.settings.hapticsEnabled },
                        set: { session.updateSettings(hapticsEnabled: $0) }
                    ))
                    .accessibilityIdentifier("settings.haptics")
                }

                Section("Data & Privacy") {
                    Button {
                        if let bytes = session.exportData() {
                            exportDocument = ProgressDocument(data: bytes)
                            showingExport = true
                        } else {
                            showAlert("Could not prepare export data")
                        }
                    } label: {
                        Label("Export save (JSON)", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("settings.export")

                    Button {
                        showingImportPicker = true
                    } label: {
                        Label("Import save (JSON)", systemImage: "square.and.arrow.down")
                    }
                    .accessibilityIdentifier("settings.import")

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete all data", systemImage: "trash")
                    }
                    .accessibilityIdentifier("settings.delete")
                }

                Section {
                    Text("100% offline. Progress, coins, unlocks, and settings stay on your iPhone. No accounts, trackers, analytics, or network calls.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
            .fileExporter(isPresented: $showingExport, document: exportDocument,
                          contentType: .json, defaultFilename: "FlockBlock-Save.json") { _ in }
            .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json]) { result in
                handleImportPicker(result)
            }
            .confirmationDialog("Replace your current progress with this save?",
                                isPresented: $showingImportConfirmation,
                                titleVisibility: .visible) {
                Button("Replace save", role: .destructive) {
                    if let pending = pendingImportSave {
                        if session.applyImport(pending) {
                            showAlert("Save restored: level \(pending.progress.level), \(pending.progress.coins) coins")
                        } else {
                            showAlert(session.storageMessage)
                        }
                        pendingImportSave = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingImportSave = nil }
            } message: {
                if let p = pendingImportSave {
                    Text("Imported save has level \(p.progress.level), \(p.progress.coins) coins, and \(p.progress.unlocked.count) unlocked blockers.")
                }
            }
            .confirmationDialog("Permanently delete all saved progress and settings?",
                                isPresented: $showingDeleteConfirmation,
                                titleVisibility: .visible) {
                Button("Delete everything", role: .destructive) {
                    if session.deleteAllData() {
                        showAlert("All progress reset to wave 1")
                    } else {
                        showAlert(session.storageMessage)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This resets your wave ladder, coins, and unlocks. This action cannot be undone.")
            }
            .alert("Flock Block", isPresented: $showingAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func handleImportPicker(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                showAlert("Could not access selected file")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                let validated = try ProgressSave.decode(data)
                pendingImportSave = validated
                showingImportConfirmation = true
            } catch {
                showAlert("File is not a valid Flock Block save: previous data untouched")
            }
        case .failure:
            break
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}
