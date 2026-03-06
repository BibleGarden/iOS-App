import SwiftUI

struct PageSelectView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    @Binding var showFromRead: Bool
    @State private var scrollToTop = false
    
    @State private var selectedBiblePartIndex: Int = -1 // 0 - OT, 1 - NT
    @State private var expandedBook: Int = 0
    @State private var needSelectedBookOpen: Bool = true
    
    @State private var booksInfo: [Components.Schemas.TranslationBookModel] = []
    
    @State private var isLoading = false
    @State private var loadingError = ""

    var body: some View {
        
        ZStack {
            VStack(spacing: 0) {
                
                VStack(spacing: 0) {
                    // MARK: Header
                    ZStack {
                        Text("page.select.title".localized)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        HStack {
                            if showFromRead {
                                Button {
                                    showFromRead = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.title3.weight(.light))
                                        .frame(width: 32, height: 32)
                                }
                                .foregroundColor(Color.white.opacity(0.7))
                                .accessibilityIdentifier("select-close")
                            }
                            else {
                                MenuButtonView()
                                    .environmentObject(settingsManager)
                                    .frame(width: 32, height: 32)
                            }

                            Spacer()

                            Color.clear
                                .frame(width: 32, height: 32)
                        }
                    }
                    .padding(.horizontal, globalBasePadding)
                    .headerPadding()
                    .background(Color("DarkGreen").brightness(0.05))
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
                            if (selectedBiblePartIndex == 0 && book.book_number < 39) || (selectedBiblePartIndex == 1 && book.book_number >= 39) || selectedBiblePartIndex == -1 {
                                
                                if let headerTitle = bibleHeaders[book.book_number] {
                                    viewGroupHeader(text: headerTitle)
                                }
                                
                                // Expand / collapse book
                                Button {
                                    
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
                                    .id("book_\(book.book_number)")
                                }
                                 
                                if expandedBook == book.book_number || (settingsManager.currentBookId == book.book_number && needSelectedBookOpen) {
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
                proxy.scrollTo("book_\(settingsManager.currentBookId)", anchor: .top)
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
            //Spacer()
        }
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
