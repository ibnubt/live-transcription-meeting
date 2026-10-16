import Foundation

struct AppError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Satu endpoint LLM OpenAI-compatible (aicon, Tokenku, Ollama, dll.).
struct Endpoint {
    let label: String
    let url: URL
    let key: String
    let model: String
    let extra: [String: Any]
}

/// Konfigurasi dari `.env` di folder proyek (folder yang berisi dokumen/, gaya.md, transkrip/).
struct Config {
    /// Folder app (berisi .env dan profil/).
    let home: URL
    /// Folder data profil aktif: dokumen/, gaya.md, transkrip/. Profil utama = `home` itu sendiri.
    let profileHome: URL
    /// Nama profil aktif; kosong = profil utama.
    let profile: String
    let env: [String: String]

    /// .env utama, lalu profil.env milik profil aktif (LIVE_PROFILE → pilihan terakhir di menu).
    static func load() -> Config {
        let home = findHome()
        var env = parseEnv(home.appendingPathComponent(".env"))
        let name = ProcessInfo.processInfo.environment["LIVE_PROFILE"] ?? UserDefaults.standard.string(forKey: "profile") ?? ""
        let dir = profilesDir(home).appendingPathComponent(name)
        var isDir: ObjCBool = false
        if !name.isEmpty, FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
            env.merge(parseEnv(dir.appendingPathComponent("profil.env"))) { _, profileValue in profileValue }
            return Config(home: home, profileHome: dir, profile: name, env: env)
        }
        return Config(home: home, profileHome: home, profile: "", env: env)
    }

    static func profilesDir(_ home: URL) -> URL { home.appendingPathComponent("profil") }

    /// Profil tambahan = subfolder di profil/.
    static func profiles(home: URL) -> [String] {
        let dir = profilesDir(home)
        return ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .filter { !$0.hasPrefix(".") }
            .sorted()
    }

    static func parseEnv(_ url: URL) -> [String: String] {
        var env: [String: String] = [:]
        guard let s = try? String(contentsOf: url, encoding: .utf8) else { return env }
        for raw in s.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let k = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            var v = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            if v.count >= 2, (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
                v = String(v.dropFirst().dropLast())
            }
            env[k] = v
        }
        return env
    }

    /// LIVE_HOME (env) → LiveHome (Info.plist, diisi build.sh) → folder kerja.
    static func findHome() -> URL {
        if let p = ProcessInfo.processInfo.environment["LIVE_HOME"], !p.isEmpty { return URL(fileURLWithPath: p) }
        if let p = Bundle.main.object(forInfoDictionaryKey: "LiveHome") as? String, !p.isEmpty { return URL(fileURLWithPath: p) }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    func str(_ k: String, _ d: String = "") -> String {
        if let v = env[k], !v.isEmpty { return v }
        return d
    }

    func num(_ k: String, _ d: Double) -> Double { Double(str(k)) ?? d }

    /// Baca LLM1_*, LLM2_*, ... sesuai urutan prioritas.
    func endpoints() -> [Endpoint] {
        (1...4).compactMap { endpoint("LLM\($0)") }
    }

    func endpoint(_ prefix: String) -> Endpoint? {
        let u = str("\(prefix)_URL"), m = str("\(prefix)_MODEL")
        guard !u.isEmpty, !m.isEmpty, let url = URL(string: chatURL(u)) else { return nil }
        var extra: [String: Any] = [:]
        if let data = str("\(prefix)_EXTRA").data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            extra = obj
        }
        return Endpoint(label: str("\(prefix)_LABEL", m), url: url, key: str("\(prefix)_KEY"), model: m, extra: extra)
    }
}

/// `https://host`, `https://host/v1`, atau URL lengkap → endpoint chat completions.
func chatURL(_ base: String) -> String {
    var b = base
    while b.hasSuffix("/") { b.removeLast() }
    if b.hasSuffix("/chat/completions") { return b }
    if b.range(of: #"/v\d+$"#, options: .regularExpression) != nil { return b + "/chat/completions" }
    return b + "/v1/chat/completions"
}
