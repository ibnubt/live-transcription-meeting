import AVFoundation
import Speech

/// Transkripsi on-device (SpeechAnalyzer macOS 26) untuk satu sumber suara.
final class LiveTranscriber: @unchecked Sendable {
    let locale: Locale
    private var analyzer: SpeechAnalyzer?
    private var format: AVAudioFormat?
    private var converter: AVAudioConverter?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    /// (teks, final?) — teks non-final menggantikan teks non-final sebelumnya.
    var onText: ((String, Bool) -> Void)?
    var onError: ((Error) -> Void)?

    init(locale: Locale) { self.locale = locale }

    /// Pastikan model bahasa terpasang (unduh sekali, ±beberapa ratus MB).
    static func prepare(locale: Locale, progress: @escaping (Double) -> Void) async throws -> Locale {
        guard SpeechTranscriber.isAvailable else { throw AppError("Transkripsi on-device tidak tersedia di Mac ini") }
        guard let loc = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw AppError("Bahasa \(locale.identifier) tidak didukung")
        }
        let probe = SpeechTranscriber(locale: loc, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        if let req = try await AssetInventory.assetInstallationRequest(supporting: [probe]) {
            let obs = req.progress.observe(\.fractionCompleted) { p, _ in progress(p.fractionCompleted) }
            try await req.downloadAndInstall()
            obs.invalidate()
        }
        return loc
    }

    func start() async throws {
        let t = SpeechTranscriber(locale: locale, transcriptionOptions: [],
                                  reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        let a = SpeechAnalyzer(modules: [t])
        guard let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [t]) else {
            throw AppError("Format audio transkripsi tidak tersedia")
        }
        let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
        resultsTask = Task { [weak self] in
            do {
                for try await r in t.results {
                    self?.onText?(String(r.text.characters), r.isFinal)
                }
            } catch {
                self?.onError?(error)
            }
        }
        try await a.prepareToAnalyze(in: fmt)
        try await a.start(inputSequence: stream)
        format = fmt
        analyzer = a
        input = cont
    }

    func feed(_ buf: AVAudioPCMBuffer) {
        guard let input, let format, let out = convert(buf, to: format) else { return }
        input.yield(AnalyzerInput(buffer: out))
    }

    /// Selesaikan input dan tunggu semua hasil final keluar.
    func finish() async {
        input?.finish()
        input = nil
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value
    }

    private func convert(_ buf: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buf.format == format { return buf }
        if converter == nil || converter?.inputFormat != buf.format {
            converter = AVAudioConverter(from: buf.format, to: format)
            converter?.primeMethod = .none
            converter?.downmix = true
        }
        guard let converter else { return nil }
        let ratio = format.sampleRate / buf.format.sampleRate
        let cap = AVAudioFrameCount(Double(buf.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: cap) else { return nil }
        var consumed = false
        var err: NSError?
        let status = converter.convert(to: out, error: &err) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buf
        }
        if status == .error || out.frameLength == 0 { return nil }
        return out
    }
}
