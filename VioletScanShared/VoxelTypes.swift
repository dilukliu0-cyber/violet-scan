import Foundation
import simd

/// Codable XYZ without extending SIMD3 (avoids duplicate Codable on newer SDKs).
public struct Vec3: Codable, Sendable, Hashable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(_ v: SIMD3<Float>) {
        self.x = v.x; self.y = v.y; self.z = v.z
    }

    public init(x: Float, y: Float, z: Float) {
        self.x = x; self.y = y; self.z = z
    }

    public var simd: SIMD3<Float> { SIMD3(x, y, z) }
}

/// Discrete cell address in world space (meters quantized by cellSize).
public struct VoxelKey: Hashable, Codable, Sendable {
    public var x: Int16
    public var y: Int16
    public var z: Int16

    public init(x: Int16, y: Int16, z: Int16) {
        self.x = x
        self.y = y
        self.z = z
    }

    public init(world point: SIMD3<Float>, cellSize: Float) {
        let inv = 1.0 / max(cellSize, 0.001)
        self.x = Int16(clamping: Int((point.x * inv).rounded(.down)))
        self.y = Int16(clamping: Int((point.y * inv).rounded(.down)))
        self.z = Int16(clamping: Int((point.z * inv).rounded(.down)))
    }

    public func center(cellSize: Float) -> SIMD3<Float> {
        SIMD3(
            (Float(x) + 0.5) * cellSize,
            (Float(y) + 0.5) * cellSize,
            (Float(z) + 0.5) * cellSize
        )
    }
}

/// Best known sample for one spatial cell.
public struct VoxelSample: Codable, Sendable {
    public var position: Vec3
    public var normal: Vec3
    public var confidence: Float
    public var observationCount: UInt16
    public var isLocked: Bool
    public var lastUpdated: TimeInterval

    public var positionSIMD: SIMD3<Float> { position.simd }
    public var normalSIMD: SIMD3<Float> { normal.simd }

    public init(
        position: SIMD3<Float>,
        normal: SIMD3<Float> = .zero,
        confidence: Float,
        observationCount: UInt16 = 1,
        isLocked: Bool = false,
        lastUpdated: TimeInterval = 0
    ) {
        self.position = Vec3(position)
        self.normal = Vec3(normal)
        self.confidence = confidence
        self.observationCount = observationCount
        self.isLocked = isLocked
        self.lastUpdated = lastUpdated
    }
}

public enum MergeDecision: String, Sendable {
    case keepExisting
    case improve
    case addNew
    case skippedLocked
}

public enum ScanQualityMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case fast
    case balanced
    case high
    case maxQuality

    public var id: String { rawValue }

    public var titleRU: String {
        switch self {
        case .fast: return "БЫСТРО"
        case .balanced: return "БАЛАНС"
        case .high: return "ВЫСОКОЕ"
        case .maxQuality: return "МАКС. КАЧЕСТВО"
        }
    }

    public var cellSize: Float {
        switch self {
        case .fast: return 0.08
        case .balanced: return 0.05
        case .high: return 0.035
        case .maxQuality: return 0.025
        }
    }

    public var lockThreshold: Float {
        switch self {
        case .fast: return 0.72
        case .balanced: return 0.78
        case .high: return 0.85
        case .maxQuality: return 0.90
        }
    }

    public var storageWarningGB: Double {
        switch self {
        case .fast: return 0.4
        case .balanced: return 0.8
        case .high: return 1.5
        case .maxQuality: return 3.0
        }
    }
}

public enum GuidanceColor: String, Sendable {
    case green
    case yellow
    case red
    case purple
    case unknown
}

public enum HoleSizeClass: String, Codable, Sendable {
    case none
    case small
    case medium
    case large
}

public enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case obj
    case usdz
    case ply
    case stl
    case glb

    public var id: String { rawValue }

    public var title: String { rawValue.uppercased() }

    public var isImplemented: Bool {
        switch self {
        case .obj, .usdz: return true
        case .ply, .stl, .glb: return false
        }
    }
}
