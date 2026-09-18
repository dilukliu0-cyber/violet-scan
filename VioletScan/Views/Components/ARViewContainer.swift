import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    let engine: ScanEngine

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.automaticallyConfigureSession = false
        view.session = engine.session
        // Soft coaching / debug options off for premium look.
        view.renderOptions.insert(.disableMotionBlur)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
