# UX Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Holistic UX redesign of Chaotic Jelly — grouped sidebar, hybrid dashboard, workflow stepper, expandable review/history rows, lively processing screen, macOS-standard settings window, first-run wizard, empty states, logs polish, and unified design tokens.

**Architecture:** MVVM with `@Observable` ViewModels and SwiftUI views. All views are in `Sources/Views/`, ViewModels in `Sources/ViewModels/`. The app uses `ServiceContainer` for dependency injection, `NavigationSplitView` for sidebar navigation, and a `Settings` scene for the preferences window. Changes are purely UI-layer — no service or model changes required.

**Tech Stack:** Swift 5.9, SwiftUI, macOS 14+, SwiftData, XcodeGen

**Spec:** `docs/superpowers/specs/2026-04-08-ux-redesign-design.md`

---

## File Structure

### New files to create:
- `Sources/Views/Theme/CJColors.swift` — Color extension with semantic design tokens
- `Sources/Views/Theme/CJFonts.swift` — Font extension with typography scale
- `Sources/Views/Theme/CJViewModifiers.swift` — Reusable view modifiers (`.cjCard()`, etc.)
- `Sources/Views/Components/FilterToolbar.swift` — Shared search + filter pills component
- `Sources/Views/Components/ExpandableRow.swift` — Disclosure-based expandable row component
- `Sources/Views/Components/StatusDot.swift` — Colored status indicator dot
- `Sources/Views/Components/EmptyStateView.swift` — Reusable empty state component
- `Sources/Views/Components/WorkflowStepper.swift` — 3-step breadcrumb component
- `Sources/Views/Wizard/FirstRunWizardView.swift` — 3-step onboarding wizard

### Files to modify:
- `Sources/Views/ContentView.swift` — Grouped sidebar, navigation enum changes
- `Sources/Views/Dashboard/DashboardView.swift` — Full redesign: hybrid hub
- `Sources/Views/Review/ReviewView.swift` — Expandable rows, new summary bar, remove modal sheet
- `Sources/Views/Queue/QueueView.swift` — Rename to Processing, lively feedback with animations
- `Sources/Views/History/HistoryView.swift` — Expandable job rows, filter pills
- `Sources/Views/Logs/LogsView.swift` — Dark terminal panel, filter pills
- `Sources/Views/Settings/SettingsView.swift` — macOS-standard toolbar icon preferences window
- `Sources/Views/Scan/ScanView.swift` — Add stepper integration
- `Sources/App/ChaoticJellyApp.swift` — First-run wizard sheet, settings window adjustment
- `Sources/ViewModels/DashboardViewModel.swift` — Add trend/weekly stats computation
- `Sources/ViewModels/QueueViewModel.swift` — Add elapsed timer, ETA, running savings total

---

### Task 1: Design Tokens — Colors, Fonts, View Modifiers

**Files:**
- Create: `Sources/Views/Theme/CJColors.swift`
- Create: `Sources/Views/Theme/CJFonts.swift`
- Create: `Sources/Views/Theme/CJViewModifiers.swift`

- [ ] **Step 1: Create `CJColors.swift`**

```swift
// Sources/Views/Theme/CJColors.swift
import SwiftUI

extension Color {
    // Semantic colors
    static let cjPrimary = Color(nsColor: NSColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1))
    static let cjSuccess = Color(nsColor: NSColor(red: 52/255, green: 199/255, blue: 89/255, alpha: 1))
    static let cjWarning = Color(nsColor: NSColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1))
    static let cjError = Color(nsColor: NSColor(red: 198/255, green: 40/255, blue: 40/255, alpha: 1))

    // Text
    static let cjTextPrimary = Color(nsColor: NSColor(red: 29/255, green: 29/255, blue: 31/255, alpha: 1))
    static let cjTextSecondary = Color(nsColor: NSColor(red: 134/255, green: 134/255, blue: 139/255, alpha: 1))

    // Surfaces
    static let cjBackground = Color(nsColor: NSColor(red: 245/255, green: 245/255, blue: 247/255, alpha: 1))
    static let cjCard = Color.white
    static let cjExpandedRow = Color(nsColor: NSColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1))
    static let cjBorder = Color(nsColor: NSColor(red: 224/255, green: 224/255, blue: 224/255, alpha: 1))
    static let cjRowDivider = Color(nsColor: NSColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1))
    static let cjLogTerminal = Color(nsColor: NSColor(red: 30/255, green: 30/255, blue: 30/255, alpha: 1))

    // Log level colors (for dark background)
    static let cjLogInfo = Color(nsColor: NSColor(red: 78/255, green: 201/255, blue: 176/255, alpha: 1))
    static let cjLogWarn = Color(nsColor: NSColor(red: 220/255, green: 220/255, blue: 170/255, alpha: 1))
    static let cjLogError = Color(nsColor: NSColor(red: 244/255, green: 71/255, blue: 71/255, alpha: 1))

    // Error background
    static let cjErrorBackground = Color(nsColor: NSColor(red: 255/255, green: 245/255, blue: 245/255, alpha: 1))
}
```

- [ ] **Step 2: Create `CJFonts.swift`**

```swift
// Sources/Views/Theme/CJFonts.swift
import SwiftUI

extension Font {
    static let cjHeroCounter: Font = .system(size: 22, weight: .bold, design: .default)
    static let cjPageTitle: Font = .system(size: 15, weight: .semibold)
    static let cjSectionHeader: Font = .system(size: 14, weight: .semibold)
    static let cjBody: Font = .system(size: 13)
    static let cjSecondary: Font = .system(size: 12)
    static let cjSectionLabel: Font = .system(size: 11, weight: .semibold)
    static let cjLogText: Font = .system(size: 11.5, design: .monospaced)
}
```

- [ ] **Step 3: Create `CJViewModifiers.swift`**

```swift
// Sources/Views/Theme/CJViewModifiers.swift
import SwiftUI

struct CJCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cjCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cjBorder, lineWidth: 1)
            )
    }
}

struct CJSectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.cjSectionLabel)
            .foregroundStyle(Color.cjTextSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func cjCard() -> some View {
        modifier(CJCardModifier())
    }

    func cjSectionLabel() -> some View {
        modifier(CJSectionLabelModifier())
    }
}
```

- [ ] **Step 4: Verify the project builds**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ChaoticJelly/Sources/Views/Theme/
git commit -m "feat: add design token system — colors, fonts, view modifiers"
```

---

### Task 2: Shared Components — StatusDot, EmptyStateView, FilterToolbar

**Files:**
- Create: `Sources/Views/Components/StatusDot.swift`
- Create: `Sources/Views/Components/EmptyStateView.swift`
- Create: `Sources/Views/Components/FilterToolbar.swift`

- [ ] **Step 1: Create `StatusDot.swift`**

```swift
// Sources/Views/Components/StatusDot.swift
import SwiftUI

