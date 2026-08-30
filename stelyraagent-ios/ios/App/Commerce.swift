import Foundation
import OSLog
import Security
import StoreKit
import SwiftUI
import WebKit

struct CommerceAccount: Codable, Sendable {
    struct Credits: Codable, Sendable {
        let allowance: Int
        let bonus: Int
        let purchased: Int
        let reserved: Int
        let total: Int

        var availableTotal: Int { total }
    }
    struct LedgerEntry: Codable, Identifiable, Sendable {
        let id: Int64
        let requestID: String?
        let action: String
        let delta: Int
        let createdAt: String
        let scope: String?
        let reportStatus: String?
        let errorCode: String?
    }
    let userID: String
    let plan: String
    let planSource: String?
    let adminPlanOverride: String?
    let premiumExpiresAt: String?
    let creditsRenewAt: String?
    let credits: Credits
    let creditLedger: [LedgerEntry]?
	let transactionDisposition: String?
}

@MainActor
final class CommerceStore: ObservableObject {
    static let shared = CommerceStore()
    static let monthlyID = "premium_monthly"
    static let annualID = "premium_annual"
    static let creditsID = "credits_10"
    static let credits20ID = "credits_20"

    @Published private(set) var products: [Product] = []
    @Published private(set) var account: CommerceAccount?
    @Published private(set) var isApplePremium = false
    @Published private(set) var accountSyncFailed = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var productsUnavailable = false
    @Published private(set) var purchaseFailed = false
    @Published private(set) var purchasePendingSync = false
	@Published private(set) var restoreRequired = false
	@Published private(set) var isDeletingAccount = false
	@Published private(set) var accountDeletionFailed = false
	@Published private(set) var accountDeletionRequiresMediaPurchasesSignIn = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRefreshingAccount = false
    @Published var showsPaywall = false
    @Published var showsCredits = false

	@Published private(set) var userID: UUID
    private var updatesTask: Task<Void, Never>?
	private var premiumExpiryTask: Task<Void, Never>?
    private var accountRefreshInProgress = false
    private var accountSyncInProgress = false
    private var lastSuccessfulSyncAt: Date?

