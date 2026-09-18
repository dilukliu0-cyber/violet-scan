import Foundation
import simd

/// Classifies uncovered / weak regions by approximate span. Does NOT auto-fill large holes.
public struct HoleRegion: Identifiable, Sendable {
    public let id: UUID
    public var keys: [VoxelKey]
    public var sizeClass: HoleSizeClass
    public var centroid: SIMD3<Float>
    public var approximateAreaM2: Float

    public init(id: UUID = UUID(), keys: [VoxelKey], sizeClass: HoleSizeClass, centroid: SIMD3<Float>, approximateAreaM2: Float) {
        self.id = id
        self.keys = keys
        self.sizeClass = sizeClass
        self.centroid = centroid
        self.approximateAreaM2 = approximateAreaM2
    }
}

public final class HoleDetector: Sendable {
    public init() {}

    /// Find weak clusters from grid. Large holes are reported only — never filled here.
    public func detect(in grid: ConfidenceGrid, weakBelow: Float = 0.5, cellSize: Float) -> [HoleRegion] {
        let weak = grid.allSamples().filter { $0.1.confidence < weakBelow && !$0.1.isLocked }
        guard !weak.isEmpty else { return [] }

        var remaining = Set(weak.map(\.0))
        var regions: [HoleRegion] = []
        let neighbors: [(Int16, Int16, Int16)] = [
            (-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1)
        ]

        while let seed = remaining.first {
            var queue: [VoxelKey] = [seed]
            var cluster: [VoxelKey] = []
            remaining.remove(seed)
            while !queue.isEmpty {
                let cur = queue.removeFirst()
                cluster.append(cur)
                for n in neighbors {
                    let k = VoxelKey(x: cur.x &+ n.0, y: cur.y &+ n.1, z: cur.z &+ n.2)
                    if remaining.contains(k) {
                        remaining.remove(k)
                        queue.append(k)
                    }
                }
            }
            let centers = cluster.map { $0.center(cellSize: cellSize) }
            let centroid = centers.reduce(SIMD3<Float>.zero, +) / Float(max(centers.count, 1))
            let area = Float(cluster.count) * cellSize * cellSize
            let sizeClass: HoleSizeClass
            switch cluster.count {
            case 0: sizeClass = .none
            case 1...8: sizeClass = .small
            case 9...40: sizeClass = .medium
            default: sizeClass = .large
            }
            regions.append(HoleRegion(keys: cluster, sizeClass: sizeClass, centroid: centroid, approximateAreaM2: area))
        }
        return regions.sorted { $0.approximateAreaM2 > $1.approximateAreaM2 }
    }

    /// Only small holes are candidates for optional fill (MVP does not apply fill).
    public func fillable(_ regions: [HoleRegion]) -> [HoleRegion] {
        regions.filter { $0.sizeClass == .small }
    }
}
