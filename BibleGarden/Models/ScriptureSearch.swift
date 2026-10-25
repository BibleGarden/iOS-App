import SwiftUI
import OpenAPIRuntime
import OpenAPIURLSession

struct ScriptureSearchHit: Identifiable {
    let result: Components.Schemas.SearchResult
    let book: Components.Schemas.TranslationBookModel

    var id: String { result.canonical.canonical_id }
    var passage: Components.Schemas.PassageModel { result.passage }
    var highlight: Components.Schemas.HighlightPassage { result.highlight.passage }
    var verses: [Components.Schemas.VerseModel] { passage.verses ?? [] }
    var keyVerses: [Components.Schemas.VerseModel] { verses.filter { isHighlighted($0.number) } }
    var reference: String { reference(from: passage.verse_start, to: passage.verse_end) }
    var keyReference: String { reference(from: highlight.verse_start, to: highlight.verse_end) }

    private func reference(from: Int, to: Int) -> String {
        let range = from == to ? "\(from)" : "\(from)–\(to)"
        return "\(book.name) \(passage.chapter_number):\(range)"
    }

    func isHighlighted(_ number: Int) -> Bool {
        number >= highlight.verse_start && number <= highlight.verse_end
    }

    static func hasValidHighlight(_ result: Components.Schemas.SearchResult) -> Bool {
        let range = result.highlight.passage
        guard let verses = result.passage.verses,
              range.chapter_number == result.passage.chapter_number,
              range.verse_start >= result.passage.verse_start,
              range.verse_end <= result.passage.verse_end,
              range.verse_start <= range.verse_end,
              verses.contains(where: { $0.number == range.verse_start }),
              verses.contains(where: { $0.number == range.verse_end }) else { return false }
        let count = verses.filter { $0.number >= range.verse_start && $0.number <= range.verse_end }.count
        return (1...3).contains(count)
    }
    var excerpt: String {
        "\(book.alias) \(passage.chapter_number):\(passage.verse_start)-\(passage.verse_end)"
    }
}

@MainActor
final class ScriptureSearchModel: ObservableObject {
    enum Phase {
        case idle, loading, loaded
        case failed(String)
    }

    @Published var query = ""
    @Published private(set) var language = ""
    @Published private(set) var translation = 0
    @Published private(set) var translationName = ""
    @Published private(set) var translations: [Components.Schemas.TranslationModel] = []
    @Published private(set) var hits: [ScriptureSearchHit] = []
    @Published private(set) var submittedQuery = ""
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var catalogError = false
    @Published private(set) var retryAfter: Date?

