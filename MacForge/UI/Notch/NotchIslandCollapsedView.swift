import SwiftUI

/// Animated audio-visualizer bars shown in the island's right ear while
/// media is playing, matching the iPhone Dynamic Island's waveform.
struct NotchAudioBarsView: View {
    var isAnimating: Bool
    var tint: Color = .mint

    private let barCount = 4
    private let idleHeight: CGFloat = 4

    var body: some View {
        // Continuous timeline (no minimumInterval) so the bars glide at the
        // display's refresh rate instead of stepping at ~14 fps.
        TimelineView(.animation(paused: !isAnimating)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(tint)
                        .frame(width: 3, height: barHeight(time: time, index: index))
                }
            }
            .frame(height: 16, alignment: .center)
        }
        .animation(.easeOut(duration: 0.2), value: isAnimating)
        .accessibilityLabel(isAnimating ? "Audio playing" : "Audio paused")
    }

    private func barHeight(time: TimeInterval, index: Int) -> CGFloat {
        guard isAnimating else { return idleHeight }
        let phase = time * (4.6 + Double(index) * 1.9) + Double(index) * 1.4
        let normalized = (sin(phase) + 1) / 2
        return idleHeight + CGFloat(normalized) * 12
    }
}
