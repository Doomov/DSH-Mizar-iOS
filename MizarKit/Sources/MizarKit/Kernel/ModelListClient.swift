//
//  ModelListClient.swift
//  MizarKit
//
//  "Test connection" for a model provider: one `GET /models`, and the list of
//  models it offers when it answers.
//
//  In the app rather than in the kernel on purpose. The kernel's
//  `kernel.apiKey.set` refuses a provider that is not already in its
//  configuration, so a test routed through the kernel would have to save the
//  provider -- address and key included -- before it could be tested, and undo
//  the save when the address turned out to be wrong. The screen asks the other
//  way round: type, test, then save. An HTTP GET does not need the kernel to
//  exist, and the kernel's own request would go through the same `URLSession`
//  anyway.
//

import Foundation

/// Lists the models a provider offers, the OpenAI-compatible way.
public struct ModelListClient: Sendable {
    /// Why a test failed, in the four shapes the screen has words for.
    public enum Failure: Error, Equatable, Sendable {
        /// 401 or 403: the key was refused.
        case unauthorized
        /// 404 or 405: there is no `/models` at that address.
        case missingEndpoint
        /// The request never reached a server: timeout, refused, no route.
        case unreachable
        /// Any other HTTP status.
        case server(Int)
        /// 200, but not the JSON this endpoint is supposed to return.
        case unreadable
    }

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Ask the provider at `baseURL` which models it has.
    ///
    /// - Parameters:
    ///   - baseURL: the address the operator typed, with or without a scheme.
    ///   - apiKey: the key, sent as `Authorization: Bearer …`.
    ///   - timeout: how long to wait for an answer.
    /// - Returns: the model ids, or one of four failures.
    public func models(
        baseURL: String,
        apiKey: String,
        timeout: TimeInterval = 10,
    ) async -> Result<[String], Failure> {
        guard let url = Self.modelsURL(baseURL) else { return .failure(.unreachable) }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            return .failure(.unreachable)
        }
        guard let http = response as? HTTPURLResponse else { return .failure(.unreadable) }
        switch http.statusCode {
        case 200..<300:
            guard let ids = Self.decodeModelIDs(data) else { return .failure(.unreadable) }
            return .success(ids)
        case 401, 403:
            return .failure(.unauthorized)
        case 404, 405:
            return .failure(.missingEndpoint)
        default:
            return .failure(.server(http.statusCode))
        }
    }

    /// `<base>/models`, once the address is worth dialling.
    ///
    /// The one normalisation the form and the test share, so an address that
    /// tests green is the address that gets saved.
    public static func modelsURL(_ baseURL: String) -> URL? {
        guard let normalized = LocalProviderDraft.normalizedBaseURL(baseURL) else { return nil }
        return URL(string: normalized + "/models")
    }

    /// Pull the ids out of either shape an OpenAI-compatible deployment returns.
    ///
    /// `{"data": [{"id": …}]}` is the standard one. `{"models": [{"name": …}]}`
    /// is what an Ollama-style endpoint answers, and it costs three lines to
    /// accept it rather than telling the operator their working server is
    /// broken.
    public static func decodeModelIDs(_ data: Data) -> [String]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let rows = root["data"] as? [[String: Any]] {
            let ids = rows.compactMap { $0["id"] as? String }
            // A `data` key that is present but carries no ids is an answer we do
            // not understand, not an empty provider.
            return rows.isEmpty ? [] : (ids.isEmpty ? nil : ids)
        }
        if let rows = root["models"] as? [[String: Any]] {
            let ids = rows.compactMap { ($0["id"] as? String) ?? ($0["name"] as? String) }
            return rows.isEmpty ? [] : (ids.isEmpty ? nil : ids)
        }
        return nil
    }
}
