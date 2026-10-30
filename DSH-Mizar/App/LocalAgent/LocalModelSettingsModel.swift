//
//  LocalModelSettingsModel.swift
//  DSH-Mizar
//
//  The model providers the on-device agent may call, as Settings edits them.
//
//  This is deliberately not `AppModel`: configuring a provider is not part of a
//  conversation, it happens whether or not the local agent is the current host,
//  and a settings screen that closed the operator's session socket to ask a
//  question about an API key would be the wrong shape. It opens its own
//  connection to the same kernel (the kernel serves several) and closes it when
//  the screen goes away.
//
//  Everything it writes goes through the two methods the kernel documents:
//  `kernel.config.set`, whose provider array replaces rather than merges, and
//  `kernel.apiKey.set`, which refuses a provider that is not in the
//  configuration yet -- hence save's fixed order.
//

import Foundation
import MizarKit

@MainActor
@Observable
final class LocalModelSettingsModel {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var providers: [KernelProviderConfig] = []
    private(set) var keyedProviderIDs: Set<String> = []
    private(set) var defaultModel: KernelModelRef?
    private(set) var config: KernelConfig?

    private var connection: MizarConnection?
    private var agent: LocalAgentController?

    /// Whether this provider may call the model: configured here, or shipped.
    func hasKey(_ provider: KernelProviderConfig) -> Bool {
        keyedProviderIDs.contains(provider.id)
    }

    /// The key already stored for a provider, for testing an edit left blank.
    func storedKey(forProvider id: String) -> String? {
        KeychainKernelKeyValueStore().value(forKey: "apiKey." + id)
    }

    // MARK: - Loading

    func load(agent: LocalAgentController) async {
        self.agent = agent
        state = .loading
        do {
            try await ensureConnection()
            try await reload()
            state = .ready
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    func close() async {
        let closing = connection
        connection = nil
        if let closing { await closing.disconnect() }
    }

    private func ensureConnection() async throws {
        guard let agent else { throw StoreError.notLoaded }
        if connection == nil {
            connection = try await agent.adminConnection()
        }
    }

    private func reload() async throws {
        guard let connection else { throw StoreError.notLoaded }
        let config = try await connection.call("kernel.config.get", as: KernelConfigResponse.self)
        let status = try await connection.call("kernel.apiKey.status", as: KernelAPIKeyStatus.self)
        self.config = config.config
        providers = config.config.providers
        defaultModel = config.config.defaultModel
        keyedProviderIDs = Set(status.providers.filter(\.hasKey).map(\.id))
    }

    // MARK: - Writing

    /// Add or replace one provider, and its key when a new one was typed.
    ///
    /// - Parameters:
    ///   - draft: the form.
    ///   - defaultModelID: the model new sessions should take; `nil` keeps the
    ///     current route when it still exists.
    func save(draft: LocalProviderDraft, defaultModelID: String? = nil) async throws {
        try await ensureConnection()
        guard let connection, let config else { throw StoreError.notLoaded }

        let taken = Set(providers.map(\.id))
        let id = draft.existingID
            ?? LocalProviderDraft.makeID(name: draft.name, baseURL: draft.baseURL, taken: taken)
        let provider = draft.provider(id: id)
        let chosen: KernelModelRef? = defaultModelID.map { KernelModelRef(provider: id, model: $0) }
        let updated = LocalModelSetup.upserting(provider, in: config, defaultModel: chosen)

        _ = try await connection.call(
            "kernel.config.set",
            payload: try KernelConfigWire.patch(updated),
            as: KernelConfigResponse.self,
        )
        // Second, and only when there is something to write: the kernel refuses
        // a key for a provider that is not in the configuration, and an edit
        // that left the key blank must not clear the one that works.
        let key = draft.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            _ = try await connection.call(
                "kernel.apiKey.set",
                payload: KernelConfigWire.apiKeySet(provider: id, key: key),
                as: JSONValue.self,
            )
        }
        try await reload()
        agent?.refreshKeyPresence()
    }

    /// Remove a provider, its key, and -- if it was the route -- the route.
    func remove(providerID: String) async throws {
        try await ensureConnection()
        guard let connection, let config else { throw StoreError.notLoaded }
        let updated = LocalModelSetup.removing(providerID: providerID, from: config)
        _ = try await connection.call(
            "kernel.config.set",
            payload: try KernelConfigWire.patch(updated),
            as: KernelConfigResponse.self,
        )
        _ = try await connection.call(
            "kernel.apiKey.clear",
            payload: KernelConfigWire.apiKeyClear(provider: providerID),
            as: JSONValue.self,
        )
        try await reload()
        agent?.refreshKeyPresence()
    }

    /// Point new sessions at one model.
    func setDefault(provider: String, model: String) async throws {
        try await ensureConnection()
        guard let connection, let config else { throw StoreError.notLoaded }
        var updated = config
        updated.defaultModel = KernelModelRef(provider: provider, model: model)
        _ = try await connection.call(
            "kernel.config.set",
            payload: try KernelConfigWire.patch(updated),
            as: KernelConfigResponse.self,
        )
        try await reload()
    }

    // MARK: - Errors

    enum StoreError: Error, Equatable {
        case notLoaded
    }

    static func describe(_ error: any Error) -> String {
        if let error = error as? MizarError { return error.message }
        return (error as NSError).localizedDescription
    }
}