    var isPremium: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["STELYRAAGENT_UI_TEST_PREMIUM"] == "1" {
            return true
        }
        #endif
		return CommerceEntitlementPolicy.isPremium(
			account: account,
			isApplePremium: isApplePremium,
			now: Date()
		)
    }
    var totalCredits: Int { account?.credits.availableTotal ?? 0 }
    var planTitle: String {
        guard let account else { return "—" }
        return account.plan == "premium" ? "Pro" : "Free"
    }

    private init() {
        userID = CommerceIdentity.userID
        account = CommerceAccountCache.load(userID: userID)
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
				let transaction = result.unsafePayloadValue
				let isLocallyVerified: Bool
				switch result {
				case .verified: isLocallyVerified = true
				case .unverified: isLocallyVerified = false
				}
				guard let self,
				      (isLocallyVerified || CommerceTransactionOwnership.isConsumable(transaction.productID)),
				      CommerceTransactionOwnership.canReconcile(
						  productID: transaction.productID,
                          appAccountToken: transaction.appAccountToken,
						  currentUserID: self.userID
                      )
                else {
                    CommerceDiagnostics.logger.notice(
						"ignored_transaction_update reason=unreconcilable_transaction"
                    )
                    continue
                }
                await self.submit(transaction, signedTransaction: result.jwsRepresentation)
            }
        }
		schedulePremiumExpiryRefresh()
    }

    deinit {
		updatesTask?.cancel()
		premiumExpiryTask?.cancel()
	}

    func start() async {
        CommerceDiagnostics.logger.info(
            "relay resolved host=\(RelayEnvironment.baseURL.host ?? "invalid", privacy: .public) source=\(RelayEnvironment.resolutionSource, privacy: .public)"
        )
        await recoverIdentityFromUnfinishedTransactionsIfNeeded()
		if CommerceIdentity.hasPendingReplacement(for: userID) {
			_ = await deleteAccount()
		}
        async let products: Void = loadProducts()
        async let entitlements: Void = refreshEntitlements()
        async let account: Void = refreshAccount()
        _ = await (products, entitlements, account)
        await retryPendingAcknowledgements()
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let requestedIDs = [Self.monthlyID, Self.annualID, Self.creditsID, Self.credits20ID]
            var loaded: [Product] = []
            for attempt in 0 ..< 3 {
                loaded = try await Product.products(for: requestedIDs)
                CommerceDiagnostics.logger.info(
                    "StoreKit catalog attempt=\(attempt + 1) requested=\(requestedIDs.count) returned=\(loaded.count) ids=\(loaded.map(\.id).sorted().joined(separator: ","), privacy: .public)"
                )
                if loaded.count == requestedIDs.count { break }
                if attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 1_000_000_000)
                }
            }
            products = loaded
            let returnedIDs = Set(loaded.map(\.id))
            let missingIDs = requestedIDs.filter { !returnedIDs.contains($0) }
            productsUnavailable = !missingIDs.isEmpty
            purchaseFailed = false
            CommerceDiagnostics.logger.info(
                "StoreKit catalog completed missing=\(missingIDs.joined(separator: ","), privacy: .public)"
            )
        } catch {
            products = []
            productsUnavailable = true
            CommerceDiagnostics.log(error, operation: "load_products")
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  [Self.monthlyID, Self.annualID].contains(transaction.productID),
                  transaction.revocationDate == nil
            else { continue }
            active = true
        }
        isApplePremium = active
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseFailed = false
        purchasePendingSync = false
		restoreRequired = false
		do {
			if CommerceTransactionOwnership.isConsumable(product.id) {
				let delivered = await retryUnfinishedTransactions()
				if delivered { await syncAccount() }
			}
			if [Self.monthlyID, Self.annualID].contains(product.id),
			   await subscriptionRequiresRestore(product) {
				restoreRequired = true
				return
			}
            let result = try await product.purchase(options: [.appAccountToken(userID)])
            switch result {
            case let .success(verification):
				let transaction = verification.unsafePayloadValue
				let isLocallyVerified: Bool
				switch verification {
				case .verified: isLocallyVerified = true
				case .unverified: isLocallyVerified = false
				}
				guard isLocallyVerified || CommerceTransactionOwnership.isConsumable(transaction.productID) else {
                    purchaseFailed = true
                    return
                }
				guard CommerceTransactionOwnership.canReconcile(
					productID: transaction.productID,
                    appAccountToken: transaction.appAccountToken,
					currentUserID: userID
                ) else {
                    purchaseFailed = true
                    CommerceDiagnostics.logger.error(
                        "purchase failed reason=foreign_or_missing_app_account_token"
                    )
                    return
                }
                await submit(transaction, signedTransaction: verification.jwsRepresentation)
            case .pending, .userCancelled:
                return
            @unknown default:
                purchaseFailed = true
            }
        } catch {
            purchaseFailed = true
            CommerceDiagnostics.log(error, operation: "purchase")
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
		restoreRequired = false
		for await result in Transaction.currentEntitlements {
			guard case let .verified(transaction) = result,
			      [Self.monthlyID, Self.annualID].contains(transaction.productID)
			else { continue }
			if CommerceTransactionOwnership.matches(appAccountToken: transaction.appAccountToken, userID: userID) {
				await submit(transaction, signedTransaction: result.jwsRepresentation)
			} else if await restore(transaction, signedTransaction: result.jwsRepresentation) {
				return
			}
        }
        await syncAccount()
    }

	func deleteAccount() async -> Bool {
		guard !isDeletingAccount else { return false }
		isDeletingAccount = true
		accountDeletionFailed = false
		accountDeletionRequiresMediaPurchasesSignIn = false
		defer { isDeletingAccount = false }
		let oldUserID = userID
		let newUserID = CommerceIdentity.pendingReplacement(for: oldUserID)
		struct Body: Encodable {
			let userID: String
			let newUserID: String
			let signedAppTransaction: String
		}
		let signedAppTransaction: String
		do {
			signedAppTransaction = try await CommerceAppleIdentity.requiredSignedAppTransactionForDeletion()
		} catch {
			accountDeletionRequiresMediaPurchasesSignIn = true
			CommerceDiagnostics.log(error, operation: "delete_account_app_store_authentication")
			return false
		}
		do {
			let data = try JSONEncoder().encode(Body(
				userID: oldUserID.uuidString.lowercased(),
				newUserID: newUserID.uuidString.lowercased(),
				signedAppTransaction: signedAppTransaction
			))
			let response = try await CommerceRelay.post(path: "v1/account/delete", body: data)
			let replacement = try JSONDecoder().decode(CommerceAccount.self, from: response)
			CommerceAccountDeletionState.markPersonalEraseRequired()
			PendingReportAcknowledgements.removeAll(userID: oldUserID)
			CommerceAccountCache.remove(userID: oldUserID)
			account = nil
			lastSuccessfulSyncAt = nil
			applyAccount(replacement)
			return true
		} catch {
			accountDeletionFailed = true
			CommerceDiagnostics.log(error, operation: "delete_account")
			return false
		}
	}

    func refreshAccount() async {
        guard !accountRefreshInProgress else { return }
        accountRefreshInProgress = true
        isRefreshingAccount = true
        defer {
            accountRefreshInProgress = false
            isRefreshingAccount = false
        }
        await syncAccount()
        let deliveredTransaction = await retryUnfinishedTransactions()
        if deliveredTransaction {
            await syncAccount()
        }
    }

    func refreshAccountIfStale(maxAge: TimeInterval = 60) async {
        if account != nil,
           let lastSuccessfulSyncAt,
           Date().timeIntervalSince(lastSuccessfulSyncAt) < maxAge
        {
            return
        }
        await refreshAccount()
    }

	func refreshForForeground() async {
		async let entitlements: Void = refreshEntitlements()
		async let relayAccount: Void = refreshAccount()
		_ = await (entitlements, relayAccount)
	}

    @discardableResult
    func syncAccount() async -> Bool {
        guard !accountSyncInProgress else { return false }
        accountSyncInProgress = true
        defer { accountSyncInProgress = false }
        struct Body: Encodable { let userID: String; let countryCode: String?; let signedAppTransaction: String? }
        do {
            let countryCode = Locale.current.region?.identifier
            let signedAppTransaction = try? await CommerceAppleIdentity.signedAppTransaction()
            let data = try JSONEncoder().encode(
                Body(
                    userID: userID.uuidString.lowercased(),
                    countryCode: countryCode,
                    signedAppTransaction: signedAppTransaction
                )
            )
            let response: Data
            do {
                response = try await CommerceRelay.post(path: "v1/account/sync", body: data)
            } catch CommerceRelayError.httpStatus(let status, let message)
                where CommerceAccountSyncPolicy.shouldRetryWithoutAppleIdentity(
                    status: status,
                    message: message,
                    hadSignedAppTransaction: signedAppTransaction != nil
                )
            {
                CommerceDiagnostics.logger.notice(
                    "sync_account retrying_without_apple_identity reason=apple_identity_conflict"
                )
                #if DEBUG
                print("COMMERCE sync_account retrying_without_apple_identity reason=apple_identity_conflict")
                #endif
                let retryData = try JSONEncoder().encode(
                    Body(
                        userID: userID.uuidString.lowercased(),
                        countryCode: countryCode,
                        signedAppTransaction: nil
                    )
                )
                response = try await CommerceRelay.post(path: "v1/account/sync", body: retryData)
            }
            applyAccount(try JSONDecoder().decode(CommerceAccount.self, from: response))
            accountSyncFailed = false
            lastSuccessfulSyncAt = Date()
            return true
        } catch {
            accountSyncFailed = true
            CommerceDiagnostics.log(error, operation: "sync_account")
            return false
        }
    }

    func enqueueReportAcknowledgement(requestID: String) {
        let pending = PendingReportAcknowledgement(
            userID: userID.uuidString.lowercased(),
            requestID: requestID
        )
        PendingReportAcknowledgements.insert(pending)
    }

    func acknowledgeReport(requestID: String) async {
        let pending = PendingReportAcknowledgement(
            userID: userID.uuidString.lowercased(),
            requestID: requestID
        )
        PendingReportAcknowledgements.insert(pending)
        await sendAcknowledgement(pending)
        await syncAccount()
    }

    private func retryPendingAcknowledgements() async {
        for pending in PendingReportAcknowledgements.load() {
            await sendAcknowledgement(pending)
        }
        await syncAccount()
    }

    private func sendAcknowledgement(_ pending: PendingReportAcknowledgement) async {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        do {
            _ = try await CommerceRelay.post(path: "v1/reports/ack", body: data)
            PendingReportAcknowledgements.remove(pending)
        } catch CommerceRelayError.httpStatus(let status, _) where [404, 409, 410].contains(status) {
            // Relay has already released or finalized this reservation. It can
            // no longer be acknowledged and must not remain in the retry queue.
            PendingReportAcknowledgements.remove(pending)
        } catch {
            // The locally saved report remains deliverable. Retry the ACK on
            // the next launch so a transient network failure cannot skip billing.
        }
    }

    @discardableResult
    private func submit(
        _ transaction: StoreKit.Transaction,
        signedTransaction: String,
        refreshAccountAfterSuccess: Bool = true
    ) async -> Bool {
		guard CommerceTransactionOwnership.canReconcile(
			productID: transaction.productID,
            appAccountToken: transaction.appAccountToken,
			currentUserID: userID
        ) else {
            CommerceDiagnostics.logger.notice(
                "ignored_transaction_submission reason=foreign_or_missing_app_account_token"
            )
            return false
        }
        // The server endpoint verifies this signed JWS before changing paid state.
		struct Body: Encodable {
			let userID: String
			let signedTransaction: String
			let transactionID: String
			let productID: String
			let appAccountToken: String?
		}
        do {
			let data = try JSONEncoder().encode(Body(
				userID: userID.uuidString.lowercased(),
				signedTransaction: signedTransaction,
				transactionID: String(transaction.id),
				productID: transaction.productID,
				appAccountToken: transaction.appAccountToken?.uuidString.lowercased()
			))
            let response = try await CommerceRelay.post(path: "v1/store/transactions", body: data)
			let responseAccount = try JSONDecoder().decode(CommerceAccount.self, from: response)
			guard CommerceTransactionDisposition.shouldFinish(responseAccount.transactionDisposition) else {
				purchasePendingSync = true
				return false
			}
			applyAccount(responseAccount)
            await transaction.finish()
			purchaseFailed = isPurchasing && CommerceTransactionDisposition.shouldShowPurchaseFailure(
				responseAccount.transactionDisposition
			)
            purchasePendingSync = false
            await refreshEntitlements()
            if refreshAccountAfterSuccess {
                await syncAccount()
            }
            return true
        } catch {
        // Keep the transaction unfinished so StoreKit can redeliver it on the
        // next account refresh or app launch without charging the user again.
            purchasePendingSync = true
            CommerceDiagnostics.log(error, operation: "submit_transaction")
            return false
        }
    }

	private func applyAccount(_ value: CommerceAccount) {
		let previousUserID = userID
		let authoritativeUserID = CommerceIdentityReconciliation.authoritativeUserID(
			responseUserID: value.userID,
			currentUserID: previousUserID
		)
		if authoritativeUserID != previousUserID {
			CommerceAccountCache.remove(userID: previousUserID)
			PendingReportAcknowledgements.removeAll(userID: previousUserID)
			CommerceIdentity.save(authoritativeUserID)
			CommerceIdentity.clearPendingReplacement()
			userID = authoritativeUserID
		}
		account = value
		accountSyncFailed = false
		CommerceAccountCache.save(value, userID: userID)
		schedulePremiumExpiryRefresh()
	}

	private func subscriptionRequiresRestore(_ product: Product) async -> Bool {
		if await activeSubscriptionOwnedByAnotherAccount() {
			return true
		}
		guard let subscription = product.subscription else { return false }
		do {
			let states = try await subscription.status.map { status in
				CommerceSubscriptionState(status.state)
			}
			return CommerceSubscriptionPurchasePolicy.requiresRestore(for: states)
		} catch {
			CommerceDiagnostics.log(error, operation: "subscription_status")
			return false
		}
	}

	private func activeSubscriptionOwnedByAnotherAccount() async -> Bool {
		for await result in Transaction.currentEntitlements {
			guard case let .verified(transaction) = result,
			      [Self.monthlyID, Self.annualID].contains(transaction.productID),
			      transaction.revocationDate == nil
			else { continue }
			if !CommerceTransactionOwnership.matches(appAccountToken: transaction.appAccountToken, userID: userID) {
				return true
			}
		}
		return false
	}

	private func restore(_ transaction: StoreKit.Transaction, signedTransaction: String) async -> Bool {
		struct Body: Encodable { let userID: String; let signedTransaction: String }
		do {
			let data = try JSONEncoder().encode(Body(userID: userID.uuidString.lowercased(), signedTransaction: signedTransaction))
			let response = try await CommerceRelay.post(path: "v1/account/restore", body: data)
			applyAccount(try JSONDecoder().decode(CommerceAccount.self, from: response))
			await transaction.finish()
			await refreshEntitlements()
			purchaseFailed = false
			return true
		} catch {
			purchaseFailed = true
			CommerceDiagnostics.log(error, operation: "restore_subscription")
			return false
		}
	}

	private func schedulePremiumExpiryRefresh() {
		premiumExpiryTask?.cancel()
		guard let expiry = CommerceEntitlementPolicy.expiryDate(account?.premiumExpiresAt) else { return }
		let delay = expiry.timeIntervalSinceNow
		guard delay > 0 else { return }
		premiumExpiryTask = Task { [weak self] in
			let nanoseconds = UInt64(min(delay, 366 * 24 * 60 * 60) * 1_000_000_000)
			try? await Task.sleep(nanoseconds: nanoseconds)
			guard !Task.isCancelled, let self else { return }
			self.objectWillChange.send()
			await self.refreshAccount()
		}
	}

    private func retryUnfinishedTransactions() async -> Bool {
        var deliveredTransaction = false
        for await verification in Transaction.unfinished {
			let transaction = verification.unsafePayloadValue
			let isLocallyVerified: Bool
			switch verification {
			case .verified: isLocallyVerified = true
			case .unverified: isLocallyVerified = false
			}
			guard isLocallyVerified || CommerceTransactionOwnership.isConsumable(transaction.productID) else { continue }
			guard CommerceTransactionOwnership.canReconcile(
				productID: transaction.productID,
                appAccountToken: transaction.appAccountToken,
				currentUserID: userID
            ) else {
                CommerceDiagnostics.logger.notice(
					"ignored_unfinished_transaction reason=unreconcilable_transaction"
                )
                continue
            }
            let delivered = await submit(
                transaction,
                signedTransaction: verification.jwsRepresentation,
                refreshAccountAfterSuccess: false
            )
            if delivered {
                deliveredTransaction = true
            }
        }
        return deliveredTransaction
    }

    private func recoverIdentityFromUnfinishedTransactionsIfNeeded() async {
        guard CommerceIdentity.wasCreatedThisLaunch else { return }
        var transactionUserIDs: [UUID] = []
        for await verification in Transaction.unfinished {
            guard case let .verified(transaction) = verification,
                  let transactionUserID = transaction.appAccountToken
            else { continue }
            transactionUserIDs.append(transactionUserID)
        }
        guard let recoveredUserID = CommerceIdentityRecovery.recoveredUserID(
            currentUserID: userID,
            wasCreatedThisLaunch: true,
            transactionUserIDs: transactionUserIDs
        ) else { return }
        CommerceIdentity.save(recoveredUserID)
        userID = recoveredUserID
        account = CommerceAccountCache.load(userID: recoveredUserID)
		schedulePremiumExpiryRefresh()
    }
}

