import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ZStack {
            VioletTheme.deepBlack.ignoresSafeArea()
            RadialGradient(
                colors: [VioletTheme.electricViolet.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("VIOLET SCAN")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(VioletTheme.softWhite)
                        Text("SCAN LONGER. GET BETTER")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .tracking(1.5)
                            .foregroundColor(VioletTheme.violetGlow)
                    }
                    Spacer()
                    Button {
                        app.path.append(.settings)
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(VioletTheme.softWhite)
                            .padding(12)
                            .background(Circle().fill(VioletTheme.graphite))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                VStack(spacing: 14) {
                    Button {
                        app.startScan()
                    } label: {
                        Text("НАЧАТЬ СКАНИРОВАНИЕ")
                    }
                    .buttonStyle(VioletPrimaryButtonStyle())

                    HStack {
                        Label(app.qualityMode.titleRU, systemImage: "sparkles")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(VioletTheme.violetGlow)
                        Spacer()
                        Text(app.lidarOK ? "LiDAR OK" : "БЕЗ LiDAR")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(app.lidarOK ? VioletTheme.greenOK : VioletTheme.yellowWarn)
                    }
                }
                .padding(18)
                .glassPanel()
                .padding(.horizontal, 20)

                Text("НЕДАВНИЕ ПРОЕКТЫ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(VioletTheme.muted)
                    .padding(.horizontal, 22)

                if app.projects.isEmpty {
                    VStack(spacing: 8) {
                        Text("Пока пусто")
                            .foregroundColor(VioletTheme.muted)
                        Text("Первый проход накапливает геометрию.\nПовторное сканирование улучшает, не портит.")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundColor(VioletTheme.muted.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(28)
                    .glassPanel()
                    .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(app.projects) { p in
                                Button {
                                    app.path.append(.result(p.id))
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(p.name)
                                                .font(.headline)
                                                .foregroundColor(VioletTheme.softWhite)
                                            Text("\(p.qualityPercent)% · \(p.cellCount) яч. · \(p.passCount) проход.")
                                                .font(.caption)
                                                .foregroundColor(VioletTheme.muted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(VioletTheme.electricViolet)
                                    }
                                    .padding(16)
                                    .glassPanel(corner: 14)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer()
            }
        }
        .onAppear { app.reloadProjects() }
    }
}
