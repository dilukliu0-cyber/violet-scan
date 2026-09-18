import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        ZStack {
            VioletTheme.deepBlack.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("НАСТРОЙКИ")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(VioletTheme.softWhite)

                    Text("КАЧЕСТВО СКАНИРОВАНИЯ")
                        .font(.caption.bold())
                        .foregroundColor(VioletTheme.muted)

                    ForEach(ScanQualityMode.allCases) { mode in
                        Button {
                            app.qualityMode = mode
                            app.engine.configure(mode: mode)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.titleRU)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(String(format: "ячейка %.0f мм · lock ≥ %.0f%%", mode.cellSize * 1000, mode.lockThreshold * 100))
                                        .font(.caption)
                                        .foregroundColor(VioletTheme.muted)
                                }
                                Spacer()
                                if app.qualityMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(VioletTheme.electricViolet)
                                }
                            }
                            .padding(14)
                            .glassPanel(corner: 14)
                        }
                    }

                    storageWarning

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ФИЛОСОФИЯ")
                            .font(.caption.bold())
                            .foregroundColor(VioletTheme.muted)
                        Text("Повторное сканирование не должно портить хорошую геометрию. VIOLET SCAN накапливает лучшие сэмплы по ячейкам и блокирует поверхности с высокой уверенностью.")
                            .font(.subheadline)
                            .foregroundColor(VioletTheme.softWhite.opacity(0.9))
                    }
                    .padding(16)
                    .glassPanel()

                    Text("v0.1.0 · com.violetscan.app")
                        .font(.caption2)
                        .foregroundColor(VioletTheme.muted)
                }
                .padding(20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var storageWarning: some View {
        let gb = app.qualityMode.storageWarningGB
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: "externaldrive.fill.badge.exclamationmark")
                .foregroundColor(VioletTheme.yellowWarn)
            VStack(alignment: .leading, spacing: 4) {
                Text("ПРЕДУПРЕЖДЕНИЕ О ПАМЯТИ")
                    .font(.caption.bold())
                    .foregroundColor(VioletTheme.yellowWarn)
                Text(String(format: "Режим «%@» может занять ≈ %.1f+ ГБ на длинном скане (Raw + Passes + Fused). Следите за свободным местом.", app.qualityMode.titleRU, gb))
                    .font(.footnote)
                    .foregroundColor(VioletTheme.softWhite.opacity(0.85))
            }
        }
        .padding(14)
        .glassPanel()
    }
}
