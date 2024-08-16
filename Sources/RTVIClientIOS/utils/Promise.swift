import Foundation

/// Represents an ongoing asynchronous operation.
class Promise<Value> {
    
    public var onResolve: ((Value) -> Void)? = nil
    public var onReject: ((Error) -> Void)? = nil

    public func resolve(value: Value) {
        self.onResolve?(value)
    }
    
    public func reject(error: Error) {
        self.onReject?(error)
    }
}
