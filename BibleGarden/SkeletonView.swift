import SwiftUI
import OpenAPIURLSession

// MARK: ReadProgress
struct ReadProgress: Codable {
    var readChapters: Set<String> = [] // ["gen_1", "exo_2", ...]
    var startDate: Date = Date()
}

// MARK: LanguageDefaults
private enum LanguageDefaults {
    static let systemLanguage: String = {
        let lang = Locale.current.languageCode ?? "en"
        switch lang {
        case "ru": return "ru"
        case "uk": return "uk"
        default: return "en"
        }
    }()

    static var language: String { systemLanguage }

    static var translation: Int {
        switch systemLanguage {
        case "ru": return 1
        case "uk": return 20
        default: return 16
        }
    }

    static var translationName: String {
        switch systemLanguage {
        case "ru": return "SYNO"
        case "uk": return "UBH"
        default: return "BSB"
        }
    }

    static var voice: Int {
        switch systemLanguage {
        case "ru": return 1
        case "uk": return 130
        default: return 151
        }
    }

    static var voiceName: String {
        switch systemLanguage {
        case "ru": return "Alexander Bondarenko"
        case "uk": return "Igor Kozlov"
        default: return "Bob Souer"
        }
    }

    static var voiceMusic: Bool {
        systemLanguage == "ru"
    }
}

// MARK: SettingsManager
class SettingsManager: ObservableObject {
    
    @Published var showMenu: Bool = false
    @Published var selectedMenuItem: MenuItem = .main
    
    @AppStorage("fontIncreasePercent") var fontIncreasePercent: Double = 100.0
    
    @AppStorage("pauseType") var pauseType: PauseType = .none
    @AppStorage("pauseLength") var pauseLength: Double = 3.0
    @AppStorage("pauseBlock") var pauseBlock: PauseBlock = .verse
    
    @AppStorage("autoNextChapter") var autoNextChapter: Bool = true
    @AppStorage("autoProgressAudioEnd") var autoProgressAudioEnd: Bool = false
    @AppStorage("autoProgressFrom90Percent") var autoProgressFrom90Percent: Bool = true
    @AppStorage("autoProgressConsiderSeeking") var autoProgressConsiderSeeking: Bool = true
    @AppStorage("autoProgressByReading") var autoProgressByReading: Bool = true
    
    @AppStorage("language") var language: String = LanguageDefaults.language
    @AppStorage("translation") var translation: Int = LanguageDefaults.translation
    @AppStorage("translationName") var translationName: String = LanguageDefaults.translationName
    @AppStorage("voice") var voice: Int = LanguageDefaults.voice
    @AppStorage("voiceName") var voiceName: String = LanguageDefaults.voiceName
    @AppStorage("voiceMusic") var voiceMusic: Bool = LanguageDefaults.voiceMusic
    
    @AppStorage("currentExcerpt") var currentExcerpt: String = "jhn 1"
    
    @Published var currentExcerptTitle: String = UserDefaults.standard.string(forKey: "currentExcerptTitle") ?? "Gospel of John" {
        didSet {
            UserDefaults.standard.set(currentExcerptTitle, forKey: "currentExcerptTitle")
        }
    }
    
    @Published var currentExcerptSubtitle: String = UserDefaults.standard.string(forKey: "currentExcerptSubtitle") ?? "Chapter 1" {
        didSet {
            UserDefaults.standard.set(currentExcerptSubtitle, forKey: "currentExcerptSubtitle")
        }
    }
    
    @AppStorage("currentBookId") var currentBookId: Int = 0
    @AppStorage("currentChapterId") var currentChapterId: Int = 0
    
    @AppStorage("currentSpeed") var currentSpeed: Double = 1.0
    
    // MARK: Multilingual
    @AppStorage("multilingualStepsData") var multilingualStepsData: Data = Data()
    @Published var multilingualSteps: [MultilingualStep] = []
    @AppStorage("multilingualReadUnit") var multilingualReadUnitRaw: String = MultilingualReadUnit.verse.rawValue
    @AppStorage("isMultilingualReadingActive") var isMultilingualReadingActive: Bool = false
    @AppStorage("isFirstMultilingualSetup") var isFirstMultilingualSetup: Bool = true
    
