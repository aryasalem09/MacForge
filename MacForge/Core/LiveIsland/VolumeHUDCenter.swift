import AudioToolbox
import CoreAudio
import Foundation

/// Listens for output-volume and mute changes on the default audio device and
/// pushes a short-lived HUD snapshot into the Live Island — the notch mirrors
/// the system volume overlay the moment the user taps a volume key. Entirely
/// local CoreAudio observation; no key interception and no permissions.
@MainActor
final class VolumeHUDCenter {
    nonisolated static let providerID = "volume-hud"

    var onHUDEvent: ((LiveIslandSnapshot) -> Void)?
    private(set) var isRunning = false

    private var deviceID = AudioObjectID(kAudioObjectUnknown)
    private var deviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?

    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        guard !isRunning else { return }
        isRunning = true
        attachToDefaultDevice()
        installDefaultDeviceListener()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        detachFromDevice()
        removeDefaultDeviceListener()
    }

    /// Builds the HUD snapshot for the current output state. Exposed for the
    /// settings test button.
    func makeSnapshot(now: Date = Date()) -> LiveIslandSnapshot? {
        guard let volume = currentVolume() else { return nil }
        let muted = isMuted()
        let level = muted ? 0 : Double(volume).clamped(to: 0...1)

        let symbolName: String
        if muted || level == 0 {
            symbolName = "speaker.slash.fill"
        } else if level < 0.34 {
            symbolName = "speaker.wave.1.fill"
        } else if level < 0.67 {
            symbolName = "speaker.wave.2.fill"
        } else {
            symbolName = "speaker.wave.3.fill"
        }

        return LiveIslandSnapshot(
            providerID: Self.providerID,
            providerName: "Volume",
            kind: .hud,
            priority: .hud,
            title: muted ? "Muted" : "Volume",
            subtitle: "\(Int((level * 100).rounded()))%",
            symbolName: symbolName,
            progress: level,
            startedAt: now,
            expiresAt: now.addingTimeInterval(1.6)
        )
    }

    func publishCurrentLevel() {
        guard let snapshot = makeSnapshot() else { return }
        onHUDEvent?(snapshot)
    }

    // MARK: - CoreAudio plumbing

    private func attachToDefaultDevice() {
        detachFromDevice()
        guard let resolved = Self.defaultOutputDeviceID() else { return }
        deviceID = resolved

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.publishCurrentLevel()
            }
        }
        deviceListenerBlock = block

        if AudioObjectHasProperty(deviceID, &Self.volumeAddress) {
            AudioObjectAddPropertyListenerBlock(deviceID, &Self.volumeAddress, .main, block)
        }
        if AudioObjectHasProperty(deviceID, &Self.muteAddress) {
            AudioObjectAddPropertyListenerBlock(deviceID, &Self.muteAddress, .main, block)
        }
    }

    private func detachFromDevice() {
        guard deviceID != AudioObjectID(kAudioObjectUnknown), let block = deviceListenerBlock else {
            deviceID = AudioObjectID(kAudioObjectUnknown)
            deviceListenerBlock = nil
            return
        }
        if AudioObjectHasProperty(deviceID, &Self.volumeAddress) {
            AudioObjectRemovePropertyListenerBlock(deviceID, &Self.volumeAddress, .main, block)
        }
        if AudioObjectHasProperty(deviceID, &Self.muteAddress) {
            AudioObjectRemovePropertyListenerBlock(deviceID, &Self.muteAddress, .main, block)
        }
        deviceID = AudioObjectID(kAudioObjectUnknown)
        deviceListenerBlock = nil
    }

    private func installDefaultDeviceListener() {
        guard defaultDeviceListenerBlock == nil else { return }
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self, self.isRunning else { return }
                // AirPods connect, displays change — follow the new default
                // output device silently (no HUD for the switch itself).
                self.attachToDefaultDevice()
            }
        }
        defaultDeviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &Self.defaultDeviceAddress,
            .main,
            block
        )
    }

    private func removeDefaultDeviceListener() {
        guard let block = defaultDeviceListenerBlock else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &Self.defaultDeviceAddress,
            .main,
            block
        )
        defaultDeviceListenerBlock = nil
    }

    private static func defaultOutputDeviceID() -> AudioObjectID? {
        var resolved = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultDeviceAddress,
            0,
            nil,
            &size,
            &resolved
        )
        guard status == noErr, resolved != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return resolved
    }

    private func currentVolume() -> Float32? {
        guard deviceID != AudioObjectID(kAudioObjectUnknown),
              AudioObjectHasProperty(deviceID, &Self.volumeAddress) else {
            return nil
        }
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &Self.volumeAddress, 0, nil, &size, &volume)
        guard status == noErr else { return nil }
        return volume
    }

    private func isMuted() -> Bool {
        guard deviceID != AudioObjectID(kAudioObjectUnknown),
              AudioObjectHasProperty(deviceID, &Self.muteAddress) else {
            return false
        }
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &Self.muteAddress, 0, nil, &size, &muted)
        return status == noErr && muted == 1
    }
}
