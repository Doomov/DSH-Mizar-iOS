//
//  LocalProviderDraft.swift
//  MizarKit
//
//  What the "add a model provider" form holds, and what it becomes.
//
//  Everything here is a pure function on purpose: the address an operator types
//  has four ways to be wrong, the id a provider gets has to stay stable for the
//  life of its API key, and deleting the default provider has to leave a
//  configuration that still names a model. Those are the parts that can be
//  tested, and none of them need a view, a kernel or a network.
//
//  The kernel's rules are the ones enforced here, not invented: a provider needs
//  `id`, `name`, `baseUrl` and at least one model (`config.ts`), the provider
//  array is replaced wholesale by `kernel.config.set`, and the API key is filed
//  under `apiKey.<id>` in the platform key-value store, which is why the id is
//  not derived from the name after the first save.
//

import Foundation

/// One filled-in provider form.
public struct LocalProviderDraft: Sendable, Equatable {
    /// The display name. Blank means "use the address's host".
    public var name: String
    /// The address, as typed: scheme optional, trailing slash ignored.
    public var baseURL: String
    /// The key. Never stored here -- the form keeps it only long enough to test
    /// and save it.
    public var apiKey: String
    /// The model ids the operator picked, in the order they were shown.
    public var modelIDs: [String]
    /// The id this provider already has, when the form is editing one.
    public var existingID: String?

    public init(
        name: String = "",
        baseURL: String = "",
        apiKey: String = "",
        modelIDs: [String] = [],
        existingID: String? = nil,
    ) {
        self.name = name
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.modelIDs = modelIDs
        self.existingID = existingID
    }

    /// What is wrong with the form, if anything.
    public enum Problem: Error, Equatable, Sendable {
        case missingAddress
        case invalidAddress
        case missingKey
        case missingModel
    }

    /// Check the form before anything is written.
    ///
    /// - Parameter requiringKey: `false` when editing a provider whose key is
    ///   already stored and the operator left the field blank on purpose.
    public func validate(requiringKey: Bool = true) throws {
        let address = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else { throw Problem.missingAddress }
        guard Self.normalizedBaseURL(address) != nil else { throw Problem.invalidAddress }
        if requiringKey {
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Problem.missingKey
            }
        }
        guard !modelIDs.isEmpty else { throw Problem.missingModel }
    }

    /// The provider entry this form becomes.
    ///
    /// - Parameters:
    ///   - id: the id to file it under; see ``makeID(name:baseURL:taken:)``.
    /// - Returns: the entry, ready for `kernel.config.set`.
    public func provider(id: String) -> KernelProviderConfig {
        let address = Self.normalizedBaseURL(baseURL) ?? baseURL
        let display = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = URL(string: address)?.host ?? address
        return KernelProviderConfig(
            id: id,
            name: display.isEmpty ? host : display,
            baseUrl: address,
            path: "/chat/completions",
            // Off for a provider the operator typed in: `stream_options` is an
            // OpenAI extension, and a deployment that rejects it fails the turn
            // rather than merely omitting token counts.
            usage: false,
            models: Self.models(from: modelIDs),
        )
    }

    /// The route a new session should take for this provider: its first model.
    public func defaultModel(for provider: KernelProviderConfig) -> KernelModelRef? {
        guard let first = provider.models.first else { return nil }
        return KernelModelRef(provider: provider.id, model: first.id)
    }

    // MARK: - Pure helpers

    /// `https://api.example.com`, from `api.example.com/` or ` https://api.example.com `.
    ///
    /// - Parameter raw: what the operator typed.
    /// - Returns: the address to save and to dial, or `nil` when it cannot be one.
    public static func normalizedBaseURL(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else { return nil }
        var normalized = text
        while normalized.hasSuffix("/") { normalized.removeLast() }
        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    /// A stable id for a new provider.
    ///
    /// `custom-<slug>`, where the slug comes from the name (or the host when the
    /// name is blank). Once the provider exists its id never changes, because
    /// the API key is filed under it.
    public static func makeID(name: String, baseURL: String, taken: Set<String>) -> String {
        let host = normalizedBaseURL(baseURL).flatMap { URL(string: $0)?.host } ?? ""
        let seed = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? host : name
        var slug = ""
        var lastWasDash = false
        for character in seed.lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character)
                lastWasDash = false
            } else if !lastWasDash, !slug.isEmpty {
                slug.append("-")
                lastWasDash = true
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        if slug.count > 32 { slug = String(slug.prefix(32)); while slug.hasSuffix("-") { slug.removeLast() } }
        if slug.isEmpty { slug = "provider" }
        var candidate = "custom-" + slug
        var suffix = 2
        while taken.contains(candidate) {
            candidate = "custom-" + slug + "-" + String(suffix)
            suffix += 1
        }
        return candidate
    }

    /// Model entries for a list of ids.
    public static func models(from ids: [String]) -> [KernelModelConfig] {
        var seen = Set<String>()
        var models: [KernelModelConfig] = []
        for raw in ids {
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            models.append(KernelModelConfig(id: id, name: id))
        }
        return models
    }
}

