import SwiftUI

struct FirstRunWizardView: View {
    let container: ServiceContainer
    let onComplete: () -> Void
    let onStartScan: () -> Void

    @State private var currentStep = 0
    @State private var toolStatuses: [ToolStatus] = []
    @State private var isCheckingTools = true

    var body: some View {
        VStack(spacing: 0) {
            // Progress bars
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { step in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(stepColor(for: step))
                        .frame(width: 32, height: 4)
                }
            }
            .padding(.top, 32)
            .padding(.bottom, 28)

            // Step content
            switch currentStep {
            case 0: toolDetectionStep
            case 1: languageStep
            default: readyStep
            }
        }
        .frame(width: 500, height: 440)
        .padding(.horizontal, 40)
    }

    private func stepColor(for step: Int) -> Color {
        if step < currentStep { return .cjSuccess }
        if step == currentStep { return .cjPrimary }
        return .cjBorder
    }

    // MARK: - Step 1: Tool Detection

    @ViewBuilder
    private var toolDetectionStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Let's get set up")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.cjTextPrimary)
                .padding(.bottom, 6)

            Text("Chaotic Jelly needs a few tools to process your video files.")
                .font(.system(size: 14))
                .foregroundStyle(Color.cjTextSecondary)
                .padding(.bottom, 28)

            VStack(spacing: 0) {
                ForEach(Array(toolStatuses.enumerated()), id: \.element.id) { index, status in
                    HStack {
                        if status.isAvailable {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.cjSuccess)
                        } else if status.tool == .mkvmerge {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.cjWarning)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.cjError)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.tool.displayName)
                                .font(.cjBody)
                                .fontWeight(.medium)
                            if let path = status.resolvedPath {
                                Text(path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cjTextSecondary)
                            } else if status.tool == .mkvmerge {
                                Text("Optional — enables safer MKV processing")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cjTextSecondary)
                            } else {
                                Text("Required — install via Homebrew: brew install \(status.tool.binaryName)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.cjError)
                            }
                        }

                        Spacer()

                        if status.isAvailable {
                            Text("Found")
                                .font(.cjSecondary)
                                .foregroundStyle(Color.cjSuccess)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)

                    if index < toolStatuses.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .cjCard()

            Spacer()

            HStack {
                Spacer()
                Button("Continue") { currentStep = 1 }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
        .task {
            isCheckingTools = true
            var statuses: [ToolStatus] = []
            for tool in ToolType.allCases {
                let available = await container.toolLocator.isAvailable(tool)
                let path = try? await container.toolLocator.path(for: tool)
                statuses.append(ToolStatus(tool: tool, isAvailable: available, resolvedPath: path, version: nil))
            }
            toolStatuses = statuses
            isCheckingTools = false
        }
    }

    // MARK: - Step 2: Language

    @ViewBuilder
    private var languageStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which languages do you want to keep?")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.cjTextPrimary)
                .padding(.bottom, 6)

            Text("Chaotic Jelly will remove subtitle and audio tracks in other languages.")
                .font(.system(size: 14))
                .foregroundStyle(Color.cjTextSecondary)
                .padding(.bottom, 28)

            VStack(spacing: 14) {
                HStack {
                    Text("Primary language")
                        .font(.cjBody)
                        .fontWeight(.medium)
                    Spacer()
                    Text("English")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.cjBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cjBorder, lineWidth: 1))
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("What should we remove?")
                        .font(.cjBody)
                        .fontWeight(.medium)

                    Toggle("Subtitle tracks", isOn: Binding(
                        get: { container.settings.removeSubtitles },
                        set: { container.settings.removeSubtitles = $0 }
                    ))
                    .font(.cjBody)

                    Toggle("Audio tracks", isOn: Binding(
                        get: { container.settings.removeAudio },
                        set: { container.settings.removeAudio = $0 }
                    ))
                    .font(.cjBody)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Conservative mode")
                            .font(.cjBody)
                            .fontWeight(.medium)
                        Text("Keep tracks with unclear language tags")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjTextSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { container.settings.conservativeMode },
                        set: { container.settings.conservativeMode = $0 }
                    ))
                    .labelsHidden()
                }
            }
            .padding(16)
            .cjCard()

            Spacer()

            HStack {
                Button("← Back") { currentStep = 0 }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.cjPrimary)
                Spacer()
                Button("Continue") { currentStep = 2 }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: - Step 3: Ready

    @ViewBuilder
    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("You're all set")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.cjTextPrimary)
                .padding(.bottom, 6)

            Text("Chaotic Jelly is ready to clean up your video library.")
                .font(.system(size: 14))
                .foregroundStyle(Color.cjTextSecondary)
                .padding(.bottom, 28)

            VStack(spacing: 0) {
                summaryRow(label: "Tools", value: toolStatuses.filter(\.isAvailable).map(\.tool.displayName).joined(separator: ", "))
                Divider().padding(.horizontal, 16)
                summaryRow(label: "Language", value: "English")
                Divider().padding(.horizontal, 16)
                summaryRow(label: "Removing", value: removingDescription)
                Divider().padding(.horizontal, 16)
                summaryRow(label: "Mode", value: container.settings.conservativeMode ? "Conservative" : "Standard")
            }
            .cjCard()

            Spacer()

            HStack {
                Button("← Back") { currentStep = 1 }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.cjPrimary)
                Spacer()
                Button("Go to Dashboard") {
                    markComplete()
                    onComplete()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Start First Scan →") {
                    markComplete()
                    onStartScan()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.cjBody)
                .foregroundStyle(Color.cjTextSecondary)
            Spacer()
            Text(value)
                .font(.cjBody)
                .foregroundStyle(Color.cjTextPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var removingDescription: String {
        let subs = container.settings.removeSubtitles
        let audio = container.settings.removeAudio
        if subs && audio { return "Subtitles + Audio" }
        if subs { return "Subtitles only" }
        if audio { return "Audio only" }
        return "Nothing"
    }

    private func markComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedFirstRun")
    }
}
