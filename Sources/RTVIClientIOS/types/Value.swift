import Foundation

/// Generic json representation used for serialization.
public enum Value: Codable, Equatable {
    struct ValueDecodingError: Error {
        let message: String
    }
    
    case boolean(Bool)
    case number(Double)
    case string(String)
    case array([Value?])
    case object([String: Value?])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolean = try? container.decode(Bool.self) {
            self = .boolean(boolean)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([Value].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: Value].self) {
            self = .object(dictionary)
        } else {
            throw ValueDecodingError(message: "could not decode a valid Value")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .boolean(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let values):
            try container.encode(values)
        case .object(let valueDictionary):
            try container.encode(valueDictionary)
        }
    }
    
    public mutating func addProperty(key: String, value: Value?) throws {
        guard case .object(var dictionary) = self else {
            throw ValueDecodingError(message: "Cannot add properties to non-object Value")
        }
        dictionary[key] = value
        self = .object(dictionary)
    }
}

extension Value: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension Value: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .number(Double(value))
    }
}

extension Value: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .number(value)
    }
}

extension Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension Value: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Value?...) {
        self = .array(elements)
    }
}

extension Value: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, Value?)...) {
        self = .object(Dictionary.init(uniqueKeysWithValues: elements))
    }
}

extension Encodable {
    func convertToRtviValue() async throws -> Value {
        // Encode the current object to JSON data
        let jsonData = try JSONEncoder().encode(self)
        // Decode the JSON data into a Value object
        let value = try JSONDecoder().decode(Value.self, from: jsonData)
        return value
    }
}
