import Foundation

public struct ServiceConfigDescription: Codable {
    // TODO check if we should receive service or name here
    // we are currently receiving name
    let service: String?
    let name: String?
    let options: [OptionDescription]
    
    init(service: String?, name: String?, options: [OptionDescription]) {
        self.service = service
        self.name = name
        self.options = options
    }
}
