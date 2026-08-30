import Foundation
import StoreKit

struct AgentStoreKitDestructiveActionPreflight: Equatable, Sendable {
    let unresolvedVerifiedTransactionIDs: [UInt64]

    var canProceed: Bool { unresolvedVerifiedTransactionIDs.isEmpty }
}

@MainActor
final class AgentStoreKitCoordinator: ObservableObject {
    typealias ReconcileHandler = @MainActor @Sendable (Transaction, String) async throws -> Bool

    @Published private(set) var pendingProductIDs: Set<String>
    @Published private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let reconcileHandler: ReconcileHandler
    private let defaults: UserDefaults
    private let pendingKey = "stelyraagent.storekit.pending-products.v1"

    init(defaults: UserDefaults = .standard, reconcile: @escaping ReconcileHandler) {
        self.defaults = defaults
        self.reconcileHandler = reconcile
        self.pendingProductIDs = Set(defaults.stringArray(forKey: pendingKey) ?? [])
    }

    deinit { updatesTask?.cancel() }

    var hasPendingPurchase: Bool { !pendingProductIDs.isEmpty }

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }
                await handle(verification)
            }
        }
        Task { [weak self] in
            guard let self else { return }
            await reconcileUnfinished()
        }
    }

    func purchase(productID: String, appAccountToken: UUID) async throws {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw StoreError.productUnavailable(productID)
        }

        let result = try await product.purchase(options: [.appAccountToken(appAccountToken)])
        switch result {
        case let .success(verification):
            await handle(verification)
        case .pending:
            markPending(productID)
        case .userCancelled:
            break
        @unknown default:
            break
        }
    }

    func reconcileUnfinished() async {
        for await verification in Transaction.unfinished {
            await handle(verification)
        }
    }

    func prepareForAccountDestructiveAction() async -> AgentStoreKitDestructiveActionPreflight {
        var unresolved: [UInt64] = []
        for await verification in Transaction.unfinished {
            switch verification {
            case let .verified(transaction):
                let delivered = await reconcileAndFinishIfDelivered(
                    transaction,
                    jwsRepresentation: verification.jwsRepresentation
                )
                if !delivered { unresolved.append(transaction.id) }
            case let .unverified(transaction, error):
                lastError = "Unverified StoreKit transaction \(transaction.id): \(error.localizedDescription)"
                unresolved.append(transaction.id)
            }
        }
        if !unresolved.isEmpty {
            lastError = "A verified App Store purchase has not been delivered to the current wallet yet. Reconnect and reconcile purchases before resetting or deleting this account."
        }
        return AgentStoreKitDestructiveActionPreflight(
            unresolvedVerifiedTransactionIDs: unresolved
        )
    }

    private func handle(_ verification: VerificationResult<Transaction>) async {
        switch verification {
        case let .verified(transaction):
            await reconcileAndFinishIfDelivered(transaction, jwsRepresentation: verification.jwsRepresentation)
        case let .unverified(transaction, error):
            lastError = "Unverified StoreKit transaction \(transaction.id): \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func reconcileAndFinishIfDelivered(_ transaction: Transaction, jwsRepresentation: String) async -> Bool {
        do {
            // Apple recommends sending VerificationResult.jwsRepresentation to the server.
            // Server acknowledgement is the delivery boundary: never finish before this returns true.
            if try await reconcileHandler(transaction, jwsRepresentation) {
                clearPending(transaction.productID)
                await transaction.finish()
                return true
            }
            return false
        } catch {
            lastError = error.localizedDescription
            // Leave the verified transaction unfinished; app launch/updates will retry.
            return false
        }
    }

    private func markPending(_ productID: String) {
        pendingProductIDs.insert(productID)
        persistPending()
    }

    private func clearPending(_ productID: String) {
        pendingProductIDs.remove(productID)
        persistPending()
    }

    private func persistPending() {
        defaults.set(Array(pendingProductIDs).sorted(), forKey: pendingKey)
    }
}

extension AgentStoreKitCoordinator {
    enum StoreError: Error, LocalizedError {
        case productUnavailable(String)

        var errorDescription: String? {
            switch self {
            case let .productUnavailable(productID): "The App Store product \(productID) is unavailable."
            }
        }
    }
}
