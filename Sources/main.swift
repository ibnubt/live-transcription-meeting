import AppKit
import AVFoundation
import Carbon.HIToolbox
import SwiftUI

// MARK: - Hotkey global (Carbon; tidak butuh izin Accessibility)

enum HotKeys {
    nonisolated(unsafe) static var handlers: [UInt32: () -> Void] = [:]
    nonisolated(unsafe) static var refs: [EventHotKeyRef?] = []

    static func install() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { HotKeys.handlers[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }

    static func register(_ id: UInt32, key: Int, mods: Int, _ handler: @escaping () -> Void) {
        handlers[id] = handler
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(key), UInt32(mods), EventHotKeyID(signature: OSType(0x4C49_5645), id: id),
                            GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel!
    var copilot: Copilot!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        let config = Config.load()
        copilot = Copilot(config: config)
        let hidden = ProcessInfo.processInfo.environment["LIVE_VISIBLE"] != "1"
        panel = FloatingPanel(rect: NSRect(x: 0, y: 0, width: 440, height: 600), hiddenFromCapture: hidden)
        panel.contentView = NSHostingView(rootView: ContentView(
            c: copilot,
            openFolder: { [weak self] in NSWorkspace.shared.open(self?.copilot.config.profileHome ?? config.home) },
            toggleCompact: { [weak self] in self?.toggleCompact() },
            quit: { NSApp.terminate(nil) }))
        panel.setFrameAutosaveName("LiveTranscriptionPanel")
        if !panel.setFrameUsingName("LiveTranscriptionPanel"), let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrame(NSRect(x: f.maxX - 460, y: f.maxY - 620, width: 440, height: 600), display: true)
        }
        if copilot.compact { placeUnderCamera() }
        panel.alphaValue = copilot.opacity
        copilot.onOpacity = { [weak self] v in self?.panel.alphaValue = v }
        panel.orderFrontRegardless()

        setupStatusItem()
        HotKeys.install()
        let ctrlOpt = controlKey | optionKey
        HotKeys.register(1, key: kVK_ANSI_J, mods: ctrlOpt) { [weak self] in self?.copilot.ask(force: true) }
        HotKeys.register(2, key: kVK_ANSI_H, mods: ctrlOpt) { [weak self] in self?.togglePanel() }
        HotKeys.register(4, key: kVK_ANSI_K, mods: ctrlOpt) { [weak self] in self?.toggleCompact() }
        HotKeys.register(5, key: kVK_RightArrow, mods: ctrlOpt) { [weak self] in self?.copilot.focusStep(1) }
        HotKeys.register(6, key: kVK_LeftArrow, mods: ctrlOpt) { [weak self] in self?.copilot.focusStep(-1) }
        HotKeys.register(3, key: kVK_ANSI_A, mods: ctrlOpt) { [weak self] in
            guard let c = self?.copilot else { return }
            c.auto.toggle()
            c.status = c.auto ? "Auto aktif" : "Auto mati — tekan ⌃⌥J untuk jawab"
        }

        copilot.status = "Memuat · " + copilot.docsSummary
        Task { await copilot.start() }
    }

