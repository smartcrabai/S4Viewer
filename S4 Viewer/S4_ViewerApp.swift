import SwiftData
import SwiftUI

@main
struct S4_ViewerApp: App {
    private let containerResult: Result<ModelContainer, Error>

    init() {
        containerResult = Result {
            let schema = Schema([ConnectionProfile.self])
            let configuration = ModelConfiguration(
                "S4Viewer",
                schema: schema,
                cloudKitDatabase: .automatic
            )
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    var body: some Scene {
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