enum CommerceEntitlementPolicy {
	static func expiryDate(_ value: String?) -> Date? {
		guard let value else { return nil }
		let fractional = ISO8601DateFormatter()
		fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
	}

	static func isPremium(account: CommerceAccount?, isApplePremium: Bool, now: Date) -> Bool {
		guard let account else {
			return isApplePremium
		}
		if account.adminPlanOverride != nil {
			return account.plan == "premium"
		}
		guard account.plan == "premium",
			  let expiry = expiryDate(account.premiumExpiresAt)
		else {
			return false
		}
		return expiry > now
	}
}

enum CommerceTransactionOwnership {
	static func isConsumable(_ productID: String) -> Bool {
		productID == "credits_10" || productID == "credits_20"
	}

    static func matches(appAccountToken: UUID?, userID: UUID) -> Bool {
        appAccountToken == userID
    }

	static func canReconcile(productID: String, appAccountToken: UUID?, currentUserID: UUID) -> Bool {
		isConsumable(productID) || matches(appAccountToken: appAccountToken, userID: currentUserID)
	}
}

enum CommerceTransactionDisposition {
	static func shouldFinish(_ value: String?) -> Bool {
		value == "credited_current" || value == "settled_owner" || value == "rejected_permanent"
	}

	static func shouldShowPurchaseFailure(_ value: String?) -> Bool {
		value == "settled_owner" || value == "rejected_permanent"
	}
}

