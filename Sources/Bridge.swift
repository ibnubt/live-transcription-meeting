import Foundation

/// Kalimat jembatan yang langsung muncul (tanpa LLM) untuk diucapkan sambil menunggu jawaban.
/// Banyak variasi dan tidak mengulang beberapa kalimat terakhir, supaya tidak terdengar berulang.
enum Bridge {
    private static let groups: [(keys: [String], phrases: [String])] = [
        ([" about yourself", "introduce yourself", "your background", "walk me through your resume", "walk me through your cv"],
         ["Sure, thank you. Let me give you a quick overview.",
          "Of course. Let me start with where I am today.",
          "Happy to. I'll keep it short."]),
        (["follow up", "follow-up", "in that design", "go deeper", "elaborate", "what about", " and how ", "expand on", "more detail", "what if", "what happens if"],
         ["Good follow-up. Let me go one level deeper.",
          "Sure, let me unpack that part a bit more.",
          "Right, that's the tricky part.",
          "Let me take that case step by step."]),
        (["measurable", " impact", " numbers", "metric", " results", "quantify", " how much", " how many"],
         ["Sure, let me give you some concrete numbers.",
          "Let me put some numbers on it.",
          "Sure. Here's how I'd measure it."]),
        (["disagree", "conflict", "push back", "pushback", "stakeholder", "product manager", " pm ", "deadline"],
         ["That's a good one. Let me share how I handle that.",
          "Sure, this comes up quite often.",
          "Okay. I'd start with the risk."]),
        (["tell me about a time", "describe a time", "give me an example", "have you ever", "a situation where", "a time when", "a time you"],
         ["Sure, one situation comes to mind.",
          "Yes, let me think of the best example.",
          "Let me pick a concrete example.",
          "Sure. A good one comes to mind."]),
        (["design a", "design the", "architect", " scale", "concurrent", "10,000", "million", "system to handle"],
         ["Okay, let me walk you through how I'd approach it.",
          "Sure. Let me start with the assumptions, then the design.",
          "Let me first size the problem, then the design.",
          "Okay. I'll start with the numbers."]),
        ([" why ", "isolation", "transaction", "consisten"],
         ["That's a fair question. Let me explain my reasoning.",
          "Good question. Let me explain why.",
          "Sure. The key point here is correctness."]),
        (["how do you", "how would you", "how did you", "how you'd", "walk me through", "imagine", "your approach", "what's your process", "debug"],
         ["Sure, let me explain how I approach that in practice.",
          "Here's how I usually handle it.",
          "Let me walk you through the steps.",
          "Okay. I'd go step by step."]),
    ]

    private static let fallback = [
        "Sure, let me think about that for a second.",
        "Okay, that's an interesting one.",
        "Good question. Let me think about it.",
        "Right. Let me answer that directly.",
    ]

    /// Pilih kalimat yang cocok dengan jenis pertanyaan, hindari kalimat yang baru saja dipakai.
    static func pick(for question: String, avoiding recent: [String]) -> String {
        let q = " " + question.lowercased().replacingOccurrences(of: "?", with: " ") + " "
        let phrases = groups.first { g in g.keys.contains { q.contains($0) } }?.phrases ?? fallback
        let fresh = phrases.filter { !recent.contains($0) }
        return (fresh.isEmpty ? phrases : fresh).randomElement() ?? fallback[0]
    }
}
