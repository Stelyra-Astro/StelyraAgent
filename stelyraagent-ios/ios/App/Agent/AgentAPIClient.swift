import Foundation

struct AgentRunActionEnvelope: Codable, Equatable, Sendable {
    let id: String
    let type: String
    let tool: String?
    let payload: [String: AgentJSONValue]
}

struct AgentRunResponse: Codable, Equatable, Sendable {
    let runID: String
    let status: AgentRunStatus
    let action: AgentRunActionEnvelope?
    let finalAnswer: AgentJSONValue?
    let failureReason: String?

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case status
        case action
        case finalAnswer = "final_answer"
        case failureReason = "failure_reason"
    }
}

struct AgentAuthSession: Codable, Equatable, Sendable {
    let accountID: String
    let generation: Int
    let walletID: String
    let appAccountToken: String
    var credits: Int
    var accessToken: String
    var refreshToken: String
    var accessExpiresAt: Int64
    var refreshExpiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case generation
        case walletID = "wallet_id"
        case appAccountToken = "app_account_token"
        case credits
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case accessExpiresAt = "access_expires_at"
        case refreshExpiresAt = "refresh_expires_at"
    }
}

private struct AgentRefreshResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let accessExpiresAt: Int64
    let refreshExpiresAt: Int64

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case accessExpiresAt = "access_expires_at"
        case refreshExpiresAt = "refresh_expires_at"
    }
}

struct AgentCreditsResponse: Decodable, Equatable, Sendable {
    let walletID: String
    let balance: Int
    let reserved: Int
    let spent: Int

    enum CodingKeys: String, CodingKey {
        case walletID = "wallet_id"
        case balance, reserved, spent
    }
}

struct AgentIAPReconcileResponse: Decodable, Equatable, Sendable {
    let status: String
    let credits: Int
}

struct AgentPurchaseRecord: Decodable, Equatable, Identifiable, Sendable {
    let transactionId: String
    let productId: String
    let credits: Int
    let status: String
    let createdAt: String

    var id: String { transactionId }
}

private struct AgentPurchaseHistoryResponse: Decodable, Sendable {
    let purchases: [AgentPurchaseRecord]
}

struct AgentSubscriptionResponse: Decodable, Equatable, Sendable {
    let status: String
    let manageInAppStore: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case manageInAppStore = "manage_in_app_store"
    }
}

struct AgentDeleteAccountResponse: Decodable, Equatable, Sendable {
    let deleted: Bool
    let appleTokenRevocation: String
    enum CodingKeys: String, CodingKey {
        case deleted
        case appleTokenRevocation = "apple_token_revocation"
    }
}

struct AgentModelOption: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let label: String
    let creditsRequired: Int
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case id, label
        case creditsRequired = "creditsRequired"
        case maxOutputTokens = "maxOutputTokens"
    }
}

private struct AgentModelsResponse: Decodable, Sendable {
    let models: [AgentModelOption]
}

private struct AgentCreateRunRequest: Encodable {
    let question: String
    let clientManifest: AgentCapabilityManifest
    let draftContext: [[String: String]]
    let modelID: String?
    let localMemory: AgentLocalMemorySnapshot?

    enum CodingKeys: String, CodingKey {
        case question
        case clientManifest = "client_manifest"
        case draftContext = "draft_context"
        case modelID = "model_id"
        case localMemory = "local_memory"
    }
}

private struct AgentSubmitActionRequest: Encodable {
    let actionID: String
    let result: [String: AgentJSONValue]

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case result
    }
}

private struct AgentAppleAuthRequest: Encodable {
    let identityToken: String
    let authorizationCode: String
    let nonce: String
    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case authorizationCode = "authorization_code"
        case nonce
    }
}

private struct AgentRefreshRequest: Encodable {
    let refreshToken: String
    enum CodingKeys: String, CodingKey { case refreshToken = "refresh_token" }
}

private struct AgentIAPReconcileRequest: Encodable {
    let signedTransaction: String
    enum CodingKeys: String, CodingKey { case signedTransaction = "signed_transaction" }
}

struct AgentRuntimeCapabilities: Decodable, Sendable {
    let supportedCapabilities: [String]
    enum CodingKeys: String, CodingKey { case supportedCapabilities = "supported_capabilities" }
}

