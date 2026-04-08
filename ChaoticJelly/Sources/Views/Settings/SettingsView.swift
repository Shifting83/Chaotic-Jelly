import SwiftUI
import AppKit

struct SettingsView: View {
    let container: ServiceContainer
    @State private var selectedTab = SettingsTab.language

    enum SettingsTab: String, CaseIterable {
        case language = "Language"
        case processing = "Processing"
        case jellyfin = "Jellyfin"
        case tools = "Tools"
        case cache = "Cache"
        case arr = "Arr"
        case updates = "Updates"

        var systemImage: String {
            switch self {
            case .language: return "globe"
            case .processing: return "gearshape.2"
            case .jellyfin: return "play.rectangle"
            case .tools: return "wrench.and.screwdriver"
            case .cache: return "externaldrive"
            case .arr: return "antenna.radiowaves.left.and.right"
            case .updates: return "arrow.triangle.2.circlepath"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            LanguageSettingsView(settings: container.settings)
                .tabItem { Label("Language", systemImage: "globe") }
                .tag(SettingsTab.language)

            ProcessingSettingsView(settings: container.settings)
                .tabItem { Label("Processing", systemImage: "gearshape.2") }
                .tag(SettingsTab.processing)

            JellyfinSettingsView(settings: container.settings)
                .tabItem { Label("Jellyfin", systemImage: "play.rectangle") }
                .tag(SettingsTab.jellyfin)

            ToolSettingsView(settings: container.settings, toolLocator: container.toolLocator)
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
                .tag(SettingsTab.tools)

            CacheSettingsView(settings: container.settings, cacheManager: container.cacheManager)
                .tabItem { Label("Cache", systemImage: "externaldrive") }
                .tag(SettingsTab.cache)

            ArrSettingsView(settings: container.settings, arrService: container.arrService)
                .tabItem { Label("Arr", systemImage: "antenna.radiowaves.left.and.right") }
                .tag(SettingsTab.arr)

            UpdateSettingsView(settings: container.settings, updateService: container.updateService)
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                .tag(SettingsTab.updates)
        }
        .frame(minWidth: 550)
    }
}

// MARK: - Language Settings

struct LanguageSettingsView: View {
    @Bindable var settings: AppSettings
    @State private var newLanguage = ""

