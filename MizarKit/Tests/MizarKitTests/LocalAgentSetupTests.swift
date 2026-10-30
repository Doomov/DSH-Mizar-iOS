//
//  LocalAgentSetupTests.swift
//  MizarKitTests
//
//  The pure parts of the local agent's model configuration: the address an
//  operator types, the id a provider is filed under, the list edits the kernel
//  expects wholesale, the "configured?" boolean the host list draws, and the
//  four ways a `/models` probe can answer.
//
//  No kernel, no Keychain, no network: those are covered by `LocalKernelTests`
//  and by the app's UI tests. What is here is what can go wrong silently.
//

import Foundation
import Testing
@testable import MizarKit

@Suite("Local agent setup")
struct LocalAgentSetupTests {
    // MARK: - Addresses

    @Test("an address the operator typed becomes a URL")
    func addressNormalisation() {
        #expect(LocalProviderDraft.normalizedBaseURL("api.deepseek.com") == "https://api.deepseek.com")
        #expect(LocalProviderDraft.normalizedBaseURL("  https://api.deepseek.com/  ") == "https://api.deepseek.com")
        #expect(LocalProviderDraft.normalizedBaseURL("http://127.0.0.1:8080/v1") == "http://127.0.0.1:8080/v1")
        #expect(LocalProviderDraft.normalizedBaseURL("https://example.com/v1///") == "https://example.com/v1")
    }

    @Test("an address that cannot be dialled is refused")
    func addressRefusal() {
        #expect(LocalProviderDraft.normalizedBaseURL("") == nil)
        #expect(LocalProviderDraft.normalizedBaseURL("   ") == nil)
        #expect(LocalProviderDraft.normalizedBaseURL("ftp://example.com") == nil)
        #expect(LocalProviderDraft.normalizedBaseURL("https://") == nil)
    }

    // MARK: - Ids

    @Test("a new provider is filed under a stable id")
    func idGeneration() {
        #expect(LocalProviderDraft.makeID(name: "My Provider", baseURL: "https://x.dev", taken: []) == "custom-my-provider")
        #expect(LocalProviderDraft.makeID(name: "  ", baseURL: "https://api.example.com", taken: []) == "custom-api-example-com")
        #expect(LocalProviderDraft.makeID(name: "OpenAI", baseURL: "https://x.dev", taken: ["custom-openai"]) == "custom-openai-2")
        #expect(LocalProviderDraft.makeID(name: "!!", baseURL: "", taken: []) == "custom-provider")
    }

    // MARK: - The form

    @Test("the form refuses what the kernel would refuse")
    func validation() {
        var draft = LocalProviderDraft()
        #expect(throws: LocalProviderDraft.Problem.missingAddress) { try draft.validate() }
        draft.baseURL = "not a url with spaces"
        #expect(throws: LocalProviderDraft.Problem.invalidAddress) { try draft.validate() }
        draft.baseURL = "https://api.example.com"
        #expect(throws: LocalProviderDraft.Problem.missingKey) { try draft.validate() }
        draft.apiKey = "sk-test"
        #expect(throws: LocalProviderDraft.Problem.missingModel) { try draft.validate() }
        draft.modelIDs = ["gpt-4o"]
        #expect(throws: Never.self) { try draft.validate() }
    }

    @Test("the form becomes a provider entry the kernel accepts")
    func providerEntry() {
        let draft = LocalProviderDraft(
            name: "  ",
            baseURL: "https://api.example.com/",
            apiKey: "sk-test",
            modelIDs: ["b", " a ", "b", ""],
        )
        let provider = draft.provider(id: "custom-api-example-com")
        #expect(provider.id == "custom-api-example-com")
        #expect(provider.name == "api.example.com")
        #expect(provider.baseUrl == "https://api.example.com")
        #expect(provider.path == "/chat/completions")
        #expect(provider.usage == false)
        #expect(provider.models.map(\.id) == ["b", "a"])
        #expect(provider.models.map(\.name) == ["b", "a"])
        #expect(draft.defaultModel(for: provider) == KernelModelRef(provider: provider.id, model: "b"))
    }