    var multilingualReadUnit: MultilingualReadUnit {
        get { MultilingualReadUnit(rawValue: multilingualReadUnitRaw) ?? .verse }
        set { multilingualReadUnitRaw = newValue.rawValue }
    }
    
    private let baseURLString: String = Config.baseURL
    static let apiKey: String = Config.apiKey
    
    let client: any APIProtocol
    
    // MARK: Book and chapter caching
    @Published var cachedBooks: [Components.Schemas.TranslationBookModel] = []
    @Published var cachedBooksTranslation: Int = 0
    @Published var cachedBooksVoice: Int = 0
    
    // MARK: Reading progress
    @Published var readProgress: ReadProgress = ReadProgress()
    private let readProgressKey = "readProgress"
    
    init() {
        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.httpAdditionalHeaders = [
            "X-API-Key": Self.apiKey
        ]
        let session = URLSession(configuration: sessionConfiguration)
        let transport = URLSessionTransport(configuration: .init(session: session))
        self.client = Client(serverURL: URL(string: baseURLString)!, transport: transport)
        
        // Load stored reading progress
        loadReadProgress()
        loadMultilingualSteps()
        loadMultilingualTemplates()
    }
    
    /// Builds a full audio URL by appending the api_key query parameter.
    /// - Parameter relativePath: For example: "syn/bondarenko/01/01.mp3".
    /// - Returns: A URL like "http://.../api/audio/syn/bondarenko/01/01.mp3?api_key=YOUR_KEY"
    func audioURL(forRelativePath relativePath: String) -> URL? {
        var components = URLComponents(string: baseURLString)
        components?.path = "/api/audio/" + relativePath
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "api_key", value: Self.apiKey))
        components?.queryItems = queryItems
        return components?.url
    }
    
    /// Appends the api_key query parameter to absolute audio URLs if missing (static variant).
    /// - Parameter url: An absolute URL that may point to the audio endpoint.
    /// - Returns: The same URL with the api_key attached if it's an audio URL, otherwise unchanged.
    static func audioURLWithKey(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        guard components.path.contains("/audio/") else { return url }
        var items = components.queryItems ?? []
        let hasKey = items.contains { $0.name == "api_key" }
        if !hasKey {
            items.append(URLQueryItem(name: "api_key", value: Self.apiKey))
            components.queryItems = items
        }
        return components.url ?? url
    }
    
    /// Appends the api_key query parameter to absolute audio URLs if missing.
    /// - Parameter url: An absolute URL that may point to the audio endpoint.
    /// - Returns: The same URL with the api_key attached if it's an audio URL, otherwise unchanged.
    func audioURL(fromAbsoluteURL url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        guard components.path.contains("/audio/") else { return url }
        var items = components.queryItems ?? []
        let hasKey = items.contains { $0.name == "api_key" }
        if !hasKey {
            items.append(URLQueryItem(name: "api_key", value: Self.apiKey))
            components.queryItems = items
        }
        return components.url ?? url
    }
    
    // MARK: Translations Caching
    @Published var cachedAllTranslations: [Components.Schemas.TranslationModel] = []
    
    /// Fetches all translations once and caches them.
    /// Thread-safe update to published property.
    func fetchAllTranslations() async throws {
        if !cachedAllTranslations.isEmpty { return }
        
        // Pass empty language to get all translations
        let response = try await client.get_translations(query: .init(language: ""))
        let translations = try response.ok.body.json
        
        await MainActor.run {
            self.cachedAllTranslations = translations
        }
    }
    
    /// Returns translations filtered by language from cache.
    func getTranslations(for languageCode: String) -> [Components.Schemas.TranslationModel] {
        return cachedAllTranslations.filter { $0.language == languageCode }
    }
    
    // MARK: Languages Caching
    @Published var cachedLanguages: [Components.Schemas.LanguageModel] = []
    
    /// Fetches languages once and caches them.
    func fetchLanguages() async throws {
        if !cachedLanguages.isEmpty { return }
        
        let response = try await client.get_languages()
        let languages = try response.ok.body.json
        
        await MainActor.run {
            self.cachedLanguages = languages
        }
    }
    
    // MARK: Fetching books with caching
    /// Returns books for the current translation and voice.
    /// Uses cache if data was already loaded for this translation/voice pair.
    /// - Returns: Array of books or throws on load error
    func getTranslationBooks() async throws -> [Components.Schemas.TranslationBookModel] {
        // Make sure cache is still valid
        if !cachedBooks.isEmpty && 
           cachedBooksTranslation == translation && 
           cachedBooksVoice == voice {
            return cachedBooks
        }
        
        // Fetch from API
        let response = try await client.get_translation_books(
            path: .init(translation_code: translation),
            query: .init(voice_code: voice)
        )
        let books = try response.ok.body.json
        
        // Save to cache
        await MainActor.run {
            self.cachedBooks = books
            self.cachedBooksTranslation = translation
            self.cachedBooksVoice = voice
        }
        
        return books
    }
    
    /// Clears book cache (e.g. when settings change)
    func clearBooksCache() {
        cachedBooks = []
        cachedBooksTranslation = 0
        cachedBooksVoice = 0
    }
    
    // MARK: Reading progress helpers
    
    /// Loads reading progress from UserDefaults
    private func loadReadProgress() {
        if let data = UserDefaults.standard.data(forKey: readProgressKey),
           let progress = try? JSONDecoder().decode(ReadProgress.self, from: data) {
            self.readProgress = progress
        }
    }
    
    /// Saves reading progress into UserDefaults
    private func saveReadProgress() {
        if let data = try? JSONEncoder().encode(readProgress) {
            UserDefaults.standard.set(data, forKey: readProgressKey)
        }
    }
    
    /// Builds a chapter key formatted as "bookAlias_chapterNumber"
    private func chapterKey(book: String, chapter: Int) -> String {
        return "\(book)_\(chapter)"
    }
    
    /// Marks a chapter as read
    func markChapterAsRead(book: String, chapter: Int) {
        let key = chapterKey(book: book, chapter: chapter)
        readProgress.readChapters.insert(key)
        saveReadProgress()
    }
    
    /// Marks a chapter as unread
    func markChapterAsUnread(book: String, chapter: Int) {
        let key = chapterKey(book: book, chapter: chapter)
        readProgress.readChapters.remove(key)
        saveReadProgress()
    }
    
    /// Checks whether a chapter is read
    func isChapterRead(book: String, chapter: Int) -> Bool {
        let key = chapterKey(book: book, chapter: chapter)
        return readProgress.readChapters.contains(key)
    }
    
    /// Returns progress for a specific book
    func getBookProgress(book: String, totalChapters: Int) -> (read: Int, total: Int) {
        var readCount = 0
        for chapter in 1...totalChapters {
            if isChapterRead(book: book, chapter: chapter) {
                readCount += 1
            }
        }
        return (readCount, totalChapters)
    }
    
    /// Returns total progress (requires info for all books)
    func getTotalProgress(books: [Components.Schemas.TranslationBookModel]) -> (read: Int, total: Int) {
        var totalRead = 0
        var totalChapters = 0
        
        for book in books {
            let progress = getBookProgress(book: book.alias, totalChapters: book.chapters_count)
            totalRead += progress.read
            totalChapters += progress.total
        }
        
        return (totalRead, totalChapters)
    }
    
    /// Resets all progress
    func resetProgress() {
        readProgress = ReadProgress()
        saveReadProgress()
    }
    
    /// Resets progress for a specific book
    func resetBookProgress(book: String, totalChapters: Int) {
        for chapter in 1...totalChapters {
            markChapterAsUnread(book: book, chapter: chapter)
        }
    }
    
    /// Marks an entire book as read
    func markBookAsRead(book: String, totalChapters: Int) {
        for chapter in 1...totalChapters {
            markChapterAsRead(book: book, chapter: chapter)
        }
    }
    
    /// Finds a book alias by its number using cached data
    func getBookAlias(bookNumber: Int) -> String {
        if let book = cachedBooks.first(where: { $0.book_number == bookNumber }) {
            return book.alias
        }
        return ""
    }
    
    // MARK: Multilingual storage
    func loadMultilingualSteps() {
        if !multilingualStepsData.isEmpty,
           let steps = try? JSONDecoder().decode([MultilingualStep].self, from: multilingualStepsData) {
            self.multilingualSteps = steps
        }
        
        if let idString = UserDefaults.standard.string(forKey: "currentTemplateId") {
            currentTemplateId = UUID(uuidString: idString)
        }
    }
    
    func saveMultilingualSteps() {
        if let data = try? JSONEncoder().encode(multilingualSteps) {
            multilingualStepsData = data
        }
        
        if let id = currentTemplateId {
            UserDefaults.standard.set(id.uuidString, forKey: "currentTemplateId")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentTemplateId")
        }
    }
    
    // MARK: Multilingual Templates
    @AppStorage("multilingualTemplatesData") var multilingualTemplatesData: Data = Data()
    @Published var multilingualTemplates: [MultilingualTemplate] = []
    @Published var currentTemplateId: UUID? = nil
    
    func loadMultilingualTemplates() {
        if let templates = try? JSONDecoder().decode([MultilingualTemplate].self, from: multilingualTemplatesData) {
            self.multilingualTemplates = templates
        }
    }
    
    func saveMultilingualTemplates() {
        if let data = try? JSONEncoder().encode(multilingualTemplates) {
            multilingualTemplatesData = data
        }
    }
    
    func deleteTemplate(at indexSet: IndexSet) {
        multilingualTemplates.remove(atOffsets: indexSet)
        saveMultilingualTemplates()
    }
}

