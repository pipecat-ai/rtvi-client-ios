import Foundation

/// A protocol representing a base error occurring during an operation.
public protocol VoiceError: Error {
    /// A human-readable description of the error.
    var message: String { get }
    
    /// If the error was caused by another error, this value is set.
    var underlyingError: Error? { get }
}

public extension VoiceError {
    var underlyingError: Error? { return nil }
    
    /// Provides a detailed description of the error, including any underlying error.
    var localizedDescription: String {
        if let underlyingError = self.underlyingError as? VoiceError {
            // Finding the root cause
            var rootCauseError: VoiceError = underlyingError
            while let underlyingError = rootCauseError.underlyingError as? VoiceError {
                rootCauseError = underlyingError
            }
            return "\(message) \(rootCauseError.localizedDescription)"
        } else {
            return message
        }
    }
}

/// Invalid or malformed auth bundle provided to Transport.
public struct InvalidAuthBundleError: VoiceError {
    public let message: String = "Invalid or malformed auth bundle provided to Transport."
    public let underlyingError: Error?
    
    public init(underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
    }
}

/// Failed to fetch the auth bundle.
public struct FetchAuthBundleError: VoiceError {
    public let message: String = "Failed to fetch the auth bundle."
    public let underlyingError: Error?
    
    public init(underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
    }
}

/// Failed to fetch the auth bundle.
public struct StartBotError: VoiceError {
    public let message: String = "Failed to connect / invalid auth bundle from base url"
    public let underlyingError: Error?
    
    public init(underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
    }
}

/// Unable to update configuration.
public struct ConfigUpdateError: VoiceError {
    public let message: String = "Unable to update configuration."
    public let underlyingError: Error?
    
    public init(underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
    }
}

/// Bot is not ready yet.
public struct BotNotReadyError: VoiceError {
    public let message: String = "Bot is not ready yet."
    public let underlyingError: Error?
    
    public init(underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
    }
}

/// Received error response from backend.
public struct BotResponseError: VoiceError {
    public let message: String
    public let underlyingError: Error?
    
    public init(message: String = "Received error response from backend.", underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }
}

/// The operation timed out before it could complete.
public struct ResponseTimeoutError: VoiceError {
    public let message: String = "The operation timed out before it could complete."
    public let underlyingError: Error?
    
    public init(underlyingError: Error? = nil) {
        self.underlyingError = underlyingError
    }
}

/// Received an error response when trying to execute the function.
public struct AsyncExecutionError: VoiceError {
    public let message: String
    public let underlyingError: Error?
    
    public init(functionName: String, underlyingError: Error? = nil) {
        self.message = "Received an error response when trying to execute the function \(functionName)."
        self.underlyingError = underlyingError
    }
}

/// An unknown error occurred..
public struct OtherError: VoiceError {
    public let message: String
    public let underlyingError: Error?
    
    public init(message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError
    }
}