enum CommerceIdentityReconciliation {
	static func authoritativeUserID(responseUserID: String, currentUserID: UUID) -> UUID {
		UUID(uuidString: responseUserID) ?? currentUserID
	}
}

enum CommerceSubscriptionState: Hashable {
	case subscribed
	case inGracePeriod
	case inBillingRetryPeriod
	case expired
	case revoked

	init(_ state: Product.SubscriptionInfo.RenewalState) {
		switch state {
		case .subscribed:
			self = .subscribed
		case .inGracePeriod:
			self = .inGracePeriod
		case .inBillingRetryPeriod:
			self = .inBillingRetryPeriod
		case .expired:
			self = .expired
		case .revoked:
			self = .revoked
		default:
			self = .expired
		}
	}
}

enum CommerceSubscriptionPurchasePolicy {
	static func requiresRestore(for states: [CommerceSubscriptionState]) -> Bool {
		states.contains { state in
			switch state {
			case .subscribed, .inGracePeriod, .inBillingRetryPeriod:
				return true
			case .expired, .revoked:
				return false
			}
		}
	}
}

enum CommerceIdentity {
    private static let service = "com.xiaoguiwk.interstellar.commerce"
    private static let account = "anonymous-user-id"
    private static let initialState: (userID: UUID, wasCreated: Bool) = {
        if let data = KeychainValue.read(service: service, account: account),
           let raw = String(data: data, encoding: .utf8), let value = UUID(uuidString: raw) {
            return (value, false)
        }
        let value = UUID()
        KeychainValue.replace(Data(value.uuidString.lowercased().utf8), service: service, account: account)
        return (value, true)
    }()

