import Foundation

/// Cliente HTTP da API do server.py (FastAPI).
struct TVClient {
    var baseURL = URL(string: "http://127.0.0.1:8000")!

    struct Volume: Decodable {
        let level: Int?
        let max: Int?
        let muted: Bool?
    }

    struct Device: Decodable {
        let manufacturer: String?
        let model: String?
    }

    struct Status: Decodable {
        let host: String
        let ligada: Bool?
        let app_atual: String?
        let volume: Volume?
        let dispositivo: Device?
        let apps: [String]
        let keys: [String]

        private enum CodingKeys: String, CodingKey {
            case host, ligada, app_atual, volume, dispositivo, apps, keys
        }

        // volume/dispositivo vêm direto da TV; se o formato mudar, não derruba o resto.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            host = try c.decode(String.self, forKey: .host)
            ligada = try? c.decode(Bool.self, forKey: .ligada)
            app_atual = try? c.decode(String.self, forKey: .app_atual)
            volume = try? c.decode(Volume.self, forKey: .volume)
            dispositivo = try? c.decode(Device.self, forKey: .dispositivo)
            apps = (try? c.decode([String].self, forKey: .apps)) ?? []
            keys = (try? c.decode([String].self, forKey: .keys)) ?? []
        }
    }

    struct APIError: LocalizedError {
        let errorDescription: String?
    }

    /// True se o servidor responde HTTP (mesmo com a TV fora do ar).
    func serverIsUp() async -> Bool {
        var req = URLRequest(url: baseURL, timeoutInterval: 2)
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            return resp is HTTPURLResponse
        } catch {
            return false
        }
    }

    func status() async throws -> Status {
        let data = try await call("/api/status", method: "GET", timeout: 15)
        return try JSONDecoder().decode(Status.self, from: data)
    }

    func key(_ name: String, times: Int = 1) async throws {
        let q = times > 1 ? "?times=\(times)" : ""
        _ = try await call("/api/key/\(name)\(q)")
    }

    func power(_ on: Bool) async throws { _ = try await call("/api/power/\(on ? "on" : "off")") }
    func screen(_ on: Bool) async throws { _ = try await call("/api/screen/\(on ? "on" : "off")") }
    func app(_ name: String) async throws { _ = try await call("/api/app/\(name)") }

    func text(_ value: String) async throws {
        _ = try await call("/api/text", body: ["value": value])
    }

    private func call(_ path: String, method: String = "POST", body: [String: String]? = nil,
                      timeout: TimeInterval = 20) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path), timeoutInterval: timeout)
        // appendingPathComponent escapa "?" — monta pela string quando há query.
        if let q = path.firstIndex(of: "?") {
            req.url = URL(string: baseURL.absoluteString + path[..<q] + "?" + path[path.index(after: q)...])
        }
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONEncoder().encode(body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError(errorDescription: "Resposta inválida") }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            switch http.statusCode {
            case 409: throw APIError(errorDescription: detail ?? "TV não pareada. Rode `tv.py pair` uma vez.")
            case 503: throw APIError(errorDescription: "Não consegui falar com a TV (ela está ligada na rede?)")
            default: throw APIError(errorDescription: detail ?? "Erro \(http.statusCode)")
            }
        }
        return data
    }
}