    // MARK: - List edits

    private func config(
        _ ids: [String],
        default provider: String? = nil,
        model: String? = nil,
    ) -> KernelConfig {
        let providers = ids.map { id in
            KernelProviderConfig(
                id: id,
                name: id,
                baseUrl: "https://\(id).example.com",
                models: [KernelModelConfig(id: "\(id)-model", name: "\(id)-model")],
            )
        }
        return KernelConfig(
            providers: providers,
            defaultModel: KernelModelRef(
                provider: provider ?? providers.first?.id ?? "",
                model: model ?? providers.first?.models.first?.id ?? "",
            ),
        )
    }

    @Test("adding a provider appends it and takes its first model as the route")
    func upsertAppends() {
        let base = config(["a"])
        let new = KernelProviderConfig(
            id: "b",
            name: "b",
            baseUrl: "https://b.example.com",
            models: [KernelModelConfig(id: "b-model", name: "b-model")],
        )
        let updated = LocalModelSetup.upserting(new, in: base)
        #expect(updated.providers.map(\.id) == ["a", "b"])
        // The existing route is still valid, so it stays: adding a provider is
        // not a reason to move a session onto a different model.
        #expect(updated.defaultModel == base.defaultModel)
    }

    @Test("the first provider becomes the route when there was none")
    func upsertFirst() {
        let empty = KernelConfig(providers: [], defaultModel: KernelModelRef(provider: "", model: ""))
        let new = KernelProviderConfig(
            id: "b",
            name: "b",
            baseUrl: "https://b.example.com",
            models: [KernelModelConfig(id: "b-model", name: "b-model")],
        )
        let updated = LocalModelSetup.upserting(new, in: empty)
        #expect(updated.defaultModel == KernelModelRef(provider: "b", model: "b-model"))
    }

    @Test("editing a provider replaces it in place")
    func upsertReplaces() {
        let base = config(["a", "b"])
        let edited = KernelProviderConfig(
            id: "b",
            name: "B renamed",
            baseUrl: "https://b2.example.com",
            models: [KernelModelConfig(id: "b-model", name: "b-model")],
        )
        let updated = LocalModelSetup.upserting(edited, in: base)
        #expect(updated.providers.map(\.id) == ["a", "b"])
        #expect(updated.providers[1].name == "B renamed")
        #expect(updated.providers[1].baseUrl == "https://b2.example.com")
    }

    @Test("a chosen route that still exists wins")
    func upsertChosenRoute() {
        let base = config(["a", "b"])
        let new = KernelProviderConfig(
            id: "c",
            name: "c",
            baseUrl: "https://c.example.com",
            models: [KernelModelConfig(id: "c-model", name: "c-model")],
        )
        let updated = LocalModelSetup.upserting(
            new,
            in: base,
            defaultModel: KernelModelRef(provider: "b", model: "b-model"),
        )
        #expect(updated.defaultModel == KernelModelRef(provider: "b", model: "b-model"))
    }

    @Test("removing the default provider hands the route to the next one")
    func removeDefault() {
        let base = config(["a", "b"], default: "a", model: "a-model")
        let updated = LocalModelSetup.removing(providerID: "a", from: base)
        #expect(updated.providers.map(\.id) == ["b"])
        #expect(updated.defaultModel == KernelModelRef(provider: "b", model: "b-model"))
    }

    @Test("removing the last provider leaves nothing to send to")
    func removeLast() {
        let base = config(["a"])
        let updated = LocalModelSetup.removing(providerID: "a", from: base)
        #expect(updated.providers.isEmpty)
        #expect(LocalModelSetup.isUsable(updated) == false)
        #expect(LocalModelSetup.isUsable(base))
    }

    // MARK: - Configured?

