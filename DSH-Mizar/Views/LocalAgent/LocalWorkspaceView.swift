//
//  LocalWorkspaceView.swift
//  DSH-Mizar
//
//  Name a folder, and the on-device agent makes it.
//
//  The remote flow asks for a *path* because the directory already exists on
//  the computer. Here the agent owns its root, so a workspace is a folder this
//  phone can create: a name, a folder of that name, and the operator can open
//  it in the Files app the way they would open any other folder.
//

import MizarKit
import SwiftUI

struct LocalWorkspaceView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var creating = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workspace name", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { Task { await create() } }
                        .accessibilityIdentifier("localWorkspace.name")
                } footer: {
                    Text("A folder with this name is created in the on-device agent's folder, where the Files app can reach it.")
                }

                if let failure {
                    Section {
                        Text(verbatim: failure)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task { await create() }
                    } label: {
                        HStack(spacing: 8) {
                            if creating { ProgressView().controlSize(.small) }
                            Text(creating ? "Creating…" : "Create workspace")
                        }
                    }
                    .disabled(creating || trimmed.isEmpty)
                    .accessibilityIdentifier("localWorkspace.create")
                }
            }
            .navigationTitle(Text("New workspace"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func create() async {
        guard !trimmed.isEmpty, !creating else { return }
        creating = true
        failure = nil
        defer { creating = false }
        do {
            _ = try await model.createLocalWorkspace(name: trimmed)
            dismiss()
        } catch {
            // The kernel's refusal is a sentence already: "already exists" is
            // the one an operator will actually hit.
            failure = (error as? LocalizedError)?.errorDescription
                ?? (error as NSError).localizedDescription
        }
    }
}
