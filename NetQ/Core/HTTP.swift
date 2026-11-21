import Foundation

enum HTTP {
    static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 8
        c.timeoutIntervalForResource = 15
        return URLSession(configuration: c)
    }()

    static func json<T: Decodable & Sendable>(_ url: URL, as type: T.Type) async throws -> T {
        let (data, resp) = try await session.data(from: url)
        guard let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(T.self, from: data)
    }
}
