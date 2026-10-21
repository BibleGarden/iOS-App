import SwiftUI

struct PageSelectView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @Binding var showFromRead: Bool
    @State private var scrollToTop = false
    
    @State private var selectedBiblePartIndex: Int = -1 // 0 - OT, 1 - NT
    @State private var expandedBook: Int = 0
    @State private var needSelectedBookOpen: Bool = true
    // The auto-scroll is the initial positioning only: the first manual
    // interaction with the list (book tap, chapter tap, testament switch,
    // scrolling) cancels it, including the already scheduled callbacks, so a
    // late list/current-book update can never override the user's position.
    @State private var isInitialAutoScrollActive: Bool = true
    @State private var pendingAutoScrollWorkItems: [DispatchWorkItem] = []
    
    @State private var booksInfo: [Components.Schemas.TranslationBookModel] = []
    
    @State private var isLoading = false
    @State private var loadingError = ""

    private static let oldTestamentBookCount = 39

    var body: some View {
        
        ZStack {
            VStack(spacing: 0) {
                
                VStack(spacing: 0) {
                    // MARK: Header
                    AppHeaderBar {
                        if showFromRead {
                            CloseHeaderButton {
                                showFromRead = false
                            }
                            .accessibilityIdentifier("select-close")
                        } else {
                            MenuButtonView()
                                .environmentObject(settingsManager)
                        }
                    } center: {
                        Text("page.select.title".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } trailing: {
                        HeaderPlaceholder()
                    }
                    .appHeaderBackground(isEmbedded: showFromRead, cornerRadius: AppHeaderMetrics.embeddedCornerRadius)
                    .padding(.bottom, 10)
                    
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                    else if loadingError == "" {
                        VStack(spacing: 0) {
                            viewSelectTestament()
                            viewBooksList()
                        }
                        .padding(.horizontal, globalBasePadding)
                    }
                    else {
                        Spacer()
                        Text("error.prefix".localized(loadingError))
                            .foregroundColor(.white)
                            .padding(.horizontal, globalBasePadding)
                        Spacer()
                    }
                }
            }
            // Background layer
            .background(
                Color("DarkGreen")
            )
            
            
            
        }
        .onAppear {
            fetchTranslationBooks()
        }
    }
    
    // MARK: fetchTranslationBooks
    func fetchTranslationBooks() {
        Task {
            do {
                self.isLoading = true
                self.loadingError = ""
                
                // Use cached method from SettingsManager
                let books = try await settingsManager.getTranslationBooks()
                
                self.booksInfo = books
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.loadingError = error.localizedDescription
            }
        }
    }
    
    // MARK: Testament selection
    fileprivate func viewSelectTestament() -> some View {
        return viewSegmentedButtons(arr: bibleParts,
                             selIndex: selectedBiblePartIndex,
                             baseColor: Color("Mustard"),
                             bgColor: Color("DarkGreen-light")
        ) { selectedIndex in
            cancelInitialAutoScroll()
            if selectedBiblePartIndex == selectedIndex {
                // Second tap clears selection
                selectedBiblePartIndex = -1
            }
            else {
                selectedBiblePartIndex = selectedIndex
            }
            scrollToTop.toggle()
        }
        .padding(.vertical, 15)
        .font(.title)
        .accessibilityIdentifier("testament-selector")
    }
    
    // MARK: Chapter list
    @ViewBuilder fileprivate func viewChaptersList(_ book: Components.Schemas.TranslationBookModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 15), count: 6), spacing: 15) {
            ForEach(1...book.chapters_count, id: \.self) { chapter_number in
                let hasNoAudio = book.chapters_without_audio?.contains(chapter_number) ?? false
                let hasNoText = book.chapters_without_text?.contains(chapter_number) ?? false
                
                let isCurrentChapter = settingsManager.currentBookId == book.book_number && settingsManager.currentChapterId == chapter_number
                let isRead = settingsManager.isChapterRead(book: book.alias, chapter: chapter_number)
                
                Button(action: {
                    // MARK: On chapter selection
                    cancelInitialAutoScroll()
                    settingsManager.currentExcerpt = "\(book.alias) \(chapter_number)"
                    settingsManager.currentExcerptTitle = book.name
                    settingsManager.currentExcerptSubtitle = "chapter.title".localized(chapter_number)
                    
                    if !showFromRead {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            settingsManager.selectedMenuItem = .read
                        }
                    }
                    
                    withAnimation(Animation.easeInOut(duration: 1)) {
                        showFromRead = false
                    }
                    
                }) {
                    ZStack {
                        Text("\(chapter_number)")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundColor(.white)
                            .background(isCurrentChapter ? .white.opacity(0.3) : .clear)
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        
                        // No-audio badge (top-left)
                        if hasNoAudio {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "speaker.slash.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color("Mustard"))
                                        .padding(3)
                                }
                            }
                        }
                        
                        // Checkmark for read chapter (top-right)
                        if isRead {
                            VStack {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.green)
                                        .padding(2)
                                }
                                Spacer()
                            }
                        }
                    }
                    .opacity(hasNoText ? 0.3 : 1)
                }
                .disabled(hasNoText)
                .contextMenu {
                    if isRead {
                        Button {
                            settingsManager.markChapterAsUnread(book: book.alias, chapter: chapter_number)
                        } label: {
                            Label("chapter.mark_as_unread".localized, systemImage: "xmark.circle")
                        }
                    } else {
                        Button {
                            settingsManager.markChapterAsRead(book: book.alias, chapter: chapter_number)
                        } label: {
                            Label("chapter.mark_as_read".localized, systemImage: "checkmark.circle")
                        }
                    }
                }
            }
        }
        .padding(.bottom, 10)
        .padding(1)
    }
    
    // MARK: Book list
    @ViewBuilder fileprivate func viewBooksList() -> ScrollViewReader<some View> {
        ScrollViewReader { proxy in
            ScrollView() {
                VStack(alignment: .leading) {
                    Color.clear
                        .frame(height: 0)
                        .id("top")
                    
                    if !self.booksInfo.isEmpty {
                        ForEach(self.booksInfo, id: \.code) { book in
                            if (selectedBiblePartIndex == 0 && book.book_number <= Self.oldTestamentBookCount) || (selectedBiblePartIndex == 1 && book.book_number > Self.oldTestamentBookCount) || selectedBiblePartIndex == -1 {
                                
                                let chaptersWithoutTextCount = book.chapters_without_text?.count ?? 0
                                let hasNoTextForWholeBook = chaptersWithoutTextCount == book.chapters_count

                                if let headerTitle = bibleHeaders[book.book_number] {
                                    viewGroupHeader(text: headerTitle)
                                }

                                // Expand / collapse book
                                Button {
                                    cancelInitialAutoScroll()

                                     withAnimation {
                                          expandedBook = book.book_number
                                     
                                         if book.book_number != settingsManager.currentBookId {
                                            needSelectedBookOpen = false
                                         }
                                     
                                         proxy.scrollTo("book_\(book.book_number)", anchor: .top)
                                     }
                                     
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(book.name)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        // Icon when entire book lacks audio
                                        let chaptersWithoutAudioCount = book.chapters_without_audio?.count ?? 0
                                        let hasNoAudioForWholeBook = chaptersWithoutAudioCount == book.chapters_count
                                        if hasNoAudioForWholeBook {
                                            Image(systemName: "speaker.slash.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(Color("Mustard"))
                                        }
                                        
                                        // Progress bar near the title
                                        let progress = settingsManager.getBookProgress(book: book.alias, totalChapters: book.chapters_count)
                                        if progress.read > 0 {
                                            let isCompleted = progress.read == progress.total
                                            let progressColor = isCompleted ? Color("Success") : Color("Mustard")
                                            
                                            ZStack {
                                                GeometryReader { geometry in
                                                    ZStack(alignment: .leading) {
                                                        // Background
                                                        RoundedRectangle(cornerRadius: 6)
                                                            .fill(Color.white.opacity(0.15))
                                                            .frame(height: 20)
                                                        
                                                        // Progress fill
                                                        let progressWidth = geometry.size.width * CGFloat(progress.read) / CGFloat(progress.total)
                                                        let progressPercent = CGFloat(progress.read) / CGFloat(progress.total)
                                                        
                                                        progressColor
                                                            .frame(width: progressWidth, height: 20)
                                                            .mask(
                                                                HStack(spacing: 0) {
                                                                    if progressPercent > 0.98 {
                                                                        RoundedRectangle(cornerRadius: 6)
                                                                    } else {
                                                                        LeftRoundedRectangle(radius: 6)
                                                                    }
                                                                }
                                                                .frame(width: progressWidth, height: 20)
                                                            )
                                                    }
                                                }
                                                .frame(height: 20)
                                                
                                                // Counter on top of progress bar
                                                Text("\(progress.read) / \(progress.total)")
                                                    .font(.footnote)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            }
                                            .frame(width: 100, height: 24)
                                        }
                                    }
                                    .padding(.vertical, 10)
                                    .opacity(hasNoTextForWholeBook ? 0.3 : 1)
                                    .id("book_\(book.book_number)")
                                }
                                .disabled(hasNoTextForWholeBook)
                                .accessibilityIdentifier("book_\(book.book_number)")

                                if !hasNoTextForWholeBook && (expandedBook == book.book_number || (settingsManager.currentBookId == book.book_number && needSelectedBookOpen)) {
                                    viewChaptersList(book)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .foregroundColor(Color("localAccentColor"))
                
            }
            .frame(maxHeight: .infinity)
            .onAppear {
                scheduleInitialAutoScroll(proxy: proxy)
            }
            .onChange(of: booksInfo) { _ in
                scheduleInitialAutoScroll(proxy: proxy)
            }
            .onChange(of: settingsManager.currentBookId) { _ in
                scheduleInitialAutoScroll(proxy: proxy)
            }
            .onChange(of: scrollToTop) { newValue in
                if newValue {
                    withAnimation {
                        proxy.scrollTo("top", anchor: .top)
                    }
                    // Reset the flag after scrolling
                    scrollToTop = false
                }
            }
            .simultaneousGesture(DragGesture(minimumDistance: 12)
                .onChanged { _ in
                    cancelInitialAutoScroll()
                }
            )
            //Spacer()
        }
    }

    /// Scrolls the book list to the current book at the initial positioning.
    ///
    /// The chapter grid is lazy: its buttons are created only when the book row
    /// is close to the viewport. A `scrollTo` issued in the same layout pass in
    /// which the lazy content is inserted may silently do nothing, so the scroll
    /// is deferred to the next run loop turn and repeated once more shortly
    /// after — both attempts stay cancelable by the first manual interaction.
    private func scheduleInitialAutoScroll(proxy: ScrollViewProxy) {
        guard isInitialAutoScrollActive, !booksInfo.isEmpty else { return }
        let bookId = settingsManager.currentBookId
        pendingAutoScrollWorkItems.forEach { $0.cancel() }
        pendingAutoScrollWorkItems = []
        for delay in [0.0, 0.35] {
            let work = DispatchWorkItem {
                proxy.scrollTo("book_\(bookId)", anchor: .top)
            }
            pendingAutoScrollWorkItems.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }

    /// Cancels the initial auto-scroll together with its scheduled callbacks.
    private func cancelInitialAutoScroll() {
        isInitialAutoScrollActive = false
        pendingAutoScrollWorkItems.forEach { $0.cancel() }
        pendingAutoScrollWorkItems = []
    }
    
}


struct TestPageSelectView: View {
    
    @State private var showFromRead: Bool = true
    
    var body: some View {
        PageSelectView(showFromRead: $showFromRead)
            .environmentObject(SettingsManager())
    }
}


#Preview {
    TestPageSelectView()
}
