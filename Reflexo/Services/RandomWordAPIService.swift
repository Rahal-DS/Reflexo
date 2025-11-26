//
//  RandomWordService.swift
//  Reflexo
//
//  Created by Asmiya Hasan on 12/10/2025.
//

import Foundation

/// A lightweight abstraction for fetching random words.
///
/// Conform to ``RandomWordService`` to provide different word sources
///
/// ### Usage
/// ```swift
/// let service: RandomWordService = RandomWordAPIService()
/// let words = try await service.fetchWords(count: 50)
protocol RandomWordService {
    /// Fetches a list of random words.
    ///
    /// Implementations should strive to:
    /// - return exactly `count` words when possible,
    /// - normalize whitespace and casing to support equality checks,
    /// - avoid duplicates or remove them before returning.
    ///
    /// - Parameter count: Desired number of words to return.
    /// - Returns: An array of words. Implementations may return fewer than
    ///   `count` items if the source cannot supply enough unique words.
    /// - Throws: An error describing a transport or decoding failure.
    func fetchWords(count: Int) async throws -> [String]
}

/// A concrete implementation of ``RandomWordService`` backed by
/// the Random Word API (`/word` endpoint).
///
/// This service:
/// - performs a simple GET with `number={count}`,
/// - validates a 2xx HTTP response,
/// - decodes the JSON into `[String]`,
/// - trims whitespace, lowercases, and de-duplicates results,
/// - returns a shuffled array.
///
/// ### Example
/// ```swift
/// let api = RandomWordAPIService()
/// let tenWords = try await api.fetchWords(count: 10)
/// print(tenWords) // ["river", "lamp", "ocean", ...]
/// ```
///
/// - Important: Network calls occur on the shared `URLSession` by default.
///   You can inject a custom session (e.g., with an ephemeral configuration or
///   a stubbing interceptor) via the initializer for testing.
struct RandomWordAPIService: RandomWordService {
    /// The `URLSession` used for requests.
    private let session: URLSession
    
    /// Base endpoint for random word retrieval.
    private let baseURL = URL(string: "https://random-word-api.herokuapp.com/word")!

    /// Creates a new service.
    ///
    /// - Parameter session: The session used for all requests. Defaults to `.shared`.
    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetches `count` random words from the Random Word API.
    ///
    /// The response is validated (2xx), decoded into `[String]`,
    /// normalized (trim + lowercase), de-duplicated, and shuffled.
    ///
    /// - Parameter count: Desired number of words to return.
    /// - Returns: A shuffled array of unique, lowercased words. The result may
    ///   contain fewer than `count` items if the upstream API returns duplicates.
    /// - Throws: `URLError(.badServerResponse)` for non-2xx responses, or any
    ///   decoding/networking error encountered by `URLSession`/`JSONDecoder`.
    ///
    func fetchWords(count: Int) async throws -> [String] {
        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "number", value: String(count))
        ]
        let url = comps.url!

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let words = try JSONDecoder().decode([String].self, from: data)
        // Normalize & de-dup just in case
        let normalized = words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return Array(Set(normalized)).shuffled()
    }
}

// MARK: - Mock for previews/tests

/// A deterministic mock implementation of ``RandomWordService``
/// for use in unit tests and SwiftUI previews.
///
/// This mock returns a stable pool of 50 words and slices it to `count`,
/// then shuffles the slice to emulate non-deterministic ordering without
/// performing any network calls.
///
/// ### Example (Injecting into a ViewModel)
/// ```swift
/// let mock = RandomWordMockService()
/// let words = try await mock.fetchWords(count: 8)
/// XCTAssertEqual(words.count, 8)
/// ```
///
/// - Note: Because the source pool is finite (50 items), requesting a `count`
///   greater than the pool size will simply return the entire pool (shuffled).
struct RandomWordMockService: RandomWordService {
    /// Returns up to `count` words from a fixed pool, shuffled.
    ///
    /// - Parameter count: Desired number of words to return.
    /// - Returns: A shuffled subset of a fixed base list whose size is `min(count, 50)`.
    func fetchWords(count: Int) async throws -> [String] {
        let base = [
            "apple","river","cloud","stone","lamp","novel","tiger","piano","garden","planet",
            "cookie","bridge","coffee","mirror","rocket","pear","shadow","candle","stream","violet",
            "castle","forest","compass","puzzle","ocean","mountain","island","silver","gold","bronze",
            "window","pillow","blanket","helmet","guitar","violin","drum","camera","clock","wallet",
            "ticket","hammer","ladder","basket","painter","singer","dancer","writer","pilot","doctor"
        ]
        return Array(base.prefix(count)).shuffled()
    }
}

