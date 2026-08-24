import AppKit
import OSLog
import SwiftData
import SwiftUI

@main
struct S4_ViewerApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
#if S4VIEWER_INTENT_TESTING
        // AppIntentsTesting launches the host app; keep it out of the user's desktop.
        NSApplication.shared.setActivationPolicy(.prohibited)
#endif
        containerResult = Result {
            let schema = Schema([ConnectionProfile.self])
#if DEBUG
            if DemoMode.isEnabled {
                return try DemoMode.makeContainer(schema: schema)
            }
#endif
            let configuration = ModelConfiguration(
                "S4Viewer",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        if case let .failure(error) = containerResult {
            Logger(subsystem: "ai.smartcrab.s4viewer", category: "startup")
                .error("Startup failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var body: some Scene {
#if S4VIEWER_INTENT_TESTING
        // Intent tests use the app service, not the window.
        Settings {
            EmptyView()
        }
#else
        WindowGroup {
            switch containerResult {
            case let .success(container):
                ContentView()
                    .modelContainer(container)
            case let .failure(error):
                StartupFailureView(message: error.localizedDescription)
            }
        }
        .defaultSize(width: 1400, height: 900)
#endif
    }
}

private struct StartupFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView(
            "Startup Failed",
            systemImage: "exclamationmark.triangle.fill",
            description: Text(message)
        )
        .frame(minWidth: 720, minHeight: 480)
        .padding()
    }
}