    static var userID: UUID { initialState.userID }
    static var wasCreatedThisLaunch: Bool { initialState.wasCreated }
	static func save(_ value: UUID) { KeychainValue.replace(Data(value.uuidString.lowercased().utf8), service: service, account: account) }
	private struct PendingReplacement: Codable {
		let oldUserID: UUID
		let newUserID: UUID
	}
	private static let pendingReplacementKey = "commerce.pending-account-replacement.v1"
	static func pendingReplacement(for oldUserID: UUID) -> UUID {
		if let data = UserDefaults.standard.data(forKey: pendingReplacementKey),
		   let pending = try? JSONDecoder().decode(PendingReplacement.self, from: data),
		   pending.oldUserID == oldUserID {
			return pending.newUserID
		}
		let value = UUID()
		let pending = PendingReplacement(oldUserID: oldUserID, newUserID: value)
		UserDefaults.standard.set(try? JSONEncoder().encode(pending), forKey: pendingReplacementKey)
		return value
	}
	static func clearPendingReplacement() {
		UserDefaults.standard.removeObject(forKey: pendingReplacementKey)
	}
	static func hasPendingReplacement(for oldUserID: UUID) -> Bool {
		guard let data = UserDefaults.standard.data(forKey: pendingReplacementKey),
		      let pending = try? JSONDecoder().decode(PendingReplacement.self, from: data)
		else { return false }
		return pending.oldUserID == oldUserID
	}
#if DEBUG
    static func resetForTesting() { KeychainValue.remove(service: service, account: account) }
#endif
}

enum CommerceAccountDeletionState {
	private static let personalEraseKey = "commerce.account-deletion.personal-erase-required.v1"
	static var requiresPersonalErase: Bool { UserDefaults.standard.bool(forKey: personalEraseKey) }
	static func markPersonalEraseRequired() { UserDefaults.standard.set(true, forKey: personalEraseKey) }
	static func clearPersonalEraseRequirement() { UserDefaults.standard.removeObject(forKey: personalEraseKey) }
}

