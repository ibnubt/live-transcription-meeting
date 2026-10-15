import AVFoundation
import CoreAudio

/// Suara lawan bicara: semua audio keluaran sistem (Zoom/Meet/Teams/YouTube) lewat Core Audio process tap.
/// Izin yang dipakai: Privacy & Security → Screen & System Audio Recording → "System Audio Recording Only".
final class SystemAudioCapture {
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    private var format: AVAudioFormat?
    private let queue = DispatchQueue(label: "live.system-audio")
    private var deviceListener: AudioObjectPropertyListenerBlock?
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onStop: ((Error) -> Void)?

    func start() throws {
        stopInternal()
        let desc = CATapDescription(__monoGlobalTapButExcludeProcesses: [])
        desc.uuid = UUID()
        desc.muteBehavior = .unmuted
        desc.isPrivate = true
        var tap = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateProcessTap(desc, &tap), "membuat tap audio sistem")
        tapID = tap

        let outputUID = try defaultOutputUID()
        let agg: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Live Transcription Tap",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[kAudioSubTapDriftCompensationKey: true,
                                               kAudioSubTapUIDKey: desc.uuid.uuidString]],
        ]
        var aggID = AudioObjectID(kAudioObjectUnknown)
        try check(AudioHardwareCreateAggregateDevice(agg as CFDictionary, &aggID), "membuat perangkat agregat")
        aggregateID = aggID

        var asbd = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        try check(AudioObjectGetPropertyData(tapID, &addr, 0, nil, &size, &asbd), "membaca format tap")
        guard let fmt = AVAudioFormat(streamDescription: &asbd) else { throw AppError("Format tap tidak dikenal") }
        format = fmt

        var proc: AudioDeviceIOProcID?
        try check(AudioDeviceCreateIOProcIDWithBlock(&proc, aggID, queue) { [weak self] _, input, _, _, _ in
            guard let self, let fmt = self.format, let buf = Self.copy(input, format: fmt) else { return }
            self.onBuffer?(buf)
        }, "membuat IOProc")
        procID = proc
        try check(AudioDeviceStart(aggID, proc), "memulai tangkapan audio")
        listenForOutputChange()
    }

    func stop() {
        removeListener()
        stopInternal()
    }

    private func stopInternal() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown { AudioHardwareDestroyProcessTap(tapID) }
        procID = nil
        aggregateID = kAudioObjectUnknown
        tapID = kAudioObjectUnknown
    }

    /// Output pindah (mis. AirPods tersambung) → bangun ulang tap di perangkat baru.
    private func listenForOutputChange() {
        guard deviceListener == nil else { return }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            do { try self.start() } catch { self.onStop?(error) }
        }
        deviceListener = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, queue, block)
    }

    private func removeListener() {
        guard let block = deviceListener else { return }
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, queue, block)
        deviceListener = nil
    }

    private func defaultOutputUID() throws -> String {
        var dev = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        try check(AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &dev),
                  "mencari output default")
        var uid: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        addr.mSelector = kAudioDevicePropertyDeviceUID
        try check(AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &uid), "membaca UID output")
        guard let uid else { throw AppError("UID output kosong") }
        return uid.takeRetainedValue() as String
    }

    /// Salin buffer IOProc (hanya valid selama callback) ke AVAudioPCMBuffer milik sendiri.
    private static func copy(_ list: UnsafePointer<AudioBufferList>, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let src = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))
        guard let first = src.first, first.mDataByteSize > 0 else { return nil }
        let frames = first.mDataByteSize / format.streamDescription.pointee.mBytesPerFrame
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        let dst = UnsafeMutableAudioBufferListPointer(buf.mutableAudioBufferList)
        for i in 0..<min(src.count, dst.count) {
            guard let s = src[i].mData, let d = dst[i].mData else { continue }
            memcpy(d, s, Int(min(src[i].mDataByteSize, dst[i].mDataByteSize)))
        }
        return buf
    }

    private func check(_ status: OSStatus, _ what: String) throws {
        if status != noErr { throw AppError("Gagal \(what) (OSStatus \(status))") }
    }
}

/// Suara saya: mikrofon default.
final class MicCapture {
    private var engine = AVAudioEngine()
    private var observer: NSObjectProtocol?
    private(set) var running = false
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    func start() throws {
        guard !running else { return }
        engine = AVAudioEngine()
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        guard fmt.sampleRate > 0, fmt.channelCount > 0 else { throw AppError("Mikrofon tidak tersedia") }
        input.installTap(onBus: 0, bufferSize: 2048, format: fmt) { [weak self] buf, _ in
            self?.onBuffer?(buf)
        }
        engine.prepare()
        try engine.start()
        running = true
        // Ganti perangkat (mis. AirPods tersambung) → mulai ulang dengan format baru.
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            guard let self, self.running else { return }
            self.stop()
            try? self.start()
        }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        running = false
    }
}
