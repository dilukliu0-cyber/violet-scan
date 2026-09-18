import Foundation

public struct ScanProjectMeta: Codable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var qualityMode: ScanQualityMode
    public var qualityPercent: Int
    public var cellCount: Int
    public var passCount: Int

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        qualityMode: ScanQualityMode = .maxQuality,
        qualityPercent: Int = 0,
        cellCount: Int = 0,
        passCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.qualityMode = qualityMode
        self.qualityPercent = qualityPercent
        self.cellCount = cellCount
        self.passCount = passCount
    }
}

/// Disk layout: Raw / Passes / Fused / Mesh / Texture / Final — preserve raw when possible.
public final class ProjectStore {
    public static let shared = ProjectStore()

    public let rootURL: URL
    private let fm = FileManager.default
    private let metaName = "projects.json"

    public init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.rootURL = docs.appendingPathComponent("VioletScanProjects", isDirectory: true)
        }
        try? fm.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    public func listProjects() -> [ScanProjectMeta] {
        let url = rootURL.appendingPathComponent(metaName)
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([ScanProjectMeta].self, from: data) else {
            return []
        }
        return list.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func saveMeta(_ list: [ScanProjectMeta]) throws {
        let url = rootURL.appendingPathComponent(metaName)
        let data = try JSONEncoder().encode(list)
        try data.write(to: url, options: .atomic)
    }

    public func upsert(_ meta: ScanProjectMeta) throws {
        var list = listProjects()
        if let i = list.firstIndex(where: { $0.id == meta.id }) {
            list[i] = meta
        } else {
            list.insert(meta, at: 0)
        }
        try saveMeta(list)
    }

    public func delete(id: UUID) throws {
        var list = listProjects().filter { $0.id != id }
        try saveMeta(list)
        let dir = projectDir(id: id)
        try? fm.removeItem(at: dir)
    }

    public func projectDir(id: UUID) -> URL {
        rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    public enum Folder: String, CaseIterable {
        case raw = "Raw"
        case passes = "Passes"
        case fused = "Fused"
        case mesh = "Mesh"
        case texture = "Texture"
        case final = "Final"
    }

    @discardableResult
    public func ensureLayout(for id: UUID) throws -> URL {
        let base = projectDir(id: id)
        for f in Folder.allCases {
            try fm.createDirectory(at: base.appendingPathComponent(f.rawValue, isDirectory: true), withIntermediateDirectories: true)
        }
        return base
    }

    public func url(project id: UUID, folder: Folder, file: String) -> URL {
        projectDir(id: id).appendingPathComponent(folder.rawValue).appendingPathComponent(file)
    }

    public func writeFusedGrid(_ grid: ConfidenceGrid, project id: UUID) throws {
        try ensureLayout(for: id)
        let data = try grid.encodeSnapshot()
        try data.write(to: url(project: id, folder: .fused, file: "confidence_grid.json"), options: .atomic)
    }

    public func writePassSnapshot(_ grid: ConfidenceGrid, project id: UUID, passIndex: Int) throws {
        try ensureLayout(for: id)
        let data = try grid.encodeSnapshot()
        let name = String(format: "pass_%03d.json", passIndex)
        try data.write(to: url(project: id, folder: .passes, file: name), options: .atomic)
    }

    /// Preserve a raw AR mesh dump (OBJ bytes) without overwriting fused.
    public func writeRawMeshOBJ(_ obj: String, project id: UUID, stamp: String) throws {
        try ensureLayout(for: id)
        let path = url(project: id, folder: .raw, file: "mesh_\(stamp).obj")
        try obj.write(to: path, atomically: true, encoding: .utf8)
    }
}
