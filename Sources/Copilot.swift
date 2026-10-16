import AVFoundation
import Foundation
import Speech
import SwiftUI

/// Puncak level audio dari thread audio, dibaca UI tiap ±150 ms.
final class PeakMeter: @unchecked Sendable {
    private let lock = NSLock()
    private var peak: Float = 0

    func push(_ b: AVAudioPCMBuffer) {
        guard let ch = b.floatChannelData else { return }
        var m: Float = 0
        for i in 0..<Int(b.frameLength) { m = max(m, abs(ch[0][i])) }
        lock.lock()
        peak = max(peak, m)
        lock.unlock()
    }

    func take() -> Float {
        lock.lock()
        defer { peak = 0; lock.unlock() }
        return peak
    }
}

/// Level suara terpisah dari Copilot supaya hanya indikatornya yang digambar ulang.
@MainActor
final class Levels: ObservableObject {
    @Published var them: Float = 0
    @Published var me: Float = 0
    var heardThem = false
}

@MainActor
final class Copilot: ObservableObject {
    @Published var lines: [Line] = []
    @Published var volatileThem = ""
    @Published var volatileMe = ""
    @Published var answers: [Answer] = []
    @Published var status = "Menyiapkan…"
    @Published var listening = false
    @Published var tick = 0
    @Published var auto = true
    @Published var micOn = true { didSet { micChanged() } }
    @Published var fontSize: Double = 16 { didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") } }
    @Published var opacity: Double = 0.94 {
        didSet {
            UserDefaults.standard.set(opacity, forKey: "opacity")
            onOpacity?(opacity)
        }
    }
    var onOpacity: ((Double) -> Void)?
    /// Poin (dilirik) vs naskah (dibaca). Default dari ANSWER_STYLE di .env, bisa diganti dari menu.
    @Published var cueMode = true { didSet { UserDefaults.standard.set(cueMode, forKey: "cueMode") } }
    /// Mode ringkas: hanya jawaban, panel kecil di bawah kamera.
    @Published var compact = false { didSet { UserDefaults.standard.set(compact, forKey: "compact") } }
    /// Kalimat yang digulir ke atas oleh ⌃⌥→ / ⌃⌥← di mode ringkas.
    @Published var focusIndex = 0
    /// Mode ringkas: false = hanya jawaban terbaru (default), true = seluruh percakapan bisa digulir.
    @Published var convoView = false { didSet { UserDefaults.standard.set(convoView, forKey: "convoView") } }
    /// Catatan tugas (mis. desain HackerRank yang baru saya kerjakan) — ikut dikirim ke AI.
    @Published var taskNotes = "" { didSet { UserDefaults.standard.set(taskNotes, forKey: "taskNotes") } }

    private(set) var config: Config
    private(set) var knowledge = Knowledge()
    private var llm: LLMClient!
    let levels = Levels()
    private let themPeak = PeakMeter()
    private let mePeak = PeakMeter()
    private let system = SystemAudioCapture()
    private let mic = MicCapture()
    private var themT: LiveTranscriber?
    private var meT: LiveTranscriber?
    private var turnTimer: Task<Void, Never>?
    private var answerTask: Task<Void, Never>?
    private var answeredLineID: UUID?
    private var recentBridges: [String] = []
    private var loggedIDs = Set<UUID>()
    private let log: TranscriptLog

    init(config: Config) {
        self.config = config
        log = TranscriptLog(dir: config.home.appendingPathComponent("transkrip"))
        let d = UserDefaults.standard
        if d.object(forKey: "fontSize") != nil { fontSize = d.double(forKey: "fontSize") }
        if d.object(forKey: "opacity") != nil { opacity = d.double(forKey: "opacity") }
        cueMode = d.object(forKey: "cueMode") != nil ? d.bool(forKey: "cueMode") : config.str("ANSWER_STYLE", "poin") != "naskah"
        compact = d.bool(forKey: "compact")
        taskNotes = d.string(forKey: "taskNotes") ?? ""
        convoView = d.bool(forKey: "convoView")
        reload()
    }

    /// Muat ulang .env, dokumen, gaya.md, dan contoh ucapan — tanpa restart.
    func reload() {
        config = Config.load()
        knowledge = KnowledgeLoader.load(home: config.home)
        // Ucapan lama dari transkrip = bacaan saya yang penuh "uh"; hanya dipakai kalau diminta.
        if config.str("STYLE_EXAMPLES", "0") != "1" { knowledge.examples = [] }
        llm = LLMClient(endpoints: config.endpoints(), hedge: config.num("LLM_HEDGE_SECONDS", 1.5),
                        maxTokens: Int(config.num("LLM_MAX_TOKENS", 220)))
    }

    var docsSummary: String {
        let docs = knowledge.docNames.isEmpty ? "belum ada dokumen" : knowledge.docNames.joined(separator: ", ")
        let llms = llm.endpoints.map(\.label).joined(separator: " → ")
        return "\(docs) · gaya.md \(knowledge.style.isEmpty ? "kosong" : "✓") · \(knowledge.examples.count) contoh ucapan · LLM: \(llms)"
    }

    // MARK: - Mulai mendengar

    func start() async {
        status = "Minta izin mikrofon…"
        let micOK = await AVCaptureDevice.requestAccess(for: .audio)
        _ = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        do {
            status = "Menyiapkan model transkripsi…"
            let loc = try await LiveTranscriber.prepare(locale: Locale(identifier: config.str("TRANSCRIBE_LOCALE", "en-US"))) { p in
                DispatchQueue.main.async { self.status = "Mengunduh model bahasa… \(Int(p * 100))%" }
            }

            let them = LiveTranscriber(locale: loc)
            them.onText = { [weak self] t, fin in DispatchQueue.main.async { self?.onText(.them, t, fin) } }
            try await them.start()
            themT = them
            let themPeak = self.themPeak
            system.onBuffer = { [weak them] b in
                themPeak.push(b)
                them?.feed(b)
            }
            system.onStop = { [weak self] e in DispatchQueue.main.async { self?.status = "Audio sistem berhenti: \(e.localizedDescription)" } }
            do {
                try system.start()
            } catch {
                status = "Audio sistem: \(error.localizedDescription). Cek izin “System Audio Recording Only” untuk Live Transcription, lalu buka ulang app"
                return
            }

            if micOK {
                let me = LiveTranscriber(locale: loc)
                me.onText = { [weak self] t, fin in DispatchQueue.main.async { self?.onText(.me, t, fin) } }
                try await me.start()
                meT = me
                let mePeak = self.mePeak
                mic.onBuffer = { [weak me] b in
                    mePeak.push(b)
                    me?.feed(b)
                }
                if micOn { try? mic.start() }
            }
            listening = true
            status = micOK ? "Mendengarkan" : "Mendengarkan (mic tidak diizinkan)"
            watchLevels()
        } catch {
            status = "Gagal: \(error.localizedDescription)"
        }
    }

    /// Perbarui indikator level; beri petunjuk kalau audio sistem tidak pernah masuk.
    private func watchLevels() {
        let started = Date()
        Task { [weak self] in
            var hinted = false
            while let self {
                self.levels.them = self.themPeak.take()
                self.levels.me = self.micOn ? self.mePeak.take() : 0
                if self.levels.them > 0.002 {
                    self.levels.heardThem = true
                    if hinted {
                        hinted = false
                        self.status = "Mendengarkan"
                    }
                }
                if !hinted, !self.levels.heardThem, Date().timeIntervalSince(started) > 20 {
                    hinted = true
                    self.status = "Belum ada suara sistem masuk. Putar audio; kalau indikator biru tetap diam, nyalakan “System Audio Recording Only” untuk Live Transcription lalu buka ulang app"
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    private func micChanged() {
        guard meT != nil else { return }
        if micOn { try? mic.start() } else { mic.stop(); volatileMe = "" }
    }

    // MARK: - Transkrip

    private func onText(_ who: Speaker, _ text: String, _ isFinal: Bool) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch who {
        case .them:
            if isFinal {
                volatileThem = ""
                if !clean.isEmpty { appendFinal(.them, clean) }
                scheduleTurnEnd()
            } else {
                volatileThem = clean
                if !clean.isEmpty { turnTimer?.cancel() }
            }
        case .me:
            if isFinal {
                volatileMe = ""
                if !clean.isEmpty, !isEcho(clean) { appendFinal(.me, clean) }
            } else {
                volatileMe = isEcho(clean) ? "" : clean
            }
        }
        tick &+= 1
    }

    private func appendFinal(_ who: Speaker, _ text: String) {
        let now = Date()
        if var last = lines.last, last.speaker == who, now.timeIntervalSince(last.updated) < 3, last.id != answeredLineID {
            last.text += " " + text
            last.updated = now
            lines[lines.count - 1] = last
        } else {
            flushLog()
            lines.append(Line(speaker: who, text: text, start: now, updated: now))
        }
    }

    /// Mic menangkap suara speaker (tanpa headphone) → buang kalau mirip ucapan mereka barusan.
    private func isEcho(_ text: String) -> Bool {
        let mine = words(text)
        guard !mine.isEmpty else { return false }
        let recent = lines.filter { $0.speaker == .them && Date().timeIntervalSince($0.updated) < 10 }.map(\.text) + [volatileThem]
        for t in recent {
            let theirs = words(t)
            let overlap = Double(mine.intersection(theirs).count) / Double(mine.count)
            if overlap >= 0.7 { return true }
        }
        return false
    }

    private func words(_ s: String) -> Set<String> {
        Set(s.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }

    /// Tulis baris yang sudah selesai ke file (baris terakhir masih bisa bertambah, kecuali `closing`).
    func flushLog(closing: UUID? = nil) {
        for l in lines where !loggedIDs.contains(l.id) && (l.id != lines.last?.id || l.id == closing) {
            log.line(l.speaker == .them ? "Mereka" : "Saya", l.text, at: l.start)
            loggedIDs.insert(l.id)
        }
    }

    func flushAll() {
        for l in lines where !loggedIDs.contains(l.id) {
            log.line(l.speaker == .them ? "Mereka" : "Saya", l.text, at: l.start)
            loggedIDs.insert(l.id)
        }
    }

    func clear() {
        flushAll()
        answerTask?.cancel()
        lines.removeAll()
        answers.removeAll()
        volatileThem = ""
        volatileMe = ""
        answeredLineID = nil
        tick &+= 1
    }

    // MARK: - Jawaban

    private func scheduleTurnEnd() {
        turnTimer?.cancel()
        guard auto else { return }
        let delay = config.num("TURN_END_SECONDS", 1.0)
        turnTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.turnEnded()
        }
    }

    private func turnEnded() {
        guard auto, volatileThem.isEmpty, let last = lines.last, last.speaker == .them, last.id != answeredLineID else { return }
        guard last.text.split(separator: " ").count >= Int(config.num("AUTO_MIN_WORDS", 4)) else { return }
        ask(force: false)
    }

    /// force = dipicu manual (tombol/hotkey/ketik) → selalu menjawab, tanpa SKIP.
    func ask(force: Bool, typed: String? = nil) {
        let typed = typed?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastThem = lines.last(where: { $0.speaker == .them })
        let question: String
        if let typed, !typed.isEmpty {
            question = typed
        } else if !volatileThem.isEmpty {
            question = (lastThem.map { $0.text + " " } ?? "") + volatileThem
        } else if let lastThem {
            question = lastThem.text
        } else {
            status = "Belum ada pertanyaan dari mereka"
            return
        }
        if typed == nil || typed!.isEmpty, let lastThem {
            answeredLineID = lastThem.id
            flushLog(closing: lastThem.id)
        }

        answerTask?.cancel()
        if let first = answers.first, !first.done { answers.removeFirst() }
        var answer = Answer(question: question)
        answer.bridge = Bridge.pick(for: question, avoiding: recentBridges)
        recentBridges = Array((recentBridges + [answer.bridge]).suffix(4))
        focusIndex = 0
        let id = answer.id
        answers.insert(answer, at: 0)
        if answers.count > 40 { answers.removeLast(answers.count - 40) }

        let messages = [
            ChatMessage(role: "system", content: Prompt.system(config, knowledge, allowSkip: !force, cues: cueMode, notes: taskNotes)),
            ChatMessage(role: "user", content: Prompt.user(lines: lines, volatileThem: volatileThem,
                                                           typed: (typed?.isEmpty ?? true) ? nil : typed,
                                                           maxWords: cueMode ? nil : Int(config.num("ANSWER_MAX_WORDS", 75)))),
        ]
        let llm = self.llm!
        answerTask = Task { [weak self] in
            let t0 = Date()
            do {
                let (label, text) = try await llm.stream(messages, until: { Prompt.isComplete($0) }) { label, full in
                    self?.update(id) { a in
                        a.source = label
                        if a.latency == nil { a.latency = Date().timeIntervalSince(t0) }
                        Prompt.parse(full, into: &a)
                    }
                }
                guard let self else { return }
                self.update(id) { a in
                    Prompt.parse(text, into: &a)
                    a.done = true
                }
                if let a = self.answers.first(where: { $0.id == id }) {
                    if a.skip || a.text.isEmpty {
                        self.answers.removeAll { $0.id == id }
                    } else {
                        self.log.answer(a.text, source: label)
                    }
                }
            } catch {
                if Task.isCancelled { return }
                self?.update(id) { a in
                    a.error = error.localizedDescription
                    a.done = true
                }
            }
        }
    }

    /// Gulir satu kalimat (⌃⌥→ / ⌃⌥←) di mode ringkas.
    func focusStep(_ delta: Int) {
        guard let a = answers.first else { return }
        let count = Focus.sentences(bridge: a.bridge, answer: a.text).count
        focusIndex = min(max(0, focusIndex + delta), max(0, count - 1))
    }

    private func update(_ id: UUID, _ change: (inout Answer) -> Void) {
        guard let i = answers.firstIndex(where: { $0.id == id }) else { return }
        change(&answers[i])
    }
}
