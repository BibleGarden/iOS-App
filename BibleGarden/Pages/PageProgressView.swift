import SwiftUI

struct PageProgressView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @State private var showResetConfirmation = false
    @State private var booksInfo: [Components.Schemas.TranslationBookModel] = []
    @State private var isLoading = false
    @State private var showMenuForBook: Int? = nil
    @State private var showSettingsSheet = false
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    // MARK: Header
                    HStack {
                        MenuButtonView()
                            .environmentObject(settingsManager)
                        Spacer()
                        Text("page.progress.title".localized)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 26))
                        }
                    }
                    .headerPadding()

                    if isLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    } else if !booksInfo.isEmpty {
                        ScrollView {
                            VStack(spacing: 20) {
                                // MARK: Overall stats
                                let totalProgress = settingsManager.getTotalProgress(books: booksInfo)
                                
                                VStack(spacing: 10) {
                                    Text("progress.total".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .accessibilityIdentifier("progress-total")
                                    
                                    // Progress bar with overlayed percent
                                    ZStack {
                                        // Progress bar background
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white.opacity(0.3))
                                            .frame(height: 24)
                                        
                                        GeometryReader { geometry in
                                            let progressWidth = geometry.size.width * CGFloat(totalProgress.read) / CGFloat(totalProgress.total)
                                            let progressPercent = CGFloat(totalProgress.read) / CGFloat(totalProgress.total)
                                            
                                            // Green progress fill
                                            HStack(spacing: 0) {
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                                .frame(width: progressWidth, height: 24)
                                                
                                                Spacer(minLength: 0)
                                            }
                                            .mask(
                                                Group {
                                                    if progressPercent > 0.98 {
                                                        RoundedRectangle(cornerRadius: 6)
                                                    } else {
                                                        LeftRoundedRectangle(radius: 6)
                                                    }
                                                }
                                            )
                                        }
                                        .frame(height: 24)
                                        
                                        // Percentage label on top of the bar
                                        Text(String(format: "%.1f%%", Double(totalProgress.read) / Double(totalProgress.total) * 100))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                // MARK: Progress by books
                                VStack(alignment: .leading, spacing: 12) {
                                    // Books currently in progress
                                    let inProgressBooks = booksInfo.filter { book in
                                        let progress = settingsManager.getBookProgress(book: book.alias, totalChapters: book.chapters_count)
                                        return progress.read > 0 && progress.read < progress.total
                                    }
                                    
                                    if !inProgressBooks.isEmpty {
                                        Text("progress.books_in_progress".localized)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.top, inProgressBooks.isEmpty ? 0 : globalBasePadding)
                                        
                                        ForEach(inProgressBooks, id: \.code) { book in
                                            bookProgressCard(book: book)
                                        }
                                    }
                                    
                                    // Books not yet started
                                    let unstartedBooks = booksInfo.filter { book in
                                        let progress = settingsManager.getBookProgress(book: book.alias, totalChapters: book.chapters_count)
                                        return progress.read == 0
                                    }
                                    
                                    if !unstartedBooks.isEmpty {
                                        Text("progress.unstarted_books".localized)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.top, inProgressBooks.isEmpty ? 0 : globalBasePadding)
                                        
                                        ForEach(unstartedBooks, id: \.code) { book in
                                            bookProgressCard(book: book)
                                        }
                                    }
                                    
                                    // Completed books
                                    let completedBooks = booksInfo.filter { book in
                                        let progress = settingsManager.getBookProgress(book: book.alias, totalChapters: book.chapters_count)
                                        return progress.read > 0 && progress.read == progress.total
                                    }
                                    
                                    if !completedBooks.isEmpty {
                                        Text("progress.completed_books".localized)
                                            .font(.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .padding(.top, (inProgressBooks.isEmpty && unstartedBooks.isEmpty) ? 0 : globalBasePadding)
                                        
                                        ForEach(completedBooks, id: \.code) { book in
                                            bookProgressCard(book: book)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, globalBasePadding)
            }
            .background(Color("DarkGreen"))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            
        }
        .alert("progress.reset_confirmation.title".localized, isPresented: $showResetConfirmation) {
            Button("progress.reset_confirmation.cancel".localized, role: .cancel) { }
            Button("progress.reset_confirmation.reset".localized, role: .destructive) {
                settingsManager.resetProgress()
            }
        } message: {
            Text("progress.reset_confirmation.message".localized)
        }
        .sheet(isPresented: $showSettingsSheet) {
            ProgressSettingsSheet(showResetConfirmation: $showResetConfirmation)
                .environmentObject(settingsManager)
                .sheetFullScreen()
        }
        .onAppear {
            loadBooks()
        }
    }
    
    func loadBooks() {
        Task {
            do {
                isLoading = true
                let books = try await settingsManager.getTranslationBooks()
                self.booksInfo = books
                isLoading = false
            } catch {
                isLoading = false
            }
        }
    }
    
    @ViewBuilder
    func bookProgressCard(book: Components.Schemas.TranslationBookModel) -> some View {
        let progress = settingsManager.getBookProgress(book: book.alias, totalChapters: book.chapters_count)
        let isCompleted = progress.read == progress.total
        
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(book.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(progress.read)/\(progress.total)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Segmented progress bar
            GeometryReader { geometry in
                let spacing: CGFloat = progress.total > 50 ? 0 : 1
                let totalSpacing = spacing * CGFloat(progress.total - 1)
                
                HStack(spacing: spacing) {
                    ForEach(1...progress.total, id: \.self) { chapter in
                        let isRead = settingsManager.isChapterRead(book: book.alias, chapter: chapter)
                        let segmentWidth = (geometry.size.width - totalSpacing) / CGFloat(progress.total)
                        
                        Rectangle()
                            .fill(isRead ? (isCompleted ? Color.green : Color("Mustard")) : Color.white.opacity(0.2))
                            .frame(width: segmentWidth, height: 8)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            showMenuForBook = book.code
        }
        .confirmationDialog("", isPresented: Binding(
            get: { showMenuForBook == book.code },
            set: { if !$0 { showMenuForBook = nil } }
        )) {
            if !isCompleted {
                let nextChapter = findNextUnreadChapter(book: book, totalChapters: progress.total)
                Button("progress.read_chapter".localized(nextChapter)) {
                    navigateToUnreadChapter(book: book, progress: progress)
                }
            }
            
            if !isCompleted {
                Button("progress.mark_all_as_read".localized) {
                    settingsManager.markBookAsRead(book: book.alias, totalChapters: book.chapters_count)
                }
            }
            
            Button("progress.reset_book".localized, role: .destructive) {
                settingsManager.resetBookProgress(book: book.alias, totalChapters: book.chapters_count)
            }
            
            Button("progress.reset_confirmation.cancel".localized, role: .cancel) {}
        }
    }
    
    
    func findNextUnreadChapter(book: Components.Schemas.TranslationBookModel, totalChapters: Int) -> Int {
        for chapter in 1...totalChapters {
            if !settingsManager.isChapterRead(book: book.alias, chapter: chapter) {
                return chapter
            }
        }
        return 1 // Fallback
    }
    
    func navigateToUnreadChapter(book: Components.Schemas.TranslationBookModel, progress: (read: Int, total: Int)) {
        // Locate the first unread chapter
        let nextChapter = findNextUnreadChapter(book: book, totalChapters: progress.total)
        
        // Close menu if it is open
        if settingsManager.showMenu {
            withAnimation(.spring().delay(0.1)) {
                settingsManager.showMenu = false
            }
        }
        
        // Update current excerpt selection
        settingsManager.currentExcerpt = "\(book.alias) \(nextChapter)"
        settingsManager.currentExcerptTitle = book.name
        settingsManager.currentExcerptSubtitle = "chapter.title".localized(nextChapter)
        
        // Switch to the reading page
        settingsManager.selectedMenuItem = .read
    }
}

private struct ProgressSettingsSheet: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    @Binding var showResetConfirmation: Bool

    @ViewBuilder
    private func settingsToggle(titleKey: String, subtitleKey: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 10) {
                Text(titleKey.localized)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color("DarkGreen-accent")))
            }
            Text(subtitleKey.localized)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    var body: some View {
        ZStack {
            Color("DarkGreen")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ZStack {
                    Text("progress.settings.title".localized)
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.light))
                                .frame(width: 32, height: 32)
                        }
                        .foregroundColor(.white.opacity(0.7))

                        Spacer()

                        Color.clear
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.vertical, 12)
                .background(Color("DarkGreen").brightness(0.05))

                ScrollView {
                    VStack(spacing: 0) {
                    viewGroupHeader(text: "progress.settings.auto_counting".localized)
                    settingsToggle(
                        titleKey: "progress.settings.auto_audio_90",
                        subtitleKey: "progress.settings.auto_audio_90.description",
                        isOn: $settingsManager.autoProgressFrom90Percent
                    )
                    settingsToggle(
                        titleKey: "progress.settings.auto_audio_end",
                        subtitleKey: "progress.settings.auto_audio_end.description",
                        isOn: $settingsManager.autoProgressAudioEnd
                    )
                    settingsToggle(
                        titleKey: "progress.settings.auto_by_reading",
                        subtitleKey: "progress.settings.auto_by_reading.description",
                        isOn: $settingsManager.autoProgressByReading
                    )

                    viewGroupHeader(text: "progress.settings.actions".localized)
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            showResetConfirmation = true
                        }
                    } label: {
                        Text("progress.settings.reset_all_progress".localized)
                            .font(.body)
                            .fontWeight(.regular)
                            .foregroundColor(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
                            .padding(.horizontal, 12)
                        .background(Color("DarkGreen-light").opacity(0.7))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
    }
}
}

struct TestPageProgressView: View {
    var body: some View {
        PageProgressView()
            .environmentObject(SettingsManager())
    }
}

#Preview {
    TestPageProgressView()
}
