import SwiftUI
import SwiftData

@main
struct ChaoticJellyApp: App {
    let modelContainer: ModelContainer
    @State private var serviceContainer: ServiceContainer?

    init() {
        do {
            let schema = Schema([Job.self, FileEntry.self])
            let config = ModelConfiguration(
                "ChaoticJelly",
                schema: schema,
                isStoredInMemoryOnly: false
            )
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = serviceContainer {
                    ContentView(container: container)
                } else {
                    ProgressView("Starting Chaotic Jelly...")
                        .frame(width: 300, height: 200)
                }
            }
            .task {
                if serviceContainer == nil {
                    let context = modelContainer.mainContext
                    let container = ServiceContainer(modelContext: context)
                    serviceContainer = container

                    // Recover interrupted jobs on startup
                    await container.jobManager.recoverInterruptedJobs()
                }
            }
        }
        .modelContainer(modelContainer)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 700)

        #if os(macOS)
        Settings {
            if let container = serviceContainer {
                SettingsView(container: container)
            }
        }
        #endif
    }
}
