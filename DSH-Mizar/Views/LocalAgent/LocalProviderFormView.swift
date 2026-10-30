//
//  LocalProviderFormView.swift
//  DSH-Mizar
//
//  One model provider, typed in by hand: a name, an address, a key.
//
//  The key is the only thing on this screen that cannot be checked without the
//  network, so "Test connection" is the centre of it: one `GET /models` says
//  whether the address exists, whether the key is accepted, and which models
//  the provider offers. The models it lists are stored whole -- the picker is
//  the app's model control, and a provider that only ever offers one model is a
//  provider whose other models are unreachable from this phone.
//
//  Nothing here writes until Save: the test is a read, and a failed test is a
//  sentence rather than a half-saved provider.
//

import MizarKit
import SwiftUI

struct LocalProviderFormView: View {
    let store: LocalModelSettingsModel
    /// The provider being edited, or `nil` when this is a new one.
    let provider: KernelProviderConfig?
    /// Whether the keychain already holds a key for the edited provider.
    let hasKey: Bool
    var onChanged: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var address: String
    @State private var key = ""
    @State private var models: [String]
    @State private var defaultModelID: String?
    @State private var manualModel = ""
    @State private var probing = false
    @State private var probeFailed = false
    @State private var probeSucceeded = false
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var confirmingDelete = false
    /// Which of the four probe failures the last test produced.
    @State private var failure: ModelListClient.Failure?

