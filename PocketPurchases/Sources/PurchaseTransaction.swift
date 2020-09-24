//
//  Copyright © 2020 pocket-ninja. All rights reserved.
//

import Foundation
import StoreKit

public struct PurchaseTransaction {
    public var product: SKProduct
    public let quantity: Int?
    public var transactionIdentifier: String?

    public init(
        product: SKProduct,
        quantity: Int? = nil,
        transactionIdentifier: String? = nil
    ) {
        self.product = product
        self.quantity = quantity
        self.transactionIdentifier = transactionIdentifier
    }
}
