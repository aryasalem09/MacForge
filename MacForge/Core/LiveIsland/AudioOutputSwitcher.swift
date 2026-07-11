import CoreAudio
import Foundation
import IOKit.pwr_mgt

struct AudioOutputDevice: Identifiable, Hashable {
    var id: AudioObjectID
    var name: String
}

/// Lists real output devices and switches the system default — the "tap the
/// island to move sound to AirPods / speakers / monitor" feature. Pure public
/// CoreAudio.
@MainActor
final class AudioOutputSwitcher: ObservableObject {
    /// Picks the device after `currentID` in `devices`, wrapping around.
    /// Pure so tests can cover the cycle order without CoreAudio.
    static func nextDevice(after currentID: AudioObjectID?, in devices: [AudioOutputDevice]) -> AudioOutputDevice? {
        guard !devices.isEmpty else { return nil }
        guard let currentID, let index = devices.firstIndex(where: { $0.id == currentID }) else {
            return devices.first
        }
        return devices[(index + 1) % devices.count]
    }

    func currentOutputDeviceID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        guard status == noErr, deviceID != AudioObjectID(kAudioObjectUnknown) else { return nil }
        return deviceID
    }

    func currentOutputDeviceName() -> String? {
        guard let id = currentOutputDeviceID() else { return nil }
        return deviceName(id)
    }

    /// All devices with output channels, in system order.
    func outputDevices() -> [AudioOutputDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else {
            return []
        }
        var ids = [AudioObjectID](repeating: AudioObjectID(kAudioObjectUnknown), count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return []
        }

        return ids.compactMap { id in
            guard hasOutputChannels(id), let name = deviceName(id) else { return nil }
            return AudioOutputDevice(id: id, name: name)
        }
    }

    /// Switches the system default output. Returns the device switched to.
    @discardableResult
    func cycleToNextOutput() -> AudioOutputDevice? {
        let devices = outputDevices()
        guard let next = Self.nextDevice(after: currentOutputDeviceID(), in: devices),
              next.id != currentOutputDeviceID() else {
            return nil
        }
        return setDefaultOutput(next) ? next : nil
    }

    func setDefaultOutput(_ device: AudioOutputDevice) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = device.id
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioObjectID>.size),
            &deviceID
        )
        return status == noErr
    }

    private func hasOutputChannels(_ id: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        // bindMemory (not assumingMemoryBound) — the allocation was never
        // bound to a type, so assuming a binding is undefined behavior.
        let bufferList = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, bufferList) == noErr else { return false }
        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) } > 0
    }

    private func deviceName(_ id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name)
        guard status == noErr, let cfName = name?.takeRetainedValue() else { return nil }
        return cfName as String
    }
}

/// Keep-awake ("caffeinate") toggle: a public IOKit power assertion that stops
/// the display from sleeping while enabled. Runtime-only — never persisted, so
/// a relaunch always starts with the Mac's normal sleep behavior.
@MainActor
final class KeepAwakeController: ObservableObject {
    @Published private(set) var isActive = false

    private var assertionID: IOPMAssertionID = 0

    func toggle() {
        setActive(!isActive)
    }

    func setActive(_ active: Bool) {
        guard active != isActive else { return }
        if active {
            var id: IOPMAssertionID = 0
            let status = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "MacForge keep awake" as CFString,
                &id
            )
            guard status == kIOReturnSuccess else { return }
            assertionID = id
            isActive = true
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            isActive = false
        }
    }
}
