import Foundation

extension RTVIClient {
    
    public static let libraryVersion = "0.2.0"
    
    static func appendRtviClientVersion(_ requestData: Value?) -> Value? {
        var requestDataWithVersion = requestData
        do {
            if (requestData == nil) {
                requestDataWithVersion = Value.object([
                    "rtvi_client_version": .string(RTVIClient.libraryVersion)
                ])
            } else {
                try requestDataWithVersion?.addProperty(key: "rtvi_client_version", value: .string(RTVIClient.libraryVersion))
            }
        } catch {
            Logger.shared.error("Failed to add rtvi_client_version \(error.localizedDescription)")
        }
        return requestDataWithVersion
    }
    
}
