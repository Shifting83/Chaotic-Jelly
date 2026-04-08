import SwiftUI

struct StatusDot: View {
    let color: Color
    var pulsing: Bool = false

    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(pulsing && isAnimating ? 0.4 : 1.0)
            .animation(pulsing ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: isAnimating)
            .onAppear {
                if pulsing { isAnimating = true }
            }
            .onChange(of: pulsing) { _, newValue in
                isAnimating = newValue
            }
    }
}

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
