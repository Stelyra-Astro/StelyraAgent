import AuthenticationServices
import Foundation
import Security

@MainActor
final class AgentAccountCoordinator: ObservableObject {
    @Published private(set) var session: AgentAuthSession?
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var purchaseHistory: [AgentPurchaseRecord] = []
    @Published private(set) var subscriptionStatus: AgentSubscriptionResponse?

    private let client: AgentAPIClient
    private let credentialStore: AgentCredentialStore
    private var pendingNonceHash: String?

    init(client: AgentAPIClient, credentialStore: AgentCredentialStore) {
        self.client = client
        self.credentialStore = credentialStore
        self.session = credentialStore.load()
        if let token = session?.accessToken {
            Task { await client.setAccessToken(token) }
        }
    }

    var isSignedIn: Bool { session != nil }
    var credits: Int? { session?.credits }
    var appAccountToken: UUID? {
        guard let raw = session?.appAccountToken else { return nil }
        return UUID(uuidString: raw)
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let rawNonce = randomNonceString()
        let hash = SHA256Digest.hash(Data(rawNonce.utf8)).hex
        pendingNonceHash = hash
        request.requestedScopes = [.email]
        request.nonce = hash
    }

    func completeAppleAuthorization(_ result: Result<ASAuthorization, Error>) async {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let authorizationCodeData = credential.authorizationCode,
                  let identityToken = String(data: identityTokenData, encoding: .utf8),
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                  let nonce = pendingNonceHash else {
                throw AgentAPIClient.ClientError.invalidResponse
            }
            pendingNonceHash = nil
            let authenticated = try await client.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            )
            try persist(authenticated)
            await refreshAccountData()
        } catch {
            pendingNonceHash = nil
            errorMessage = error.localizedDescription
        }
    }

    func ensureFreshSession() async throws {
        guard var current = session else { throw AgentAccountError.signInRequired }
        let now = Int64(Date().timeIntervalSince1970)
        if current.accessExpiresAt > now + 60 {
            await client.setAccessToken(current.accessToken)
            return
        }
        guard current.refreshExpiresAt > now else {
            credentialStore.clear()
            session = nil
            await client.setAccessToken(nil)
            throw AgentAccountError.sessionExpired
        }
        let refreshed = try await client.refreshSession(refreshToken: current.refreshToken)
        current.accessToken = refreshed.accessToken
        current.refreshToken = refreshed.refreshToken
        current.accessExpiresAt = refreshed.accessExpiresAt
        current.refreshExpiresAt = refreshed.refreshExpiresAt
        try persist(current)
    }

    func refreshCredits() async {
        guard session != nil else { return }
        do {
            try await ensureFreshSession()
            let response = try await client.credits()
            guard var current = session else { return }
            current.credits = response.balance
            try persist(current)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshAccountData() async {
        guard session != nil else {
            purchaseHistory = []
            subscriptionStatus = nil
            return
        }
        do {
            try await ensureFreshSession()
            async let creditsResponse = client.credits()
            async let purchaseResponse = client.purchases()
            async let subscriptionResponse = client.subscription()
            let (creditsValue, purchasesValue, subscriptionValue) = try await (creditsResponse, purchaseResponse, subscriptionResponse)
            if var current = session {
                current.credits = creditsValue.balance
                try persist(current)
            }
            purchaseHistory = purchasesValue
            subscriptionStatus = subscriptionValue
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reconcileStoreTransaction(signedJWS: String) async throws -> Bool {
        try await ensureFreshSession()
        let response = try await client.reconcileIAP(signedTransaction: signedJWS)
        guard response.status == "credited" || response.status == "already_processed" else { return false }
        if var current = session {
            current.credits = response.credits
            try persist(current)
        }
        return true
    }

    func signOut() async {
        guard session != nil else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await ensureFreshSession()
            try await client.logout()
        } catch {
            // Local sign-out still proceeds; server access token is short-lived and the refresh token is removed locally.
            errorMessage = error.localizedDescription
        }
        credentialStore.clear()
        session = nil
        purchaseHistory = []
        subscriptionStatus = nil
        await client.setAccessToken(nil)
    }

    func resetAccount() async throws {
        isBusy = true
        defer { isBusy = false }
        try await ensureFreshSession()
        let reset = try await client.resetAccount()
        try persist(reset)
        purchaseHistory = []
        subscriptionStatus = nil
        await refreshAccountData()
    }

    @discardableResult
    func deleteAccount() async throws -> AgentDeleteAccountResponse {
        isBusy = true
        defer { isBusy = false }
        try await ensureFreshSession()
        let response = try await client.deleteAccount()
        credentialStore.clear()
        session = nil
        purchaseHistory = []
        subscriptionStatus = nil
        await client.setAccessToken(nil)
        return response
    }

    private func persist(_ value: AgentAuthSession) throws {
        try credentialStore.save(value)
        session = value
        Task { await client.setAccessToken(value.accessToken) }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }
}

enum AgentAccountError: Error, LocalizedError {
    case signInRequired
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .signInRequired: "Sign in with Apple is required before paid AI analysis."
        case .sessionExpired: "Your StelyraAgent session expired. Please sign in with Apple again."
        }
    }
}
