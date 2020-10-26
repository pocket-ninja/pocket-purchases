//
//  Copyright © 2020 pocket-ninja. All rights reserved.
//

import Foundation
import StoreKit

public struct PurchaseProduct: Identifiable {
    public struct Price {
        public var price: NSDecimalNumber
        public var locale: Locale

        public init(price: NSDecimalNumber, locale: Locale) {
            self.price = price
            self.locale = locale
        }
    }

    public struct Discount {
        public var trialDays: Int

        public init(trialDays: Int) {
            self.trialDays = trialDays
        }
    }

    public let id: String
    public let period: PurchasePeriod
    public let price: Price
    public let discount: Discount?

    public init(
        id: String,
        period: PurchasePeriod,
        price: PurchaseProduct.Price,
        discount: PurchaseProduct.Discount? = nil
    ) {
        self.id = id
        self.period = period
        self.price = price
        self.discount = discount
    }
}

extension PurchaseProduct.Price {
    public var string: String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        return formatter.string(from: price)
    }
}

extension PurchaseProduct {
    init(product: SKProduct) {
        self.id = product.productIdentifier
        self.price = Price(product: product)
        self.period = PurchasePeriod(product: product)
        self.discount = Discount(product: product)
    }
}

extension PurchaseProduct.Discount {
    init?(product: SKProduct) {
        guard let intro = product.introductoryPrice else {
            return nil
        }

        let units = intro.subscriptionPeriod.numberOfUnits
        let period = intro.subscriptionPeriod.unit
        self.trialDays = units * period.estimatedDays
    }
}

extension PurchaseProduct.Price {
    init(product: SKProduct) {
        self.price = product.price
        self.locale = product.priceLocale
    }
}

extension SKProduct.PeriodUnit {
    var estimatedDays: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        @unknown default:
            fatalError()
        }
    }
}
