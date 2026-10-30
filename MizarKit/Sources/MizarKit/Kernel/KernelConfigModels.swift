//
//  KernelConfigModels.swift
//  MizarKit
//
//  The kernel's configuration, in Swift.
//
//  `kernel.config.get` answers with the kernel's stored configuration and
//  `kernel.config.set` accepts a patch of it; both are JSON objects with a shape
//  that is fixed by `LocalKernel/kernel/src/core/config.ts`. The app has to read
//  one and write the other to add a model provider, so the shape lives here
//  rather than being assembled out of `JSONValue` in the middle of a view.
//
//  Deliberately not the same type as ``ModelCatalog``. The catalogue is a
//  projection the host may narrow for the picker; the configuration is what the
//  kernel will actually call. They agree today, and a field that only one of
//  them carries must not be inferred into the other -- that is how a picker
//  starts offering a model the engine cannot reach.
//

import Foundation

/// One provider entry, as the kernel stores it.
public struct KernelProviderConfig: Codable, Sendable, Equatable, Identifiable {
    /// Stable identity. The API key is filed under `apiKey.<id>`, so this must
    /// not change when the operator renames the provider.
    public var id: String
    /// What the picker calls it.
    public var name: String
    /// Base URL of an OpenAI-compatible deployment.
    public var baseUrl: String
    /// Path appended to the base URL. The kernel defaults to `/chat/completions`.
    public var path: String?
    /// Whether the provider reports usage on streamed completions.
    ///
    /// Absent means the kernel's default for that field, which is `false` for a
    /// provider written by the app: asking for `stream_options.include_usage`
    /// from a deployment that does not know the field fails the whole turn, and
    /// missing token counts are the cheaper failure.
    public var usage: Bool?
    /// The models this provider offers.
    public var models: [KernelModelConfig]

    public init(
        id: String,
        name: String,
        baseUrl: String,
        path: String? = nil,
        usage: Bool? = nil,
        models: [KernelModelConfig],
    ) {
        self.id = id
        self.name = name
        self.baseUrl = baseUrl
        self.path = path
        self.usage = usage
        self.models = models
    }
}

/// One model inside a provider entry.
public struct KernelModelConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var description: String?
    /// Reasoning efforts, when the model takes one.
    public var efforts: [KernelEffortConfig]?
    public var defaultEffort: String?

    public init(
        id: String,
        name: String,
        description: String? = nil,
        efforts: [KernelEffortConfig]? = nil,
        defaultEffort: String? = nil,
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.efforts = efforts
        self.defaultEffort = defaultEffort
    }
}

/// One reasoning effort a model accepts.
public struct KernelEffortConfig: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var description: String?

    public init(id: String, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

/// `{ provider, model, reasoningEffort }`, the route a new session takes.
public struct KernelModelRef: Codable, Sendable, Equatable {
    public var provider: String
    public var model: String
    public var reasoningEffort: String?

    public init(provider: String, model: String, reasoningEffort: String? = nil) {
        self.provider = provider
        self.model = model
        self.reasoningEffort = reasoningEffort
    }
}

/// The whole configuration, as `kernel.config.get` reports it.
public struct KernelConfig: Codable, Sendable, Equatable {
    public var providers: [KernelProviderConfig]
    public var defaultModel: KernelModelRef
    /// Reported in `session.stats`. Optional on the wire; the kernel has a default.
    public var contextWindow: Int?
    public var systemPromptAddendum: String?
    public var defaultPreset: String?

    public init(
        providers: [KernelProviderConfig],
        defaultModel: KernelModelRef,
        contextWindow: Int? = nil,
        systemPromptAddendum: String? = nil,
        defaultPreset: String? = nil,
    ) {
        self.providers = providers
        self.defaultModel = defaultModel
        self.contextWindow = contextWindow
        self.systemPromptAddendum = systemPromptAddendum
        self.defaultPreset = defaultPreset
    }
}

/// The `{ config: … }` envelope `kernel.config.get` answers with.
public struct KernelConfigResponse: Decodable, Sendable {
    public let config: KernelConfig
}

/// Wire helpers for the two calls that write the configuration.
public enum KernelConfigWire {
    /// The payload for `kernel.config.set`.
    ///
    /// A patch, not a replacement: the kernel merges scalars and replaces the
    /// provider array wholesale (`mergeConfig`), so the caller must send the
    /// complete list it wants to end up with.
    public static func patch(_ config: KernelConfig) throws -> JSONValue {
        let data = try JSONEncoder().encode(config)
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// The payload for `kernel.apiKey.set`.
    public static func apiKeySet(provider: String, key: String) -> JSONValue {
        .object(["provider": .string(provider), "key": .string(key)])
    }

    /// The payload for `kernel.apiKey.clear`.
    public static func apiKeyClear(provider: String) -> JSONValue {
        .object(["provider": .string(provider)])
    }
}

/// The `{ providers: [{ id, name, hasKey }] }` envelope of `kernel.apiKey.status`.
public struct KernelAPIKeyStatus: Decodable, Sendable, Equatable {
    public struct Provider: Decodable, Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let hasKey: Bool
    }
    public let providers: [Provider]
}
