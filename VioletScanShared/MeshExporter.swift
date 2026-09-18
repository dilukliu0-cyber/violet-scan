import Foundation
import simd

public struct TriangleMesh: Sendable {
    public var vertices: [SIMD3<Float>]
    public var normals: [SIMD3<Float>]
    public var indices: [UInt32]

    public init(vertices: [SIMD3<Float>] = [], normals: [SIMD3<Float>] = [], indices: [UInt32] = []) {
        self.vertices = vertices
        self.normals = normals
        self.indices = indices
    }

    public var isEmpty: Bool { vertices.isEmpty || indices.isEmpty }
}

public enum MeshExporter {
    /// Build a simple point-splat mesh (quads/triangles) from confidence grid for MVP export.
    public static func meshFromGrid(_ grid: ConfidenceGrid, maxVertices: Int = 80_000) -> TriangleMesh {
        let samples = grid.allSamples()
        let cell = grid.cellSize
        var vertices: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        vertices.reserveCapacity(min(samples.count, maxVertices) * 4)
        let half = cell * 0.45
        for (i, (_, s)) in samples.enumerated() {
            if vertices.count / 4 >= maxVertices { break }
            let p = s.positionSIMD
            let n: SIMD3<Float>
            if simd_length(s.normalSIMD) > 0.1 {
                n = simd_normalize(s.normalSIMD)
            } else {
                n = SIMD3(0, 1, 0)
            }
            // Build a small billboard quad facing approximate normal.
            let up = abs(n.y) > 0.9 ? SIMD3<Float>(1, 0, 0) : SIMD3<Float>(0, 1, 0)
            let t = simd_normalize(simd_cross(up, n))
            let b = simd_normalize(simd_cross(n, t))
            let v0 = p + (-t - b) * half
            let v1 = p + ( t - b) * half
            let v2 = p + ( t + b) * half
            let v3 = p + (-t + b) * half
            let base = UInt32(vertices.count)
            vertices.append(contentsOf: [v0, v1, v2, v3])
            normals.append(contentsOf: [n, n, n, n])
            indices.append(contentsOf: [base, base+1, base+2, base, base+2, base+3])
            _ = i
        }
        return TriangleMesh(vertices: vertices, normals: normals, indices: indices)
    }

    public static func exportOBJ(_ mesh: TriangleMesh) -> String {
        var out = "# VIOLET SCAN OBJ\n# SCAN LONGER. GET BETTER\n"
        for v in mesh.vertices {
            out += String(format: "v %.6f %.6f %.6f\n", v.x, v.y, v.z)
        }
        for n in mesh.normals {
            out += String(format: "vn %.6f %.6f %.6f\n", n.x, n.y, n.z)
        }
        var i = 0
        while i + 2 < mesh.indices.count {
            let a = Int(mesh.indices[i]) + 1
            let b = Int(mesh.indices[i+1]) + 1
            let c = Int(mesh.indices[i+2]) + 1
            out += "f \(a)//\(a) \(b)//\(b) \(c)//\(c)\n"
            i += 3
        }
        return out
    }

    /// Minimal USDA ascii that SceneKit/RealityKit can often ingest as .usdz after zip — MVP writes .usda text.
    public static func exportUSDA(_ mesh: TriangleMesh) -> String {
        var points = ""
        for v in mesh.vertices {
            points += String(format: "(%f, %f, %f), ", v.x, v.y, v.z)
        }
        var faceCounts = ""
        var faceIndices = ""
        var i = 0
        var tris = 0
        while i + 2 < mesh.indices.count {
            faceCounts += "3, "
            faceIndices += "\(mesh.indices[i]), \(mesh.indices[i+1]), \(mesh.indices[i+2]), "
            i += 3
            tris += 1
        }
        return """
        #usda 1.0
        (
            defaultPrim = "VioletScanMesh"
            metersPerUnit = 1
            upAxis = "Y"
        )
        def Xform "VioletScanMesh" {
            def Mesh "Geometry" {
                int[] faceVertexCounts = [\(faceCounts)]
                int[] faceVertexIndices = [\(faceIndices)]
                point3f[] points = [\(points)]
                uniform token subdivisionScheme = "none"
            }
        }
        """
    }
}
