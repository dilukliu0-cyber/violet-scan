import SwiftUI

struct PrecisionPassView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        PrecisionPassBody(engine: app.engine)
            .environmentObject(app)
    }
}

struct PrecisionPassBody: View {
    @EnvironmentObject var app: AppModel
    @ObservedObject var engine: ScanEngine

    var body: some View {
        ZStack {
            VioletTheme.deepBlack.ignoresSafeArea()
            ARViewContainer(engine: engine)
                .ignoresSafeArea()
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(VioletTheme.electricViolet.opacity(0.55), lineWidth: 3)
                        .shadow(color: VioletTheme.electricViolet.opacity(0.6), radius: 20)
                        .padding(8)
                        .allowsHitTesting(false)
                )

            VStack(spacing: 12) {
                Text("PRECISION PASS")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundColor(VioletTheme.violetGlow)
                    .padding(.top, 16)

                Text(engine.currentPrecisionLabelRU)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassPanel(corner: 12)

                progressRing

                if engine.precisionAreaComplete {
                    Text("ЗОНА ЗАВЕРШЕНА")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(VioletTheme.greenOK)
                        .padding(10)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                }

                Spacer()

                targetList

                HStack {
                    Button("НАЗАД К СКАНУ") {
                        app.path.removeAll { route in
                            if case .precision = route { return true }
                            return false
                        }
                    }
                    .buttonStyle(VioletGhostButtonStyle())
                    Spacer()
                    Button("ДАЛЕЕ / FINISH") {
                        Task { await finish() }
                    }
                    .buttonStyle(VioletPrimaryButtonStyle())
                    .frame(maxWidth: 180)
                }
                .padding(16)
            }
        }
        .navigationBarHidden(true)
    }

    private var progressRing: some View {
        let p = Double(engine.precisionProgressPercent) / 100.0
        return ZStack {
            Circle()
                .stroke(VioletTheme.graphite, lineWidth: 10)
            Circle()
                .trim(from: 0, to: p)
                .stroke(
                    AngularGradient(colors: [VioletTheme.electricViolet, VioletTheme.violetGlow], center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(engine.precisionProgressPercent)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: 120, height: 120)
        .padding()
    }

    private var targetList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("СЛАБЫЕ ЗОНЫ")
                .font(.caption.weight(.bold))
                .foregroundColor(VioletTheme.muted)
            ScrollView {
                ForEach(Array(engine.precisionPlanner.targets.enumerated()), id: \.element.id) { idx, t in
                    HStack {
                        Circle()
                            .fill(idx == engine.precisionPlanner.currentIndex ? VioletTheme.electricViolet : VioletTheme.graphiteSoft)
                            .frame(width: 10, height: 10)
                        Text(String(format: "Зона %d · conf %.0f%%", idx + 1, t.meanConfidence * 100))
                            .foregroundColor(.white)
                            .font(.subheadline)
                        Spacer()
                        if t.isComplete {
                            Text("OK").foregroundColor(VioletTheme.greenOK).font(.caption.bold())
                        } else if idx == engine.precisionPlanner.currentIndex {
                            Text("\(Int(t.progress * 100))%").foregroundColor(VioletTheme.violetGlow).font(.caption.bold())
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(idx == engine.precisionPlanner.currentIndex ? VioletTheme.electricViolet.opacity(0.18) : VioletTheme.graphite.opacity(0.5))
                    )
                }
            }
            .frame(maxHeight: 160)
        }
        .padding(14)
        .glassPanel()
        .padding(.horizontal, 16)
    }

    @MainActor
    private func finish() async {
        engine.finishPass()
        let id = UUID()
        let name = "Precision " + DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
        do {
            try app.store.ensureLayout(for: id)
            try app.store.writeFusedGrid(engine.grid, project: id)
            let obj = MeshExporter.exportOBJ(MeshExporter.meshFromGrid(engine.grid))
            try obj.write(to: app.store.url(project: id, folder: .mesh, file: "model.obj"), atomically: true, encoding: .utf8)
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
