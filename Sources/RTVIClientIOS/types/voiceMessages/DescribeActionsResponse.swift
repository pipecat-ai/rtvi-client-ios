import Foundation

public struct DescribeActionResponse: Codable {
    public let actions: [ActionDescription]
    
    init(actions: [ActionDescription]) {
        self.actions = actions
    }
}
