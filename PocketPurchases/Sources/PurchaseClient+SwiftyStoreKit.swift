//
//  Copyright © 2020 pocket-ninja. All rights reserved.
//

#if os(iOS)

    import Combine
    import Foundation
    import SwiftyStoreKit

    public extension PurchasesClient {
        static func swiftyStoreKit(storeSecret: @escaping () -> String) -> PurchasesClient {
            let service = SwiftyPurchasesService(storeSecret: storeSecret)

            return PurchasesClient(
                state: { service.state },
                delegate: { service.delegate },
                setup: service.setup,
                loadProducts: service.loadProducts(_:then:),
                restorePurhcases: service.restorePurchases(then:),
                purchaseProduct: service.purchaseProduct(with:then:)
            )
        }
    }

    final class SwiftyPurchasesService {
        var userDefaults = UserDefaults.standard
        var workingQueue = DispatchQueue(label: "com.pocket-ninja.purchases.swifty.working-queue")
        var completionQueue = DispatchQueue.main

        var state: PurchasesClient.PurchasesState {
            get {
                userDefaults.purchasesState
            }

            set {
                userDefaults.purchasesState = newValue
                delegateSubject.send(.didChangeState(newValue))
            }
        }

        var delegate: AnyPublisher<PurchasesClient.DelegateEvent, Never> {
            delegateSubject
                .receive(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

        init(storeSecret: @escaping () -> String) {
            self.storeSecret = storeSecret
        }

        func setup() {
            proceedPurchases()
            validatePurchases()

            willEnterForegroundNotificationCancellable = NotificationCenter.default
                .addObserver(forName: UIApplication.willEnterForegroundNotification,
                             object: nil,
                             queue: .main) { [weak self] _ in
                    self?.validatePurchases()
                }
        }

        func loadProducts(
            _ ids: [PurchaseProduct.ID],
            then completion: @escaping (Result<[PurchaseProduct], Error>) -> Void
        ) {
            workingQueue.async {
                let cachedProducts = ids.compactMap { self.cache[$0] }
                if cachedProducts.count == ids.count {
                    self.completionQueue.async {
                        completion(.success(cachedProducts))
                    }
                    return
                }

                _ = SwiftyStoreKit.retrieveProductsInfo(Set(ids)) { result in
                    self.workingQueue.async {
                        self.handle(result, ofRetriving: ids, with: completion)
                    }
                }
            }
        }

        private func handle(
            _ results: RetrieveResults,
            ofRetriving ids: [PurchaseProduct.ID],
            with completion: @escaping (Result<[PurchaseProduct], Error>) -> Void
        ) {
            let products: [PurchaseProduct] = ids.compactMap { id in
                results.retrievedProducts
                    .first { $0.productIdentifier == id }
                    .flatMap(PurchaseProduct.init(product:))
            }

            products.forEach { cache[$0.id] = $0 }

            completionQueue.async {
                if let error = results.error, products.isEmpty {
                    completion(.failure(error))
                } else {
                    completion(.success(products))
                }
            }
        }

        func restorePurchases(then completion: @escaping (Result<[PurchaseProduct.ID], PurchasesClient.RestoreError>) -> Void) {
            SwiftyStoreKit.restorePurchases { results in
                self.workingQueue.async {
                    self.handle(results, with: completion)
                }
            }
        }

        private func handle(
            _ results: RestoreResults,
            with completion: @escaping (Result<[PurchaseProduct.ID], PurchasesClient.RestoreError>) -> Void
        ) {
            if results.restoredPurchases.count > 0 {
                let restoredIds = results.restoredPurchases.map(\.productId)
                let restoredState = restoredIds.map { ($0, PurchaseStatus.purchased) }
                state.merge(restoredState, uniquingKeysWith: { _, rhs in rhs })

                completionQueue.async {
                    self.delegateSubject.send(.didRestoreProducts(restoredIds))
                    completion(.success(restoredIds))
                }
            } else {
                let isFailedToRestore = results.restoreFailedPurchases.count > 0
                let error: PurchasesClient.RestoreError = isFailedToRestore ? .failedToRestore : .nothingToRestore

                completionQueue.async {
                    completion(.failure(error))
                }
            }
        }

        func purchaseProduct(with id: PurchaseProduct.ID, then completion: @escaping (Result<PurchaseTransaction, PurchasesClient.PurchaseError>) -> Void) {
            SwiftyStoreKit.purchaseProduct(id) { result in
                self.workingQueue.async {
                    self.handle(result, with: completion)
                }
            }
        }

        private func handle(
            _ results: PurchaseResult,
            with completion: @escaping (Result<PurchaseTransaction, PurchasesClient.PurchaseError>) -> Void
        ) {
            completionQueue.async {
                switch results {
                case let .success(purchase: details):
                    self.completionQueue.async {
                        self.state[details.productId] = .purchased
                    }

                    let transaction = PurchaseTransaction(
                        product: details.product,
                        quantity: details.quantity,
                        transactionIdentifier: details.transaction.transactionIdentifier
                    )
                    self.delegateSubject.send(.didPurchaseProduct(transaction))
                    completion(.success(transaction))

                case let .error(error):
                    let purchaseError = PurchasesClient.PurchaseError(error)
                    completion(.failure(purchaseError))
                }
            }
        }

        private func validatePurchases() {
            let validator = AppleReceiptValidator(
                service: .production,
                sharedSecret: storeSecret()
            )

            SwiftyStoreKit.verifyReceipt(using: validator) { results in
                self.handle(results)
            }
        }

        private func handle(_ results: VerifyReceiptResult) {
            guard
                case let .success(receipt: receipt) = results,
                let ids = SwiftyStoreKit.getDistinctPurchaseIds(inReceipt: receipt)
            else {
                return
            }

            loadProducts(Array(ids)) { result in
                guard let products = try? result.get() else {
                    return
                }

                self.workingQueue.async {
                    let verifiedState = products.map { product in
                        (product.id, SwiftyStoreKit.verifyProduct(product, inReceipt: receipt))
                    }

                    self.state.merge(verifiedState, uniquingKeysWith: { _, rhs in rhs })
                }
            }
        }

        private func proceedPurchases() {
            SwiftyStoreKit.completeTransactions { purchases in
                self.workingQueue.async {
                    self.handle(purchases)
                }
            }
        }

        private func handle(_ purchases: [Purchase]) {
            let completedState = purchases
                .filter { purchase in
                    let state = purchase.transaction.transactionState
                    return state == .purchased || state == .restored
                }
                .map { purchase in
                    (purchase.productId, PurchaseStatus.purchased)
                }

            state.merge(completedState, uniquingKeysWith: { _, rhs in rhs })
            delegateSubject.send(.didProceedProducts(completedState.map { $0.0 }))
        }

        private let storeSecret: () -> String
        private var cache: [PurchaseProduct.ID: PurchaseProduct] = [:]
        private var willEnterForegroundNotificationCancellable: Any?
        private let delegateSubject = PassthroughSubject<PurchasesClient.DelegateEvent, Never>()
    }

    private extension UserDefaults {
        var purchasesState: PurchasesClient.PurchasesState {
            get {
                guard
                    let data = data(forKey: .purchasesStateKey),
                    let state = try? data.decoded() as PurchasesClient.PurchasesState
                else {
                    return [:]
                }

                return state
            }
            set {
                if let data = try? newValue.encoded() {
                    set(data, forKey: .purchasesStateKey)
                }
            }
        }
    }

    private extension String {
        static let purchasesStateKey = "com.pocket-ninja.purchases.swifty.purchases-state"
    }

    private extension SwiftyStoreKit {
        static func verifyProduct(_ product: PurchaseProduct, inReceipt receipt: ReceiptInfo) -> PurchaseStatus {
            if product.period == .lifetime {
                return PurchaseStatus(
                    SwiftyStoreKit.verifyPurchase(productId: product.id, inReceipt: receipt)
                )
            } else {
                return PurchaseStatus(
                    SwiftyStoreKit.verifySubscription(ofType: .autoRenewable, productId: product.id, inReceipt: receipt)
                )
            }
        }
    }

    private extension PurchaseStatus {
        init(_ result: VerifyPurchaseResult) {
            switch result {
            case .notPurchased:
                self = .notPurchased
            case .purchased:
                self = .purchased
            }
        }

        init(_ result: VerifySubscriptionResult) {
            switch result {
            case .notPurchased:
                self = .notPurchased
            case .expired:
                self = .expired
            case .purchased:
                self = .purchased
            }
        }
    }

#endif