enum CommerceIdentityRecovery {
    static func recoveredUserID(
        currentUserID: UUID,
        wasCreatedThisLaunch: Bool,
        transactionUserIDs: [UUID]
    ) -> UUID? {
        guard wasCreatedThisLaunch, let candidate = transactionUserIDs.first else { return nil }
        guard transactionUserIDs.allSatisfy({ $0 == candidate }) else { return nil }
        return candidate == currentUserID ? nil : candidate
    }
}

private enum CommerceAccountCache {
    private static let keyPrefix = "commerce.account-cache.v1."

    static func load(userID: UUID) -> CommerceAccount? {
        guard let data = UserDefaults.standard.data(forKey: keyPrefix + userID.uuidString.lowercased()) else {
            return nil
        }
        return try? JSONDecoder().decode(CommerceAccount.self, from: data)
    }

    static func save(_ account: CommerceAccount, userID: UUID) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        UserDefaults.standard.set(data, forKey: keyPrefix + userID.uuidString.lowercased())
    }

	static func remove(userID: UUID) {
		UserDefaults.standard.removeObject(forKey: keyPrefix + userID.uuidString.lowercased())
	}
}

private struct PendingReportAcknowledgement: Codable, Hashable {
    let userID: String
    let requestID: String
}

private enum PendingReportAcknowledgements {
    private static let key = "commerce.pending-report-acknowledgements.v1"

    static func load() -> Set<PendingReportAcknowledgement> {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode(Set<PendingReportAcknowledgement>.self, from: data)
        else { return [] }
        return values
    }

    static func insert(_ value: PendingReportAcknowledgement) {
        var values = load()
        values.insert(value)
        save(values)
    }

    static func remove(_ value: PendingReportAcknowledgement) {
        var values = load()
        values.remove(value)
        save(values)
    }

	static func removeAll(userID: UUID) {
		let raw = userID.uuidString.lowercased()
		save(load().filter { $0.userID != raw })
	}

    private static func save(_ values: Set<PendingReportAcknowledgement>) {
        if values.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

enum CommerceAppleIdentity {
	static func signedAppTransaction() async throws -> String {
		let result = try await AppTransaction.shared
		guard case .verified = result else {
			throw CommerceRelayError.httpStatus(422, "App Transaction verification failed")
		}
		return result.jwsRepresentation
	}

	static func requiredSignedAppTransactionForDeletion() async throws -> String {
		try await requiredSignedAppTransactionForDeletion(
			cached: { try await signedAppTransaction() },
			refresh: {
				let result = try await AppTransaction.refresh()
				guard case .verified = result else {
					throw CommerceRelayError.httpStatus(422, "App Transaction verification failed")
				}
				return result.jwsRepresentation
			}
		)
	}

	static func requiredSignedAppTransactionForDeletion(
		cached: () async throws -> String,
		refresh: () async throws -> String
	) async throws -> String {
		do {
			return try await cached()
		} catch {
			return try await refresh()
		}
	}
}

enum CommerceRelay {
    static func post(path: String, body: Data) async throws -> Data {
        let baseURL = RelayEnvironment.baseURL
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.timeoutInterval = 20
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(InstallationIdentity.value, forHTTPHeaderField: "X-Installation-ID")
        let response = try await AppAttestAuthorizer.shared.send(
            request,
            body: body,
            baseURL: baseURL,
            language: .english
        )
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: response.data) as? [String: Any])?["error"] as? String
            throw CommerceRelayError.httpStatus(response.statusCode, message)
        }
        return response.data
    }
}

enum RelayEnvironment {
    static var baseURL: URL {
        resolve(
            environment: ProcessInfo.processInfo.environment,
            infoValue: Bundle.main.object(forInfoDictionaryKey: "STELYRAAGENT_RELAY_BASE_URL") as? String
        ).url
    }

    static var resolutionSource: String {
        resolve(
            environment: ProcessInfo.processInfo.environment,
            infoValue: Bundle.main.object(forInfoDictionaryKey: "STELYRAAGENT_RELAY_BASE_URL") as? String
        ).source
    }

    static func resolve(environment: [String: String], infoValue: String?) -> (url: URL, source: String) {
        if let value = validURL(environment["STELYRAAGENT_RELAY_BASE_URL"]) {
            return (value, "environment")
        }
        if let value = validURL(infoValue) {
            return (value, "info-plist")
        }
#if targetEnvironment(simulator)
        return (URL(string: "http://127.0.0.1:8080")!, "simulator-default")
#else
        return (URL(string: "https://aaadmin.xiaoguiwk.top")!, "fallback-production")
#endif
    }

    private static func validURL(_ rawValue: String?) -> URL? {
        guard let rawValue,
              let value = URL(string: rawValue),
              value.scheme != nil,
              value.host != nil
        else { return nil }
        return value
    }
}

private enum CommerceDiagnostics {
    static let logger = Logger(subsystem: "com.xiaoguiwk.interstellar", category: "Commerce")

    static func log(_ error: Error, operation: String) {
        let value = error as NSError
        logger.error(
            "\(operation, privacy: .public) failed domain=\(value.domain, privacy: .public) code=\(value.code) relay=\(RelayEnvironment.baseURL.host ?? "invalid", privacy: .public)"
        )
    }
}

