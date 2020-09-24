//
//  Copyright © 2020 pocket-ninja. All rights reserved.
//

import Foundation
import StoreKit

public enum PurchasePeriod: String, Hashable, Codable {
    case week
    case month
    case year
    case lifetime
}

extension PurchasePeriod {
    init(product: SKProduct) {
        guard let period = product.subscriptionPeriod else {
            self = .lifetime
            return
        }

        switch period.unit {
        case .month:
            self = .month
        case .year:
            self = .year
        default:
            self = .week
        }
    }
}
