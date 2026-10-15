import AppKit
import SwiftUI

/// Panel melayang yang tidak ikut tertangkap screen share / rekaman layar (sharingType = .none).
final class FloatingPanel: NSPanel {
    init(rect: NSRect, hiddenFromCapture: Bool) {
        super.init(contentRect: rect,
                   styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        appearance = NSAppearance(named: .darkAqua)
        sharingType = hiddenFromCapture ? .none : .readOnly
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            standardWindowButton(b)?.isHidden = true
        }
        minSize = NSSize(width: 320, height: 300)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

struct ContentView: View {
    @ObservedObject var c: Copilot
    var openFolder: () -> Void
    var quit: () -> Void
    @State private var typed = ""
    @State private var info = ""

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 8) {
                header
                answers.frame(height: max(140, geo.size.height * 0.5))
                Divider().opacity(0.4)
                transcript
                TextField("Ketik pertanyaan mereka lalu Enter…", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        c.ask(force: true, typed: typed)
                        typed = ""
                    }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(ZStack {
            VisualEffect()
            Color(white: 0.07).opacity(0.82)
        }.ignoresSafeArea())
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle().fill(c.listening ? Color.green : Color.orange).frame(width: 8, height: 8)
            LevelBars(levels: c.levels)
            Text(c.status).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(c.status)
            Spacer(minLength: 4)
            Toggle("Auto", isOn: $c.auto).toggleStyle(.button).controlSize(.small)
                .help("Jawab otomatis setiap mereka selesai bicara (⌃⌥A)")
            Toggle(isOn: $c.micOn) { Image(systemName: c.micOn ? "mic.fill" : "mic.slash") }
                .toggleStyle(.button).controlSize(.small)
                .help("Transkrip suara saya juga (pakai headphone)")
            Button { c.ask(force: true) } label: { Label("Jawab", systemImage: "sparkles") }
                .controlSize(.small)
                .help("Susun jawaban untuk ucapan terakhir mereka (⌃⌥J)")
            Menu {
                Button("Huruf lebih besar") { c.fontSize = min(28, c.fontSize + 1) }
                Button("Huruf lebih kecil") { c.fontSize = max(11, c.fontSize - 1) }
                Menu("Transparansi") {
                    ForEach([1.0, 0.94, 0.85, 0.75, 0.6], id: \.self) { v in
                        Button("\(Int(v * 100))%") { c.opacity = v }
                    }
                }
                Divider()
                Button("Muat ulang dokumen & gaya") {
                    c.reload()
                    c.status = "Dimuat ulang · " + c.docsSummary
                }
                Button("Buka folder (dokumen, gaya.md, transkrip)") { openFolder() }
                Button("Bersihkan layar") { c.clear() }
                Divider()
                Button("Keluar") { quit() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var answers: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if c.answers.isEmpty {
                    Text("Saran jawaban muncul di sini setelah mereka selesai bicara.\n⌃⌥J jawab sekarang · ⌃⌥H sembunyikan · ⌃⌥A auto")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                ForEach(Array(c.answers.prefix(5).enumerated()), id: \.element.id) { i, a in
                    AnswerCard(a: a, big: i == 0, font: c.fontSize)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(c.lines.suffix(80)) { l in
                        LineText(speaker: l.speaker, text: l.text, live: false, font: c.fontSize - 3)
                    }
                    if !c.volatileThem.isEmpty {
                        LineText(speaker: .them, text: c.volatileThem, live: true, font: c.fontSize - 3)
                    }
                    if !c.volatileMe.isEmpty {
                        LineText(speaker: .me, text: c.volatileMe, live: true, font: c.fontSize - 3)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: c.tick) { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
}

struct LevelBars: View {
    @ObservedObject var levels: Levels

    var body: some View {
        VStack(spacing: 3) {
            bar(levels.them, .cyan)
            bar(levels.me, .yellow)
        }
        .help("Level suara — biru: mereka (audio sistem), kuning: saya (mic)")
    }

    private func bar(_ v: Float, _ color: Color) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.15))
            Capsule().fill(color).frame(width: 28 * CGFloat(min(1, sqrt(v) * 1.3)))
        }
        .frame(width: 28, height: 4)
    }
}

struct LineText: View {
    let speaker: Speaker
    let text: String
    let live: Bool
    let font: Double

    var body: some View {
        let who = Text(speaker == .them ? "Mereka  " : "Saya  ").bold()
            .foregroundColor(speaker == .them ? .cyan : .yellow)
        let what = Text(text).foregroundColor(live ? .secondary : .primary)
        return Text("\(who)\(what)")
            .font(.system(size: font))
            .italic(live)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AnswerCard: View {
    let a: Answer
    let big: Bool
    let font: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(a.question)
                .font(.caption).foregroundStyle(.secondary).lineLimit(big ? 2 : 1)
            if a.text.isEmpty && !a.done && a.error == nil {
                ProgressView().controlSize(.small)
            }
            if !a.text.isEmpty {
                Text(a.text)
                    .font(.system(size: big ? font + 1 : font - 2, weight: big ? .semibold : .regular))
                    .foregroundStyle(big ? .primary : .secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !a.gist.isEmpty {
                Text((a.warn ? "⚠︎ tidak ada di dokumen · " : "") + a.gist)
                    .font(.caption)
                    .foregroundStyle(a.warn ? Color.orange : Color.secondary)
            }
            if let e = a.error {
                Text(e).font(.caption).foregroundStyle(.red).lineLimit(3)
            }
            if big, let lat = a.latency {
                Text("\(a.source) · \(String(format: "%.1f", lat)) dtk")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(big ? 0.10 : 0.04)))
    }
}
