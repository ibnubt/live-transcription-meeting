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
    var toggleCompact: () -> Void
    var quit: () -> Void
    @State private var typed = ""
    @State private var info = ""

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 8) {
                header
                if c.compact {
                    liveThem
                    if c.convoView {
                        ConversationView(c: c)
                    } else if !c.cueMode, let a = c.answers.first {
                        ScriptScroller(a: a, index: c.focusIndex, font: c.fontSize)
                    } else {
                        answers.frame(maxHeight: .infinity)
                    }
                } else {
                    answers.frame(height: max(140, geo.size.height * 0.5))
                    Divider().opacity(0.4)
                    transcript
                    TextField("Ketik pertanyaan mereka lalu Enter…", text: $typed)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            c.ask(force: true, typed: typed)
                            typed = ""
                        }
                    DisclosureGroup(c.taskNotes.isEmpty ? "Catatan tugas (tempel desain/solusi Anda)" : "Catatan tugas ✓ dipakai AI") {
                        TextEditor(text: $c.taskNotes)
                            .font(.system(size: 12))
                            .frame(height: 90)
                            .scrollContentBackground(.hidden)
                            .background(Color.white.opacity(0.06))
                        Button("Hapus catatan") { c.taskNotes = "" }.controlSize(.small)
                    }
                    .font(.caption)
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
                Picker("Format jawaban", selection: $c.cueMode) {
                    Text("Poin — dilirik, diucapkan sendiri").tag(true)
                    Text("Naskah — kalimat lengkap").tag(false)
                }
                Picker("Tampilan mode ringkas", selection: $c.convoView) {
                    Text("Jawaban terbaru").tag(false)
                    Text("Seluruh percakapan (bisa digulir)").tag(true)
                }
                Button(c.compact ? "Mode lengkap  ⌃⌥K" : "Mode ringkas di bawah kamera  ⌃⌥K") { toggleCompact() }
                Divider()
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
                    AnswerCard(a: a, big: i == 0, font: c.fontSize, phrases: !c.cueMode, compact: c.compact)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Mode ringkas: ucapan interviewer terbaru (ikut berubah saat mereka bicara), di atas jawaban.
    private var liveThem: some View {
        let last = c.lines.last
        var said = (last?.speaker == .them ? last?.text : nil) ?? ""
        if !c.volatileThem.isEmpty { said += (said.isEmpty ? "" : " ") + c.volatileThem }
        if said.isEmpty { said = c.lines.last(where: { $0.speaker == .them })?.text ?? "…" }
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Mereka").bold().foregroundColor(.cyan)
            Text(said)
                .foregroundStyle(c.volatileThem.isEmpty ? Color.primary : Color.secondary)
                .lineLimit(3)
                .truncationMode(.head)
        }
        .font(.system(size: c.fontSize - 1))
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// Mode ringkas + naskah: kalimat utuh per baris, area pendek (3–5 baris) yang saya gulir sendiri
/// supaya baris yang sedang dibaca tetap di dekat kamera. ⌃⌥→ / ⌃⌥← menggulir satu kalimat.
/// Naskah satu jawaban: kalimat jembatan (biru) lalu kalimat utuh per baris dengan tanda › dan indentasi gantung.
struct AnswerScript: View {
    let a: Answer
    let font: Double
    var tagSentences = false   // beri id per kalimat supaya bisa digulir dengan ⌃⌥→ / ⌃⌥←

    var body: some View {
        let paragraphs = (a.bridge.isEmpty ? [] : [[a.bridge]]) + Phrases.paragraphs(a.text)
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { p, para in
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(para.enumerated()), id: \.offset) { j, sentence in
                        let n = paragraphs.prefix(p).map(\.count).reduce(0, +) + j
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("›").foregroundStyle(.tertiary)
                            Text(sentence)
                                .foregroundStyle(n == 0 && !a.bridge.isEmpty ? Color.cyan : Color.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(tagSentences ? AnyHashable(n) : AnyHashable("\(a.id)-\(n)"))
                    }
                }
            }
            if !a.done && a.error == nil { ProgressView().controlSize(.small) }
            if let e = a.error { Text(e).font(.caption).foregroundStyle(.red).lineLimit(3) }
            if !a.gist.isEmpty {
                Text((a.warn ? "⚠︎ " : "") + a.gist).font(.caption).foregroundStyle(a.warn ? Color.orange : Color.secondary)
            }
        }
        .font(.system(size: font + 4, weight: .semibold))
    }
}

/// Mode ringkas + "Jawaban terbaru": area pendek (3–5 baris) yang saya gulir sendiri.
struct ScriptScroller: View {
    let a: Answer
    let index: Int
    let font: Double

