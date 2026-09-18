import Foundation
import simd

public struct PrecisionTarget: Identifiable, Sendable {
    public let id: UUID
    public var keys: [VoxelKey]
    public var centroid: SIMD3<Float>
    public var meanConfidence: Float
    public var progress: Float  // 0…1 for this target
    public var isComplete: Bool

    public init(
        id: UUID = UUID(),
        keys: [VoxelKey],
        centroid: SIMD3<Float>,
        meanConfidence: Float,
        progress: Float = 0,
        isComplete: Bool = false
    ) {
        self.id = id
        self.keys = keys
        self.centroid = centroid
        self.meanConfidence = meanConfidence
        self.progress = progress
        self.isComplete = isComplete
    }
}

/// After first pass: rank weak cells into targets for purple-highlight precision scanning.
public final class PrecisionPassPlanner {
    public private(set) var targets: [PrecisionTarget] = []
    public private(set) var currentIndex: Int = 0
    public var completionThreshold: Float = 0.82

    public init() {}

    public func reset() {
        targets = []
        currentIndex = 0
    }

    public var current: PrecisionTarget? {
        guard targets.indices.contains(currentIndex) else { return nil }
        return targets[currentIndex]
    }

    public var overallProgress: Float {
        guard !targets.isEmpty else { return 1 }
        let done = targets.filter(\.isComplete).count
        let cur = current?.progress ?? 0
        return (Float(done) + cur) / Float(targets.count)
    }

    public func rebuild(from grid: ConfidenceGrid, maxTargets: Int = 12) {
        let weak = grid.weakKeys(below: 0.7, limit: 200)
        guard !weak.isEmpty else {
            targets = []
            currentIndex = 0
            return
        }
        let cellSize = grid.cellSize
        // Cluster nearby weak keys into targets.
        var remaining = Set(weak)
        var built: [PrecisionTarget] = []
        let neigh: [(Int16, Int16, Int16)] = [(-1,0,0),(1,0,0),(0,-1,0),(0,1,0),(0,0,-1),(0,0,1),
                                              (-1,-1,0),(1,1,0),(-1,0,1),(1,0,-1)]

        while let seed = remaining.first, built.count < maxTargets {
            var queue = [seed]
            var cluster: [VoxelKey] = []
            remaining.remove(seed)
            while !queue.isEmpty && cluster.count < 48 {
                let cur = queue.removeFirst()
                cluster.append(cur)
                for n in neigh {
                    let k = VoxelKey(x: cur.x &+ n.0, y: cur.y &+ n.1, z: cur.z &+ n.2)
                    if remaining.contains(k) {
                        remaining.remove(k)
                        queue.append(k)
                    }
                }
            }
            let centers = cluster.map { $0.center(cellSize: cellSize) }
            let centroid = centers.reduce(SIMD3<Float>.zero, +) / Float(max(centers.count, 1))
            let mean = cluster.compactMap { grid.sample(at: $0)?.confidence }.reduce(0, +) / Float(max(cluster.count, 1))
            built.append(PrecisionTarget(keys: cluster, centroid: centroid, meanConfidence: mean))
        }
        // Worst first
        targets = built.sorted { $0.meanConfidence < $1.meanConfidence }
        currentIndex = 0
    }

    /// Call periodically during precision scanning with live grid.
    @discardableResult
    public func updateProgress(grid: ConfidenceGrid) -> (progressPercent: Int, areaComplete: Bool, advanced: Bool) {
        guard targets.indices.contains(currentIndex) else {
            return (100, true, false)
        }
        var t = targets[currentIndex]
        let confs = t.keys.compactMap { grid.sample(at: $0)?.confidence }
        let mean = confs.isEmpty ? t.meanConfidence : confs.reduce(0, +) / Float(confs.count)
        t.meanConfidence = mean
        let good = confs.filter { $0 >= completionThreshold }.count
        t.progress = confs.isEmpty ? 0 : Float(good) / Float(confs.count)
        var advanced = false
        if t.progress >= 0.92 {
            t.isComplete = true
            t.progress = 1
            targets[currentIndex] = t
            if currentIndex + 1 < targets.count {
                currentIndex += 1
                advanced = true
            }
            return (Int((overallProgress * 100).rounded()), true, advanced)
        }
        targets[currentIndex] = t
        return (Int((t.progress * 100).rounded()), false, false)
    }
}