actor AgentAPIClient {
    enum ClientError: Error, LocalizedError {
        case missingBaseURL
        case invalidResponse
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .missingBaseURL: "StelyraAgent Runtime URL is not configured."
            case .invalidResponse: "StelyraAgent Runtime returned an invalid response."
            case let .http(status, message): "StelyraAgent Runtime error \(status): \(message)"
            }
        }
    }

    private let baseURL: URL?
    private let session: URLSession
    private var accessToken: String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL? = AgentAPIClient.configuredBaseURL(), session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setAccessToken(_ token: String?) { accessToken = token }

    func signInWithApple(identityToken: String, authorizationCode: String, nonce: String) async throws -> AgentAuthSession {
        let response: AgentAuthSession = try await request(
            path: "/v1/auth/apple",
            method: "POST",
            body: AgentAppleAuthRequest(identityToken: identityToken, authorizationCode: authorizationCode, nonce: nonce),
            authenticated: false
        )
        accessToken = response.accessToken
        return response
    }

    func refreshSession(refreshToken: String) async throws -> (accessToken: String, refreshToken: String, accessExpiresAt: Int64, refreshExpiresAt: Int64) {
        let response: AgentRefreshResponse = try await request(
            path: "/v1/auth/refresh",
            method: "POST",
            body: AgentRefreshRequest(refreshToken: refreshToken),
            authenticated: false
        )
        accessToken = response.accessToken
        return (response.accessToken, response.refreshToken, response.accessExpiresAt, response.refreshExpiresAt)
    }

    func logout() async throws {
        let _: EmptyResponse = try await request(path: "/v1/auth/logout", method: "POST", body: Optional<Int>.none)
        accessToken = nil
    }

    func resetAccount() async throws -> AgentAuthSession {
        let response: AgentAuthSession = try await request(path: "/v1/account/reset", method: "POST", body: Optional<Int>.none)
        accessToken = response.accessToken
        return response
    }

    func deleteAccount() async throws -> AgentDeleteAccountResponse {
        let response: AgentDeleteAccountResponse = try await request(path: "/v1/account", method: "DELETE", body: Optional<Int>.none)
        accessToken = nil
        return response
    }

    func credits() async throws -> AgentCreditsResponse {
        try await request(path: "/v1/credits", method: "GET", body: Optional<Int>.none)
    }

    func reconcileIAP(signedTransaction: String) async throws -> AgentIAPReconcileResponse {
        try await request(
            path: "/v1/iap/reconcile",
            method: "POST",
            body: AgentIAPReconcileRequest(signedTransaction: signedTransaction)
        )
    }

    func purchases() async throws -> [AgentPurchaseRecord] {
        let response: AgentPurchaseHistoryResponse = try await request(
            path: "/v1/purchases",
            method: "GET",
            body: Optional<Int>.none
        )
        return response.purchases
    }

    func subscription() async throws -> AgentSubscriptionResponse {
        try await request(path: "/v1/subscription", method: "GET", body: Optional<Int>.none)
    }

    func createRun(
        question: String,
        manifest: AgentCapabilityManifest,
        draftContext: [AgentDraftContextChip],
        modelID: String? = nil,
        localMemory: AgentLocalMemorySnapshot? = nil
    ) async throws -> AgentRunResponse {
        try await request(
            path: "/v1/runs",
            method: "POST",
            body: AgentCreateRunRequest(
                question: question,
                clientManifest: manifest,
                draftContext: draftContext.map { ["kind": $0.kind.rawValue, "value": $0.value, "title": $0.title] },
                modelID: modelID,
                localMemory: localMemory
            )
        )
    }

    func models() async throws -> [AgentModelOption] {
        let response: AgentModelsResponse = try await request(
            path: "/v1/models",
            method: "GET",
            body: Optional<Int>.none
        )
        return response.models
    }

    func getRun(_ runID: String) async throws -> AgentRunResponse {
        try await request(path: "/v1/runs/\(runID)", method: "GET", body: Optional<Int>.none)
    }

    func submitAction(runID: String, actionID: String, result: [String: AgentJSONValue]) async throws -> AgentRunResponse {
        try await request(
            path: "/v1/runs/\(runID)/actions",
            method: "POST",
            body: AgentSubmitActionRequest(actionID: actionID, result: result)
        )
    }

    func acknowledge(runID: String) async throws -> AgentRunResponse {
        try await request(path: "/v1/runs/\(runID)/ack", method: "POST", body: Optional<Int>.none)
    }

    func cancel(runID: String) async throws -> AgentRunResponse {
        try await request(path: "/v1/runs/\(runID)/cancel", method: "POST", body: Optional<Int>.none)
    }

    func capabilities() async throws -> AgentRuntimeCapabilities {
        try await request(path: "/v1/capabilities", method: "GET", body: Optional<Int>.none)
    }

    func runtimeConfig() async throws -> [String: AgentJSONValue] {
        try await request(path: "/v1/runtime-config", method: "GET", body: Optional<Int>.none)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        authenticated: Bool = true
    ) async throws -> Response {
        guard let baseURL else { throw ClientError.missingBaseURL }
        var request = URLRequest(url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated, let accessToken { request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ClientError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }

    static func configuredBaseURL(bundle: Bundle = .main) -> URL? {
        guard let raw = bundle.object(forInfoDictionaryKey: "STELYRAAGENT_RUNTIME_BASE_URL") as? String,
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }
}

private struct EmptyResponse: Codable, Sendable { }
