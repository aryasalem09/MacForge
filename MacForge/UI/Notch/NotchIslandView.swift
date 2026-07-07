import SwiftUI

/// The island silhouette: flat top edge flush with the screen, top corners
/// flaring outward the way the physical notch meets the bezel, and rounded
/// bottom corners. Both radii animate so the shape can morph between states.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let topR = min(topRadius, rect.width / 4, rect.height / 2)
        let bottomR = min(bottomRadius, rect.width / 2 - topR, rect.height - topR)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR, y: rect.minY + topR),
            control: CGPoint(x: rect.minX + topR, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topR, y: rect.maxY - bottomR))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topR + bottomR, y: rect.maxY),
            control: CGPoint(x: rect.minX + topR, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topR - bottomR, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topR, y: rect.maxY - bottomR),
            control: CGPoint(x: rect.maxX - topR, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topR, y: rect.minY + topR))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topR, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// Root of the island panel. The window stays put; this view morphs the
/// island shape between collapsed, compact, and expanded with a spring, the
/// same way the iPhone's Dynamic Island grows out of its cutout.
struct NotchIslandRootView: View {
    @ObservedObject var model: NotchIslandLayoutModel
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter
    @EnvironmentObject private var liveIslandCoordinator: LiveIslandCoordinator

    private var state: NotchIslandPresentationState { model.displayState }

    private var isCollapsed: Bool {
        state == .collapsed || state == .hidden
    }

    private var hoverScale: CGFloat {
        isCollapsed && environment.notchHoverState == .hoverPending ? 1.05 : 1.0
    }

    private var bottomRadius: CGFloat {
        switch state {
        case .hidden, .collapsed: 9
        case .compact: 13
        case .expanded: 24
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if let layout = model.layout {
                island(layout: layout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func island(layout: NotchIslandLayout) -> some View {
        let size = layout.shapeSize(for: state)
        let topRadius = CGFloat(NotchIslandLayout.topCornerFlare)
        let shape = NotchShape(topRadius: topRadius, bottomRadius: bottomRadius)

        return ZStack(alignment: .top) {
            content(layout: layout)
        }
        .frame(width: size.width, height: size.height)
        .background(shape.fill(islandFill))
        .clipShape(shape)
        .overlay {
            if !isCollapsed {
                shape.stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .compositingGroup()
        .shadow(
            color: .black.opacity(isCollapsed ? 0 : 0.5),
            radius: isCollapsed ? 0 : 14,
            x: 0,
            y: 5
        )
        .scaleEffect(hoverScale, anchor: .top)
        .contentShape(shape)
        .onTapGesture {
            environment.toggleNotchIslandExpansionByClick()
        }
        .gesture(swipeGesture)
        .onExitCommand {
            activityCenter.collapse()
        }
        .overlay(alignment: .bottom) {
            if environment.notchConfig.showPlacementDebugOverlay {
                debugOverlay(layout: layout)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.82), value: state)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: hoverScale)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notch Island")
    }

    private var islandFill: AnyShapeStyle {
        if isCollapsed {
            // Pure black so the collapsed shape is indistinguishable from the
            // physical camera housing it sits on.
            return AnyShapeStyle(Color.black)
        }
        switch environment.notchConfig.materialStyle {
        case .dark:
            return AnyShapeStyle(Color.black)
        case .glass:
            return AnyShapeStyle(.ultraThinMaterial)
        }
    }

    @ViewBuilder
    private func content(layout: NotchIslandLayout) -> some View {
        switch state {
        case .hidden, .collapsed:
            Color.clear
        case .compact:
            NotchIslandCompactView(layout: layout)
                .transition(contentTransition)
        case .expanded:
            NotchIslandExpandedView(topContentInset: layout.notchFrame.rect.height)
                .transition(contentTransition)
        }
    }

    /// Content fades in slightly after the shape starts growing and vanishes
    /// immediately when it shrinks, so text never overflows the island.
    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.92, anchor: .top))
                .animation(.easeOut(duration: 0.22).delay(0.08)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onEnded { value in
                handleSwipe(value.translation)
            }
    }

    private func handleSwipe(_ translation: CGSize) {
        if abs(translation.height) > abs(translation.width) {
            if translation.height > 10 {
                environment.expandNotchIsland()
            } else if translation.height < -10 {
                environment.collapseNotchIsland()
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

    private func debugOverlay(layout: NotchIslandLayout) -> some View {
        let notch = layout.notchFrame.rect
        return Text("\(MacForgeBuildInfo.label) | \(state.rawValue) | hover \(environment.notchHoverState.rawValue) | notch \(Int(notch.width))x\(Int(notch.height))\(layout.hasPhysicalNotch ? "" : " (virtual)")")
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.74))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.black.opacity(0.72), in: Capsule())
            .padding(.bottom, 4)
    }
}