    var body: some View {
        let count = Focus.sentences(bridge: a.bridge, answer: a.text).count
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    AnswerScript(a: a, font: font, tagSentences: true)
                    Color.clear.frame(height: 600)   // kalimat terakhir bisa digulir ke atas; tampilan tidak ikut turun saat teks bertambah
                }
                .frame(maxWidth: 340, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .id(a.id)        // jawaban baru selalu mulai dari baris pertama
            .clipped()       // isi tidak boleh naik menimpa strip "Mereka"
            .defaultScrollAnchor(.top)
            .onAppear { proxy.scrollTo(0, anchor: .top) }
            .onChange(of: index) { proxy.scrollTo(min(index, max(0, count - 1)), anchor: .top) }
        }
    }
}

/// Mode ringkas + "Seluruh percakapan": semua giliran berurutan dan bisa digulir.
/// Saat jawaban baru muncul, daftar menggulir ke jawaban itu; selebihnya saya yang menggulir.
struct ConversationView: View {
    @ObservedObject var c: Copilot

    private enum Item: Identifiable {
        case line(Line), answer(Answer)
        var id: UUID {
            switch self {
            case .line(let l): return l.id
            case .answer(let a): return a.id
            }
        }
        var date: Date {
            switch self {
            case .line(let l): return l.start
            case .answer(let a): return a.created
            }
        }
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let id = c.answers.first?.id else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if animated { withAnimation { proxy.scrollTo(id, anchor: .top) } } else { proxy.scrollTo(id, anchor: .top) }
        }
    }

    var body: some View {
        let items = (c.lines.map { Item.line($0) } + c.answers.reversed().map { Item.answer($0) })
            .sorted { $0.date < $1.date }
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(items) { item in
                        switch item {
                        case .line(let l):
                            LineText(speaker: l.speaker, text: l.text, live: false,
                                     font: l.speaker == .them ? c.fontSize : c.fontSize - 3)
                                .opacity(l.speaker == .me ? 0.6 : 1)
                        case .answer(let a):
                            Group {
                                if c.cueMode {
                                    Text(AnswerCard.display(a.text))
                                        .font(.system(size: c.fontSize + 2, weight: .semibold))
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    AnswerScript(a: a, font: c.fontSize)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)))
                        }
                    }
                    if !c.volatileThem.isEmpty {
                        LineText(speaker: .them, text: c.volatileThem, live: true, font: c.fontSize)
                    }
                    // ruang kosong lebih tinggi dari layar: saat jawaban bertambah panjang, tampilan tidak ikut turun
                    Color.clear.frame(height: 600)
                }
                .frame(maxWidth: 360, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .clipped()
            // gulir setelah tata letak selesai, supaya mendarat tepat di awal jawaban terbaru
            .onAppear { scrollToLatest(proxy, animated: false) }
            .onChange(of: c.answers.first?.id) { scrollToLatest(proxy, animated: true) }
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
    var phrases = false
    var compact = false

    /// Format poin: "- …" ditampilkan sebagai "▸ …".
    static func display(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            line.hasPrefix("- ") ? "▸ " + line.dropFirst(2) : String(line)
        }.joined(separator: "\n")
    }

    /// Format naskah: satu kalimat per baris (tidak dipotong di tengah), lanjutan kalimat menjorok sejajar teks.
    private func script(_ text: String, size: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(Phrases.paragraphs(text).enumerated()), id: \.offset) { _, sentences in
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sentences.enumerated()), id: \.offset) { _, sentence in
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("›").foregroundStyle(.tertiary)
                            Text(sentence)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .font(.system(size: size, weight: big ? .semibold : .regular))
        .foregroundStyle(big ? .primary : .secondary)
        .textSelection(.enabled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !(compact && big) {
                Text(a.question)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(big ? 2 : 1)
            }
            if big && !a.bridge.isEmpty {
                // Kalimat pembuka instan: diucapkan sambil menunggu jawaban muncul.
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "quote.bubble.fill")
                    Text(a.bridge).italic()
                }
                .font(.system(size: font, weight: .medium))
                .foregroundStyle(Color.cyan.opacity(a.text.isEmpty ? 1 : 0.55))
                .fixedSize(horizontal: false, vertical: true)
            }
            if a.text.isEmpty && !a.done && a.error == nil {
                ProgressView().controlSize(.small)
            }
            if !a.text.isEmpty && phrases {
                script(a.text, size: big ? font + 1 : font - 2)
            } else if !a.text.isEmpty {
                Text(Self.display(a.text))
                    .font(.system(size: big ? font + 1 : font - 2, weight: big ? .semibold : .regular))
                    .lineSpacing(3)
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
            if big, !compact, let lat = a.latency {
                Text("\(a.source) · \(String(format: "%.1f", lat)) dtk")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(big ? 0.10 : 0.04)))
    }
}
