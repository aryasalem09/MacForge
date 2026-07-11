import AppKit
import AVFoundation
import SwiftUI

/// Owns the capture session for the Mirror tab. The session only runs while
/// the tab is actually visible — the camera indicator light goes off the
/// moment the user switches away or the island collapses.
@MainActor
final class CameraMirrorController: ObservableObject {
    enum Status: Equatable {
        case idle
        case unauthorized
        case running
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    let session = AVCaptureSession()
    private var configured = false
    /// Desired state, so a stop() that races an in-flight async start (the
    /// permission prompt or the blocking startRunning call) still wins: the
    /// start path re-checks this after every suspension point.
    private var shouldBeRunning = false

    func start() {
        shouldBeRunning = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    guard self.shouldBeRunning else { return }
                    if granted {
                        self.configureAndRun()
                    } else {
                        self.status = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            status = .unauthorized
        @unknown default:
            status = .unauthorized
        }
    }

    func stop() {
        shouldBeRunning = false
        status = .idle
        let session = self.session
        Task.detached(priority: .userInitiated) {
            // stopRunning on a never-started session is a harmless no-op;
            // always issuing it closes the gap where startRunning is still
            // in flight when stop() is called.
            session.stopRunning()
        }
    }

    private func configureAndRun() {
        guard shouldBeRunning else { return }
        if !configured {
            session.beginConfiguration()
            session.sessionPreset = .medium
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                status = .failed("No camera is available.")
                return
            }
            session.addInput(input)
            session.commitConfiguration()
            configured = true
        }

        guard !session.isRunning else {
            status = .running
            return
        }
        let session = self.session
        Task.detached(priority: .userInitiated) {
            // startRunning blocks; never call it on the main thread.
            session.startRunning()
            await MainActor.run { [weak self] in
                guard let self else {
                    session.stopRunning()
                    return
                }
                if !self.shouldBeRunning {
                    // stop() raced our startup — honor it.
                    Task.detached(priority: .userInitiated) {
                        session.stopRunning()
                    }
                    return
                }
                self.status = session.isRunning ? .running : .failed("The camera could not be started.")
            }
        }
    }

    func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// AVCaptureVideoPreviewLayer wrapper, mirrored like a real mirror.
struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// The Mirror tab: a quick "how do I look" check before a call, exactly like
/// NotchNook/Boring Notch. Nothing is recorded — it's a live preview only.
struct NotchMirrorView: View {
    @StateObject private var controller = CameraMirrorController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch controller.status {
            case .running:
                CameraPreviewView(session: controller.session)
                    .aspectRatio(16.0 / 10.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    )
                Label("Live preview only — nothing is recorded.", systemImage: "eye.slash")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            case .unauthorized:
                permissionCard
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            case .idle:
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                    Spacer()
                }
                .frame(height: 120)
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
        .accessibilityLabel("Camera mirror")
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Camera access needed", systemImage: "video.slash")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            Text("Allow MacForge to use the camera to check yourself before a call. The preview is local and never recorded.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Camera Settings") {
                controller.openCameraPrivacySettings()
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// The Clip tab: local clipboard history. Click a row to copy it back.
struct NotchClipboardView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var clipboard: ClipboardHistoryCenter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(
                    clipboard.isPaused ? "Capture paused" : "Click an item to copy it",
                    systemImage: clipboard.isPaused ? "pause.circle" : "doc.on.clipboard"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Button {
                    clipboard.setPaused(!clipboard.isPaused)
                } label: {
                    Image(systemName: clipboard.isPaused ? "play.fill" : "pause.fill")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
                .help(clipboard.isPaused ? "Resume capturing" : "Pause capturing")
                Button {
                    clipboard.clear()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(clipboard.items.isEmpty ? 0.34 : 0.82))
                .disabled(clipboard.items.isEmpty)
                .help("Clear history")
            }

            if clipboard.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Nothing copied yet", systemImage: "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Everything you copy shows up here. History stays in memory and clears when MacForge quits; passwords marked by password managers are never captured.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            } else {
                // The expanded island's outer scroll handles overflow, so the
                // whole history is reachable (and removable), not just a slice.
                VStack(spacing: 5) {
                    ForEach(clipboard.items) { item in
                        clipRow(item)
                    }
                }
            }
        }
        .accessibilityLabel("Clipboard history")
    }

    private func clipRow(_ item: ClipboardHistoryItem) -> some View {
        Button {
            clipboard.copyToPasteboard(item)
            environment.flashClipboardCopied(item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.symbolName)
                    .font(.system(size: 11))
                    .foregroundStyle(.mint)
                    .frame(width: 16)
                Text(item.preview)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(item.capturedAt, style: .relative)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy") {
                clipboard.copyToPasteboard(item)
                environment.flashClipboardCopied(item)
            }
            Button("Remove", role: .destructive) {
                clipboard.remove(item)
            }
        }
        .help(item.preview)
    }
}