struct StatusDot: View {
    let color: Color
    var pulsing: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(pulsing ? pulseOpacity : 1)
            .animation(pulsing ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: pulsing)
    }

    @State private var pulseOpacity: Double = 0.4
}

// Convenience initializer for file/job statuses
extension StatusDot {
    static func forFileStatus(_ status: FileStatus) -> StatusDot {
        switch status {
        case .analyzed: return StatusDot(color: .cjPrimary)
        case .completed: return StatusDot(color: .cjSuccess)
        case .failed: return StatusDot(color: .cjError)
        case .skipped: return StatusDot(color: .cjTextSecondary)
        case .processing: return StatusDot(color: .cjPrimary, pulsing: true)
        default: return StatusDot(color: .cjTextSecondary)
        }
    }

    static func forJobStatus(_ status: JobStatus) -> StatusDot {
        switch status {
        case .completed: return StatusDot(color: .cjSuccess)
        case .failed: return StatusDot(color: .cjError)
        case .cancelled: return StatusDot(color: .cjWarning)
        case .processing, .scanning, .analyzing: return StatusDot(color: .cjPrimary, pulsing: true)
        default: return StatusDot(color: .cjTextSecondary)
        }
    }
}
```

- [ ] **Step 2: Create `EmptyStateView.swift`**

```swift
// Sources/Views/Components/EmptyStateView.swift
import SwiftUI

struct CJEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var isPrimaryAction: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 40))
                .opacity(0.6)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.cjTextPrimary)

            Text(message)
                .font(.cjBody)
                .foregroundStyle(Color.cjTextSecondary)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(isPrimaryAction ? .borderedProminent : .bordered)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Create `FilterToolbar.swift`**

```swift
// Sources/Views/Components/FilterToolbar.swift
import SwiftUI

struct FilterPill<Value: Hashable>: View {
    let label: String
    let value: Value?
    @Binding var selection: Value?
    var labelColor: Color?

    var isSelected: Bool {
        selection == value
    }

    var body: some View {
        Button {
            selection = value
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .white : (labelColor ?? Color.cjTextSecondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.cjPrimary : Color.cjCard)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.clear : Color.cjBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.cjTextSecondary)
                .font(.system(size: 12))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.cjSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.cjCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.cjBorder, lineWidth: 1)
        )
        .frame(maxWidth: 220)
    }
}
```

- [ ] **Step 4: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add ChaoticJelly/Sources/Views/Components/StatusDot.swift ChaoticJelly/Sources/Views/Components/EmptyStateView.swift ChaoticJelly/Sources/Views/Components/FilterToolbar.swift
git commit -m "feat: add shared components — StatusDot, EmptyStateView, FilterToolbar"
```

---

### Task 3: WorkflowStepper Component

**Files:**
- Create: `Sources/Views/Components/WorkflowStepper.swift`

- [ ] **Step 1: Create `WorkflowStepper.swift`**

```swift
// Sources/Views/Components/WorkflowStepper.swift
import SwiftUI

enum WorkflowStep: Int, CaseIterable {
    case scan = 0
    case review = 1
    case processing = 2

    var label: String {
        switch self {
        case .scan: return "Scan"
        case .review: return "Review"
        case .processing: return "Processing"
        }
    }
}

struct WorkflowStepper: View {
    let currentStep: WorkflowStep
    var scanSummary: String?
    var reviewSummary: String?
    var processingSummary: String?
    var onStepTapped: ((WorkflowStep) -> Void)?