    init(
        store: LocalModelSettingsModel,
        provider: KernelProviderConfig?,
        hasKey: Bool,
        onChanged: @escaping () -> Void = {},
    ) {
        self.store = store
        self.provider = provider
        self.hasKey = hasKey
        self.onChanged = onChanged
        _name = State(initialValue: provider?.name ?? "")
        _address = State(initialValue: provider?.baseUrl ?? "")
        _models = State(initialValue: provider?.models.map(\.id) ?? [])
        _defaultModelID = State(initialValue: {
            guard let provider, store.defaultModel?.provider == provider.id else { return nil }
            return store.defaultModel?.model
        }())
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("localAgent.form.name")
                TextField("API base URL", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityIdentifier("localAgent.form.address")
                SecureField(
                    "API Key",
                    text: $key,
                    prompt: Text(
                        hasKey
                            ? "An API key is already saved for this provider."
                            : "API Key",
                    ),
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("localAgent.form.key")
            } footer: {
                Text("The address is the base of an OpenAI-compatible deployment, for example https://api.deepseek.com.")
            }

            Section {
                Button {
                    Task { await test() }
                } label: {
                    HStack(spacing: 8) {
                        if probing {
                            ProgressView().controlSize(.small)
                        }
                        Text(probing ? "Testing…" : "Test connection")
                    }
                }
                .disabled(probing || address.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("localAgent.form.test")

                if let errorMessage {
                    Text(verbatim: errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if probeFailed, let failure = failureText {
                    Text(failure)
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if probeSucceeded {
                    Text(
                        models.isEmpty
                            ? String(localized: "Connected, but no models were listed.")
                            : String(
                                format: String(localized: "Connected — %lld models found"),
                                models.count,
                            ),
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if !models.isEmpty {
                Section {
                    Picker("Default model", selection: $defaultModelID) {
                        ForEach(models, id: \.self) { model in
                            Text(verbatim: model).tag(Optional(model))
                        }
                    }
                    .accessibilityIdentifier("localAgent.form.defaultModel")
                } footer: {
                    Text("New sessions start on this model. Every model the provider listed is available in the picker.")
                }
            } else if probeSucceeded || provider != nil {
                Section {
                    TextField("Type a model id", text: $manualModel)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("localAgent.form.manualModel")
                } footer: {
                    Text("This address listed no models. Type a model id below.")
                }
            }

            if let provider {
                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Text("Delete")
                    }
                    .disabled(saving)
                    .accessibilityIdentifier("localAgent.form.delete")
                } footer: {
                    Text("Deleting this provider also removes its key.")
                }
            }
        }
        .navigationTitle(Text(provider == nil ? "New model provider" : "Edit model provider"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView().controlSize(.small) } else { Text("Save") }
                }
                .disabled(saving)
                .accessibilityIdentifier("localAgent.form.save")
            }
        }
        .confirmationDialog(
            Text("Delete this provider? Sessions that use it will stop working."),
            isPresented: $confirmingDelete,
            titleVisibility: .visible,
        ) {
            Button("Delete", role: .destructive) {
                Task { await remove() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Actions

    /// Ask the provider what it offers. A read: nothing is saved here.
    private func test() async {
        errorMessage = nil
        probeFailed = false
        probeSucceeded = false
        guard let normalized = LocalProviderDraft.normalizedBaseURL(address) else {
            errorMessage = String(localized: "This address is not usable.")
            probeFailed = true
            return
        }
        // An edit usually leaves the key blank on purpose. Testing it must use
        // the key that is stored, not refuse the test.
        var effectiveKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if effectiveKey.isEmpty, hasKey, let provider {
            effectiveKey = store.storedKey(forProvider: provider.id) ?? ""
        }
        guard !effectiveKey.isEmpty else {
            errorMessage = String(localized: "Add an API key to use this provider.")
            probeFailed = true
            return
        }
        probing = true
        defer { probing = false }
        let result = await ModelListClient().models(baseURL: normalized, apiKey: effectiveKey)
        switch result {
        case .success(let ids):
            models = ids
            probeSucceeded = true
            if let current = defaultModelID, ids.contains(current) {
                // Keep the operator's choice when the provider still offers it.
            } else {
                defaultModelID = ids.first
            }
        case .failure(let failure):
            probeFailed = true
            self.failure = failure
        }
    }

    private func save() async {
        saving = true
        errorMessage = nil
        defer { saving = false }
        let draft = LocalProviderDraft(
            name: name,
            baseURL: address,
            apiKey: key,
            modelIDs: selectedModels,
            existingID: provider?.id,
        )
        do {
            // An edit that leaves the key blank keeps the stored one; only a
            // provider that has none needs one before it can be saved.
            try draft.validate(requiringKey: !(hasKey && draft.apiKey.isEmpty))
            try await store.save(draft: draft, defaultModelID: defaultModelIDForSave)
            onChanged()
            dismiss()
        } catch let problem as LocalProviderDraft.Problem {
            errorMessage = Self.message(for: problem)
        } catch {
            errorMessage = LocalModelSettingsModel.describe(error)
        }
    }

    private func remove() async {
        guard let provider else { return }
        saving = true
        defer { saving = false }
        do {
            try await store.remove(providerID: provider.id)
            onChanged()
            dismiss()
        } catch {
            errorMessage = LocalModelSettingsModel.describe(error)
        }
    }

    // MARK: - Derived

    /// The models the provider will offer: everything the test listed, or the
    /// single id the operator typed when the endpoint listed nothing.
    private var selectedModels: [String] {
        if !models.isEmpty { return models }
        let manual = manualModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return manual.isEmpty ? [] : [manual]
    }

    /// The route to save, when it is a model this provider really offers.
    private var defaultModelIDForSave: String? {
        if let defaultModelID, selectedModels.contains(defaultModelID) { return defaultModelID }
        return selectedModels.first
    }

    private var failureText: String? {
        switch failure {
        case .unauthorized: String(localized: "The API key was rejected.")
        case .missingEndpoint: String(localized: "No /models endpoint at this address.")
        case .unreachable: String(localized: "Could not reach this address.")
        case .server: String(localized: "The server answered with an error.")
        case .unreadable: String(localized: "Could not read the model list.")
        case nil: nil
        }
    }

    /// A sentence for each way the form is incomplete.
    private static func message(for problem: LocalProviderDraft.Problem) -> String {
        switch problem {
        case .missingAddress: String(localized: "Type the provider's address.")
        case .invalidAddress: String(localized: "This address is not usable.")
        case .missingKey: String(localized: "Add an API key to use this provider.")
        case .missingModel: String(localized: "Type a model id or test the connection first.")
        }
    }
}
