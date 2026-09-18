import Foundation
import simd

/// Spatial store of best depth/mesh samples with confidence-aware merge.
/// Critical rule: re-scanning must NOT degrade good geometry.
public final class ConfidenceGrid: @unchecked Sendable {
    public private(set) var cellSize: Float
    public private(set) var lockThreshold: Float
    private var cells: [VoxelKey: VoxelSample] = [:]
    private let lock = NSLock()

    public var cellCount: Int {
        lock.lock(); defer { lock.unlock() }
        return cells.count
    }

    public var lockedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return cells.values.filter(\.isLocked).count
    }

    public init(cellSize: Float = 0.05, lockThreshold: Float = 0.85) {
        self.cellSize = cellSize
        self.lockThreshold = lockThreshold
    }

    public func reconfigure(mode: ScanQualityMode) {
        lock.lock()
        defer { lock.unlock() }
        // Changing cell size mid-scan is lossy; keep existing keys, update thresholds for new merges.
        cellSize = mode.cellSize
        lockThreshold = mode.lockThreshold
    }

    public func reset() {
        lock.lock()
        cells.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    /// Merge one sample. Never blind-replace; locked cells only improve if new confidence is strictly better AND caller allows unlockImprove (default false for locked).
    @discardableResult
    public func merge(
        worldPoint: SIMD3<Float>,
        normal: SIMD3<Float> = .zero,
        confidence: Float,
        timestamp: TimeInterval,
        allowImproveLocked: Bool = false
    ) -> MergeDecision {
        let conf = max(0, min(1, confidence))
        let key = VoxelKey(world: worldPoint, cellSize: cellSize)
        lock.lock()
        defer { lock.unlock() }

        guard var existing = cells[key] else {
            var sample = VoxelSample(
                position: worldPoint,
                normal: normal,
                confidence: conf,
                observationCount: 1,
                isLocked: conf >= lockThreshold,
                lastUpdated: timestamp
            )
            if sample.isLocked == false && conf >= lockThreshold {
                sample.isLocked = true
            }
            cells[key] = sample
            return .addNew
        }

        if existing.isLocked && !allowImproveLocked {
            // Locked: only accept strictly better confidence (rare refine), otherwise keep.
            if conf > existing.confidence + 0.02 {
                existing = blend(existing: existing, incomingPos: worldPoint, incomingNormal: normal, incomingConf: conf, timestamp: timestamp)
                cells[key] = existing
                return .improve
            }
            return .skippedLocked
        }

        if conf < existing.confidence - 0.001 {
            // Worse sample — keep existing geometry.
            existing.observationCount = UInt16(clamping: Int(existing.observationCount) + 1)
            cells[key] = existing
            return .keepExisting
        }

        if conf > existing.confidence || (abs(conf - existing.confidence) < 0.02 && betterAgreement(existing: existing, candidate: worldPoint, normal: normal)) {
            existing = blend(existing: existing, incomingPos: worldPoint, incomingNormal: normal, incomingConf: conf, timestamp: timestamp)
            if existing.confidence >= lockThreshold {
                existing.isLocked = true
            }
            cells[key] = existing
            return .improve
        }

        existing.observationCount = UInt16(clamping: Int(existing.observationCount) + 1)
        cells[key] = existing
        return .keepExisting
    }

    public func lockCells(above threshold: Float? = nil) -> Int {
        let t = threshold ?? lockThreshold
        lock.lock()
        defer { lock.unlock() }
        var n = 0
        for (k, var s) in cells where !s.isLocked && s.confidence >= t {
            s.isLocked = true
            cells[k] = s
            n += 1
        }
        return n
    }

    public func sample(at key: VoxelKey) -> VoxelSample? {
        lock.lock(); defer { lock.unlock() }
        return cells[key]
    }

    public func allSamples() -> [(VoxelKey, VoxelSample)] {
        lock.lock(); defer { lock.unlock() }
        return Array(cells)
    }

    public func weakKeys(below threshold: Float, limit: Int = 64) -> [VoxelKey] {
        lock.lock(); defer { lock.unlock() }
        return cells
            .filter { !$0.value.isLocked && $0.value.confidence < threshold }
            .sorted { $0.value.confidence < $1.value.confidence }
            .prefix(limit)
            .map(\.key)
    }

    public func averageConfidence() -> Float {
        lock.lock(); defer { lock.unlock() }
        guard !cells.isEmpty else { return 0 }
        let sum = cells.values.reduce(Float(0)) { $0 + $1.confidence }
        return sum / Float(cells.count)
    }

    public func coverageStats() -> (total: Int, locked: Int, weak: Int, meanConf: Float) {
        lock.lock(); defer { lock.unlock() }
        let total = cells.count
        let locked = cells.values.filter(\.isLocked).count
        let weak = cells.values.filter { $0.confidence < 0.55 }.count
        let mean = total == 0 ? Float(0) : cells.values.reduce(Float(0)) { $0 + $1.confidence } / Float(total)
        return (total, locked, weak, mean)
    }

    public func encodeSnapshot() throws -> Data {
        lock.lock()
        let copy = cells
        let size = cellSize
        let thr = lockThreshold
        lock.unlock()
        let payload = Snapshot(cellSize: size, lockThreshold: thr, cells: copy.map { CellRec(key: $0.key, sample: $0.value) })
        return try JSONEncoder().encode(payload)
    }

    public func loadSnapshot(_ data: Data) throws {
        let payload = try JSONDecoder().decode(Snapshot.self, from: data)
        lock.lock()
        cellSize = payload.cellSize
        lockThreshold = payload.lockThreshold
        cells = Dictionary(uniqueKeysWithValues: payload.cells.map { ($0.key, $0.sample) })
        lock.unlock()
    }

    // MARK: - Private

    private struct CellRec: Codable {
        var key: VoxelKey
        var sample: VoxelSample
    }

    private struct Snapshot: Codable {
        var cellSize: Float
        var lockThreshold: Float
        var cells: [CellRec]
    }

    private func blend(
        existing: VoxelSample,
        incomingPos: SIMD3<Float>,
        incomingNormal: SIMD3<Float>,
        incomingConf: Float,
        timestamp: TimeInterval
    ) -> VoxelSample {
        var out = existing
        let wNew = incomingConf
        let wOld = existing.confidence
        let wSum = max(wOld + wNew, 0.0001)
        out.position = Vec3((existing.positionSIMD * wOld + incomingPos * wNew) / wSum)
        if simd_length(incomingNormal) > 0.1 {
            let n = existing.normalSIMD * wOld + incomingNormal * wNew
            let len = simd_length(n)
            out.normal = Vec3(len > 0.001 ? n / len : incomingNormal)
        }
        // Confidence rises toward better observation, never drops on improve path.
        out.confidence = max(existing.confidence, min(1, existing.confidence * 0.35 + incomingConf * 0.65 + 0.02))
        out.observationCount = UInt16(clamping: Int(existing.observationCount) + 1)
        out.lastUpdated = timestamp
        return out
    }

    private func betterAgreement(existing: VoxelSample, candidate: SIMD3<Float>, normal: SIMD3<Float>) -> Bool {
        let d = simd_distance(existing.positionSIMD, candidate)
        if d < cellSize * 0.25 { return true }
        if simd_length(existing.normalSIMD) > 0.1 && simd_length(normal) > 0.1 {
            return simd_dot(existing.normalSIMD, normal) > 0.9 && d < cellSize * 0.5
        }
        return false
    }
}

/// Alias used in product docs.
public typealias VoxelStore = ConfidenceGrid

// MARK: - Next iteration TODOs (structured, not claimed done)
/*
 TODO(plane-fitting): Fit local planes per neighborhood to reject outliers before merge.
 TODO(metal-recon): GPU voxel hash / TSDF fusion for MAX QUALITY long sessions.
 TODO(poisson): Optional screened Poisson from locked cells only for Final mesh.
*/