enum CommerceRelayError: LocalizedError {
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case let .httpStatus(status, message):
            return message ?? "HTTP \(status)"
        }
    }
}

enum CommerceAccountSyncPolicy {
    private static let appleIdentityConflict = "Apple identity is already linked to another active account"

    static func shouldRetryWithoutAppleIdentity(
        status: Int,
        message: String?,
        hadSignedAppTransaction: Bool
    ) -> Bool {
        hadSignedAppTransaction && status == 409 && message == appleIdentityConflict
    }
}

struct PremiumPaywallView: View {
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    @State private var selectedProductID = CommerceStore.annualID
    @State private var legalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Capsule().fill(AppTheme.muted.opacity(0.45)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                    Text("STELYRAAGENT PRO")
                        .font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(AppTheme.violet)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(AppTheme.violet.opacity(0.12), in: Capsule())
                    Text(localized("premium.see-full-picture", language: language)).font(.largeTitle.bold()).foregroundStyle(AppTheme.text)
                    Text(localized("premium.pro-description", language: language)).font(.subheadline).foregroundStyle(AppTheme.muted)

                    VStack(spacing: 10) {
                        productChoice(
                            id: CommerceStore.monthlyID,
                            titleKey: "premium.monthly",
                            fallbackPrice: "$4.99",
                            periodKey: "premium.per-month"
                        )
                        productChoice(
                            id: CommerceStore.annualID,
                            titleKey: "premium.annual",
                            fallbackPrice: "$39.99",
                            periodKey: "premium.per-year",
                            detailKey: "premium.annual-bonus"
                        )
                    }

                    productAvailability

                    VStack(spacing: 0) {
                        benefit("premium.all-insights", value: localized("premium.included", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.unlimited-people", value: localized("premium.unlimited", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.ten-credits", value: localized("premium.per-period", language: language))
                        Divider().overlay(AppTheme.line)
                        benefit("premium.annual-welcome", value: localized("premium.annual-only", language: language), sparkle: true)
                    }

                    Button {
                        Task {
                            if let product = commerce.products.first(where: { $0.id == selectedProductID }) {
                                await commerce.purchase(product)
                            } else {
                                await commerce.loadProducts()
                            }
                        }
                    } label: {
                        Text(purchaseButtonTitle)
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .drawerTapTarget(minHeight: 52)
                    }
                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16))
                    .buttonStyle(.plain)
                    .disabled(commerce.isPurchasing)

                    Button {
                        commerce.showsPaywall = false
                    } label: {
                        Text(localized("location.cancel", language: language))
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                            .drawerTapTarget(minHeight: 52)
                    }
                    .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line))
                    .buttonStyle(.plain)

                    Button(localized("premium.restore", language: language)) { Task { await commerce.restore() } }
                        .font(.footnote.weight(.semibold)).frame(maxWidth: .infinity)
                    Text(localized("premium.renewal-note", language: language)).font(.caption2).foregroundStyle(AppTheme.muted)
                    HStack {
                        Button(localized("legal.terms", language: language)) { legalDocument = .terms }
                        Spacer()
                        Button(localized("legal.privacy", language: language)) { legalDocument = .privacy }
                    }.font(.caption.weight(.semibold))
                }
                .padding(20)
            }.background(ScreenBackground())
            .sheet(item: $legalDocument) { LegalDocumentView(document: $0, language: language) }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task {
            if commerce.products.isEmpty { await commerce.loadProducts() }
        }
    }

    private var purchaseButtonTitle: String {
        if commerce.isPurchasing {
            return localized("commerce.processing-purchase", language: language)
        }
        if commerce.isLoadingProducts {
            return localized("commerce.loading-products", language: language)
        }
        if commerce.products.first(where: { $0.id == selectedProductID }) == nil {
            return localized("commerce.retry-products", language: language)
        }
        return selectedProductID == CommerceStore.annualID
            ? localized("premium.choose-annual", language: language)
            : localized("premium.choose-monthly", language: language)
    }

    @ViewBuilder
    private var productAvailability: some View {
        if commerce.isLoadingProducts {
            HStack(spacing: 8) {
                ProgressView()
                Text(localized("commerce.loading-products", language: language))
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
        } else if commerce.purchasePendingSync {
            Text(localized("commerce.purchase-pending-sync", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.violet)
		} else if commerce.restoreRequired {
			Text(localized("commerce.restore-required", language: language))
				.font(.footnote)
				.foregroundStyle(AppTheme.violet)
        } else if commerce.productsUnavailable {
            Text(localized("commerce.products-unavailable", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        } else if commerce.purchaseFailed {
            Text(localized("commerce.purchase-failed", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        }
    }

    private func productChoice(
        id: String,
        titleKey: String,
        fallbackPrice: String,
        periodKey: String,
        detailKey: String? = nil
    ) -> some View {
        let product = commerce.products.first { $0.id == id }
        return Button { selectedProductID = id } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selectedProductID == id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(AppTheme.violet)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized(titleKey, language: language))
                        .font(.headline).foregroundStyle(AppTheme.text)
                    if let detailKey {
                        Text(localized(detailKey, language: language)).font(.caption).foregroundStyle(AppTheme.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product?.displayPrice ?? fallbackPrice).font(.title3.bold()).foregroundStyle(AppTheme.text)
                    Text(localized(periodKey, language: language)).font(.caption2).foregroundStyle(AppTheme.muted)
                }
            }.padding(16)
            .background(selectedProductID == id ? AppTheme.violet.opacity(0.13) : AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedProductID == id ? AppTheme.violet : AppTheme.line))
        }.buttonStyle(.plain)
    }

    private func benefit(_ key: String, value: String, sparkle: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: sparkle ? "sparkles" : "checkmark").foregroundStyle(AppTheme.violet).frame(width: 20)
            Text(localized(key, language: language)).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.text)
            Spacer()
            Text(value).font(.caption).foregroundStyle(AppTheme.muted)
        }.padding(.vertical, 13)
    }
}

