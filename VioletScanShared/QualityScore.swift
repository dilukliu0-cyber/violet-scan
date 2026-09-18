import Foundation

public struct QualityBreakdown: Sendable {
    public var coverage: Float      // 0…1
    public var geometry: Float      // mean confidence
    public var tracking: Float      // AR tracking heuristic
    public var corners: Float       // corner/edge proxy
    public var overall: Float

    public init(coverage: Float, geometry: Float, tracking: Float, corners: Float) {
        self.coverage = coverage
        self.geometry = geometry
        self.tracking = tracking
        self.corners = corners
        // Weighted overall
        self.overall = (coverage * 0.35 + geometry * 0.35 + tracking * 0.15 + corners * 0.15)
    }

    public var percent: Int { Int((overall * 100).rounded()) }
}

public enum QualityScorer {
    /// Heuristic quality from grid + session signals.
    public static func score(
        grid: ConfidenceGrid,
        expectedCells: Int,
        trackingQuality: Float,
        cornerHits: Int,
        expectedCorners: Int = 8
    ) -> QualityBreakdown {
        let stats = grid.coverageStats()
        let coverage = expectedCells <= 0
            ? min(1, Float(stats.total) / 500)
            : min(1, Float(stats.total) / Float(max(expectedCells, 1)))
        let geometry = stats.meanConf
        let tracking = max(0, min(1, trackingQuality))
        let corners = expectedCorners <= 0 ? 0.5 : min(1, Float(cornerHits) / Float(expectedCorners))
        return QualityBreakdown(coverage: coverage, geometry: geometry, tracking: tracking, corners: corners)
    }
}
