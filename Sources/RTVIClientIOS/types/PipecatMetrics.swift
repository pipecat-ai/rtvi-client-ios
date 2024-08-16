import Foundation

/// Metrics received from a Pipecat instance.
public struct PipecatMetrics: Codable {
    let processing: [PipecatMetricsData]?
    let ttfb: [PipecatMetricsData]?
}
