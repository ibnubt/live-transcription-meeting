import Foundation

/// Urutan kalimat untuk tampilan gulir di mode ringkas.
enum Focus {
    /// Urutan yang diucapkan: kalimat jembatan dulu, lalu kalimat-kalimat jawaban.
    static func sentences(bridge: String, answer: String) -> [String] {
        (bridge.isEmpty ? [] : [bridge]) + Phrases.paragraphs(answer).flatMap { $0 }
    }

    static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    /// Kata-kata ternormalisasi untuk dicocokkan dengan transkrip ("5,000" → "5000", "I'd" → "id").
    static func words(_ s: String) -> [String] {
        s.lowercased()
            .replacingOccurrences(of: #"(\d),(\d)"#, with: "$1$2", options: .regularExpression)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}
