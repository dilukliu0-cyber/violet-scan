import Foundation

/// Freeze cells above confidence threshold so later passes cannot degrade them.
enum AutoProtect {
    @discardableResult
    static func lockHighConfidence(in grid: ConfidenceGrid, threshold: Float? = nil) -> Int {
        grid.lockCells(above: threshold)
    }
}

/// Product alias.
typealias LockGoodData = AutoProtect
