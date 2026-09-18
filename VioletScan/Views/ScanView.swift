import SwiftUI

struct ScanView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        let eng = app.engine
        return ScanViewBody(engine: eng)
            .environmentObject(app)
    }
}

struct ScanViewBody: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var engine: ScanEngine

    var body: some View {
        ZStack {
            VioletTheme.deepBlack.ignoresSafeArea()
            ARViewContainer(engine: engine)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                guidanceChip
                bottomBar
            }
        }
        .navigationBarHidden(true)
    }

    private var topBar: some View {
        HStack {
            Button {
                engine.pause()
                app.path.removeAll()
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("ПОКРЫТИЕ \(engine.coveragePercent)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text("КАЧЕСТВО \(engine.quality.percent)%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(VioletTheme.violetGlow)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassPanel(corner: 12)
            Spacer()
            Text(engine.surfaceChipRU)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(VioletTheme.softWhite)
                .padding(8)
                .background(Capsule().fill(VioletTheme.graphite.opacity(0.85)))
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var guidanceChip: some View {
        Text(engine.guidance.messageRU)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(Capsule().stroke(VioletTheme.guidance(engine.guidance.color), lineWidth: 1.5))
                    .shadow(color: VioletTheme.guidance(engine.guidance.color).opacity(0.45), radius: 12)
            )
            .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                scanButton(engine.isPaused ? "ПРОДОЛЖ." : "ПАУЗА", icon: engine.isPaused ? "play.fill" : "pause.fill") {
                    if engine.isPaused { engine.resumePass() } else { engine.pause() }
                }
                scanButton("LOCK", icon: "lock.fill") { engine.lockGoodNow() }
                scanButton("PRECISION", icon: "scope") {
                    engine.finishPass()
                    engine.enablePrecisionPass()
                    app.path.append(.precision)
                }
                scanButton("FINISH", icon: "checkmark") {
                    Task { await finishAndSave() }
                }
            }
            Text("Проход \(engine.passIndex + 1) · ячеек \(engine.cellCount) · lock \(engine.lockedCells)")
                .font(.caption2)
                .foregroundColor(VioletTheme.muted)
        }
        .padding(14)
        .glassPanel(corner: 20)
        .padding(.horizontal, 12)
        .padding(.bottom, 18)
    }

    private func scanButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(VioletTheme.graphiteSoft))
        }
    }

    @MainActor
    private func finishAndSave() async {
        engine.finishPass()
        _ = AutoProtect.lockHighConfidence(in: engine.grid)
        let id = UUID()
        let name = "Скан " + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        do {
            try app.store.ensureLayout(for: id)
            try app.store.writeFusedGrid(engine.grid, project: id)
            try app.store.writePassSnapshot(engine.grid, project: id, passIndex: engine.passIndex)
            let mesh = engine.exportAccumulatedMesh()
            let built = mesh.isEmpty ? MeshExporter.meshFromGrid(engine.grid) : mesh
            let obj = MeshExporter.exportOBJ(built)
            try app.store.writeRawMeshOBJ(obj, project: id, stamp: "final")
            try obj.write(
                to: app.store.url(project: id, folder: .mesh, file: "model.obj"),
                atomically: true,
                encoding: .utf8
            )
            let meta = ScanProjectMeta(
                id: id,
                name: name,
                qualityMode: app.qualityMode,
                qualityPercent: engine.quality.percent,
                cellCount: engine.cellCount,
                passCount: max(1, engine.passIndex)
            )
            try app.store.upsert(meta)
            app.reloadProjects()
            app.path.append(.reconstruction(id))
        } catch {
            app.path.append(.result(id))
        }
    }
}
