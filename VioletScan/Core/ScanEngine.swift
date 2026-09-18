import Foundation
import Combine
import ARKit
import RealityKit
import simd

/// ARSession + sceneDepth / LiDAR mesh accumulation into ConfidenceGrid across passes.
@MainActor
final class ScanEngine: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var lidarAvailable = false
    @Published var trackingStateRU = "ожидание"
    @Published var coveragePercent: Int = 0
    @Published var quality: QualityBreakdown = QualityBreakdown(coverage: 0, geometry: 0, tracking: 0, corners: 0)
    @Published var guidance: GuidanceHint = GuidanceHint(color: .unknown, messageRU: "ГОТОВО К СКАНИРОВАНИЮ", messageEN: "READY")
    @Published var surfaceChipRU = "—"
    @Published var passIndex: Int = 0
    @Published var lockedCells: Int = 0
    @Published var cellCount: Int = 0
    @Published var precisionMode = false
    @Published var precisionProgressPercent: Int = 0
    @Published var precisionAreaComplete = false
    @Published var currentPrecisionLabelRU: String = ""
    @Published var localConfidence: Float = 0
    @Published var distanceMeters: Float? = nil

    let grid = ConfidenceGrid()
    let precisionPlanner = PrecisionPassPlanner()
    let holeDetector = HoleDetector()

    private(set) var session = ARSession()
    private var qualityMode: ScanQualityMode = .maxQuality
    private var expectedCells: Int = 800
    private var cornerHits: Int = 0
    private var frameCounter = 0
    private var trackingQuality: Float = 0.5
    private var lastMeshAnchorCount = 0

    /// Accumulated ARMesh geometry (world) for raw export — simplified vertex bag.
    private var rawMeshVertices: [SIMD3<Float>] = []
    private var rawMeshIndices: [UInt32] = []

    override init() {
        super.init()
        session.delegate = self
        refreshLiDARSupport()
    }

    func refreshLiDARSupport() {
        let mesh = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        let depth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        lidarAvailable = mesh || depth
    }

    func configure(mode: ScanQualityMode) {
        qualityMode = mode
        grid.reconfigure(mode: mode)
        expectedCells = mode == .maxQuality ? 2500 : (mode == .high ? 1600 : (mode == .balanced ? 1000 : 600))
    }

    func startNewScan(mode: ScanQualityMode) {
        configure(mode: mode)
        grid.reset()
        precisionPlanner.reset()
        passIndex = 0
        cornerHits = 0
        rawMeshVertices.removeAll(keepingCapacity: true)
        rawMeshIndices.removeAll(keepingCapacity: true)
        precisionMode = false
        runSession(reset: true)
    }

    func resumePass() {
        guard !isRunning || isPaused else { return }
        runSession(reset: false)
    }

    func pause() {
        session.pause()
        isPaused = true
        isRunning = false
        trackingStateRU = "пауза"
    }

    func finishPass() {
        passIndex += 1
        pause()
        _ = AutoProtect.lockHighConfidence(in: grid)
        lockedCells = grid.lockedCount
        cellCount = grid.cellCount
        publishStats()
    }

    func enablePrecisionPass() {
        precisionMode = true
        precisionPlanner.rebuild(from: grid)
        precisionProgressPercent = 0
        precisionAreaComplete = false
        if let t = precisionPlanner.current {
            currentPrecisionLabelRU = String(format: "Зона %d · conf %.0f%%", 1, t.meanConfidence * 100)
        } else {
            currentPrecisionLabelRU = "Слабых зон нет"
        }
        resumePass()
    }

    func lockGoodNow() {
        let n = AutoProtect.lockHighConfidence(in: grid)
        lockedCells = grid.lockedCount
        surfaceChipRU = "ЗАБЛОКИРОВАНО +\(n)"
    }

    private func runSession(reset: Bool) {
        refreshLiDARSupport()
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        config.environmentTexturing = .automatic
        var opts: ARSession.RunOptions = []
        if reset {
            opts.insert(.resetTracking)
            opts.insert(.removeExistingAnchors)
        }
        session.run(config, options: opts)
        isRunning = true
        isPaused = false
        trackingStateRU = "сканирование"
    }

    func exportAccumulatedMesh() -> TriangleMesh {
        if !rawMeshVertices.isEmpty && !rawMeshIndices.isEmpty {
            return TriangleMesh(vertices: rawMeshVertices, normals: [], indices: rawMeshIndices)
        }
        return MeshExporter.meshFromGrid(grid)
    }

    private func publishStats() {
        let q = QualityScorer.score(
            grid: grid,
            expectedCells: expectedCells,
            trackingQuality: trackingQuality,
            cornerHits: cornerHits
        )
        quality = q
        coveragePercent = Int((q.coverage * 100).rounded())
        cellCount = grid.cellCount
        lockedCells = grid.lockedCount
        let stats = grid.coverageStats()
        surfaceChipRU = String(format: "пов. %.0f%% · lock %d", stats.meanConf * 100, stats.locked)
    }

    private func ingestDepth(_ frame: ARFrame) {
        guard let depth = frame.sceneDepth?.depthMap else { return }
        let confMap = frame.sceneDepth?.confidenceMap
        let w = CVPixelBufferGetWidth(depth)
        let h = CVPixelBufferGetHeight(depth)
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }
        if let confMap { CVPixelBufferLockBaseAddress(confMap, .readOnly) }
        defer { if let confMap { CVPixelBufferUnlockBaseAddress(confMap, .readOnly) } }

        guard let base = CVPixelBufferGetBaseAddress(depth) else { return }
        let depthStrideBytes = CVPixelBufferGetBytesPerRow(depth)
        let confBase = confMap.flatMap { CVPixelBufferGetBaseAddress($0) }
        let confStride = confMap.map { CVPixelBufferGetBytesPerRow($0) } ?? 0

        let cam = frame.camera
        let intrinsics = cam.intrinsics
        let view = cam.transform
        // Sample sparsely for performance.
        let step = qualityMode == .maxQuality ? 4 : (qualityMode == .high ? 6 : 8)
        let ts = frame.timestamp
        var nearest: Float?
        var localAcc: Float = 0
        var localN = 0

        for y in Swift.stride(from: 0, to: h, by: step) {
            for x in Swift.stride(from: 0, to: w, by: step) {
                let dRow = base.advanced(by: y * depthStrideBytes).assumingMemoryBound(to: Float32.self)
                let z = Float(dRow[x])
                guard z.isFinite, z > 0.15, z < 5.0 else { continue }
                var conf: Float = 0.5
                if let confBase {
                    let cRow = confBase.advanced(by: y * confStride).assumingMemoryBound(to: UInt8.self)
                    // ARConfidenceLevel: 0 low, 1 medium, 2 high
                    switch cRow[x] {
                    case 2: conf = 0.92
                    case 1: conf = 0.7
                    default: conf = 0.4
                    }
                }
                let fx = intrinsics[0, 0]
                let fy = intrinsics[1, 1]
                let cx = intrinsics[2, 0]
                let cy = intrinsics[2, 1]
                let xCam = (Float(x) - cx) * z / fx
                let yCam = (Float(y) - cy) * z / fy
                let local = SIMD4<Float>(xCam, yCam, -z, 1) // camera looks -Z in ARKit
                let world4 = view * local
                let world = SIMD3(world4.x, world4.y, world4.z)
                _ = grid.merge(worldPoint: world, confidence: conf, timestamp: ts)

                if nearest == nil || z < nearest! { nearest = z }
                // Center patch confidence
                if abs(x - w/2) < step * 3 && abs(y - h/2) < step * 3 {
                    localAcc += conf
                    localN += 1
                }
            }
        }
        distanceMeters = nearest
        if localN > 0 {
            localConfidence = localAcc / Float(localN)
        }
    }

    private func ingestMeshAnchors(_ anchors: [ARAnchor], timestamp: TimeInterval) {
        for case let mesh as ARMeshAnchor in anchors {
            let geom = mesh.geometry
            let vertices = geom.vertices
            let normals = geom.normals
            let faces = geom.faces
            let transform = mesh.transform

            let vCount = vertices.count
            let strideBytes = vertices.stride
            let vBuf = vertices.buffer.contents()
            let nBuf = normals.buffer.contents()
            let nStride = normals.stride

            // Subsample faces into grid + accumulate raw mesh lightly.
            let faceCount = faces.count
            let indexCountPerFace = faces.indexCountPerPrimitive
            let idxBuf = faces.buffer.contents().assumingMemoryBound(to: UInt32.self)

            let faceStep = max(1, faceCount / 400)
            for f in Swift.stride(from: 0, to: faceCount, by: faceStep) {
                let base = f * indexCountPerFace
                var centroid = SIMD3<Float>.zero
                var normalAcc = SIMD3<Float>.zero
                for k in 0..<min(3, indexCountPerFace) {
                    let vi = Int(idxBuf[base + k])
                    let local = Self.loadFloat3(vBuf, index: vi, strideBytes: strideBytes)
                    let world4 = transform * SIMD4(local.x, local.y, local.z, 1)
                    centroid += SIMD3(world4.x, world4.y, world4.z)
                    let nLocal = Self.loadFloat3(nBuf, index: vi, strideBytes: nStride)
                    let nWorld = (transform * SIMD4(nLocal.x, nLocal.y, nLocal.z, 0))
                    normalAcc += SIMD3(nWorld.x, nWorld.y, nWorld.z)
                }
                centroid /= 3
                let nLen = simd_length(normalAcc)
                let n = nLen > 0.001 ? normalAcc / nLen : .zero
                // Mesh samples tend to be decent when classified; boost slightly.
                var conf: Float = 0.75
                if #available(iOS 14.0, *) {
                    // classification of first vertex face — optional
                    conf = 0.8
                }
                _ = grid.merge(worldPoint: centroid, normal: n, confidence: conf, timestamp: timestamp)

                // Corner heuristic: near-horizontal + near-vertical neighbors proxy via normal y.
                if abs(n.y) < 0.25 { cornerHits = min(cornerHits + 1, 64) }
            }

            // Keep a thinned raw mesh for export (cap size).
            if rawMeshVertices.count < 60_000 {
                let stepV = max(1, vCount / 2000)
                let baseIndex = UInt32(rawMeshVertices.count)
                var added = 0
                for vi in Swift.stride(from: 0, to: vCount, by: stepV) {
                    let local = Self.loadFloat3(vBuf, index: vi, strideBytes: strideBytes)
                    let world4 = transform * SIMD4(local.x, local.y, local.z, 1)
                    rawMeshVertices.append(SIMD3(world4.x, world4.y, world4.z))
                    added += 1
                }
                // Degenerate: we don't rebuild faces perfectly when thinning — grid export is primary.
                _ = baseIndex
                _ = added
            }
            lastMeshAnchorCount += 1
        }
    }

    /// Load packed xyz floats from ARMesh source buffers (stride may be > 12).
    private static func loadFloat3(_ buf: UnsafeMutableRawPointer, index: Int, strideBytes: Int) -> SIMD3<Float> {
        let p = buf.advanced(by: index * strideBytes).assumingMemoryBound(to: Float.self)
        return SIMD3(p[0], p[1], p[2])
    }

}

