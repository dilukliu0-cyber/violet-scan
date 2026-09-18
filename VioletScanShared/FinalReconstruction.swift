import Foundation

public enum ReconstructionStage: String, CaseIterable, Identifiable, Sendable {
    case loadFused
    case cleanNoise
    case fillSmallHoles
    case buildMesh
    case exportOBJ
    case exportUSDZ
    case writeFinal

    public var id: String { rawValue }

    public var titleRU: String {
        switch self {
        case .loadFused: return "Загрузка fused-сетки"
        case .cleanNoise: return "Очистка шума"
        case .fillSmallHoles: return "Малые отверстия"
        case .buildMesh: return "Построение меша"
        case .exportOBJ: return "Экспорт OBJ"
        case .exportUSDZ: return "Экспорт USDZ/USDA"
        case .writeFinal: return "Запись Final"
        }
    }
}

public struct ReconstructionProgress: Sendable {
    public var stage: ReconstructionStage
    public var fraction: Float
    public var messageRU: String
    public var isFinished: Bool
    public var outputURLs: [URL]
}

/// Staged reconstruction pipeline UI driver. Advanced plane-fitting / Metal recon = TODO.
public final class FinalReconstructionPipeline {
    public init() {}

    /// Runs simplified pipeline synchronously with progress callbacks.
    public func run(
        grid: ConfidenceGrid,
        projectId: UUID,
        store: ProjectStore = .shared,
        onProgress: @escaping (ReconstructionProgress) -> Void
    ) throws {
        try store.ensureLayout(for: projectId)
        var outputs: [URL] = []

        func report(_ stage: ReconstructionStage, _ f: Float, _ msg: String, done: Bool = false) {
            onProgress(ReconstructionProgress(stage: stage, fraction: f, messageRU: msg, isFinished: done, outputURLs: outputs))
        }

        report(.loadFused, 0.05, "Чтение confidence grid…")
        try store.writeFusedGrid(grid, project: projectId)

        report(.cleanNoise, 0.2, "Фильтрация слабых незаблокированных ячеек (эвристика)…")
        // MVP: we do not delete locked/high-conf; weak unlocked stay for precision.
        // TODO: Metal/CPU plane-fitting outlier rejection.

        report(.fillSmallHoles, 0.35, "Классификация отверстий (крупные не заполняем)…")
        let holes = HoleDetector().detect(in: grid, cellSize: grid.cellSize)
        let _ = HoleDetector().fillable(holes)
        // TODO: actual small-hole fill via local RBF / Poisson.

        report(.buildMesh, 0.55, "Сборка меша из вокселей…")
        let mesh = MeshExporter.meshFromGrid(grid)

        report(.exportOBJ, 0.7, "Запись OBJ…")
        let obj = MeshExporter.exportOBJ(mesh)
        let objURL = store.url(project: projectId, folder: .mesh, file: "model.obj")
        try obj.write(to: objURL, atomically: true, encoding: .utf8)
        outputs.append(objURL)

        report(.exportUSDZ, 0.85, "Запись USDA (USDZ-совместимый текст)…")
        let usda = MeshExporter.exportUSDA(mesh)
        let usdaURL = store.url(project: projectId, folder: .mesh, file: "model.usda")
        try usda.write(to: usdaURL, atomically: true, encoding: .utf8)
        outputs.append(usdaURL)
        // TODO: package real .usdz via ModelIO / RealityKit on device.

        report(.writeFinal, 0.95, "Копирование в Final…")
        let finalOBJ = store.url(project: projectId, folder: .final, file: "VioletScan.obj")
        try? FileManager.default.removeItem(at: finalOBJ)
        try FileManager.default.copyItem(at: objURL, to: finalOBJ)
        outputs.append(finalOBJ)

        report(.writeFinal, 1.0, "Готово", done: true)
    }
}
