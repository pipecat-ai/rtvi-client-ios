import Foundation

public enum OptionType: String, Codable {
    case str = "string"
    case bool = "bool"
    case number = "number"
    case array = "array"
    case object = "object"
}