extension ScanEngine: ARSessionDelegate {
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            self.frameCounter += 1
            switch frame.camera.trackingState {
            case .normal:
                self.trackingQuality = min(1, self.trackingQuality + 0.02)
                self.trackingStateRU = "трекинг OK"
            case .limited(let reason):
                self.trackingQuality = max(0.2, self.trackingQuality - 0.05)
                self.trackingStateRU = "ограничен: \(String(describing: reason))"
            case .notAvailable:
                self.trackingQuality = 0.1
                self.trackingStateRU = "трекинг недоступен"
            }

            if self.frameCounter % 2 == 0 {
                self.ingestDepth(frame)
            }

            let isPrecision = self.precisionMode
            let hint = GuidanceEngine.hint(
                localConfidence: self.localConfidence,
                distanceMeters: self.distanceMeters,
                isPrecisionTarget: isPrecision && self.precisionPlanner.current != nil,
                trackingOK: self.trackingQuality > 0.35
            )
            self.guidance = hint

            if isPrecision && self.frameCounter % 15 == 0 {
                let r = self.precisionPlanner.updateProgress(grid: self.grid)
                self.precisionProgressPercent = r.progressPercent
                self.precisionAreaComplete = r.areaComplete
                if let t = self.precisionPlanner.current {
                    let idx = self.precisionPlanner.currentIndex + 1
                    self.currentPrecisionLabelRU = r.areaComplete && r.advanced
                        ? "ЗОНА ЗАВЕРШЕНА → следующая"
                        : String(format: "Зона %d/%d · %d%%", idx, max(self.precisionPlanner.targets.count, 1), r.progressPercent)
                }
            }

            if self.frameCounter % 10 == 0 {
                self.publishStats()
            }
        }
    }

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            self.ingestMeshAnchors(anchors, timestamp: Date().timeIntervalSince1970)
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            self.ingestMeshAnchors(anchors, timestamp: Date().timeIntervalSince1970)
        }
    }
}
