import AppKit
import Foundation
import PDFKit

/// Bahan yang dikirim ke LLM: isi dokumen, panduan gaya, dan contoh ucapan asli dari transkrip lama.
struct Knowledge {
    var documents = ""
    var docNames: [String] = []
    var style = ""
    var examples: [String] = []
}

enum KnowledgeLoader {
    static let maxPerDoc = 40_000
    static let maxTotal = 120_000

    static func load(home: URL) -> Knowledge {
        var k = Knowledge()
        let dir = home.appendingPathComponent("dokumen")
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var parts: [String] = []
        var total = 0
        for f in files {
            guard var text = extract(f).map(squeeze), !text.isEmpty else { continue }
            if text.count > maxPerDoc { text = String(text.prefix(maxPerDoc)) + "\n[...dipotong]" }
            if total + text.count > maxTotal { break }
            total += text.count
            parts.append("## \(f.lastPathComponent)\n\(text)")
            k.docNames.append(f.lastPathComponent)
        }
        k.documents = parts.joined(separator: "\n\n")
        let style = (try? String(contentsOf: home.appendingPathComponent("gaya.md"), encoding: .utf8)) ?? ""
        k.style = style.replacingOccurrences(of: #"(?s)<!--.*?-->"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        k.examples = pastUtterances(home.appendingPathComponent("transkrip"))
        return k
    }

    static func extract(_ url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return PDFDocument(url: url)?.string
        case "txt", "md", "markdown", "csv", "json":
            return try? String(contentsOf: url, encoding: .utf8)
        case "docx", "doc", "rtf", "odt", "html", "htm":
            return (try? NSAttributedString(url: url, options: [:], documentAttributes: nil))?.string
        default:
            return nil
        }
    }

    /// Rapikan spasi berlebih hasil ekstraksi PDF.
    static func squeeze(_ s: String) -> String {
        s.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Ucapan saya (≥ 8 kata) dari transkrip sebelumnya, untuk meniru gaya bicara.
    static func pastUtterances(_ dir: URL) -> [String] {
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        var out: [String] = []
        for f in files {
            guard let s = try? String(contentsOf: f, encoding: .utf8) else { continue }
            for line in s.split(separator: "\n") {
                guard let r = line.range(of: #"^\[\d\d:\d\d:\d\d\] Saya: "#, options: .regularExpression) else { continue }
                let text = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                if text.split(separator: " ").count >= 8 { out.append(text) }
            }
        }
        var picked: [String] = []
        var chars = 0
        for t in out.reversed() {
            if picked.count >= 25 || chars + t.count > 3000 { break }
            picked.insert(t, at: 0)
            chars += t.count
        }
        return picked
    }
}

/// Transkrip rapat disimpan per sesi di transkrip/YYYY-MM-DD_HH-mm.md.
final class TranscriptLog {
    let dir: URL
    private var file: URL?
    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    init(dir: URL) { self.dir = dir }

    func line(_ who: String, _ text: String, at date: Date) {
        write("[\(timeFmt.string(from: date))] \(who): \(text)\n")
    }

    func answer(_ text: String, source: String) {
        write("           ↳ Saran (\(source)): \(text.replacingOccurrences(of: "\n", with: " "))\n")
    }

    private func write(_ s: String) {
        if file == nil {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd_HH-mm"
            let url = dir.appendingPathComponent("\(f.string(from: Date())).md")
            let header = "# Transkrip \(f.string(from: Date()))\n\n"
            FileManager.default.createFile(atPath: url.path, contents: header.data(using: .utf8))
            file = url
        }
        guard let file, let h = try? FileHandle(forWritingTo: file) else { return }
        defer { try? h.close() }
        _ = try? h.seekToEnd()
        try? h.write(contentsOf: Data(s.utf8))
    }
}
