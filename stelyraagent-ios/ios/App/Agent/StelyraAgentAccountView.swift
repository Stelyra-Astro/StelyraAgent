import AuthenticationServices
import SwiftUI
import UIKit

struct StelyraAgentAccountView: View {
    @ObservedObject var account: AgentAccountCoordinator
    @ObservedObject var storeKit: AgentStoreKitCoordinator
    let onResetLocalData: () -> Void
    let onDeleteLocalData: () -> Void

    @State private var confirmsReset = false
    @State private var confirmsDelete = false

    private var hasPendingPurchase: Bool { storeKit.hasPendingPurchase }

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    if account.isSignedIn {
                        LabeledContent("Credits", value: account.credits.map(String.init) ?? "—")
                        Button("Sign Out") { Task { await account.signOut() } }
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            account.configureAppleRequest(request)
                        } onCompletion: { result in
                            Task { await account.completeAppleAuthorization(result) }
                        }
                        .signInWithAppleButtonStyle(.whiteOutline)
                        .frame(height: 46)
                    }
                }

                Section("Purchases") {
                    Button("Buy Credits") { buyCredits() }
                        .disabled(!account.isSignedIn || configuredCreditsProductID == nil)
                    NavigationLink("Purchase History") {
                        AgentPurchaseHistoryView(purchases: account.purchaseHistory)
                    }
                    LabeledContent("Subscription", value: subscriptionLabel)
                    Button("Manage Subscription") { openSubscriptions() }
                    Button("Restore / Reconcile Purchases") {
                        Task {
                            await storeKit.reconcileUnfinished()
                            await account.refreshCredits()
                        }
                    }
                    if hasPendingPurchase {
                        Text("You have a purchase still pending with Apple. Resetting or deleting your account won't cancel the App Store transaction. If Apple completes it later, it may require support to resolve.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Account Data") {
                    Button("Reset Account", role: .destructive) { confirmsReset = true }
                        .disabled(!account.isSignedIn)
                    Button("Delete Account", role: .destructive) { confirmsDelete = true }
                        .disabled(!account.isSignedIn)
                }

                if let error = account.errorMessage ?? storeKit.lastError {
                    Section("Status") {
                        Text(error).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Account")
            .task {
                if account.isSignedIn { await account.refreshAccountData() }
            }
            .alert("Reset Account?", isPresented: $confirmsReset) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) { resetAccount() }
            } message: {
                Text(resetWarning)
            }
            .alert("Delete Account?", isPresented: $confirmsDelete) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteAccount() }
            } message: {
                Text(deleteWarning)
            }
        }
    }

    private var resetWarning: String {
        var value = "Remaining Credits will not be recoverable after reset. A new account generation, wallet and appAccountToken will be created."
        if hasPendingPurchase {
            value += " You have a purchase still pending with Apple. Resetting your account won't cancel the App Store transaction."
        }
        return value
    }

    private var deleteWarning: String {
        var value = "Remaining Credits will not be recoverable after account deletion. Your server account and local authentication will be removed."
        if hasPendingPurchase {
            value += " You have a purchase still pending with Apple. Deleting your account won't cancel the App Store transaction."
        }
        return value
    }


    private var subscriptionLabel: String {
        guard let status = account.subscriptionStatus?.status else { return "—" }
        switch status {
        case "managed_by_apple": return "Managed by Apple"
        case "active": return "Active"
        case "expired": return "Expired"
        default: return status.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private var configuredCreditsProductID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "STELYRAAGENT_CREDITS_PRODUCT_ID") as? String,
              !value.isEmpty else { return nil }
        return value
    }

    private func buyCredits() {
        guard let productID = configuredCreditsProductID,
              let token = account.appAccountToken else { return }
        Task {
            do {
                try await account.ensureFreshSession()
                try await storeKit.purchase(productID: productID, appAccountToken: token)
                await account.refreshCredits()
            } catch {
                // The coordinator surfaces persistent StoreKit/runtime errors; a cancelled purchase is intentionally silent.
            }
        }
    }

    private func resetAccount() {
        Task {
            let preflight = await storeKit.prepareForAccountDestructiveAction()
            guard preflight.canProceed else { return }
            do {
                try await account.resetAccount()
                onResetLocalData()
            } catch { }
        }
    }

    private func deleteAccount() {
        Task {
            let preflight = await storeKit.prepareForAccountDestructiveAction()
            guard preflight.canProceed else { return }
            do {
                _ = try await account.deleteAccount()
                onDeleteLocalData()
            } catch { }
        }
    }

    private func openSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        UIApplication.shared.open(url)
    }
}


private struct AgentPurchaseHistoryView: View {
    let purchases: [AgentPurchaseRecord]

    var body: some View {
        List {
            if purchases.isEmpty {
                ContentUnavailableView(
                    "No Purchases",
                    systemImage: "creditcard",
                    description: Text("Verified credit purchases for this wallet will appear here.")
                )
            } else {
                ForEach(purchases) { purchase in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("+\(purchase.credits) Credits")
                                .font(.headline)
                            Spacer()
                            Text(purchase.status.capitalized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(purchase.productId)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(purchase.createdAt)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Purchase History")
    }
}