    func applicationWillTerminate(_ n: Notification) {
        copilot.flushAll()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Live Transcription")
        statusItem.button?.window?.sharingType = .none
        let menu = NSMenu()
        menu.addItem(item("Tampilkan / sembunyikan panel  ⌃⌥H", #selector(togglePanel)))
        menu.addItem(item("Jawab sekarang  ⌃⌥J", #selector(answerNow)))
        menu.addItem(item("Mode ringkas di bawah kamera  ⌃⌥K", #selector(toggleCompact)))
        menu.addItem(item("Muat ulang dokumen & gaya", #selector(reloadDocs)))
        menu.addItem(item("Buka folder", #selector(openFolder)))
        menu.addItem(.separator())
        menu.addItem(item("Keluar", #selector(quit)))
        statusItem.menu = menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self
        return i
    }

    @objc func togglePanel() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    @objc func answerNow() { copilot.ask(force: true) }

    private var fullFrame: NSRect?

    /// Mode ringkas: panel lebar-pendek tepat di bawah kamera (tengah atas layar), hanya jawaban.
    @objc func toggleCompact() {
        if copilot.compact {
            copilot.compact = false
            if let f = fullFrame { panel.setFrame(f, display: true, animate: true) }
        } else {
            fullFrame = panel.frame
            copilot.compact = true
            placeUnderCamera()
        }
    }

    private func placeUnderCamera() {
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let w = min(420, v.width * 0.4), h: CGFloat = 330
        panel.setFrame(NSRect(x: v.midX - w / 2, y: v.maxY - h, width: w, height: h), display: true, animate: true)
    }

    @objc func reloadDocs() {
        copilot.reload()
        copilot.status = "Dimuat ulang · " + copilot.docsSummary
    }

    @objc func openFolder() { NSWorkspace.shared.open(copilot.config.profileHome) }

    @objc func quit() { NSApp.terminate(nil) }
}

// MARK: - Mode uji dari terminal

/// `LiveTranscription --test-file rekaman.wav` → transkripsi file lewat jalur yang sama dengan audio live.
func testFile(_ path: String) async {
    do {
        let loc = try await LiveTranscriber.prepare(locale: Locale(identifier: "en-US")) { p in
            print(String(format: "unduh model %.0f%%", p * 100))
        }
        let t = LiveTranscriber(locale: loc)
        let t0 = Date()
        t.onText = { text, fin in
            if fin { print(String(format: "[%5.2fs] FINAL: %@", Date().timeIntervalSince(t0), text)) }
        }
        try await t.start()
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let chunk: AVAudioFrameCount = 4800
        while file.framePosition < file.length {
            guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { break }
            try file.read(into: buf, frameCount: chunk)
            t.feed(buf)
        }
        await t.finish()
        print(String(format: "selesai %.2fs", Date().timeIntervalSince(t0)))
    } catch {
        print("GAGAL:", error.localizedDescription)
    }
}

/// `LiveTranscription --test-ask "pertanyaan"` → uji prompt + LLM dengan dokumen & gaya.md.
@MainActor
func testAsk(_ question: String) async {
    let cfg = Config.load()
    let k = KnowledgeLoader.load(home: cfg.profileHome)
    print("dokumen:", k.docNames, "| gaya.md:", k.style.isEmpty ? "kosong" : "\(k.style.count) karakter", "| contoh:", k.examples.count)
    let llm = LLMClient(endpoints: cfg.endpoints(), hedge: cfg.num("LLM_HEDGE_SECONDS", 1.5),
                        maxTokens: Int(cfg.num("LLM_MAX_TOKENS", 220)))
    let now = Date()
    let lines = [Line(speaker: .them, text: question, start: now, updated: now)]
    let messages = [ChatMessage(role: "system", content: Prompt.system(cfg, k, allowSkip: false, cues: cfg.str("ANSWER_STYLE", "poin") != "naskah", notes: UserDefaults.standard.string(forKey: "taskNotes") ?? "")),
                    ChatMessage(role: "user", content: Prompt.user(lines: lines, volatileThem: "", typed: nil, maxWords: cfg.str("ANSWER_STYLE", "poin") == "naskah" ? Int(cfg.num("ANSWER_MAX_WORDS", 75)) : nil))]
    var first: Double?
    do {
        let (label, text) = try await llm.stream(messages, until: { Prompt.isComplete($0) }) { _, _ in
            if first == nil { first = Date().timeIntervalSince(now) }
        }
        var a = Answer(question: question)
        Prompt.parse(text, into: &a)
        print(String(format: "[%@] kata pertama %.1fs, selesai %.1fs, %d kata", label, first ?? -1,
                     Date().timeIntervalSince(now), a.text.split(separator: " ").count))
        print("JAWAB:", a.text)
        print("ID:", (a.warn ? "⚠ " : "") + a.gist)
    } catch {
        print("GAGAL:", error.localizedDescription)
    }
}

/// `LiveTranscription --test-system 15` → tangkap audio sistem N detik, cetak statistik buffer + transkrip.
func testSystem(_ seconds: Int) async {
    do {
        let loc = try await LiveTranscriber.prepare(locale: Locale(identifier: "en-US")) { _ in }
        let t = LiveTranscriber(locale: loc)
        t.onText = { text, fin in if fin { print("FINAL:", text) } }
        try await t.start()
        let sys = SystemAudioCapture()
        nonisolated(unsafe) var n = 0, frames = 0, peak: Float = 0, fmt = ""
        sys.onBuffer = { b in
            n += 1
            frames += Int(b.frameLength)
            fmt = "\(b.format.sampleRate)Hz ch=\(b.format.channelCount) \(b.format.commonFormat.rawValue) inter=\(b.format.isInterleaved)"
            if let ch = b.floatChannelData {
                for i in 0..<Int(b.frameLength) { peak = max(peak, abs(ch[0][i])) }
            }
            t.feed(b)
        }
        sys.onStop = { e in print("STOP:", e.localizedDescription) }
        try sys.start()
        print("capture started")
        for s in 0..<seconds {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("t=\(s + 1)s buffers=\(n) frames=\(frames) peak=\(peak) \(fmt)")
            peak = 0
        }
        sys.stop()
        await t.finish()
    } catch {
        print("GAGAL:", error.localizedDescription)
    }
}

/// `LiveTranscription --test-convo pertanyaan.txt` → simulasi wawancara: tiap baris = pertanyaan mereka,
/// jawaban sebelumnya masuk riwayat sebagai "Me:" (seolah sudah diucapkan).
@MainActor
func testConvo(_ path: String) async {
    let cfg = Config.load()
    let k = KnowledgeLoader.load(home: cfg.profileHome)
    print("dokumen:", k.docNames, "| gaya.md:", k.style.count, "karakter")
    let llm = LLMClient(endpoints: cfg.endpoints(), hedge: cfg.num("LLM_HEDGE_SECONDS", 1.5),
                        maxTokens: Int(cfg.num("LLM_MAX_TOKENS", 220)))
    let questions = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
        .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    var lines: [Line] = []
    for q in questions {
        let now = Date()
        lines.append(Line(speaker: .them, text: q, start: now, updated: now))
        let messages = [ChatMessage(role: "system", content: Prompt.system(cfg, k, allowSkip: false, cues: cfg.str("ANSWER_STYLE", "poin") != "naskah", notes: UserDefaults.standard.string(forKey: "taskNotes") ?? "")),
                        ChatMessage(role: "user", content: Prompt.user(lines: lines, volatileThem: "", typed: nil, maxWords: cfg.str("ANSWER_STYLE", "poin") == "naskah" ? Int(cfg.num("ANSWER_MAX_WORDS", 75)) : nil))]
        var first: Double?
        do {
            let (label, text) = try await llm.stream(messages, until: { Prompt.isComplete($0) }) { _, _ in
                if first == nil { first = Date().timeIntervalSince(now) }
            }
            var a = Answer(question: q)
            Prompt.parse(text, into: &a)
            print("\n=== \(q)")
            print("JEMBATAN:", Bridge.pick(for: q, avoiding: []))
            print(String(format: "[%@] kata pertama %.1fs, %d kata", label, first ?? -1, a.text.split(separator: " ").count))
            print(a.text)
            print("ID:", (a.warn ? "⚠ " : "") + a.gist)
            lines.append(Line(speaker: .me, text: a.text, start: Date(), updated: Date()))
        } catch {
            print("\n=== \(q)\nGAGAL:", error.localizedDescription)
        }
    }
}

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--test-file"), i + 1 < args.count {
    Task { await testFile(args[i + 1]); exit(0) }
    RunLoop.main.run()
} else if let i = args.firstIndex(of: "--test-system"), i + 1 < args.count {
    Task { await testSystem(Int(args[i + 1]) ?? 10); exit(0) }
    RunLoop.main.run()
} else if args.contains("--ui-preview") {
    // Pratinjau tampilan mode ringkas dengan contoh jawaban, tanpa mic/audio (tidak memicu izin).
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let c = Copilot(config: Config.load())
        c.compact = true
        c.cueMode = false
        c.status = "Pratinjau"
        let now = Date()
        c.lines = [Line(speaker: .them, text: "Walk me through how you would design a flash sale system.", start: now, updated: now)]
        var a = Answer(question: "Walk me through how you would design a flash sale system.")
        a.bridge = "Sure. Let me start with the assumptions, then the design."
        a.text = "I'd assume 10,000 items and a huge spike in the first seconds, with no overselling allowed.\n\nThe product page comes from a CDN. Stock sits in Redis, and one atomic step decides who gets an item. Winners get a short reservation.\n\nThe hardest part is overselling under heavy load. Redis is fast, but the database stays the source of truth. I'd load test at several times the peak."
        a.gist = "Jelaskan desain sistem flash sale."
        a.done = true
        c.answers = [a]
        c.convoView = args.contains("convo")
        if args.contains("convo") {
            let t0 = now.addingTimeInterval(-120)
            var a0 = Answer(question: "Tell me about yourself.")
            a0.bridge = "Happy to. I'll keep it short."
            a0.text = "I'm a senior software engineer with more than nine years of experience.\n\nI lead a team of five engineers."
            a0.done = true
            c.lines = [Line(speaker: .them, text: "Tell me about yourself.", start: t0, updated: t0),
                       Line(speaker: .me, text: "I'm a senior software engineer with more than nine years of experience.", start: t0.addingTimeInterval(20), updated: t0.addingTimeInterval(20)),
                       Line(speaker: .them, text: "Walk me through how you would design a flash sale system.", start: now, updated: now)]
            c.answers = [a, a0]
        }
        if args.contains("stream") {
            // simulasi jawaban yang sedang mengalir: teks bertambah tiap 0,25 detik
            let full = a.text
            c.answers[0].text = ""
            c.answers[0].done = false
            Task { @MainActor in
                var shown = ""
                for word in full.split(separator: " ", omittingEmptySubsequences: false) {
                    shown += (shown.isEmpty ? "" : " ") + word
                    c.answers[0].text = shown
                    try? await Task.sleep(nanoseconds: 60_000_000)
                }
                c.answers[0].done = true
            }
        }
        if args.contains("history") { c.answers[0].done = true; c.lines.removeLast(); c.answers.removeFirst() }
        let screen = NSScreen.main!.visibleFrame
        let panel = FloatingPanel(rect: NSRect(x: screen.midX - 210, y: screen.maxY - 330, width: 420, height: 330), hiddenFromCapture: false)
        panel.contentView = NSHostingView(rootView: ContentView(c: c, openFolder: {}, toggleCompact: {}, quit: { NSApp.terminate(nil) }))
        panel.setFrame(NSRect(x: screen.midX - 210, y: screen.maxY - 330, width: 420, height: 330), display: true)
        panel.orderFrontRegardless()
        withExtendedLifetime((c, panel)) { app.run() }
    }
} else if let i = args.firstIndex(of: "--test-convo"), i + 1 < args.count {
    Task { @MainActor in await testConvo(args[i + 1]); exit(0) }
    RunLoop.main.run()
} else if let i = args.firstIndex(of: "--test-ask"), i + 1 < args.count {
    Task { @MainActor in await testAsk(args[i + 1]); exit(0) }
    RunLoop.main.run()
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
