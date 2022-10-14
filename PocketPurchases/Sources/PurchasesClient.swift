//
//  Copyright © 2020 pocket-ninja. All rights reserved.
//

import Combine
import Foundation
import StoreKit

public struct PurchasesClient {
    public typealias PurchasesState = [PurchaseProduct.ID: PurchaseStatus]

    public enum PurchaseError: Error {
        case unknown
        case networkConnectionFailed
        case cancelled
    }

    public enum RestoreError: Error {
        case unknown
        case nothingToRestore
        case failedToRestore
    }

    public enum DelegateEvent {
        case didChangeState(PurchasesState)
        case didPurchaseProduct(PurchaseTransaction)
        case didRestoreProducts([PurchaseProduct.ID])
        case didProceedProducts([PurchaseProduct.ID])
    }

    public var state: () -> PurchasesState
    public var delegate: () -> AnyPublisher<DelegateEvent, Never>
    public var setup: () -> Void
    public var loadProducts: ([PurchaseProduct.ID], @escaping (Result<[PurchaseProduct], Error>) -> Void) -> Void
    public var restorePurhcases: (@escaping (Result<[PurchaseProduct.ID], RestoreError>) -> Void) -> Void
    public var purchaseProduct: (PurchaseProduct.ID, @escaping (Result<PurchaseTransaction, PurchaseError>) -> Void) -> Void

    public init(
        state: @escaping () -> PurchasesState,
        delegate: @escaping () -> AnyPublisher<DelegateEvent, Never>,
        setup: @escaping () -> Void,
        loadProducts: @escaping ([PurchaseProduct.ID], @escaping (Result<[PurchaseProduct], Error>) -> Void) -> Void,
        restorePurhcases: @escaping (@escaping (Result<[PurchaseProduct.ID], RestoreError>) -> Void) -> Void,
        purchaseProduct: @escaping (PurchaseProduct.ID, @escaping (Result<PurchaseTransaction, PurchaseError>) -> Void) -> Void
    ) {
        self.state = state
        self.delegate = delegate
        self.setup = setup
        self.loadProducts = loadProducts
        self.restorePurhcases = restorePurhcases
        self.purchaseProduct = purchaseProduct
    }
}

public extension PurchasesClient {
    func loadProducts(
        with identifiers: [PurchaseProduct.ID],
        then completion: @escaping (Result<[PurchaseProduct], Error>) -> Void
    ) {
        loadProducts(identifiers, completion)
    }

    func purchaseProduct(
        with id: PurchaseProduct.ID,
        then completion: @escaping (Result<PurchaseTransaction, PurchasesClient.PurchaseError>) -> Void
    ) {
        purchaseProduct(id, completion)
    }
}

extension PurchasesClient.PurchaseError {
    init(_ error: SKError) {
        switch error.code {
        case .cloudServiceNetworkConnectionFailed:
            self = .networkConnectionFailed
        case .paymentCancelled:
            self = .cancelled
        default:
            self = .unknown
        }
    }
}
