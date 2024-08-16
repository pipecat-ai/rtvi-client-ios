import Foundation

public struct ActionResponse: Codable {
    let result: Value
    
    public init(result: Value) {
        self.result = result
    }
}

struct ActionResponseWrapper<T: Decodable>: Decodable {
    let result: T
}