/// Adding, editing and removing providers inside a configuration.
///
/// The kernel replaces its provider array wholesale, so every edit is "build the
/// list I want, then write it". These functions are that list.
public enum LocalModelSetup {
    /// The configuration with `provider` added, or replacing the entry with its id.
    ///
    /// - Parameters:
    ///   - provider: the entry to write.
    ///   - config: what the kernel currently has.
    ///   - defaultModel: the route to new sessions, when the operator chose one.
    /// - Returns: the configuration to send.
    public static func upserting(
        _ provider: KernelProviderConfig,
        in config: KernelConfig,
        defaultModel: KernelModelRef? = nil,
    ) -> KernelConfig {
        var providers = config.providers
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
        } else {
            providers.append(provider)
        }
        var updated = config
        updated.providers = providers
        // The chosen route wins when it still names something in the list --
        // the choice may be on a provider other than the one being edited. Failing
        // that, keep a route that still exists, or take the new provider's first
        // model so a fresh install is usable without a second decision.
        if let defaultModel, routeIsValid(defaultModel, in: providers) {
            updated.defaultModel = KernelModelRef(
                provider: defaultModel.provider,
                model: defaultModel.model,
                reasoningEffort: defaultModel.reasoningEffort,
            )
        } else if let existing = existingRoute(in: providers, current: config.defaultModel) {
            updated.defaultModel = existing
        } else if let first = provider.models.first {
            updated.defaultModel = KernelModelRef(provider: provider.id, model: first.id)
        }
        return updated
    }

    /// Whether a route still names a model inside a provider that exists.
    private static func routeIsValid(_ route: KernelModelRef, in providers: [KernelProviderConfig]) -> Bool {
        providers.contains { provider in
            provider.id == route.provider && provider.models.contains { $0.id == route.model }
        }
    }

    /// The configuration with one provider gone.
    ///
    /// When the removed provider was the default, the first model of the first
    /// remaining provider takes over. Removing the last provider leaves the
    /// route naming a provider that no longer exists -- the app treats "no
    /// providers" as unconfigured and refuses to send, which is the honest
    /// state, and inventing a provider to point at would not be.
    public static func removing(providerID: String, from config: KernelConfig) -> KernelConfig {
        var updated = config
        updated.providers = config.providers.filter { $0.id != providerID }
        if config.defaultModel.provider == providerID {
            if let first = updated.providers.first, let model = first.models.first {
                updated.defaultModel = KernelModelRef(provider: first.id, model: model.id)
            }
        }
        return updated
    }

    /// Whether the configuration can actually serve a turn.
    public static func isUsable(_ config: KernelConfig) -> Bool {
        config.providers.contains { provider in
            provider.models.contains { $0.id == config.defaultModel.model }
                && provider.id == config.defaultModel.provider
        }
    }

    /// The current route, if the configuration still contains it.
    private static func existingRoute(
        in providers: [KernelProviderConfig],
        current: KernelModelRef,
    ) -> KernelModelRef? {
        guard let provider = providers.first(where: { $0.id == current.provider }),
              provider.models.contains(where: { $0.id == current.model }) else { return nil }
        return current
    }
}
