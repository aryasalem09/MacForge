import SwiftUI

struct NotchIslandView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var activityCenter: NotchIslandActivityCenter

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
        .contentShape(Rectangle())
        .onTapGesture {
            guard environment.notchConfig.expandOnClick else { return }
            if activityCenter.presentationState == .expanded {
                activityCenter.collapse()
            } else {
                activityCenter.expand()
            }
        }
        .onHover { isHovering in
            guard environment.notchConfig.expandOnHover else { return }
            if isHovering {
                activityCenter.expand()
            } else if activityCenter.currentActivity == nil {
                activityCenter.collapse()
            }
        }
        .onExitCommand {
            activityCenter.collapse()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notch Island")
    }
}
