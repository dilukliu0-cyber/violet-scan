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

            // Live confidence tint so accumulation / quality state is visible on camera
            VioletTheme.guidance(engine.guidance.color)
                .opacity(0.14)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topHUD
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                Spacer(minLength: 8)

                guidanceBanner
                    .padding(.horizontal, 16)

                bottomBar
                    .padding(.top, 10)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Large always-visible progress HUD

    private var topHUD: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    engine.pause()
                    app.path.removeAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                }
                Spacer()
                Text(engine.surfaceChipRU)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(VioletTheme.softWhite)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
            }

            HStack(spacing: 10) {
                metricChip(
                    title: "ПОКРЫТИЕ",
                    value: "\(engine.coveragePercent)%",
                    progress: Double(engine.coveragePercent) / 100.0,
                    accent: VioletTheme.violetGlow
                )
                metricChip(
                    title: "КАЧЕСТВО",
                    value: "\(engine.quality.percent)%",
                    progress: Double(engine.quality.percent) / 100.0,
                    accent: VioletTheme.electricViolet
                )
            }

            HStack(spacing: 8) {
                miniStat(title: "ПРОХОД", value: "\(engine.passIndex + 1)")
                miniStat(title: "ЯЧЕЕК", value: "\(engine.cellCount)")
                miniStat(title: "LOCK", value: "\(engine.lockedCells)")
                if let d = engine.distanceMeters {
                    miniStat(title: "ДИСТ.", value: String(format: "%.1fм", d))
                } else {
                    miniStat(title: "ДИСТ.", value: "—")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(VioletTheme.electricViolet.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: VioletTheme.electricViolet.opacity(0.25), radius: 18, y: 4)
        )
    }

    private func metricChip(title: String, value: String, progress: Double, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundColor(VioletTheme.muted)
            Text(value)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent, accent.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(min(1, max(0, progress)))), height: 10)
                        .shadow(color: accent.opacity(0.6), radius: 6)
                }
            }
            .frame(height: 10)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VioletTheme.graphiteSoft.opacity(0.95))
        )
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundColor(VioletTheme.muted)
            Text(value)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
    }

    private var guidanceBanner: some View {
        let accent = VioletTheme.guidance(engine.guidance.color)
        return Text(engine.guidance.messageRU)
            .font(.system(size: 18, weight: .black, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(accent, lineWidth: 2.5)
                    )
                    .shadow(color: accent.opacity(0.55), radius: 16)
            )
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Secondary live readout — large enough to read while walking
            HStack(spacing: 6) {
                Image(systemName: engine.isRunning && !engine.isPaused ? "dot.radiowaves.left.and.right" : "pause.circle")
                    .foregroundColor(engine.isRunning && !engine.isPaused ? VioletTheme.greenOK : VioletTheme.yellowWarn)
                Text(engine.trackingStateRU.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "conf %.0f%%", engine.localConfidence * 100))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(VioletTheme.violetGlow)
            }

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
