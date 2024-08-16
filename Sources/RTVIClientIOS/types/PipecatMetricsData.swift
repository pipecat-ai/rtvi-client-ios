import Foundation

/// Metrics data received from a Pipecat instance.
public struct PipecatMetricsData: Codable {
    let processor: String
    let value: Double
}
