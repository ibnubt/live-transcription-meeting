import Foundation

struct ChatMessage {
    let role: String
    let content: String
}

/// Siapa yang menang balapan antar-endpoint (yang pertama mengirim token).
private actor Race {
    var winner: Int?
    var failed: [Int: String] = [:]

    func claim(_ i: Int) -> Bool {
        if winner == nil { winner = i }
        return winner == i
    }

    func fail(_ i: Int, _ msg: String) { failed[i] = msg }

    /// Endpoint ke-i boleh mulai kalau belum ada pemenang dan (semua sebelumnya gagal atau waktu tunggu habis).
    func mayStart(_ i: Int, elapsed: Double, hedge: Double) -> Bool? {
        if winner != nil { return false }
        if (0..<i).allSatisfy({ failed[$0] != nil }) { return true }
        return elapsed >= hedge * Double(i) ? true : nil
    }
}

/// Klien chat completions OpenAI-compatible dengan "hedging": endpoint utama dulu,
/// endpoint cadangan ikut jalan kalau utama belum menjawab dalam `hedge` detik atau gagal.
final class LLMClient: @unchecked Sendable {
    let endpoints: [Endpoint]
    let hedge: Double
    let maxTokens: Int

    init(endpoints: [Endpoint], hedge: Double, maxTokens: Int) {
        self.endpoints = endpoints
        self.hedge = hedge
        self.maxTokens = maxTokens
    }

    /// `onDelta(label, teksLengkapSejauhIni)` dipanggil di main actor. Mengembalikan (label, teks akhir).
    func stream(_ messages: [ChatMessage], until: (@Sendable (String) -> Bool)? = nil,
                onDelta: @escaping @MainActor (String, String) -> Void) async throws -> (String, String) {
        guard !endpoints.isEmpty else { throw AppError("Belum ada LLM di .env (LLM1_URL, LLM1_MODEL)") }
        let race = Race()
        let eps = endpoints
        var result: (String, String)?
        await withTaskGroup(of: (Int, String?).self) { group in
            for (i, ep) in eps.enumerated() {
                group.addTask {
                    if i > 0 {
                        let start = Date()
                        while true {
                            if Task.isCancelled { return (i, nil) }
                            if let go = await race.mayStart(i, elapsed: Date().timeIntervalSince(start), hedge: self.hedge) {
                                if !go { return (i, nil) }
                                break
                            }
                            try? await Task.sleep(nanoseconds: 50_000_000)
                        }
                    }
                    do {
                        let text = try await self.streamOne(ep, messages, until: until) { full in
                            guard await race.claim(i) else { return false }
                            await onDelta(ep.label, full)
                            return true
                        }
                        if text == nil, await race.winner == nil { await race.fail(i, "\(ep.label): jawaban kosong") }
                        return (i, text)
                    } catch {
                        if !(error is CancellationError) { await race.fail(i, "\(ep.label): \(error.localizedDescription)") }
                        return (i, nil)
                    }
                }
            }
            for await (i, text) in group {
                if let text, await race.winner == i {
                    result = (eps[i].label, text)
                    group.cancelAll()
                }
            }
        }
        if let result { return result }
        try Task.checkCancellation()
        let errs = await race.failed.sorted { $0.key < $1.key }.map(\.value)
        throw AppError(errs.isEmpty ? "LLM tidak menjawab" : errs.joined(separator: " · "))
    }

    /// Satu permintaan streaming. `onFull` mengembalikan false kalau endpoint lain sudah menang.
    private func streamOne(_ ep: Endpoint, _ messages: [ChatMessage], until: (@Sendable (String) -> Bool)?,
                           onFull: (String) async -> Bool) async throws -> String? {
        var req = URLRequest(url: ep.url, timeoutInterval: 20)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !ep.key.isEmpty { req.setValue("Bearer \(ep.key)", forHTTPHeaderField: "Authorization") }
        var body: [String: Any] = [
            "model": ep.model,
            "stream": true,
            "max_tokens": maxTokens,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        for (k, v) in ep.extra { body[k] = v }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        defer { bytes.task.cancel() }
        guard let http = resp as? HTTPURLResponse else { throw AppError("tidak ada respons") }
        if http.statusCode != 200 {
            var detail = ""
            for try await line in bytes.lines {
                detail += line
                if detail.count > 200 { break }
            }
            throw AppError("HTTP \(http.statusCode) \(detail.prefix(160))")
        }
        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let d = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if d == "[DONE]" { break }
            guard let data = d.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = obj["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let c = delta["content"] as? String, !c.isEmpty else { continue }
            full += c
            if !(await onFull(full)) { return nil }
            if let until, until(full) { break }
        }
        return full.isEmpty ? nil : full
    }
}
