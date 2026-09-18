import SwiftUI

@main
struct VioletScanApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var qualityMode: ScanQualityMode = .maxQuality
    @Published var projects: [ScanProjectMeta] = []
    @Published var lidarChecked = false
    @Published var lidarOK = false
    @Published var showLiDARAlert = false

    let engine = ScanEngine()
    let store = ProjectStore.shared

    enum AppRoute: Hashable {
        case scan
        case precision
        case result(UUID)
        case settings
        case reconstruction(UUID)
    }

    init() {
        reloadProjects()
        checkLiDAR()
    }

    func reloadProjects() {
        projects = store.listProjects()
    }

    func checkLiDAR() {
        engine.refreshLiDARSupport()
        lidarOK = engine.lidarAvailable
        lidarChecked = true
        // On Simulator / non-LiDAR: still allow UI exploration but warn.
        if !lidarOK {
            showLiDARAlert = true
        }
    }

    func startScan() {
        engine.startNewScan(mode: qualityMode)
        path.append(.scan)
    }
}

struct RootView: View {
    @EnvironmentObject var app: AppModel

    var body: some View {
        NavigationStack(path: $app.path) {
            HomeView()
                .navigationDestination(for: AppModel.AppRoute.self) { route in
                    switch route {
                    case .scan:
                        ScanView()
                    case .precision:
                        PrecisionPassView()
                    case .result(let id):
                        ResultViewerView(projectId: id)
                    case .settings:
                        SettingsView()
                    case .reconstruction(let id):
                        ReconstructionView(projectId: id)
                    }
                }
        }
        .alert("LiDAR", isPresented: $app.showLiDARAlert) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text("Для полного сканирования нужен iPhone/iPad с LiDAR (Pro). На этом устройстве UI доступен, но глубина/меш могут быть недоступны.")
        }
    }
}
