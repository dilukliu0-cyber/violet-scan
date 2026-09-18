import SwiftUI
import SceneKit

struct ResultViewerView: View {
    @EnvironmentObject var app: AppModel
    let projectId: UUID
    @State private var mode: ViewMode = .mesh
    @State private var exportNote = ""

    enum ViewMode: String, CaseIterable, Identifiable {
        case mesh, wireframe, texture
        var id: String { rawValue }
        var titleRU: String {
            switch self {
            case .mesh: return "МЕШ"
            case .wireframe: return "КАРКАС"
            case .texture: return "ТЕКСТУРА"
            }
        }
    }

    var body: some View {
        ZStack {
            VioletTheme.deepBlack.ignoresSafeArea()
            VStack(spacing: 0) {
                MeshPreviewRepresentable(projectId: projectId, mode: mode)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VioletTheme.graphite)

                VStack(spacing: 14) {
                    Picker("mode", selection: $mode) {
                        ForEach(ViewMode.allCases) { m in
                            Text(m.titleRU).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    if mode == .texture {
                        Text("Текстура: stub — захват UV/атласа в след. итерации")
                            .font(.caption)
                            .foregroundColor(VioletTheme.muted)
                    }

                    Text("Экспорт")
                        .font(.caption.bold())
                        .foregroundColor(VioletTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(ExportFormat.allCases) { fmt in
                            Button(fmt.title) {
                                exportNote = fmt.isImplemented
                                    ? "\(fmt.title): файл в Mesh/Final проекта"
                                    : "\(fmt.title): скоро (stub)"
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(fmt.isImplemented ? .white : VioletTheme.muted)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(fmt.isImplemented ? VioletTheme.electricViolet.opacity(0.55) : VioletTheme.graphiteSoft)
                            )
                        }
                    }

                    if !exportNote.isEmpty {
                        Text(exportNote).font(.caption2).foregroundColor(VioletTheme.violetGlow)
                    }

                    Button("ФИНАЛЬНАЯ РЕКОНСТРУКЦИЯ") {
                        app.path.append(.reconstruction(projectId))
                    }
                    .buttonStyle(VioletPrimaryButtonStyle())
                }
                .padding(16)
                .glassPanel(corner: 0)
            }
        }
        .navigationTitle("Результат")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MeshPreviewRepresentable: UIViewRepresentable {
    let projectId: UUID
    var mode: ResultViewerView.ViewMode

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1)
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = true
        v.scene = buildScene()
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if let node = uiView.scene?.rootNode.childNode(withName: "mesh", recursively: false) {
            node.geometry?.firstMaterial?.fillMode = mode == .wireframe ? .lines : .fill
            node.geometry?.firstMaterial?.diffuse.contents = mode == .texture
                ? UIColor(red: 0.56, green: 0.27, blue: 1, alpha: 1)
                : UIColor(white: 0.85, alpha: 1)
        }
    }

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        let url = ProjectStore.shared.url(project: projectId, folder: .mesh, file: "model.obj")
        if FileManager.default.fileExists(atPath: url.path),
           let model = try? SCNScene(url: url, options: nil) {
            for c in model.rootNode.childNodes {
                c.name = "mesh"
                scene.rootNode.addChildNode(c)
            }
        } else {
            let box = SCNBox(width: 0.4, height: 0.3, length: 0.5, chamferRadius: 0.01)
            box.firstMaterial?.diffuse.contents = UIColor(red: 0.56, green: 0.27, blue: 1, alpha: 0.85)
            let node = SCNNode(geometry: box)
            node.name = "mesh"
            scene.rootNode.addChildNode(node)
        }
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(0.6, 0.5, 1.2)
        cam.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(cam)
        return scene
    }
}
