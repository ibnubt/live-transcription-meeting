import Foundation

enum Speaker { case them, me }

struct Line: Identifiable {
    let id = UUID()
    let speaker: Speaker
    var text: String
    let start: Date
    var updated: Date
}

struct Answer: Identifiable {
    let id = UUID()
    var question: String
    let created = Date()
    var bridge = ""
    var text = ""
    var gist = ""
    var warn = false
    var skip = false
    var source = ""
    var latency: Double?
    var done = false
    var error: String?
}

enum Prompt {
    static func system(_ cfg: Config, _ k: Knowledge, allowSkip: Bool, cues: Bool, notes: String = "") -> String {
        let name = cfg.str("MY_NAME", "the user")
        let maxWords = Int(cfg.num("ANSWER_MAX_WORDS", 40))
        let maxSentences = Int(cfg.num("ANSWER_MAX_SENTENCES", 3))
        var s = """
        You are the private real-time copilot of \(name). \(name) is in a live English conversation (a meeting or a job interview) with native English speakers. You prepare what \(name) should say next.

        Rules:
        \(cues ? cueRules : scriptRules(maxSentences: maxSentences, maxWords: maxWords))
        - Sound like \(name): follow the style guide and mirror how \(name) actually talks (examples below, if any).
        - Facts about \(name) must be literally stated in the documents: roles, years, companies, projects, tools, numbers, dates, results. Keep each detail with the project it belongs to; never move a detail from one project to another. Do not add implementation details, problems, results, or numbers the documents do not state; speak at the level of detail the documents give.
        - If the question needs something the documents do not cover (a tool not listed, a personal story, an opinion, a preference), answer honestly and generally in \(name)'s voice without inventing specifics (e.g. "I haven't run X in production, but I've worked with Y"), and mark the ID line with ⚠.
        - The transcript comes from live speech recognition and may contain errors; infer what they meant.
        - If they asked several things, answer the main point first, briefly.

        Output format, exactly two parts and nothing after them:
        \(cues ? "<the opening sentence, then the cue lines>" : "<the spoken answer>")
        ID: <the meaning of their last question or statement in Indonesian, max 12 words>
        Write "ID: ⚠ ..." instead when any part of the answer is not backed by the documents.
        """
        if allowSkip {
            s += "\nIf their last turn clearly needs no reply from \(name) (e.g. \"okay\", \"mm-hmm\", they are clearly mid-sentence, or they are talking to someone else), output only: SKIP"
        }
        if !k.style.isEmpty {
            s += "\n\n# Style guide (written by \(name); it overrides the rules above if they conflict)\n" + k.style
        }
        if !k.examples.isEmpty {
            s += "\n\n# How \(name) actually talks (real past utterances, speech-recognized)\n"
                + k.examples.map { "- " + $0 }.joined(separator: "\n")
        }
        let notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            s += "\n\n# My submission in today's task (questions about \"your design\" or \"your solution\" refer to this)\n" + notes
        }
        s += "\n\n# Documents\n" + (k.documents.isEmpty ? "(none)" : k.documents)
        return s
    }

    /// Format poin: dilirik sekilas lalu diucapkan dengan kata-kata sendiri (tidak terlihat membaca).
    static let cueRules = """
    - Write speaking cues, not a script. I glance at them for a second and then talk in my own words, so they must be readable at a glance.
    - Line 1: one short opening sentence I can say right away (at most 15 words): the direct answer or headline, first person, simple words.
    - Then EXACTLY 3 or 4 cue lines (system design: exactly 5), each starting with "- ", each 3 to 8 words, never full sentences. Never more lines: if you have more points, keep only the most important ones; I will add detail myself when they ask. Order: problem → decision → trade-off → result or next step. Keep concrete names and numbers in the cues (for example "- 5,000+ stations, heartbeat every 8 s").
    - Each point once. No markdown besides the "- " at the start of cue lines, no emojis, no quotation marks. No openers like "Great question".
    """

    /// Format naskah: kalimat lengkap untuk dibacakan.
    static func scriptRules(maxSentences: Int, maxWords: Int) -> String {
        """
        - Write only the words to be spoken: first person ("I", "we"), natural spoken English, simple words. No markdown, bullets, labels, emojis or quotation marks.
        - Layout: follow the answer framework for the question type in the style guide; put a blank line between its parts so I can see where each part starts. A short direct answer stays one paragraph. Never end with a summary.
        - Say each point once; never repeat yourself.
        - HARD LIMIT: at most \(maxSentences) sentences and \(maxWords) words. Shorter is better. The first sentence is the direct answer. No openers like "Great question", no restating the question, no closing filler.
        """
    }

    static func user(lines: [Line], volatileThem: String, typed: String?, maxWords: Int? = nil) -> String {
        var convo: [String] = []
        var chars = 0
        for l in lines.reversed() {
            let row = (l.speaker == .them ? "Them: " : "Me: ") + l.text
            if chars + row.count > 5000 { break }
            convo.insert(row, at: 0)
            chars += row.count
        }
        if !volatileThem.isEmpty { convo.append("Them: " + volatileThem) }
        var s = "Conversation so far (most recent last):\n"
        s += convo.isEmpty ? "(nothing yet)" : convo.joined(separator: "\n")
        let limit = maxWords.map { " Keep it under \($0) words; they will ask follow-ups for more." } ?? ""
        if let typed {
            s += "\n\nThey just asked (typed by me): \(typed)\n\nDraft my reply to that.\(limit)"
        } else {
            s += "\n\nDraft my reply to their last turn.\(limit)"
        }
        return s
    }

    /// Jawaban lengkap begitu baris "ID: ..." sudah berakhir (model kadang terus menulis sesudahnya).
    static func isComplete(_ raw: String) -> Bool {
        raw.range(of: #"(^|\n|(?<=[.!?])[ \t]+)ID\s*:[^\n]*\S[^\n]*\n"#, options: .regularExpression) != nil
    }

    /// Pisahkan jawaban, baris "ID:", dan penanda SKIP dari teks streaming.
    static func parse(_ raw: String, into a: inout Answer) {
        var s = raw.replacingOccurrences(of: #"(?s)<think>.*?</think>"#, with: "", options: .regularExpression)
        if let open = s.range(of: "<think>") { s = String(s[..<open.lowerBound]) }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = s.uppercased()
        if !upper.isEmpty, upper.hasPrefix("SKIP") || "SKIP".hasPrefix(upper) {
            a.skip = upper.hasPrefix("SKIP")
            a.text = ""
            return
        }
        a.skip = false
        if let r = s.range(of: #"(^|\n|(?<=[.!?])[ \t]+)\s*ID\s*:"#, options: .regularExpression) {
            a.text = String(s[..<r.lowerBound])
            var g = String(s[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if let nl = g.firstIndex(of: "\n") { g = String(g[..<nl]) }
            if g.hasPrefix("⚠") {
                a.warn = true
                g = String(g.dropFirst()).trimmingCharacters(in: CharacterSet(charactersIn: " \u{FE0F}:-"))
            }
            a.gist = g
        } else {
            a.text = s
        }
        a.text = a.text.replacingOccurrences(of: "**", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
