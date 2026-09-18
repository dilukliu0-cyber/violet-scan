import SwiftUI

struct ReconstructionView: View {
    @EnvironmentObject var app: AppModel
    let projectId: UUID
    @State private var stage: ReconstructionStage = .loadFused
    @State private var fraction: Float = 0
    @State private var message = "Запуск…"
    @State private var finished = false
    @State private var outputs: [URL] = []
    @State private var errorText: String?

    var body: some View {
        ZStack {
            VioletTheme.deepBlack.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("ФИНАЛЬНАЯ РЕКОНСТРУКЦИЯ")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(VioletTheme.softWhite)

                ProgressView(value: Double(fraction))
                    .tint(VioletTheme.electricViolet)
                    .padding(.horizontal)

                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(VioletTheme.violetGlow)

                Text(stage.titleRU)
                    .foregroundColor(VioletTheme.electricViolet)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(VioletTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ReconstructionStage.allCases) { s in
                        HStack {
                            Image(systemName: icon(for: s))
                                .foregroundColor(color(for: s))
                            Text(s.titleRU)
                                .foregroundColor(VioletTheme.softWhite)
                            Spacer()
                        }
                        .font(.caption)
                    }
                }
                .padding(16)
                .glassPanel()
                .padding(.horizontal)

                if let errorText {
                    Text(errorText).foregroundColor(VioletTheme.redBad).font(.caption)
                }

                if finished {
                    Button("ОТКРЫТЬ РЕЗУЛЬТАТ") {
                        app.path.append(.result(projectId))
                    }
                    .buttonStyle(VioletPrimaryButtonStyle())
                    .padding(.horizontal, 24)

                    if !outputs.isEmpty {
                        Text(outputs.map(\.lastPathComponent).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundColor(VioletTheme.muted)
                            .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding(.top, 24)
        }
        .navigationBarHidden(true)
        .task { await run() }
    }

    private func icon(for s: ReconstructionStage) -> String {
        if s == stage && !finished { return "circle.fill" }
        let order = ReconstructionStage.allCases
        guard let si = order.firstIndex(of: s), let ci = order.firstIndex(of: stage) else { return "circle" }
        if finished || si < ci { return "checkmark.circle.fill" }
        return "circle"
    }

    private func color(for s: ReconstructionStage) -> Color {
        let order = ReconstructionStage.allCases
        guard let si = order.firstIndex(of: s), let ci = order.firstIndex(of: stage) else { return VioletTheme.muted }
        if finished || si < ci { return VioletTheme.greenOK }
        if si == ci { return VioletTheme.electricViolet }
        return VioletTheme.muted
    }

    @MainActor
    private func run() async {
        let grid: ConfidenceGrid
        if app.engine.grid.cellCount > 0 {
            grid = app.engine.grid
        } else {
            grid = ConfidenceGrid()
            let url = app.store.url(project: projectId, folder: .fused, file: "confidence_grid.json")
            if let data = try? Data(contentsOf: url) {
                try? grid.loadSnapshot(data)
            }
        }

        let pipeline = FinalReconstructionPipeline()
        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try pipeline.run(grid: grid, projectId: projectId) { prog in
                            DispatchQueue.main.async {
                                stage = prog.stage
                                fraction = prog.fraction
                                message = prog.messageRU
                                finished = prog.isFinished
                                outputs = prog.outputURLs
                            }
                        }
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        } catch {
            errorText = error.localizedDescription
        }
    }
}