    var body: some View {
        Form {
            Section("Keep Languages") {
                ForEach(settings.keepLanguages, id: \.self) { lang in
                    HStack {
                        Text(LanguageUtils.displayName(for: lang))
                        Text("(\(lang))")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if settings.keepLanguages.count > 1 {
                            Button(role: .destructive) {
                                settings.keepLanguages.removeAll { $0 == lang }
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    TextField("Language code (e.g., spa, fre)", text: $newLanguage)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let code = newLanguage.trimmingCharacters(in: .whitespaces).lowercased()
                        if !code.isEmpty && !settings.keepLanguages.contains(code) {
                            settings.keepLanguages.append(code)
                            newLanguage = ""
                        }
                    }
                    .disabled(newLanguage.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Removal Options") {
                Toggle("Remove non-kept subtitles", isOn: $settings.removeSubtitles)
                Toggle("Remove non-kept audio tracks", isOn: $settings.removeAudio)
            }

            Section("Preservation") {
                Toggle("Preserve forced subtitles", isOn: $settings.preserveForced)
                Toggle("Preserve SDH / hearing-impaired subtitles", isOn: $settings.preserveSDH)
                Toggle("Preserve commentary tracks", isOn: $settings.preserveCommentary)
            }

            Section("Safety") {
                Toggle("Conservative mode (keep ambiguous streams)", isOn: $settings.conservativeMode)
                Text("When enabled, streams with missing or unreliable language tags will be kept rather than removed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Processing Settings

struct ProcessingSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Backup") {
                Toggle("Create backup before modifying", isOn: $settings.createBackup)
                if settings.createBackup {
                    Stepper("Retention: \(settings.backupRetentionDays) days", value: $settings.backupRetentionDays, in: 1...90)
                }
            }

            Section("Overwrite Behavior") {
                Picker("When replacing files", selection: $settings.overwriteBehaviorRaw) {
                    ForEach(OverwriteBehavior.allCases, id: \.self) { behavior in
                        Text(behavior.displayName).tag(behavior.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("Concurrency") {
                Stepper("Max concurrent files: \(settings.maxConcurrentFiles)", value: $settings.maxConcurrentFiles, in: 1...8)
                Text("Higher values process faster but use more disk space and CPU.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Jellyfin Settings

struct JellyfinSettingsView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Enable Jellyfin optimization", isOn: $settings.optimizeForJellyfin)
            }

            if settings.optimizeForJellyfin {
                Section("Target Profile") {
                    Picker("Profile", selection: $settings.jellyfinProfileRaw) {
                        ForEach(JellyfinProfile.allCases, id: \.rawValue) { profile in
                            Text(profile.displayName).tag(profile.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Profile Details") {
                    let profile = settings.jellyfinProfile
                    LabeledContent("Video Codecs") {
                        Text(profile.targetVideoCodecs.isEmpty ? "Any" : profile.targetVideoCodecs.joined(separator: ", "))
                    }
                    LabeledContent("Audio Codecs") {
                        Text(profile.targetAudioCodecs.isEmpty ? "Any" : profile.targetAudioCodecs.joined(separator: ", "))
                    }
                    LabeledContent("Containers") {
                        Text(profile.targetContainers.joined(separator: ", "))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Tool Settings

struct ToolSettingsView: View {
    @Bindable var settings: AppSettings
    let toolLocator: ToolLocator
    @State private var toolStatuses: [ToolStatus] = []

    var body: some View {
        Form {
            Section("Tool Paths (leave blank to use bundled/auto-detected)") {
                LabeledContent("FFmpeg") {
                    TextField("Path", text: $settings.ffmpegPath)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("FFprobe") {
                    TextField("Path", text: $settings.ffprobePath)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("MKVmerge") {
                    TextField("Path (optional)", text: $settings.mkvmergePath)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Section("Status") {
                ForEach(toolStatuses) { status in
                    HStack {
                        Image(systemName: status.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(status.isAvailable ? Color.cjSuccess : Color.cjError)
                        Text(status.tool.displayName)
                        Spacer()
                        Text(status.resolvedPath ?? "Not found")
                            .font(.caption)
                            .foregroundStyle(status.isAvailable ? Color.cjTextSecondary : Color.cjError)
                    }
                }

                Button("Refresh") {
                    Task { await refreshTools() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task { await refreshTools() }
    }

    private func refreshTools() async {
        await toolLocator.invalidateCache()
        var statuses: [ToolStatus] = []
        for tool in ToolType.allCases {
            let available = await toolLocator.isAvailable(tool)
            let path = try? await toolLocator.path(for: tool)
            statuses.append(ToolStatus(tool: tool, isAvailable: available, resolvedPath: path, version: nil))
        }
        toolStatuses = statuses
    }
}

// MARK: - Cache Settings

struct CacheSettingsView: View {
    @Bindable var settings: AppSettings
    let cacheManager: CacheManager
    @State private var cacheUsage: Int64 = 0

    var body: some View {
        Form {
            Section("Cache Location") {
                LabeledContent("Path") {
                    HStack {
                        Text(settings.cachePath.path)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Button("Change...") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                settings.cachePath = url
                            }
                        }
                    }
                }
            }

            Section("Limits") {
                Stepper("Max cache size: \(settings.maxCacheSizeGB) GB", value: $settings.maxCacheSizeGB, in: 5...500, step: 5)
            }

            Section("Usage") {
                LabeledContent("Current usage") {
                    Text(cacheUsage.formattedFileSize)
                }

                Button("Clean Cache") {
                    Task {
                        await cacheManager.cleanOrphanedCaches(activeJobIDs: [])
                        cacheUsage = await cacheManager.currentCacheUsage()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            cacheUsage = await cacheManager.currentCacheUsage()
        }
    }
}

// MARK: - Update Settings

struct UpdateSettingsView: View {
    @Bindable var settings: AppSettings
    var updateService: UpdateService
    @State private var hasGitHubToken = false
    @State private var tokenInput = ""

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates automatically", isOn: $settings.checkForUpdates)

                HStack {
                    Button("Check Now") {
                        Task { await updateService.check() }
                    }
                    .disabled(updateService.isChecking)

                    if updateService.isChecking {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()

                    if let date = updateService.lastCheckDate {
                        Text("Last checked: \(date.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if updateService.isInstalling {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text(updateService.installProgress ?? "Installing...")
                            .foregroundStyle(.secondary)
                    }
                } else if updateService.updateAvailable, let release = updateService.latestRelease {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(Color.cjPrimary)
                        Text("\(release.tagName) available")
                            .fontWeight(.medium)
                        Spacer()
                        if release.assets.contains(where: { $0.name.hasSuffix(".dmg") }) {
                            Button("Install Now") {
                                Task { await updateService.installUpdate() }
                            }
                            Button("Download") {
                                updateService.downloadDMG()
                            }
                        }
                        Button("View Release") {
                            updateService.openReleasePage()
                        }
                    }
                } else if updateService.latestRelease != nil {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.cjSuccess)
                        Text("You're up to date")
                    }
                }

                if let error = updateService.lastError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.cjWarning)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("GitHub Private Repository") {
                HStack {
                    Image(systemName: hasGitHubToken ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(hasGitHubToken ? Color.cjSuccess : Color.cjError)
                    Text(hasGitHubToken ? "Token configured" : "No token configured")
                }

                SecureField("GitHub Personal Access Token", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save Token") {
                        guard !tokenInput.isEmpty else { return }
                        try? KeychainService.save(key: .githubPAT, value: tokenInput)
                        hasGitHubToken = true
                        tokenInput = ""
                    }
                    .disabled(tokenInput.isEmpty)

                    if hasGitHubToken {
                        Button("Remove Token", role: .destructive) {
                            try? KeychainService.delete(key: .githubPAT)
                            hasGitHubToken = false
                        }
                    }
                }

                Text("A GitHub Personal Access Token with 'repo' scope is needed to check for updates from a private repository. The token is stored securely in your macOS Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version") {
                    Text("\(Constants.appVersion) (\(Constants.buildNumber))")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            hasGitHubToken = KeychainService.exists(key: .githubPAT)
        }
    }
}

// MARK: - Sonarr / Radarr Settings

struct ArrSettingsView: View {
    @Bindable var settings: AppSettings
    var arrService: ArrService
    @State private var testResults: [UUID: String] = [:]

    var body: some View {
        Form {
            Section {
                Toggle("Delete corrupt files and trigger re-download", isOn: $settings.deleteCorruptFiles)
                Text("When a file fails analysis (corrupt/incomplete), delete it via Sonarr/Radarr and trigger a search for re-download.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Instances") {
                ForEach($settings.arrInstances) { $instance in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: instance.type.systemImage)
                                .foregroundStyle(instance.isEnabled ? Color.cjPrimary : Color.cjTextSecondary)
                            TextField("Name", text: $instance.name)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: 150)
                            Picker("", selection: $instance.type) {
                                ForEach(ArrType.allCases, id: \.self) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .frame(width: 100)
                            Toggle("", isOn: $instance.isEnabled)
                                .labelsHidden()
                            Button(role: .destructive) {
                                settings.arrInstances.removeAll { $0.id == instance.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            TextField("URL (e.g. http://localhost:8989)", text: $instance.url)
                                .textFieldStyle(.roundedBorder)
                            SecureField("API Key", text: $instance.apiKey)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 200)
                            Button("Test") {
                                Task {
                                    let result = await arrService.testConnection(
                                        baseURL: instance.baseURL,
                                        apiKey: instance.apiKey
                                    )
                                    testResults[instance.id] = result.success
                                        ? "Connected — \(result.message)"
                                        : result.message
                                }
                            }
                        }
                        if let result = testResults[instance.id] {
                            Text(result)
                                .font(.caption)
                                .foregroundStyle(result.hasPrefix("Connected") ? Color.cjSuccess : Color.cjError)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Button("Add Instance") {
                    settings.arrInstances.append(ArrInstance(name: "New Instance"))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

