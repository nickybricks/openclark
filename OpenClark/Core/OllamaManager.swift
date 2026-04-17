import Foundation
import os.log

/// Manages the Ollama server binary lifecycle and model downloads.
/// Downloads the binary on first use; finds existing system installations.
actor OllamaManager {
    static let shared = OllamaManager()

    private let logger = Logger(subsystem: "com.openclark", category: "ollama")
    private var serverProcess: Process?

    let port = 11434
    var baseURL: String { "http://127.0.0.1:\(port)" }

    private var appSupportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenClark/ollama-bin")
    }

    private var appSupportBinaryURL: URL {
        appSupportDir.appendingPathComponent("ollama")
    }

    // MARK: - Binary

    var isOllamaAvailable: Bool {
        findBinaryPath() != nil
    }

    func findBinaryPath() -> String? {
        let candidates = [
            appSupportBinaryURL.path,
            "/opt/homebrew/bin/ollama",
            "/usr/local/bin/ollama",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Downloads ollama-darwin.tgz from GitHub Releases and extracts it (binary + dylibs).
    func downloadOllama(onProgress: @escaping @Sendable (String) -> Void) async throws {
        guard let url = URL(string: "https://github.com/ollama/ollama/releases/latest/download/ollama-darwin.tgz") else {
            throw OllamaError.invalidURL
        }

        try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)

        onProgress("Ollama wird heruntergeladen…")
        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw OllamaError.downloadFailed
        }

        onProgress("Ollama wird entpackt…")

        // Remove old install if present
        if FileManager.default.fileExists(atPath: appSupportBinaryURL.path) {
            try FileManager.default.removeItem(at: appSupportDir)
            try FileManager.default.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        let tgzDest = appSupportDir.appendingPathComponent("ollama-darwin.tgz")
        try FileManager.default.moveItem(at: tempURL, to: tgzDest)

        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-xzf", tgzDest.path, "-C", appSupportDir.path]
        try tar.run()
        tar.waitUntilExit()

        try? FileManager.default.removeItem(at: tgzDest)

        guard FileManager.default.fileExists(atPath: appSupportBinaryURL.path) else {
            throw OllamaError.downloadFailed
        }

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755 as Int],
            ofItemAtPath: appSupportBinaryURL.path
        )
        onProgress("Ollama bereit")
    }

    // MARK: - Server

    func ensureServerRunning() async throws {
        if await isServerRunning() { return }

        guard let path = findBinaryPath() else {
            throw OllamaError.binaryNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["serve"]
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["OLLAMA_HOST": "127.0.0.1:\(port)"],
            uniquingKeysWith: { _, new in new }
        )
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        serverProcess = process

        for _ in 0..<20 {
            try await Task.sleep(for: .milliseconds(500))
            if await isServerRunning() { return }
        }
        throw OllamaError.serverStartTimeout
    }

    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
    }

    func isServerRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        return (try? await URLSession.shared.data(for: req)) != nil
    }

    // MARK: - Models

    func isModelInstalled(_ model: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/api/tags"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return false }
        let base = model.components(separatedBy: ":").first ?? model
        return models.contains {
            ($0["name"] as? String)?.hasPrefix(base) == true
        }
    }

    /// Streams pull progress lines. Throws on network/server errors.
    func pullModel(_ model: String, onProgress: @escaping @Sendable (String) -> Void) async throws {
        guard let url = URL(string: "\(baseURL)/api/pull") else {
            throw OllamaError.invalidURL
        }
        let body = try JSONSerialization.data(withJSONObject: ["name": model, "stream": true])
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (bytes, _) = try await URLSession.shared.bytes(for: request)
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? String else { continue }

            if let total = json["total"] as? Int64, let completed = json["completed"] as? Int64, total > 0 {
                let pct = Int((Double(completed) / Double(total)) * 100)
                let mb = ByteCountFormatter.string(fromByteCount: completed, countStyle: .binary)
                let totalMB = ByteCountFormatter.string(fromByteCount: total, countStyle: .binary)
                onProgress("\(status) – \(pct)% (\(mb) / \(totalMB))")
            } else {
                onProgress(status)
            }
        }
    }
}

enum OllamaError: Error, LocalizedError {
    case binaryNotFound
    case serverStartTimeout
    case downloadFailed
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .binaryNotFound: return "Ollama nicht gefunden. Bitte herunterladen."
        case .serverStartTimeout: return "Ollama-Server konnte nicht gestartet werden."
        case .downloadFailed: return "Ollama-Download fehlgeschlagen."
        case .invalidURL: return "Ungültige Ollama URL."
        }
    }
}
