//
//  Copyright © 2020 pocket-ninja. All rights reserved.
//

import Foundation

extension Encodable {
    func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }
}

extension Data {
    func decoded<T: Decodable>() throws -> T {
        try JSONDecoder().decode(T.self, from: self)
    }
}
