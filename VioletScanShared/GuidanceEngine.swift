import Foundation
import simd

public struct GuidanceHint: Sendable {
    public var color: GuidanceColor
    public var messageRU: String
    public var messageEN: String

    public init(color: GuidanceColor, messageRU: String, messageEN: String) {
        self.color = color
        self.messageRU = messageRU
        self.messageEN = messageEN
    }
}

/// Rule-based guidance from local confidence + camera distance to surface.
public enum GuidanceEngine {
    public static func hint(
        localConfidence: Float?,
        distanceMeters: Float?,
        isPrecisionTarget: Bool,
        trackingOK: Bool
    ) -> GuidanceHint {
        if !trackingOK {
            return GuidanceHint(
                color: .red,
                messageRU: "УДЕРЖИВАЙТЕ УСТРОЙСТВО РОВНО",
                messageEN: "HOLD DEVICE STEADY"
            )
        }
        if isPrecisionTarget {
            return GuidanceHint(
                color: .purple,
                messageRU: "ЦЕЛЬ ТОЧНОСТИ — СКАНИРУЙТЕ ЗОНУ",
                messageEN: "PRECISION TARGET — SCAN THIS AREA"
            )
        }
        if let d = distanceMeters {
            if d < 0.25 {
                return GuidanceHint(color: .yellow, messageRU: "ОТОЙДИТЕ НЕМНОГО", messageEN: "MOVE BACK A LITTLE")
            }
            if d > 2.5 {
                return GuidanceHint(color: .yellow, messageRU: "ПОДОЙДИТЕ БЛИЖЕ", messageEN: "MOVE CLOSER")
            }
        }
        guard let c = localConfidence else {
            return GuidanceHint(color: .red, messageRU: "НЕТ ДАННЫХ ГЛУБИНЫ", messageEN: "NO DEPTH DATA")
        }
        switch c {
        case 0.85...:
            return GuidanceHint(color: .green, messageRU: "ОТЛИЧНО — ПРОДОЛЖАЙТЕ", messageEN: "EXCELLENT — CONTINUE")
        case 0.55..<0.85:
            return GuidanceHint(color: .yellow, messageRU: "МЕДЛЕННЕЕ, БОЛЬШЕ УГЛОВ", messageEN: "SLOWER, MORE ANGLES")
        default:
            return GuidanceHint(color: .red, messageRU: "СЛАБАЯ ЗОНА — ПОВТОРИТЕ", messageEN: "WEAK AREA — RESCAN")
        }
    }

    public static func color(forConfidence c: Float) -> GuidanceColor {
        switch c {
        case 0.85...: return .green
        case 0.55..<0.85: return .yellow
        case 0..<0.55: return .red
        default: return .unknown
        }
    }
}