struct CreditsPurchaseView: View {
    @ObservedObject var commerce = CommerceStore.shared
    let language: AppLanguage
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Capsule().fill(AppTheme.muted.opacity(0.45)).frame(width: 42, height: 5).frame(maxWidth: .infinity)
                Text(localized("credits.need-more", language: language)).font(.largeTitle.bold()).foregroundStyle(AppTheme.text)
                Text(localized("credits.purchase-description", language: language)).font(.subheadline).foregroundStyle(AppTheme.muted)
                creditPurchaseButton(id: CommerceStore.creditsID, amount: 10, fallbackPrice: "$1.99")
                creditPurchaseButton(id: CommerceStore.credits20ID, amount: 20, fallbackPrice: "$2.99")
                productAvailability
                Text(localized("credits.never-expire", language: language)).font(.footnote).foregroundStyle(AppTheme.muted)
                Button {
                    commerce.showsCredits = false
                } label: {
                    Text(localized("location.cancel", language: language))
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                        .drawerTapTarget(minHeight: 52)
                }
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.line))
                .buttonStyle(.plain)
            }.padding(20).background(ScreenBackground())
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task {
            if commerce.products.isEmpty { await commerce.loadProducts() }
        }
    }

    private func creditPurchaseButton(id: String, amount: Int, fallbackPrice: String) -> some View {
        let product = commerce.products.first { $0.id == id }
        return Button {
            Task {
                if let product {
                    await commerce.purchase(product)
                } else {
                    await commerce.loadProducts()
                }
            }
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(amount) Credits").font(.title3.bold()).foregroundStyle(AppTheme.text)
                    Text(localized("credits.permanent-pack", language: language)).font(.caption).foregroundStyle(AppTheme.muted)
                }
                Spacer()
                Text(product?.displayPrice ?? fallbackPrice).font(.title3.bold()).foregroundStyle(Color.white)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(AppTheme.violet, in: Capsule())
            }
            .padding(17)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppTheme.line))
            .drawerTapTarget(minHeight: 54)
        }
        .buttonStyle(.plain)
        .disabled(commerce.isPurchasing)
    }

    @ViewBuilder
    private var productAvailability: some View {
        if commerce.isPurchasing {
            HStack(spacing: 8) {
                ProgressView()
                Text(localized("commerce.processing-purchase", language: language))
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
        } else if commerce.isLoadingProducts {
            HStack(spacing: 8) {
                ProgressView()
                Text(localized("commerce.loading-products", language: language))
            }
            .font(.footnote)
            .foregroundStyle(AppTheme.muted)
        } else if commerce.purchasePendingSync {
            Text(localized("commerce.purchase-pending-sync", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.violet)
		} else if commerce.restoreRequired {
			Text(localized("commerce.restore-required", language: language))
				.font(.footnote)
				.foregroundStyle(AppTheme.violet)
        } else if commerce.productsUnavailable {
            Text(localized("commerce.products-unavailable", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        } else if commerce.purchaseFailed {
            Text(localized("commerce.purchase-failed", language: language))
                .font(.footnote)
                .foregroundStyle(AppTheme.coral)
        }
    }
}

enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var url: URL {
        URL(string: "https://aaadmin.xiaoguiwk.top/\(rawValue)")!
    }
}

struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let document: LegalDocument
    let language: AppLanguage
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if loadFailed {
                    ScrollView {
                        Text(localized(document == .terms ? "legal.terms-body" : "legal.privacy-body", language: language))
                            .font(.body)
                            .foregroundStyle(AppTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
                } else {
                    LegalWebView(url: document.url, loadFailed: $loadFailed)
                }
            }
                .background(ScreenBackground())
                .navigationTitle(localized(document == .terms ? "legal.terms" : "legal.privacy", language: language))
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .bottom) {
                    Text(document.url.absoluteString)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(localized("common.done", language: language)) { dismiss() }
                    }
                }
        }
    }
}

private struct LegalWebView: UIViewRepresentable {
    let url: URL
    @Binding var loadFailed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(loadFailed: $loadFailed)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var loadFailed: Bool

        init(loadFailed: Binding<Bool>) {
            _loadFailed = loadFailed
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            loadFailed = true
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            loadFailed = true
        }
    }
}