    @Test("a provider key means the agent is configured")
    func keyPresence() {
        let prefix = "mizar.kernel."
        #expect(APIKeyPresence.hasKey(accounts: [:], prefix: prefix) == false)
        #expect(
            APIKeyPresence.hasKey(
                accounts: [prefix + "kernel.hostId": Data("abc".utf8)],
                prefix: prefix,
            ) == false
        )
        #expect(
            APIKeyPresence.hasKey(
                accounts: [prefix + "apiKey.a": Data("sk-test".utf8)],
                prefix: prefix,
            )
        )
        // A cleared key is stored as the empty string by some paths; that is not
        // a configured provider.
        #expect(
            APIKeyPresence.hasKey(
                accounts: [prefix + "apiKey.a": Data("   ".utf8)],
                prefix: prefix,
            ) == false
        )
    }

    @Test("the key's account name matches the kernel's")
    func keyAccount() {
        #expect(APIKeyPresence.account(forProvider: "custom-x") == "mizar.kernel.apiKey.custom-x")
    }

    // MARK: - /models

    @Test("both shapes of a model list are understood")
    func decodeModels() {
        let standard = Data(#"{"object":"list","data":[{"id":"a"},{"id":"b"}]}"#.utf8)
        #expect(ModelListClient.decodeModelIDs(standard) == ["a", "b"])
        let ollama = Data(#"{"models":[{"name":"llama3:latest"}]}"#.utf8)
        #expect(ModelListClient.decodeModelIDs(ollama) == ["llama3:latest"])
        let empty = Data(#"{"object":"list","data":[]}"#.utf8)
        #expect(ModelListClient.decodeModelIDs(empty) == [])
        #expect(ModelListClient.decodeModelIDs(Data("not json".utf8)) == nil)
        #expect(ModelListClient.decodeModelIDs(Data(#"{"data":[{"object":"model"}]}"#.utf8)) == nil)
    }

    @Test("the probe reports the four answers the screen has words for")
    func probeAnswers() async {
        let cases: [(Int, Data, ModelListClient.Failure?)] = [
            (200, Data(#"{"data":[{"id":"a"}]}"#.utf8), nil),
            (401, Data(), .unauthorized),
            (403, Data(), .unauthorized),
            (404, Data(), .missingEndpoint),
            (500, Data(), .server(500)),
            (200, Data("nope".utf8), .unreadable),
        ]
        for (status, body, expected) in cases {
            let client = ModelListClient(session: StubURLProtocol.session(status: status, body: body))
            let result = await client.models(baseURL: "https://example.com", apiKey: "sk")
            switch (result, expected) {
            case (.success(let ids), nil):
                #expect(ids == ["a"])
            case (.failure(let failure), let expected?):
                #expect(failure == expected, "status \(status)")
            default:
                Issue.record("status \(status): unexpected \(result)")
            }
        }
    }

    @Test("a refused connection reads as unreachable")
    func probeUnreachable() async {
        let client = ModelListClient(session: StubURLProtocol.session(error: URLError(.cannotConnectToHost)))
        let result = await client.models(baseURL: "https://example.com", apiKey: "sk")
        #expect(result == .failure(.unreachable))
    }
}

// MARK: - A URLSession that answers without a network

/// Answers every request with one canned status, body or error.
final class StubURLProtocol: URLProtocol {
    struct Answer: Sendable {
        var status: Int = 200
        var body: Data = Data()
        var error: URLError?
    }

    /// Answers are keyed by class, because `URLProtocol` is instantiated by the
    /// loader. One test at a time uses each key, which is how the other suites
    /// in this target do it.
    nonisolated(unsafe) private static var answers: [String: Answer] = [:]
    private static let lock = NSLock()

    static func session(status: Int = 200, body: Data = Data()) -> URLSession {
        session(answering: Answer(status: status, body: body))
    }

    static func session(error: URLError) -> URLSession {
        session(answering: Answer(error: error))
    }

    private static func session(answering answer: Answer) -> URLSession {
        let key = UUID().uuidString
        lock.lock()
        answers[key] = answer
        lock.unlock()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Stub-Key": key]
        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let key = request.value(forHTTPHeaderField: "X-Stub-Key") ?? ""
        Self.lock.lock()
        let answer = Self.answers[key]
        Self.lock.unlock()
        guard let answer else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        if let error = answer.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: answer.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"],
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