    private var task: Task<Void, Never>?
    private var requestID = UUID()
    private let client: any APIProtocol

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 45
        configuration.httpAdditionalHeaders = ["X-API-Key": Config.apiKey]
        client = Client(
            serverURL: URL(string: Config.baseURL)!,
            transport: URLSessionTransport(configuration: .init(session: URLSession(configuration: configuration)))
        )
    }

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    func configure(settings: SettingsManager) async {
        if language.isEmpty {
            language = settings.language
            translation = settings.translation
            translationName = settings.translationName
        }
        guard translations.isEmpty else { return }
        catalogError = false
        do {
            try await settings.fetchAllTranslations()
            try Task.checkCancellation()
            translations = settings.cachedAllTranslations.filter {
                $0.active && ["ru", "en", "uk"].contains($0.language)
            }
            if let selected = translations.first(where: { $0.code == translation }) {
                translationName = selected.name
            }
        } catch is CancellationError {
            return
        } catch {
            catalogError = true
        }
    }

    func select(_ selection: Components.Schemas.TranslationModel) {
        cancel()
        language = selection.language
        translation = selection.code
        translationName = selection.name
        hits = []
        phase = .idle
    }

    func cancel() {
        requestID = UUID()
        task?.cancel()
        task = nil
        if isLoading { phase = hits.isEmpty ? .idle : .loaded }
    }

    func search() {
        guard !trimmedQuery.isEmpty, trimmedQuery.count <= 500,
              translation > 0, let searchLanguage = Components.Schemas.Language(rawValue: language),
              retryAfter == nil || retryAfter! <= Date() else { return }
        cancel()
        let id = requestID
        let text = trimmedQuery
        let requestedTranslation = translation
        submittedQuery = text
        hits = []
        phase = .loading
        task = Task {
            do {
                let response = try await client.search_scripture(body: .json(.init(
                    query: text, language: searchLanguage, translation: requestedTranslation, limit: 5
                )))
                try Task.checkCancellation()
                guard requestID == id else { return }
                switch response {
                case .ok(let output):
                    let answer = try output.body.json
                    guard answer.translation == requestedTranslation, answer.language == searchLanguage else {
                        phase = .failed("search.error.response")
                        return
                    }
                    if answer.results.isEmpty {
                        phase = .loaded
                        return
                    }
                    let booksResponse = try await client.get_translation_books(
                        path: .init(translation_code: answer.translation), query: .init(voice_code: 0)
                    )
                    guard requestID == id, !Task.isCancelled else { return }
                    guard case .ok(let booksOutput) = booksResponse else {
                        phase = .failed("search.error.response")
                        return
                    }
                    let books = try booksOutput.body.json
                    try Task.checkCancellation()
                    guard requestID == id else { return }
                    var resolved: [ScriptureSearchHit] = []
                    for result in answer.results {
                        guard result.passage.translation == answer.translation,
                              ScriptureSearchHit.hasValidHighlight(result),
                              let book = books.first(where: { $0.book_number == result.passage.book_number }) else {
                            phase = .failed("search.error.response")
                            return
                        }
                        resolved.append(.init(result: result, book: book))
                    }
                    hits = resolved
                    phase = .loaded
                case .forbidden:
                    phase = .failed("search.error.authorization")
                case .unprocessableContent:
                    phase = .failed("search.error.translation")
                case .tooManyRequests(let output):
                    guard let raw = output.headers.Retry_hyphen_After,
                          let seconds = Int(raw), seconds >= 0 else {
                        phase = .failed("search.error.response")
                        return
                    }
                    retryAfter = Date().addingTimeInterval(TimeInterval(seconds))
                    phase = .failed("search.error.limit")
                case .serviceUnavailable:
                    phase = .failed("search.error.unavailable")
                case .gatewayTimeout:
                    phase = .failed("search.error.timeout")
                default:
                    phase = .failed("search.error.unavailable")
                }
            } catch {
                guard requestID == id, !Task.isCancelled else { return }
                let underlying = (error as? ClientError)?.underlyingError ?? error
                if let urlError = underlying as? URLError, urlError.code == .timedOut {
                    phase = .failed("search.error.timeout")
                } else if underlying is DecodingError {
                    phase = .failed("search.error.response")
                } else {
                    phase = .failed("search.error.network")
                }
            }
        }
    }

    func open(_ hit: ScriptureSearchHit, settings: SettingsManager) {
        guard let selected = translations.first(where: { $0.code == hit.passage.translation }) else {
            phase = .failed("search.error.translation")
            return
        }
        let voices = selected.voices.filter(\.active)
        let voice = voices.first(where: { $0.code == settings.voice }) ?? voices.first
        settings.language = selected.language
        settings.translation = selected.code
        settings.translationName = selected.name
        settings.voice = voice?.code ?? 0
        settings.voiceName = voice?.name ?? ""
        settings.voiceMusic = voice?.is_music ?? false
        settings.clearBooksCache()
        settings.currentExcerpt = hit.excerpt
        settings.currentBookId = hit.passage.book_number
        settings.currentChapterId = hit.passage.chapter_number
        settings.currentExcerptTitle = hit.book.name
        settings.currentExcerptSubtitle = "\(hit.passage.chapter_number):\(hit.passage.verse_start)–\(hit.passage.verse_end)"
        settings.readingFromSearch = true
        settings.selectedMenuItem = .read
    }
}
