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
            openFolder: { NSWorkspace.shared.open(config.home) },
            quit: { NSApp.terminate(nil) }))
        panel.setFrameAutosaveName("LiveTranscriptionPanel")
        if !panel.setFrameUsingName("LiveTranscriptionPanel"), let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrame(NSRect(x: f.maxX - 460, y: f.maxY - 620, width: 440, height: 600), display: true)
        }
        panel.alphaValue = copilot.opacity
        copilot.onOpacity = { [weak self] v in self?.panel.alphaValue = v }
        panel.orderFrontRegardless()

        setupStatusItem()
        HotKeys.install()
        let ctrlOpt = controlKey | optionKey
        HotKeys.register(1, key: kVK_ANSI_J, mods: ctrlOpt) { [weak self] in self?.copilot.ask(force: true) }
        HotKeys.register(2, key: kVK_ANSI_H, mods: ctrlOpt) { [weak self] in self?.togglePanel() }
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

    @objc func reloadDocs() {
        copilot.reload()
        copilot.status = "Dimuat ulang · " + copilot.docsSummary
    }

    @objc func openFolder() { NSWorkspace.shared.open(copilot.config.home) }

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
    let k = KnowledgeLoader.load(home: cfg.home)
    print("dokumen:", k.docNames, "| gaya.md:", k.style.isEmpty ? "kosong" : "\(k.style.count) karakter", "| contoh:", k.examples.count)
    let llm = LLMClient(endpoints: cfg.endpoints(), hedge: cfg.num("LLM_HEDGE_SECONDS", 1.5),
                        maxTokens: Int(cfg.num("LLM_MAX_TOKENS", 220)))
    let now = Date()
    let lines = [Line(speaker: .them, text: question, start: now, updated: now)]
    let messages = [ChatMessage(role: "system", content: Prompt.system(cfg, k, allowSkip: false)),
                    ChatMessage(role: "user", content: Prompt.user(lines: lines, volatileThem: "", typed: nil))]
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

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--test-file"), i + 1 < args.count {
    Task { await testFile(args[i + 1]); exit(0) }
    RunLoop.main.run()
} else if let i = args.firstIndex(of: "--test-system"), i + 1 < args.count {
    Task { await testSystem(Int(args[i + 1]) ?? 10); exit(0) }
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