struct SkeletonView: View {
    
    @StateObject private var settingsManager = SettingsManager()
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Not relevant here
    @State private var showAsPartOfRead: Bool = false
    @State private var showSoftUpdate = false
    @State private var versionCheckData: Components.Schemas.VersionCheckModel? = nil

    var body: some View {
        ZStack {
            Color("DarkGreen")
                .edgesIgnoringSafeArea(.all)
            
            if settingsManager.selectedMenuItem == .main {
                PageMainView()
                .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .read {
                PageReadView()
                    .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .select {
                PageSelectView(showFromRead: $showAsPartOfRead)
                .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .progress {
                PageProgressView()
                .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .setup {
                PageReadSettingsView(showFromRead: $showAsPartOfRead)
                .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .contacts {
                PageAboutView()
                .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .multilingual {
                PageMultilingualSetupView()
                .environmentObject(settingsManager)
            }
            
            else if settingsManager.selectedMenuItem == .multilingualRead {
                PageMultilingualReadView()
                .environmentObject(settingsManager)
            }
            
            /// menu overlay: tap outside to close
            if settingsManager.showMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            settingsManager.showMenu = false
                        }
                    }
            }

            /// menu layer
            MenuView()
                .environmentObject(settingsManager)
                .offset(x: settingsManager.showMenu ? 0 : -getRect().width)
                .animation(.spring(), value: settingsManager.showMenu)
                .id("menu_\(settingsManager.selectedMenuItem)_\(localizationManager.currentLanguage.rawValue)")

            // Hard update — full-screen blocking overlay
            if let data = versionCheckData, data.update_type == .hard {
                Color("DarkGreen").ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.7))
                    if let msg = data.message {
                        Text(localizedMessage(msg))
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Button {
                        if let url = URL(string: data.store_url) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Text("update.go".localized)
                            .fontWeight(.bold)
                            .foregroundColor(Color("DarkGreen"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            checkAppVersion()
        }
        .alert("", isPresented: $showSoftUpdate) {
            Button("update.later".localized, role: .cancel) { }
            Button("update.go".localized) {
                if let data = versionCheckData, let url = URL(string: data.store_url) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            if let data = versionCheckData, let msg = data.message {
                Text(localizedMessage(msg))
            }
        }
    }

    // MARK: - Version Check

    private func checkAppVersion() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        Task {
            do {
                let response = try await settingsManager.client.versionCheck(query: .init(app_version: appVersion))
                let data = try response.ok.body.json
                await MainActor.run {
                    versionCheckData = data
                    if data.update_type == .soft {
                        showSoftUpdate = true
                    }
                }
            } catch {
                // Silently ignore — don't block app on network error
            }
        }
    }

    private func localizedMessage(_ text: Components.Schemas.LocalizedText) -> String {
        switch localizationManager.currentLanguage {
        case .russian:  return text.ru
        case .english:  return text.en
        case .ukrainian: return text.uk
        }
    }
}

#Preview {
    SkeletonView()
}
