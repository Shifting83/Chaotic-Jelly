import SwiftUI
import SwiftData

@main
struct ChaoticJellyApp: App {
    let modelContainer: ModelContainer
    @State private var serviceContainer: ServiceContainer?
    @State private var showUpdateAlert = false
    @State private var showWizard = false

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

                    // Show wizard on first run
                    if !UserDefaults.standard.bool(forKey: "hasCompletedFirstRun") {
                        showWizard = true
                    }

                    // Recover interrupted jobs on startup
                    await container.jobManager.recoverInterruptedJobs()

                    // Check for updates
                    await container.updateService.checkIfNeeded()
                    if container.updateService.updateAvailable {
                        showUpdateAlert = true
                    }
                }
            }
            .sheet(isPresented: $showWizard) {
                if let container = serviceContainer {
                    FirstRunWizardView(
                        container: container,
                        onComplete: { showWizard = false },
                        onStartScan: { showWizard = false }
                    )
                    .interactiveDismissDisabled()
                }
            }
            .alert("Update Available",
                   isPresented: $showUpdateAlert,
                   presenting: serviceContainer?.updateService.latestRelease
            ) { release in
                if release.assets.contains(where: { $0.name.hasSuffix(".dmg") }) {
                    Button("Install Now") {
                        Task {
                            await serviceContainer?.updateService.installUpdate()
                        }
                    }
                    Button("Download Manually") {
                        serviceContainer?.updateService.downloadDMG()
                    }
                }
                Button("Later", role: .cancel) {}
            } message: { release in
                Text("Chaotic Jelly \(release.tagName) is available. You're currently running v\(Constants.appVersion).")
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
