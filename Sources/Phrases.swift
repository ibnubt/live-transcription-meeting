import Foundation

/// Membagi naskah jawaban menjadi paragraf dan kalimat utuh (satu kalimat per baris di layar).
enum Phrases {
    /// Paragraf dipisah baris kosong; tiap paragraf berisi kalimat-kalimat utuh.
    static func paragraphs(_ text: String) -> [[String]] {
        text.components(separatedBy: "\n")
            .split(whereSeparator: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map { lines in lines.flatMap { sentences(String($0)) } }
            .filter { !$0.isEmpty }
    }

    /// Pecah di akhir kalimat (. ? ! diikuti spasi); angka seperti 0.8 tidak ikut terpotong.
    static func sentences(_ line: String) -> [String] {
        line.replacingOccurrences(of: #"([.?!])\s+"#, with: "$1\n", options: .regularExpression)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