    var body: some View {
        HStack(spacing: 0) {
            stepView(step: .scan, summary: scanSummary)
            connector(after: .scan)
            stepView(step: .review, summary: reviewSummary)
            connector(after: .review)
            stepView(step: .processing, summary: processingSummary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .cjCard()
    }

    @ViewBuilder
    private func stepView(step: WorkflowStep, summary: String?) -> some View {
        let state = stepState(for: step)
        HStack(spacing: 8) {
            stepCircle(step: step, state: state)

            Text(step.label)
                .font(.cjSecondary)
                .fontWeight(state == .active ? .semibold : .medium)
                .foregroundStyle(stepColor(state))

            if let summary {
                Text(summary)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if state == .completed {
                onStepTapped?(step)
            }
        }
    }

    @ViewBuilder
    private func stepCircle(step: WorkflowStep, state: StepState) -> some View {
        ZStack {
            Circle()
                .fill(circleColor(state))
                .frame(width: 24, height: 24)

            switch state {
            case .completed:
                Text("✓")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            case .active:
                if step == .processing {
                    Text("⚡")
                        .font(.system(size: 12))
                } else {
                    Text("\(step.rawValue + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            case .pending:
                Text("\(step.rawValue + 1)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.cjTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func connector(after step: WorkflowStep) -> some View {
        let state = stepState(for: step)
        let nextState = stepState(for: WorkflowStep(rawValue: step.rawValue + 1) ?? .processing)

        Rectangle()
            .fill(connectorColor(currentState: state, nextState: nextState))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
    }

    // MARK: - State Logic

    private enum StepState {
        case completed, active, pending
    }

    private func stepState(for step: WorkflowStep) -> StepState {
        if step.rawValue < currentStep.rawValue { return .completed }
        if step.rawValue == currentStep.rawValue { return .active }
        return .pending
    }

    private func stepColor(_ state: StepState) -> Color {
        switch state {
        case .completed: return .cjSuccess
        case .active: return .cjPrimary
        case .pending: return .cjTextSecondary
        }
    }

    private func circleColor(_ state: StepState) -> Color {
        switch state {
        case .completed: return .cjSuccess
        case .active: return .cjPrimary
        case .pending: return Color.cjBorder
        }
    }

    private func connectorColor(currentState: StepState, nextState: StepState) -> some ShapeStyle {
        if currentState == .completed && nextState == .completed {
            return AnyShapeStyle(Color.cjSuccess)
        } else if currentState == .completed && nextState == .active {
            return AnyShapeStyle(LinearGradient(colors: [.cjSuccess, .cjPrimary], startPoint: .leading, endPoint: .trailing))
        } else {
            return AnyShapeStyle(Color.cjBorder)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/Components/WorkflowStepper.swift
git commit -m "feat: add WorkflowStepper component for Scan/Review/Processing flow"
```

---

### Task 4: ExpandableRow Component

**Files:**
- Create: `Sources/Views/Components/ExpandableRow.swift`

- [ ] **Step 1: Create `ExpandableRow.swift`**

```swift
// Sources/Views/Components/ExpandableRow.swift
import SwiftUI

struct ExpandableRow<Header: View, Detail: View>: View {
    @State private var isExpanded = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cjTextSecondary)
                    .frame(width: 10)

                header()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isExpanded ? Color.cjExpandedRow : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Detail panel
            if isExpanded {
                VStack(alignment: .leading) {
                    detail()
                }
                .padding(.leading, 44)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
                .background(Color.cjExpandedRow.opacity(0.7))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/Components/ExpandableRow.swift
git commit -m "feat: add ExpandableRow component with disclosure animation"
```

---

### Task 5: Sidebar Navigation Redesign

**Files:**
- Modify: `Sources/Views/ContentView.swift`

- [ ] **Step 1: Rewrite `ContentView.swift` with grouped sidebar**

Replace the entire file:

```swift
// Sources/Views/ContentView.swift
import SwiftUI

// MARK: - Navigation

enum SidebarSection: String, CaseIterable {
    case home
    case workflow
    case reference
}

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case scan = "New Scan"
    case review = "Review"
    case processing = "Processing"
    case history = "History"
    case logs = "Logs"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.33percent"
        case .scan: return "doc.text.magnifyingglass"
        case .review: return "checklist"
        case .processing: return "bolt.fill"
        case .history: return "clock.arrow.circlepath"
        case .logs: return "doc.plaintext"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard: return .home
        case .scan, .review, .processing: return .workflow
        case .history, .logs: return .reference
        }
    }

    static var workflowItems: [NavigationItem] { [.scan, .review, .processing] }
    static var referenceItems: [NavigationItem] { [.history, .logs] }
}

// MARK: - ContentView

struct ContentView: View {
    let container: ServiceContainer
    @State private var selectedItem: NavigationItem = .dashboard
    @State private var scanVM: ScanViewModel?
    @State private var reviewVM: ReviewViewModel?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                // Dashboard (ungrouped)
                Label(NavigationItem.dashboard.rawValue, systemImage: NavigationItem.dashboard.systemImage)
                    .tag(NavigationItem.dashboard)

                // Workflow section
                Section("Workflow") {
                    ForEach(NavigationItem.workflowItems) { item in
                        sidebarRow(item: item)
                    }
                }

                // Reference section
                Section("Reference") {
                    ForEach(NavigationItem.referenceItems) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(selectedItem.rawValue)
        .onAppear {
            scanVM = ScanViewModel(container: container)
            reviewVM = ReviewViewModel(container: container)
        }
    }

    @ViewBuilder
    private func sidebarRow(item: NavigationItem) -> some View {
        switch item {
        case .review:
            let count = reviewVM?.job?.files.filter({ $0.fileStatus == .analyzed }).count ?? 0
            Label(item.rawValue, systemImage: item.systemImage)
                .tag(item)
                .badge(count > 0 ? count : 0)
        case .processing:
            let vm = QueueViewModel(container: container)
            if let job = vm.activeJob {
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
                    .badge("\(job.completedFileCount)/\(job.fileCount)")
            } else {
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
        default:
            Label(item.rawValue, systemImage: item.systemImage)
                .tag(item)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView(viewModel: DashboardViewModel(container: container), onNewScan: {
                selectedItem = .scan
            })
        case .scan:
            if let scanVM {
                ScanView(viewModel: scanVM, settings: container.settings, onReview: { job in
                    reviewVM?.job = job
                    selectedItem = .review
                })
            }
        case .review:
            if let reviewVM {
                ReviewView(viewModel: reviewVM, onStartProcessing: {
                    selectedItem = .processing
                })
            }
        case .processing:
            QueueView(viewModel: QueueViewModel(container: container))
        case .history:
            HistoryView(viewModel: HistoryViewModel(container: container))
        case .logs:
            LogsView(viewModel: LogsViewModel(container: container))
        }
    }
}
```

Note: `DashboardView` now receives `onNewScan` callback — we'll update `DashboardView` in the next task.

- [ ] **Step 2: Verify build (may fail on `onNewScan` param until Task 6 — that's expected)**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -10`

If the build fails only on the `onNewScan` parameter, that's expected — Task 6 fixes it.

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/ContentView.swift
git commit -m "feat: grouped sidebar navigation — Workflow and Reference sections"
```

---

### Task 6: Dashboard Redesign

**Files:**
- Modify: `Sources/Views/Dashboard/DashboardView.swift`
- Modify: `Sources/ViewModels/DashboardViewModel.swift`

- [ ] **Step 1: Update `DashboardViewModel.swift` to add weekly savings**

Add a `weeklySpaceSaved` computed property. Replace the entire file:

```swift
// Sources/ViewModels/DashboardViewModel.swift
import Foundation
import SwiftUI

@Observable
final class DashboardViewModel {
    private let container: ServiceContainer

    var recentJobs: [Job] = []
    var totalSpaceSaved: Int64 = 0
    var totalFilesProcessed: Int = 0
    var totalJobCount: Int = 0
    var weeklySpaceSaved: Int64 = 0
    var cacheUsage: Int64 = 0

    init(container: ServiceContainer) {
        self.container = container
    }

    var activeJob: Job? {
        container.jobManager.activeJob
    }

    var isProcessing: Bool {
        container.jobManager.isProcessing
    }

    var currentFileProgress: FileProcessingProgress? {
        container.jobManager.currentFileProgress
    }

    @MainActor
    func refresh() async {
        let jobs = container.jobManager.fetchJobs()
        recentJobs = Array(jobs.prefix(5))
        totalSpaceSaved = container.jobManager.totalSpaceSaved()
        totalJobCount = jobs.count
        totalFilesProcessed = jobs
            .flatMap(\.files)
            .filter { $0.fileStatus == .completed }
            .count

        // Weekly savings
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        weeklySpaceSaved = jobs
            .filter { ($0.completedAt ?? $0.createdAt) >= oneWeekAgo }
            .reduce(0) { $0 + $1.bytesSaved }

        cacheUsage = await container.cacheManager.currentCacheUsage()
    }
}
```

- [ ] **Step 2: Rewrite `DashboardView.swift`**

Replace the entire file:

```swift
// Sources/Views/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @State var viewModel: DashboardViewModel
    var onNewScan: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top row: New Scan CTA + Stat cards
                topRow

                // Active job panel (only when processing)
                if let job = viewModel.activeJob, viewModel.isProcessing {
                    activeJobPanel(job: job)
                }

                // Recent jobs
                recentJobsPanel
            }
            .padding(24)
        }
        .background(Color.cjBackground)
        .task {
            await viewModel.refresh()
        }
    }

    // MARK: - Top Row

    @ViewBuilder
    private var topRow: some View {
        HStack(spacing: 16) {
            // New Scan CTA
            Button(action: onNewScan) {
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cjPrimary)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Scan")
                            .font(.cjPageTitle)
                            .foregroundStyle(Color.cjTextPrimary)
                        Text("Scan a folder for video files")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjTextSecondary)
                    }

                    Spacer()
                }
                .padding(20)
                .cjCard()
            }
            .buttonStyle(.plain)

            // Space Saved
            VStack(spacing: 4) {
                Text("Space Saved")
                    .cjSectionLabel()
                Text(viewModel.totalSpaceSaved.formattedFileSize)
                    .font(.cjHeroCounter)
                    .foregroundStyle(Color.cjTextPrimary)
                    .monospacedDigit()
                if viewModel.weeklySpaceSaved > 0 {
                    Text("↑ \(viewModel.weeklySpaceSaved.formattedFileSize) this week")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cjSuccess)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .cjCard()

            // Files Processed
            VStack(spacing: 4) {
                Text("Files Processed")
                    .cjSectionLabel()
                Text("\(viewModel.totalFilesProcessed)")
                    .font(.cjHeroCounter)
                    .foregroundStyle(Color.cjTextPrimary)
                    .monospacedDigit()
                Text("across \(viewModel.totalJobCount) jobs")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .cjCard()
        }
    }

    // MARK: - Active Job Panel

    @ViewBuilder
    private func activeJobPanel(job: Job) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    StatusDot(color: .cjPrimary, pulsing: true)
                    Text("Processing — \(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)")
                        .font(.cjPageTitle)
                        .foregroundStyle(Color.cjTextPrimary)
                }
                Spacer()
                if let duration = job.duration {
                    Text(duration.formattedDuration)
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)
                }
            }

            // Progress bar with shimmer
            ProgressView(value: job.progressFraction)
                .tint(Color.cjPrimary)

            // Stats row
            HStack {
                HStack(spacing: 20) {
                    Text("Progress: **\(job.completedFileCount) / \(job.fileCount) files**")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)

                    if let currentFile = job.files.first(where: { $0.fileStatus == .processing }) {
                        Text("Current: **\(currentFile.fileName)**")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjTextSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if job.bytesSaved > 0 {
                    Text("↓ \(job.bytesSaved.formattedFileSize) saved")
                        .font(.cjSecondary)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.cjSuccess)
                }
            }
        }
        .padding(20)
        .cjCard()
    }

    // MARK: - Recent Jobs

    @ViewBuilder
    private var recentJobsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Jobs")
                .font(.cjSectionHeader)
                .foregroundStyle(Color.cjTextPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if viewModel.recentJobs.isEmpty {
                CJEmptyStateView(
                    icon: "📁",
                    title: "No scans yet",
                    message: "Scan a folder to find video files to clean up",
                    actionTitle: "New Scan",
                    action: onNewScan
                )
                .frame(height: 200)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentJobs.enumerated()), id: \.element.id) { index, job in
                        DashboardJobRow(job: job)
                        if index < viewModel.recentJobs.count - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .cjCard()
    }
}

