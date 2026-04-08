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
