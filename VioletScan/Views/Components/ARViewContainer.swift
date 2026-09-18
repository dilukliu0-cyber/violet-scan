import SwiftUI
import ARKit
import RealityKit
import Combine
import simd

struct ARViewContainer: UIViewRepresentable {
    let engine: ScanEngine

    func makeCoordinator() -> Coordinator {
        Coordinator(engine: engine)
    }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.session = engine.session
        view.renderOptions.insert(.disableMotionBlur)

        // Critical: without this, LiDAR mesh accumulates but is invisible on the live scan screen.
        view.debugOptions.insert(.showSceneUnderstanding)

        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.engine = engine
        if !uiView.debugOptions.contains(.showSceneUnderstanding) {
            uiView.debugOptions.insert(.showSceneUnderstanding)
        }
        context.coordinator.refreshOverlayIfNeeded()
    }

    @MainActor
    final class Coordinator {
        var engine: ScanEngine
        weak var arView: ARView?
        private var rootAnchor: AnchorEntity?
        private var cancellables = Set<AnyCancellable>()
        private var lastOverlayTick: Int = -1
        private var sphereMesh: MeshResource?

        init(engine: ScanEngine) {
            self.engine = engine
        }

        func attach(to view: ARView) {
            arView = view
            let root = AnchorEntity(world: .zero)
            view.scene.addAnchor(root)
            rootAnchor = root
            sphereMesh = MeshResource.generateSphere(radius: 0.02)

            engine.$overlayTick
                .receive(on: RunLoop.main)
                .sink { [weak self] tick in
                    self?.rebuildVoxelOverlay(tick: tick)
                }
                .store(in: &cancellables)

            rebuildVoxelOverlay(tick: engine.overlayTick)
        }

        func refreshOverlayIfNeeded() {
            if engine.overlayTick != lastOverlayTick {
                rebuildVoxelOverlay(tick: engine.overlayTick)
            }
        }

        private func rebuildVoxelOverlay(tick: Int) {
            guard tick != lastOverlayTick || (rootAnchor?.children.isEmpty ?? true) else { return }
            lastOverlayTick = tick
            guard let root = rootAnchor, let mesh = sphereMesh else { return }

            root.children.removeAll()
            let samples = engine.overlaySamples
            guard !samples.isEmpty else { return }

            let maxN = min(samples.count, 450)
            for i in 0..<maxN {
                let sample = samples[i]
                let color = confidenceUIColor(sample.confidence, locked: sample.isLocked)
                let material = UnlitMaterial(color: color)
                let entity = ModelEntity(mesh: mesh, materials: [material])
                entity.position = sample.position
                let scale: Float = sample.isLocked ? 1.35 : 1.0
                entity.scale = SIMD3(repeating: scale)
                root.addChild(entity)
            }
        }

        private func confidenceUIColor(_ c: Float, locked: Bool) -> UIColor {
            if locked {
                return UIColor(red: 0.20, green: 1.0, blue: 0.55, alpha: 1.0)
            }
            switch c {
            case 0.85...:
                return UIColor(red: 0.25, green: 0.95, blue: 0.50, alpha: 1.0)
            case 0.55..<0.85:
                return UIColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1.0)
            default:
                return UIColor(red: 1.0, green: 0.30, blue: 0.35, alpha: 1.0)
            }
        }
    }
}