// MARK: - Dashboard Job Row

struct DashboardJobRow: View {
    let job: Job

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)
                    .font(.cjBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)

                Text("\(job.fileCount) files · \(job.bytesSaved.formattedFileSize) saved · \(job.duration?.formattedDuration ?? "—")")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }

            Spacer()

            Text(job.createdAt.relativeString)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)

            JobStatusBadge(status: job.jobStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct JobStatusBadge: View {
    let status: JobStatus

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(badgeBackground)
            .foregroundStyle(badgeColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var badgeColor: Color {
        switch status {
        case .completed: return .cjSuccess
        case .failed: return .cjError
        case .cancelled: return .cjWarning
        default: return .cjTextSecondary
        }
    }

    private var badgeBackground: Color {
        switch status {
        case .completed: return Color.cjSuccess.opacity(0.12)
        case .failed: return Color.cjError.opacity(0.12)
        case .cancelled: return Color.cjWarning.opacity(0.12)
        default: return Color.cjTextSecondary.opacity(0.12)
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ChaoticJelly/Sources/Views/Dashboard/DashboardView.swift ChaoticJelly/Sources/ViewModels/DashboardViewModel.swift
git commit -m "feat: redesign Dashboard — hybrid hub with New Scan CTA, active job panel, stat cards"
```

---

### Task 7: Review Screen Redesign

**Files:**
- Modify: `Sources/Views/Review/ReviewView.swift`

- [ ] **Step 1: Rewrite `ReviewView.swift` with expandable rows and filter pills**

Replace the entire file:

```swift
// Sources/Views/Review/ReviewView.swift
import SwiftUI

struct ReviewView: View {
    @State var viewModel: ReviewViewModel
    let onStartProcessing: () -> Void
    @State private var showConfirmation = false

    var body: some View {
        if viewModel.job == nil {
            CJEmptyStateView(
                icon: "🔍",
                title: "Nothing to review",
                message: "Run a scan to analyze files before processing",
                actionTitle: "Go to New Scan",
                action: nil,
                isPrimaryAction: false
            )
        } else {
            VStack(spacing: 0) {
                // Workflow stepper
                WorkflowStepper(
                    currentStep: .review,
                    scanSummary: "\(viewModel.summary.totalFiles) files found",
                    reviewSummary: "\(viewModel.summary.filesToProcess) to process"
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Summary bar
                summaryBar

                // Filter toolbar
                filterToolbar

                // File list
                fileList
            }
            .background(Color.cjBackground)
            .confirmationDialog(
                "Start Processing",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Process \(viewModel.summary.filesToProcess) Files", role: .destructive) {
                    Task {
                        await viewModel.startProcessing()
                        onStartProcessing()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will modify \(viewModel.summary.filesToProcess) files. \(viewModel.summary.totalStreamsToRemove) streams will be removed. Estimated savings: \(viewModel.summary.estimatedSavingsBytes.formattedFileSize).")
            }
        }
    }

    // MARK: - Summary Bar

    @ViewBuilder
    private var summaryBar: some View {
        HStack(spacing: 20) {
            HStack(spacing: 16) {
                Text("**\(viewModel.summary.totalFiles)** total")
                    .font(.cjSecondary)
                Text("**\(viewModel.summary.filesToProcess)** to process")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjPrimary)
                Text("**\(viewModel.summary.filesToSkip)** skipped")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
                if viewModel.summary.warningCount > 0 {
                    Text("**\(viewModel.summary.warningCount)** warnings")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjWarning)
                }
            }

            Spacer()

            Text("Est. savings: \(viewModel.summary.estimatedSavingsBytes.formattedFileSize)")
                .font(.cjSecondary)
                .fontWeight(.semibold)
                .foregroundStyle(Color.cjSuccess)

            if viewModel.summary.filesToProcess > 0 {
                Button("Start Processing") {
                    showConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .cjCard()
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Filter Toolbar

    @ViewBuilder
    private var filterToolbar: some View {
        HStack(spacing: 10) {
            SearchField(text: $viewModel.searchText, placeholder: "Search files...")

            HStack(spacing: 4) {
                FilterPill(label: "All", value: nil as FileStatus?, selection: $viewModel.filterStatus)
                FilterPill(label: "To Process", value: .analyzed, selection: $viewModel.filterStatus)
                FilterPill(label: "Warnings", value: .analyzed, selection: $viewModel.filterStatus)
                FilterPill(label: "Skipped", value: .skipped, selection: $viewModel.filterStatus)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
    }

    // MARK: - File List

    @ViewBuilder
    private var fileList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.filteredFiles.enumerated()), id: \.element.id) { index, file in
                    ExpandableRow {
                        fileRowHeader(file: file)
                    } detail: {
                        fileRowDetail(file: file)
                    }
                    .opacity(file.fileStatus == .skipped ? 0.5 : 1)

                    if index < viewModel.filteredFiles.count - 1 {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .cjCard()
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private func fileRowHeader(file: FileEntry) -> some View {
        HStack(spacing: 10) {
            statusIcon(for: file)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .font(.cjBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)

                Text(actionSummary(for: file))
                    .font(.system(size: 11))
                    .foregroundStyle(file.warnings.isEmpty ? Color.cjTextSecondary : Color.cjWarning)
                    .lineLimit(1)
            }

            Spacer()

            if let savings = file.analysisResult?.estimatedSavingsBytes, savings > 0 {
                Text("-\(savings.formattedFileSize)")
                    .font(.cjSecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjSuccess)
            } else {
                Text("—")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }

            Text(file.originalSize.formattedFileSize)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
                .frame(width: 70, alignment: .trailing)
        }
    }

    @ViewBuilder
    private func fileRowDetail(file: FileEntry) -> some View {
        if let analysis = file.analysisResult {
            HStack(alignment: .top, spacing: 16) {
                // Removing column
                VStack(alignment: .leading, spacing: 8) {
                    Text("Removing")
                        .cjSectionLabel()

                    ForEach(analysis.actions.filter { if case .removeStream = $0 { return true }; return false }) { action in
                        HStack(spacing: 6) {
                            Text("✕")
                                .foregroundStyle(Color.cjError)
                            Text(action.displayDescription.replacingOccurrences(of: "Remove stream \\d+: ", with: "", options: .regularExpression))
                                .font(.cjSecondary)
                                .foregroundStyle(Color.cjError)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Keeping column
                VStack(alignment: .leading, spacing: 8) {
                    Text("Keeping")
                        .cjSectionLabel()

                    ForEach(analysis.actions.filter { if case .keepStream = $0 { return true }; return false }) { action in
                        HStack(spacing: 6) {
                            Text("✓")
                                .foregroundStyle(Color.cjSuccess)
                            Text(action.displayDescription.replacingOccurrences(of: "Keep stream \\d+: ", with: "", options: .regularExpression))
                                .font(.cjSecondary)
                                .foregroundStyle(Color.cjSuccess)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func statusIcon(for file: FileEntry) -> some View {
        switch file.fileStatus {
        case .analyzed:
            if !file.warnings.isEmpty {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.cjWarning)
            } else {
                StatusDot(color: .cjPrimary)
            }
        case .skipped:
            StatusDot(color: .cjTextSecondary)
        case .failed:
            StatusDot(color: .cjError)
        default:
            StatusDot(color: .cjTextSecondary)
        }
    }

    private func actionSummary(for file: FileEntry) -> String {
        if !file.warnings.isEmpty {
            return file.warnings.first ?? "Warning"
        }
        guard let analysis = file.analysisResult else {
            return file.fileStatus == .skipped ? "English only — nothing to remove" : "Pending analysis"
        }
        let removeCount = analysis.removedStreamCount
        if removeCount == 0 { return "Nothing to remove" }
        let subtitleRemoves = analysis.actions.filter {
            if case .removeStream = $0 { return true }; return false
        }.count
        return "Remove \(removeCount) track\(removeCount == 1 ? "" : "s")"
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/Review/ReviewView.swift
git commit -m "feat: redesign Review screen — expandable rows, filter pills, inline stream detail"
```

---

### Task 8: Processing Screen Redesign (Lively Feedback)

**Files:**
- Modify: `Sources/Views/Queue/QueueView.swift`
- Modify: `Sources/ViewModels/QueueViewModel.swift`

- [ ] **Step 1: Update `QueueViewModel.swift` with elapsed timer and running savings**

Replace the entire file:

```swift
// Sources/ViewModels/QueueViewModel.swift
import Foundation
import SwiftUI

@MainActor @Observable
final class QueueViewModel {
    private let container: ServiceContainer
    var elapsedSeconds: Int = 0
    private var timer: Timer?

    init(container: ServiceContainer) {
        self.container = container
    }

    var activeJob: Job? {
        container.jobManager.activeJob
    }

    var isProcessing: Bool {
        container.jobManager.isProcessing
    }

    var currentProgress: FileProcessingProgress? {
        container.jobManager.currentFileProgress
    }

    var completedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .completed }.reversed()
    }

    var failedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .failed }
    }

    var queuedFiles: [FileEntry] {
        guard let job = activeJob else { return [] }
        return job.files.filter { $0.fileStatus == .queued || $0.fileStatus == .analyzed }
    }

    var currentFile: FileEntry? {
        activeJob?.files.first(where: { $0.fileStatus == .processing || $0.fileStatus == .validating })
    }

    var runningSavings: Int64 {
        completedFiles.reduce(0) { $0 + $1.bytesSaved }
    }

    var estimatedRemainingSeconds: Int? {
        guard let job = activeJob, job.completedFileCount > 0 else { return nil }
        let avgPerFile = elapsedSeconds / job.completedFileCount
        let remaining = job.fileCount - job.completedFileCount
        return avgPerFile * remaining
    }

    func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func cancelJob() async {
        await container.jobManager.cancelActiveJob()
        stopTimer()
    }

    var elapsedFormatted: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var remainingFormatted: String? {
        guard let remaining = estimatedRemainingSeconds else { return nil }
        let minutes = remaining / 60
        return "~\(minutes) min"
    }
}
```

- [ ] **Step 2: Rewrite `QueueView.swift` with lively feedback**

Replace the entire file:

```swift
// Sources/Views/Queue/QueueView.swift
import SwiftUI

struct QueueView: View {
    @State var viewModel: QueueViewModel

    var body: some View {
        if let job = viewModel.activeJob, viewModel.isProcessing {
            ScrollView {
                VStack(spacing: 16) {
                    // Workflow stepper
                    WorkflowStepper(
                        currentStep: .processing,
                        scanSummary: "\(job.fileCount) files",
                        reviewSummary: "\(job.fileCount) files",
                        processingSummary: "\(job.completedFileCount) / \(job.fileCount)"
                    )

                    // Hero stats panel
                    heroPanel(job: job)

                    // Current file
                    if let file = viewModel.currentFile {
                        currentFileCard(file: file)
                    }

                    // File feed
                    fileFeed(job: job)
                }
                .padding(24)
            }
            .background(Color.cjBackground)
            .onAppear { viewModel.startTimer() }
            .onDisappear { viewModel.stopTimer() }
        } else {
            CJEmptyStateView(
                icon: "⚡",
                title: "No active jobs",
                message: "Start processing from the Review screen"
            )
        }
    }

    // MARK: - Hero Stats Panel

    @ViewBuilder
    private func heroPanel(job: Job) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    StatusDot(color: .cjPrimary, pulsing: true)
                    Text("Processing \(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)")
                        .font(.cjPageTitle)
                        .foregroundStyle(Color.cjTextPrimary)
                }
                Spacer()
                Button(role: .destructive) {
                    Task { await viewModel.cancelJob() }
                } label: {
                    Text("Cancel")
                        .font(.cjSecondary)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cjBorder)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [.cjPrimary, Color(red: 90/255, green: 200/255, blue: 250/255)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * job.progressFraction)
                        .animation(.easeInOut(duration: 0.3), value: job.progressFraction)
                }
            }
            .frame(height: 12)

            // Counter grid
            HStack(spacing: 0) {
                counterCell(label: "Progress", value: "\(job.completedFileCount) / \(job.fileCount)")
                counterCell(label: "Space Saved", value: viewModel.runningSavings.formattedFileSize, color: .cjSuccess)
                counterCell(label: "Elapsed", value: viewModel.elapsedFormatted)
                counterCell(label: "Remaining", value: viewModel.remainingFormatted ?? "—")
            }
        }
        .padding(24)
        .cjCard()
    }

    @ViewBuilder
    private func counterCell(label: String, value: String, color: Color = .cjTextPrimary) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .cjSectionLabel()
            Text(value)
                .font(.cjHeroCounter)
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Current File Card

    @ViewBuilder
    private func currentFileCard(file: FileEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(file.fileName)
                        .font(.cjBody)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cjTextPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(file.originalSize.formattedFileSize)")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }

            if let progress = viewModel.currentProgress {
                ProgressView(value: progress.progress)
                    .tint(Color.cjPrimary)

                Text(progress.message)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }
        }
        .padding(16)
        .cjCard()
    }

    // MARK: - File Feed

    @ViewBuilder
    private func fileFeed(job: Job) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("File Feed")
                    .font(.cjSectionHeader)
                    .foregroundStyle(Color.cjTextPrimary)
                Spacer()
                HStack(spacing: 12) {
                    Text("✓ \(viewModel.completedFiles.count) done")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjSuccess)
                    Text("○ \(viewModel.queuedFiles.count) queued")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)
                    if !viewModel.failedFiles.isEmpty {
                        Text("✕ \(viewModel.failedFiles.count) error")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjError)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().padding(.horizontal, 16)

            // Completed files (most recent first)
            ForEach(viewModel.completedFiles) { file in
                feedRow(file: file, type: .completed)
                Divider().padding(.horizontal, 16)
            }

            // Failed files
            ForEach(viewModel.failedFiles) { file in
                feedRow(file: file, type: .failed)
                Divider().padding(.horizontal, 16)
            }

            // Queued files
            ForEach(viewModel.queuedFiles) { file in
                feedRow(file: file, type: .queued)
                if file.id != viewModel.queuedFiles.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .cjCard()
    }

    private enum FeedRowType { case completed, failed, queued }

    @ViewBuilder
    private func feedRow(file: FileEntry, type: FeedRowType) -> some View {
        switch type {
        case .completed:
            HStack {
                HStack(spacing: 8) {
                    Text("✓").foregroundStyle(Color.cjSuccess)
                    Text(file.fileName)
                        .font(.cjBody)
                        .foregroundStyle(Color.cjTextPrimary)
                        .lineLimit(1)
                }
                Spacer()
                if file.bytesSaved > 0 {
                    Text("-\(file.bytesSaved.formattedFileSize)")
                        .font(.cjSecondary)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.cjSuccess)
                }
                if let duration = fileDuration(file) {
                    Text(duration)
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjTextSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

        case .failed:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("✕").foregroundStyle(Color.cjError)
                    Text(file.fileName)
                        .font(.cjBody)
                        .foregroundStyle(Color.cjTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("Error")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjError)
                }
                if let error = file.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cjError)
                        .padding(.leading, 22)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cjErrorBackground)

        case .queued:
            HStack {
                HStack(spacing: 8) {
                    Text("○").foregroundStyle(Color.cjTextSecondary)
                    Text(file.fileName)
                        .font(.cjBody)
                        .foregroundStyle(Color.cjTextPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Text(file.originalSize.formattedFileSize)
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .opacity(0.4)
        }
    }

    private func fileDuration(_ file: FileEntry) -> String? {
        guard let start = file.startedAt, let end = file.completedAt else { return nil }
        let seconds = Int(end.timeIntervalSince(start))
        return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ChaoticJelly/Sources/Views/Queue/QueueView.swift ChaoticJelly/Sources/ViewModels/QueueViewModel.swift
git commit -m "feat: redesign Processing screen — lively feedback with animated counters and file feed"
```

---

### Task 9: History Screen Redesign

**Files:**
- Modify: `Sources/Views/History/HistoryView.swift`

- [ ] **Step 1: Rewrite `HistoryView.swift` with expandable rows and filter pills**

Replace the entire file:

```swift
// Sources/Views/History/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @State var viewModel: HistoryViewModel
    @State private var showDeleteConfirmation = false
    @State private var jobToDelete: Job?

    var body: some View {
        VStack(spacing: 0) {
            // Summary stats
            HStack(spacing: 12) {
                miniStat(value: "\(viewModel.jobs.count)", label: "Total Jobs")
                miniStat(value: viewModel.totalSpaceSaved.formattedFileSize, label: "Total Saved", color: .cjSuccess)
                miniStat(value: "\(viewModel.jobs.flatMap(\.files).filter { $0.fileStatus == .completed }.count)", label: "Files Processed")
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Filter toolbar
            HStack(spacing: 10) {
                SearchField(text: $viewModel.searchText, placeholder: "Search jobs...")

                HStack(spacing: 4) {
                    FilterPill(label: "All", value: nil as JobStatus?, selection: $viewModel.filterStatus)
                    FilterPill(label: "Completed", value: .completed, selection: $viewModel.filterStatus)
                    FilterPill(label: "Failed", value: .failed, selection: $viewModel.filterStatus, labelColor: .cjError)
                    FilterPill(label: "Cancelled", value: .cancelled, selection: $viewModel.filterStatus)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Job list
            if viewModel.filteredJobs.isEmpty {
                CJEmptyStateView(
                    icon: "📋",
                    title: viewModel.jobs.isEmpty ? "No history yet" : "No matching jobs",
                    message: viewModel.jobs.isEmpty ? "Completed jobs will appear here" : "Try adjusting your filters"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.filteredJobs.enumerated()), id: \.element.id) { index, job in
                            ExpandableRow {
                                historyRowHeader(job: job)
                            } detail: {
                                historyRowDetail(job: job)
                            }
                            .contextMenu {
                                if job.failedFileCount > 0 {
                                    Button("Retry Failed Files") {
                                        Task { await viewModel.retryJob(job) }
                                    }
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    jobToDelete = job
                                    showDeleteConfirmation = true
                                }
                            }

                            if index < viewModel.filteredJobs.count - 1 {
                                Divider().padding(.horizontal, 16)
                            }
                        }
                    }
                    .cjCard()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.cjBackground)
        .task { viewModel.refresh() }
        .confirmationDialog(
            "Delete Job",
            isPresented: $showDeleteConfirmation,
            presenting: jobToDelete
        ) { job in
            Button("Delete", role: .destructive) {
                viewModel.deleteJob(job)
            }
        } message: { _ in
            Text("Delete this job and all its history? This cannot be undone.")
        }
    }

    @ViewBuilder
    private func miniStat(value: String, label: String, color: Color = .cjTextPrimary) -> some View {
        HStack(spacing: 12) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cjCard()
    }

    @ViewBuilder
    private func historyRowHeader(job: Job) -> some View {
        HStack(spacing: 10) {
            StatusDot.forJobStatus(job.jobStatus)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(fileURLWithPath: job.sourceFolderPath).lastPathComponent)
                    .font(.cjBody)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjTextPrimary)
                    .lineLimit(1)

                Text("\(job.fileCount) files · \(job.processingMode.displayName) · \(job.duration?.formattedDuration ?? "—")")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.cjTextSecondary)
            }

            Spacer()

            if job.bytesSaved > 0 {
                Text("-\(job.bytesSaved.formattedFileSize)")
                    .font(.cjSecondary)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cjSuccess)
            } else if job.failedFileCount > 0 {
                Text("\(job.failedFileCount) failed")
                    .font(.cjSecondary)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.cjError)
            }

            Text(job.createdAt.relativeString)
                .font(.cjSecondary)
                .foregroundStyle(Color.cjTextSecondary)
        }
    }

    @ViewBuilder
    private func historyRowDetail(job: Job) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 20) {
                Text("✓ \(job.files.filter { $0.fileStatus == .completed }.count) completed")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjTextSecondary)
                if job.failedFileCount > 0 {
                    Text("✕ \(job.failedFileCount) failed")
                        .font(.cjSecondary)
                        .foregroundStyle(Color.cjError)
                }
            }

            // Show first few files
            ForEach(Array(job.files.prefix(5).enumerated()), id: \.element.id) { _, file in
                HStack {
                    Text(file.fileName)
                        .font(.cjSecondary)
                        .foregroundStyle(file.fileStatus == .failed ? Color.cjError : Color.cjTextPrimary)
                        .lineLimit(1)
                    Spacer()
                    if file.fileStatus == .completed && file.bytesSaved > 0 {
                        Text("-\(file.bytesSaved.formattedFileSize)")
                            .font(.cjSecondary)
                            .foregroundStyle(Color.cjSuccess)
                    } else if file.fileStatus == .failed {
                        Text(file.errorMessage ?? "Error")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.cjError)
                            .lineLimit(1)
                    }
                }
            }

            if job.files.count > 5 {
                Text("Show all \(job.files.count) files →")
                    .font(.cjSecondary)
                    .foregroundStyle(Color.cjPrimary)
            }
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/History/HistoryView.swift
git commit -m "feat: redesign History screen — expandable job rows, filter pills, file previews"
```

---

### Task 10: Logs Screen Redesign

**Files:**
- Modify: `Sources/Views/Logs/LogsView.swift`

- [ ] **Step 1: Rewrite `LogsView.swift` with dark terminal panel and filter pills**

Replace the entire file:

```swift
// Sources/Views/Logs/LogsView.swift
import SwiftUI
import AppKit

struct LogsView: View {
    @State var viewModel: LogsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 10) {
                SearchField(text: $viewModel.searchText, placeholder: "Filter logs...")

                HStack(spacing: 4) {
                    FilterPill(label: "All", value: nil as LogLevel?, selection: $viewModel.filterLevel)
                    FilterPill(label: "Info", value: .info, selection: $viewModel.filterLevel)
                    FilterPill(label: "Warning", value: .warning, selection: $viewModel.filterLevel, labelColor: .cjWarning)
                    FilterPill(label: "Error", value: .error, selection: $viewModel.filterLevel, labelColor: .cjError)
                }

                Spacer()

                Toggle("Diagnostics", isOn: $viewModel.showDiagnostic)
                    .toggleStyle(.checkbox)
                    .font(.cjSecondary)

                Button {
                    Task {
                        if let url = await viewModel.exportLogs() {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                } label: {
                    Text("Export")
                        .font(.cjSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    Task { await viewModel.clearLogs() }
                } label: {
                    Text("Clear")
                        .font(.cjSecondary)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            // Log panel (dark terminal)
            if viewModel.filteredEntries.isEmpty {
                CJEmptyStateView(
                    icon: "📝",
                    title: "No logs yet",
                    message: "Logs will appear when you start processing"
                )
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(viewModel.filteredEntries) { entry in
                                logEntryRow(entry: entry)
                                    .id(entry.id)
                            }
                        }
                        .padding(12)
                    }
                    .background(Color.cjLogTerminal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(white: 0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .onChange(of: viewModel.filteredEntries.count) {
                        if let last = viewModel.filteredEntries.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color.cjBackground)
        .task {
            await viewModel.refresh()
        }
        .onChange(of: viewModel.showDiagnostic) {
            Task { await viewModel.refresh() }
        }
    }

    @ViewBuilder
    private func logEntryRow(entry: LogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .foregroundStyle(Color(white: 0.4))
                .frame(width: 72, alignment: .leading)

            Text(entry.level.rawValue.uppercased())
                .fontWeight(.medium)
                .foregroundStyle(logLevelColor(entry.level))
                .frame(width: 52, alignment: .leading)

            Text(entry.message)
                .foregroundStyle(logMessageColor(entry.level))
                .textSelection(.enabled)
                .lineLimit(3)
        }
        .font(.cjLogText)
        .padding(.vertical, 1)
    }

    private func logLevelColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return .cjLogInfo
        case .warning: return .cjLogWarn
        case .error: return .cjLogError
        case .diagnostic: return Color(white: 0.5)
        }
    }

    private func logMessageColor(_ level: LogLevel) -> Color {
        switch level {
        case .info: return Color(white: 0.83)
        case .warning: return .cjLogWarn
        case .error: return .cjLogError
        case .diagnostic: return Color(white: 0.5)
        }
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/Logs/LogsView.swift
git commit -m "feat: redesign Logs screen — dark terminal panel, filter pills, auto-scroll"
```

---

### Task 11: Settings Window — macOS Standard Preferences

**Files:**
- Modify: `Sources/Views/Settings/SettingsView.swift`
- Modify: `Sources/App/ChaoticJellyApp.swift`

- [ ] **Step 1: Update `SettingsView.swift` to use toolbar-style tabs**

The existing `Settings { ... }` scene in `ChaoticJellyApp.swift` already opens via ⌘,. We need to remove the fixed frame and use `.tabViewStyle(.grouped)` for the macOS toolbar appearance. Replace only the `SettingsView` struct and its `body`:

In `Sources/Views/Settings/SettingsView.swift`, replace lines 1-62 (the `SettingsView` struct) with:

```swift
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
```

Key changes: removed the fixed `.frame(width: 600, height: 450)`, changed "Sonarr / Radarr" to "Arr", updated SF Symbol to `antenna.radiowaves.left.and.right`, set `minWidth: 550` so the window can resize per pane.

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/Settings/SettingsView.swift
git commit -m "feat: Settings window — remove fixed size, consolidate Arr tab, toolbar icons"
```

---

### Task 12: First-Run Wizard

**Files:**
- Create: `Sources/Views/Wizard/FirstRunWizardView.swift`
- Modify: `Sources/App/ChaoticJellyApp.swift`

- [ ] **Step 1: Create `FirstRunWizardView.swift`**

```swift
// Sources/Views/Wizard/FirstRunWizardView.swift
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
                // Primary language (simplified — just English for now)
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

                // What to remove
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

                // Conservative mode
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
```

- [ ] **Step 2: Update `ChaoticJellyApp.swift` to show wizard on first run**

Replace the entire file:

```swift
// Sources/App/ChaoticJellyApp.swift
import SwiftUI
import SwiftData

@main
struct ChaoticJellyApp: App {
    let modelContainer: ModelContainer
    @State private var serviceContainer: ServiceContainer?
    @State private var showUpdateAlert = false
    @State private var showWizard = false
    @State private var navigateToScan = false

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
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add ChaoticJelly/Sources/Views/Wizard/FirstRunWizardView.swift ChaoticJelly/Sources/App/ChaoticJellyApp.swift
git commit -m "feat: add first-run wizard — tool detection, language prefs, onboarding"
```

---

### Task 13: Scan View — Add Stepper Integration

**Files:**
- Modify: `Sources/Views/Scan/ScanView.swift`

- [ ] **Step 1: Add WorkflowStepper to the ScanView when a scan is in progress or complete**

In `Sources/Views/Scan/ScanView.swift`, replace the `body` property (lines 8-18) with:

```swift
    var body: some View {
        VStack(spacing: 0) {
            // Show stepper when scan is active or complete
            if viewModel.isScanning || viewModel.isAnalyzing || viewModel.isProcessing ||
               (viewModel.currentJob?.jobStatus == .reviewing) {
                WorkflowStepper(
                    currentStep: .scan,
                    scanSummary: viewModel.currentJob.map { "\($0.files.count) files" }
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            if viewModel.isScanning || viewModel.isAnalyzing || viewModel.isProcessing {
                progressView
            } else if let job = viewModel.currentJob, job.jobStatus == .reviewing {
                // Analysis complete — prompt review
                analysisCompleteView(job: job)
            } else {
                configurationView
            }
        }
        .padding()
        .background(Color.cjBackground)
    }
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug build 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add ChaoticJelly/Sources/Views/Scan/ScanView.swift
git commit -m "feat: add WorkflowStepper to Scan view during active scans"
```

---

### Task 14: Final Build Verification and Cleanup

- [ ] **Step 1: Regenerate Xcode project and do a clean build**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodegen generate && xcodebuild -scheme ChaoticJelly -configuration Debug clean build 2>&1 | tail -10`

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Fix any remaining build errors**

If any errors appear, fix them. Common issues to check:
- Missing imports
- Type mismatches between `NavigationItem.queue` renamed to `.processing`
- Any references to old `StatCard` (still used by old code paths — if removed from Dashboard, check it's not referenced elsewhere)

- [ ] **Step 3: Run existing tests**

Run: `cd /Users/travishayes/Documents/Chaotic-Jelly/ChaoticJelly && xcodebuild -scheme ChaoticJelly -configuration Debug test 2>&1 | tail -15`

Expected: All existing tests pass (tests are unit tests for FFprobe parsing, AnalysisEngine, Job state, LanguageUtils — none depend on view code)

- [ ] **Step 4: Add .superpowers to .gitignore if not already there**

Run: `grep -q '.superpowers' /Users/travishayes/Documents/Chaotic-Jelly/.gitignore 2>/dev/null || echo '.superpowers/' >> /Users/travishayes/Documents/Chaotic-Jelly/.gitignore`

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: final build verification and cleanup for UX redesign"
```
