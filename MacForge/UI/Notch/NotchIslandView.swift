import SwiftUI

struct AttachedNotchShellShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

struct NotchIslandShellBackground: View {
    var cornerRadius: CGFloat
    var materialStyle: NotchIslandMaterialStyle

    var body: some View {
        AttachedNotchShellShape(cornerRadius: cornerRadius)
            .fill(backgroundFill)
            .overlay {
                AttachedNotchShellShape(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.26), radius: 10, x: 0, y: 5)
    }

    private var backgroundFill: AnyShapeStyle {
        switch materialStyle {
        case .dark:
            AnyShapeStyle(Color.black.opacity(0.96))
        case .glass:
            AnyShapeStyle(.ultraThinMaterial)
        }
    }
}

extension NotchShelfConfig {
    var attachedContentTopPadding: CGFloat {
        guard overlayMenuBarForAttachedNotch else { return 0 }
        return CGFloat((attachedShellHeight - compactHeight).clamped(to: 0...44))
    }
}

struct NotchIslandView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator
    @State private var dragStartX: Double = 0
    @State private var dragStartY: Double = 0
    @State private var calibrationDragActive = false

    var body: some View {
        Group {
            switch activityCenter.presentationState {
            case .hidden, .collapsed:
                NotchIslandCollapsedView()
            case .compact:
                NotchIslandCompactView()
            case .expanded:
                NotchIslandExpandedView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if environment.notchConfig.showPlacementDebugOverlay {
                Text(debugOverlayText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.white.opacity(0.74))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.72), in: Capsule())
                    .padding(.bottom, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            environment.toggleNotchIslandExpansionByClick()
        }
        .onHover { isHovering in
            environment.handleNotchHoverChanged(isHovering)
        }
        .gesture(
            DragGesture(minimumDistance: 14)
                .onChanged { value in
                    if environment.notchConfig.calibrationModeEnabled {
                        if !calibrationDragActive {
                            calibrationDragActive = true
                            dragStartX = environment.notchConfig.islandHorizontalOffset
                            dragStartY = environment.notchConfig.islandVerticalOffset
                            environment.beginNotchCalibrationDrag()
                        }
                        environment.updateNotchCalibrationDrag(
                            startX: dragStartX,
                            startY: dragStartY,
                            translation: value.translation
                        )
                    }
                }
                .onEnded { value in
                    if environment.notchConfig.calibrationModeEnabled {
                        calibrationDragActive = false
                        environment.endNotchCalibrationDrag()
                        return
                    }
                    handleSwipe(value.translation)
                }
        )
        .onExitCommand {
            activityCenter.collapse()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notch Island")
    }

    private func handleSwipe(_ translation: CGSize) {
        if abs(translation.height) > abs(translation.width) {
            if translation.height > 10 {
                activityCenter.expand()
            } else if translation.height < -10 {
                activityCenter.collapse()
            }
            return
        }

        if translation.width < -24 {
            performSupportedMediaAction(.next)
        } else if translation.width > 24 {
            performSupportedMediaAction(.previous)
        }
    }

    private func performSupportedMediaAction(_ kind: LiveIslandActionKind) {
        guard liveIslandCoordinator.currentSnapshot.actions.contains(where: { $0.kind == kind && $0.isEnabled }) else {
            return
        }
        Task {
            let result = await liveIslandCoordinator.performCurrentAction(kind)
            if !result.success {
                environment.append(result)
            }
        }
    }

    private var debugOverlayText: String {
        let config = environment.notchConfig
        let snapshot = liveIslandCoordinator.currentSnapshot
        return "\(MacForgeBuildInfo.label) | state \(activityCenter.presentationState.rawValue) | hover \(environment.notchHoverState.rawValue) | \(snapshot.kind.rawValue) | shell \(Int(config.attachedShellHeight)) | x \(Int(config.islandHorizontalOffset)) | y \(Int(config.islandVerticalOffset))"
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
