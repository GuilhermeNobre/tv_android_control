import Foundation

/// Finds the project folder and starts server.py when it isn't running.
@MainActor
final class ServerManager {
    private var process: Process?
    let port = 8000

    /// Project folder: Info.plist (written by build.sh) or the `projectRoot` default.
    var projectRoot: String? {
        let candidates = [
            UserDefaults.standard.string(forKey: "projectRoot"),
            Bundle.main.object(forInfoDictionaryKey: "TVProjectRoot") as? String,
        ]
        return candidates.compactMap { $0 }.first {
            FileManager.default.fileExists(atPath: ($0 as NSString).appendingPathComponent("server.py"))
        }
    }

    /// Starts the server (127.0.0.1 only) and returns an error message on failure.
    func start() -> String? {
        guard let root = projectRoot else {
            return "Não achei a pasta do projeto (server.py). Rode macos/build.sh de novo."
        }
        let python = (root as NSString).appendingPathComponent(".venv/bin/python")
        guard FileManager.default.isExecutableFile(atPath: python) else {
            return "Falta o ambiente Python: rode `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt` em \(root)"
        }
        let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
        let logURL = logs.appendingPathComponent("TVControl-server.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let log = try? FileHandle(forWritingTo: logURL)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: python)
        p.arguments = ["server.py", "--host", "127.0.0.1", "--port", String(port)]
        p.currentDirectoryURL = URL(fileURLWithPath: root)
        p.standardOutput = log
        p.standardError = log
        do {
            try p.run()
            process = p
            return nil
        } catch {
            return "Não consegui iniciar o servidor: \(error.localizedDescription)"
        }
    }

    /// Stops the server, but only if this app started it.
    func stop() {
        process?.terminate()
        process = nil
    }
}
