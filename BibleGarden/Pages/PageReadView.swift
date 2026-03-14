import SwiftUI
import AVFoundation
import Combine
import OpenAPIRuntime

struct PageReadView: View {

    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared

    @StateObject var audiopleer = PlayerModel()
    
    // Observer for tracking audio completion
    @State private var audioStateObserver: AnyCancellable?
    @State private var isUpdatingExcerpt: Bool = false
    @State private var hasStartedPlaybackInSession: Bool = false
    @State private var completionHandledForSession: Bool = true
    @State private var completionGuardStartTime: Date = .distantPast
    @State private var currentAudioVerseIndex: Int = -1
    @State private var listenedVerseIndexes: Set<Int> = []
    @State private var audioVerseCount: Int = 0
    @State private var ninetyPercentHandledForSession: Bool = true
    @State private var readingSessionID: UUID = UUID()
    @State private var chapterReadingAccumulatedSeconds: Double = 0
    @State private var chapterReadingActiveStartTime: Date? = nil
    @State private var chapterReachedTextBottom: Bool = false
    @State private var readingAutoProgressHandledForSession: Bool = true
    @State private var pendingReadingAutoMarkWorkItem: DispatchWorkItem?

    @State private var showSelection = false
    @State private var showSetup = false

    @State private var errorDescription: String = ""

    @State private var textVerses: [BibleTextualVerseFull] = []
    @State private var currentVerseNumber: Int?
    @State private var prevExcerpt: String = ""
    @State private var nextExcerpt: String = ""

    @State private var showAudioPanel = true

    @State private var scrollViewProxy: ScrollViewProxy? = nil

    @State private var isTextLoading: Bool = true
    @State private var hasAudio: Bool = true
    @State private var hasText: Bool = true

    @State var scrollToVerseId: Int?

    @State var oldExcerpt: String = "" // value before tapping on selection
    @State var oldTranslation: Int = 0
    @State var oldVoice: Int = 0
    @State var oldFontIncreasePercent: Double = 0

    @State var skipOnePause: Bool = false
    @State private var activeVerseIndex: Int = -1 // current position in textVerses (not reset by HTMLTextView)

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                VStack(spacing: 0) {

                    // MARK: Header
                    HStack(alignment: .center) {
                        MenuButtonView()
                            .environmentObject(settingsManager)

                        Spacer()

                        // Title that opens chapter selection
                        Button {
                            withAnimation(Animation.easeInOut(duration: 1)) {
                                oldExcerpt = settingsManager.currentExcerpt
                                showSelection = true
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Text(settingsManager.currentExcerptTitle)
                                    .fontWeight(.bold)
                                Text(settingsManager.currentExcerptSubtitle.uppercased())
                                    .foregroundColor(Color("Mustard"))
                                    .font(.footnote)
                                    .fontWeight(.bold)
                            }
                        }
                        .accessibilityIdentifier("read-chapter-title")

                        Spacer()

                        // Settings button
                        Button {
                            openSetupFromRead()
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 26))
                        }
                        .accessibilityIdentifier("read-settings-button")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, globalBasePadding)
                    .headerPadding()

                    // MARK: Text content
                    if isTextLoading {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                    else if textVerses.isEmpty && self.errorDescription != "" {
                        // Show only the error if text failed to load
                        ScrollView {
                            VStack {
                                Spacer()
                                Text(self.errorDescription)
                                    .foregroundColor(.pink)
                                    .padding(globalBasePadding)
                                    .accessibilityIdentifier("read-error-text")
                                Spacer()
                            }
                        }
                        .refreshable {
                            Task {
                               await updateExcerpt(proxy: proxy)
                            }
                        }
                    }
                    else {
                        // Show text (with audio warning when applicable)
                        VStack(spacing: 0) {
                            if self.errorDescription != "" && !hasText {
                                Text("error.audio_warning".localized(self.errorDescription))
                                    .foregroundColor(Color("Mustard"))
                                    .font(.footnote)
                                    .padding(.horizontal, globalBasePadding)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Color("DarkGreen-light"))
                                    .accessibilityIdentifier("read-audio-warning")
                            }
                            
                        HTMLTextView(
                            htmlContent: generateHTMLContent(verses: textVerses, fontIncreasePercent: settingsManager.fontIncreasePercent),
                            scrollToVerse: $currentVerseNumber,
                            onScrollMetricsChanged: { _, isAtBottom in
                                handleTextScroll(isAtBottom: isAtBottom)
                            }
                        )
                            .mask(LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color.black.opacity(0), location: 0.0),
                                    .init(color: Color.black, location: 0.03),
                                    .init(color: Color.black, location: 0.9),
                                    .init(color: Color.black.opacity(0), location: 1.0)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                        .accessibilityIdentifier("read-text-content")
                    }
                    }
                    // MARK: Audio panel
                    viewAudioPanel(proxy: proxy)

                }

                // Background layer
                .background(
                    Color("DarkGreen")
                        .accessibilityIdentifier("page-reading")
                )


                if !showAudioPanel {
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                if prevExcerpt != "" {
                                    Task {
                                        settingsManager.currentExcerpt = prevExcerpt
                                        await updateExcerpt(proxy: proxy)
                                    }
                                }
                            }
                            label: {
                                let prevColor =  prevExcerpt == "" ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
                                Image(systemName: "chevron.backward.2")
                                    .font(.system(size: 18))
                                    .foregroundColor(prevColor)
                                    .padding(10)
                            }
                            Spacer()
                            Button {
                                if nextExcerpt != "" {
                                    Task {
                                        settingsManager.currentExcerpt = nextExcerpt
                                        await updateExcerpt(proxy: proxy)
                                    }
                                }
                            }
                            label: {
                                let nextColor =  nextExcerpt == "" ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
                                Image(systemName: "chevron.forward.2")
                                    .font(.system(size: 18))
                                    .foregroundColor(nextColor)
                                    .padding(10)
                            }
                        }
                        .padding(10)
                    }
                }
            }
            .sheet(isPresented: $showSelection, onDismiss: {
                Task {
                    if oldExcerpt != settingsManager.currentExcerpt {
                        await updateExcerpt(proxy: proxy)
                    }
                }
            })
            {
                PageSelectView(showFromRead: $showSelection)
                    .environmentObject(settingsManager)
                    .sheetFullScreen()
            }

            .sheet(isPresented: $showSetup, onDismiss: {
                Task {
                    if oldTranslation != settingsManager.translation || oldVoice != settingsManager.voice || oldFontIncreasePercent != settingsManager.fontIncreasePercent {
                        await updateExcerpt(proxy: proxy)
                    }
                }
            })
            {
                PageReadSettingsView(showFromRead: $showSetup)
                    .environmentObject(settingsManager)
                    .sheetFullScreen()
            }

            .edgesIgnoringSafeArea(.bottom)

            .onAppear {
                UIRefreshControl.appearance().tintColor = UIColor(Color("localAccentColor"))

                Task {
                    audiopleer.onEndVerse = onEndVerse
                    audiopleer.onStartVerse = onStartVerse
                    audiopleer.smoothPauseLength = settingsManager.voiceMusic ? 0.3 : 0
                    await updateExcerpt(proxy: proxy)
                    audiopleer.setSpeed(speed: Float(self.settingsManager.currentSpeed))
                    self.scrollViewProxy = proxy
                    
                    // Setup observer for finishing audio to auto-switch chapters
                    setupAudioCompletionObserver(proxy: proxy)
                }

                scrollToVerseId = nil
            }
            .onDisappear {
                // Cleanup observer to avoid memory leaks
                audioStateObserver?.cancel()
                audioStateObserver = nil
                invalidateTextReadingTracking()
            }
            .onChange(of: settingsManager.autoProgressByReading) { _ in
                evaluateTextReadingAutoProgress()
            }
        }
    }

    // MARK: After selection
    func updateExcerpt(proxy: ScrollViewProxy) async {
        isUpdatingExcerpt = true
        invalidateAudioCompletionTracking()
        invalidateTextReadingTracking()
        defer { isUpdatingExcerpt = false }

        // Stop current audio immediately before loading new chapter
        audiopleer.stop()
        self.hasAudio = false

        do {
                self.isTextLoading = true
                self.errorDescription = ""
                self.hasText = false

            // UI Testing: simulate load error
            if TestingEnvironment.shouldForceLoadError {
                throw NSError(domain: "UITesting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Simulated load error for UI testing"])
            }

            let (thisTextVerses, audioVerses, firstUrl, isSingleChapter, part) = try await getExcerptTextualVersesOnline(excerpts: settingsManager.currentExcerpt, client: settingsManager.client, translation: settingsManager.translation, voice: settingsManager.voice)

            // UI Testing: simulate no audio
            let effectiveFirstUrl = TestingEnvironment.forceNoAudio ? "" : firstUrl

            textVerses = thisTextVerses
            self.hasText = true
            beginTextReadingTracking()
            
            // Update book and chapter information
            settingsManager.currentBookId = textVerses[0].bookDigitCode
            settingsManager.currentChapterId = textVerses[0].chapterDigitCode
            
            self.currentVerseNumber = -1
            self.activeVerseIndex = -1
            if (part != nil) {
                self.prevExcerpt = part!.prev_excerpt
                self.nextExcerpt = part!.next_excerpt
                withAnimation() {
                    settingsManager.currentExcerptTitle = part!.book.name
                    settingsManager.currentExcerptSubtitle = "page.read.chapter_subtitle".localized(String(part!.chapter_number))
                    settingsManager.currentBookId = part!.book.number
                    settingsManager.currentChapterId = part!.chapter_number
                }
            }
            
            // Scroll back to top
            withAnimation {
                proxy.scrollTo("top", anchor: .top)
            }
            
            // Check for audio availability
            if effectiveFirstUrl.isEmpty {
                self.hasAudio = false
                self.errorDescription = "Audio file for this chapter is missing"
            } else if let url = URL(string: effectiveFirstUrl) {
                let (from, to) = getExcerptPeriod(audioVerses: audioVerses)
                
                let playerItem = AVPlayerItem(url: url)
                audiopleer.setItem(playerItem: playerItem, periodFrom: isSingleChapter ? 0 : from, periodTo: isSingleChapter ? 0 : to, audioVerses: audioVerses, itemTitle: settingsManager.currentExcerptTitle, itemSubtitle: settingsManager.currentExcerptSubtitle)
                
                self.hasAudio = true
                self.errorDescription = ""
                beginAudioCompletionTracking(audioVerseCount: audioVerses.count)
            } else {
                self.hasAudio = false
                self.errorDescription = "Invalid audio file URL"
            }
        } catch {
            print("[PageReadView] Failed to load excerpt: \(error)")
            self.errorDescription = userFacingLoadingErrorMessage(for: error)
        }
        withAnimation(.easeOut(duration: 0.8)) {
            self.isTextLoading = false
        }
    }

    private func userFacingLoadingErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "getExcerptTextualVersesOnline", nsError.code == 422 {
            let detail = compactErrorText(nsError.localizedDescription)
            if !detail.isEmpty {
                return detail
            }
        }

        let rawErrorText = "\(error)"
        if let statusCode = extractHTTPStatusCode(from: rawErrorText) {
            return "error.loading.chapter.with_code".localized(statusCode)
        }

        #if DEBUG
        return "\("error.loading.chapter".localized)\n\n\(compactErrorText(rawErrorText, maxLength: 300))"
        #else
        return "error.loading.chapter".localized
        #endif
    }

    private func extractHTTPStatusCode(from text: String) -> Int? {
        let patterns = [
            #"statusCode:\s*(\d{3})"#,
            #"status\s*code\s*[:=]\s*(\d{3})"#,
            #"status:\s*(\d{3})"#
        ]

        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                  let match = regex.firstMatch(in: text, options: [], range: searchRange),
                  match.numberOfRanges > 1,
                  let codeRange = Range(match.range(at: 1), in: text),
                  let statusCode = Int(text[codeRange]) else {
                continue
            }
            return statusCode
        }
        return nil
    }

    private func compactErrorText(_ text: String, maxLength: Int = 120) -> String {
        let normalized = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength - 3)) + "..."
    }

    // MARK: Verse change handlers
    func onStartVerse(_ cur: Int) {
        currentAudioVerseIndex = cur
        activeVerseIndex = cur
        if skipOnePause {
            skipOnePause = false
        }
        else if cur < 0 {
            currentAudioVerseIndex = -1
            activeVerseIndex = -1
            self.currentVerseNumber = 0
            return
        }
        else if cur > 0 && (settingsManager.pauseBlock == .paragraph || settingsManager.pauseBlock == .fragment) {
            if settingsManager.pauseType == .time {
                if (settingsManager.pauseBlock == .paragraph && textVerses[cur].startParagraph) ||
                   (settingsManager.pauseBlock == .fragment  && !textVerses[cur].beforeTitles.isEmpty)
                {
                    audiopleer.breakForSeconds(settingsManager.pauseLength)
                    DispatchQueue.main.asyncAfter(deadline: .now() + settingsManager.pauseLength) {
                        self.currentVerseNumber = textVerses[cur].number
                    }
                    return
                }
            }
            else if settingsManager.pauseType == .full {
                audiopleer.doPlayOrPause()
                return
            }
        }
        self.currentVerseNumber = textVerses[cur].number
    }

    func onEndVerse() {

        if skipOnePause {
            skipOnePause = false
            return
        }

        if currentAudioVerseIndex >= 0 {
            listenedVerseIndexes.insert(currentAudioVerseIndex)
            evaluateNinetyPercentAutoProgress(includeCurrentVerse: false)
        }

        // Apply pause if needed
        // (event not fired after last verse and full stop)
        if settingsManager.pauseBlock == .verse {
            if settingsManager.pauseType == .time {
                audiopleer.breakForSeconds(settingsManager.pauseLength)
            }
            else if settingsManager.pauseType == .full {
                audiopleer.doPlayOrPause()
            }
        }
    }

    // MARK: Audio completion observer setup
    private func setupAudioCompletionObserver(proxy: ScrollViewProxy) {
        audioStateObserver = audiopleer.$state
            .receive(on: DispatchQueue.main)
            .sink { newState in
                if newState == .playing {
                    self.hasStartedPlaybackInSession = true
                }

                if self.isUpdatingExcerpt {
                    return
                }

                self.updateTextReadingTimerForAudioState(newState)

                // React only to natural playback completion (segment or full file)
                if newState == .finished || newState == .segmentFinished {
                    guard self.hasStartedPlaybackInSession else { return }
                    guard !self.completionHandledForSession else { return }
                    guard Date().timeIntervalSince(self.completionGuardStartTime) >= 0.8 else { return }

                    self.completionHandledForSession = true
                    self.evaluateNinetyPercentAutoProgress(includeCurrentVerse: true)

                    if self.settingsManager.autoProgressAudioEnd {
                        self.markCurrentChapterAsRead()
                    }
                    
                    if self.settingsManager.autoNextChapter && !self.nextExcerpt.isEmpty {
                        // Small delay for better UX
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            Task {
                                self.settingsManager.currentExcerpt = self.nextExcerpt
                                await self.updateExcerpt(proxy: proxy)
                                
                                // Determine needed pause between chapters and auto-play flag
                                let (pauseDelay, shouldAutoPlay) = self.calculateChapterTransitionPause()
                                
                                // Show autopausing state when pause is long enough
                                if pauseDelay > 0.3 && shouldAutoPlay {
                                    self.audiopleer.state = .autopausing
                                }
                                
                                // Auto-start playback once pause ends (if required)
                                if shouldAutoPlay {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + pauseDelay) {
                                        self.audiopleer.doPlayOrPause()
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }

    private func beginAudioCompletionTracking(audioVerseCount: Int) {
        hasStartedPlaybackInSession = false
        completionHandledForSession = false
        completionGuardStartTime = Date()
        currentAudioVerseIndex = -1
        listenedVerseIndexes.removeAll(keepingCapacity: true)
        self.audioVerseCount = audioVerseCount
        ninetyPercentHandledForSession = false
    }

    private func invalidateAudioCompletionTracking() {
        hasStartedPlaybackInSession = false
        completionHandledForSession = true
        completionGuardStartTime = Date()
        currentAudioVerseIndex = -1
        listenedVerseIndexes.removeAll(keepingCapacity: true)
        audioVerseCount = 0
        ninetyPercentHandledForSession = true
    }

    private func evaluateNinetyPercentAutoProgress(includeCurrentVerse: Bool) {
        guard settingsManager.autoProgressFrom90Percent else { return }
        guard !ninetyPercentHandledForSession else { return }
        guard audioVerseCount > 0 else { return }

        var listened = listenedVerseIndexes
        if includeCurrentVerse, currentAudioVerseIndex >= 0, currentAudioVerseIndex < audioVerseCount {
            listened.insert(currentAudioVerseIndex)
        }

        let requiredVerseCount = Int(ceil(Double(audioVerseCount) * 0.9))
        guard requiredVerseCount > 0 else { return }

        if listened.count >= requiredVerseCount {
            ninetyPercentHandledForSession = true
            markCurrentChapterAsRead()
        }
    }

    private func beginTextReadingTracking() {
        readingSessionID = UUID()
        chapterReadingAccumulatedSeconds = 0
        chapterReadingActiveStartTime = isAudioActiveForTextReadingTimer(audiopleer.state) ? nil : Date()
        chapterReachedTextBottom = false
        readingAutoProgressHandledForSession = false
        pendingReadingAutoMarkWorkItem?.cancel()
        pendingReadingAutoMarkWorkItem = nil
    }

    private func invalidateTextReadingTracking() {
        readingSessionID = UUID()
        pendingReadingAutoMarkWorkItem?.cancel()
        pendingReadingAutoMarkWorkItem = nil
        chapterReadingAccumulatedSeconds = 0
        chapterReadingActiveStartTime = nil
        chapterReachedTextBottom = false
        readingAutoProgressHandledForSession = true
    }

    private func isAudioActiveForTextReadingTimer(_ state: PlayerModel.PlaybackState) -> Bool {
        switch state {
        case .playing, .buffering, .autopausing, .waitingForPause, .pausing:
            return true
        case .waitingForSelection, .waitingForPlay, .finished, .segmentFinished, .error:
            return false
        }
    }

    private func updateTextReadingTimerForAudioState(_ state: PlayerModel.PlaybackState) {
        guard settingsManager.autoProgressByReading else { return }
        guard !readingAutoProgressHandledForSession else { return }
        guard hasText else { return }
        guard !isUpdatingExcerpt else { return }

        if isAudioActiveForTextReadingTimer(state) {
            pauseTextReadingTimer()
        } else {
            resumeTextReadingTimerIfNeeded()
        }
    }

    private func pauseTextReadingTimer() {
        guard let start = chapterReadingActiveStartTime else { return }
        chapterReadingAccumulatedSeconds += Date().timeIntervalSince(start)
        chapterReadingActiveStartTime = nil
        pendingReadingAutoMarkWorkItem?.cancel()
        pendingReadingAutoMarkWorkItem = nil
    }

    private func resumeTextReadingTimerIfNeeded() {
        guard chapterReadingActiveStartTime == nil else { return }
        chapterReadingActiveStartTime = Date()
        evaluateTextReadingAutoProgress()
    }

    private func handleTextScroll(isAtBottom: Bool) {
        guard hasText else { return }
        guard !isUpdatingExcerpt else { return }
        guard isAtBottom else { return }

        if !chapterReachedTextBottom {
            chapterReachedTextBottom = true
        }
        evaluateTextReadingAutoProgress()
    }

    private var textReadingAutoProgressRequiredSeconds: Double {
        if let override = TestingEnvironment.readingProgressSecondsOverride {
            return override
        }
        let verseCount = textVerses.count
        guard verseCount > 0 else { return 60 }
        return min(60, max(10, Double(verseCount) * 2))
    }

    private var textReadingElapsedSeconds: Double {
        chapterReadingAccumulatedSeconds + (chapterReadingActiveStartTime.map { Date().timeIntervalSince($0) } ?? 0)
    }

    private func evaluateTextReadingAutoProgress() {
        guard settingsManager.autoProgressByReading else {
            pendingReadingAutoMarkWorkItem?.cancel()
            pendingReadingAutoMarkWorkItem = nil
            return
        }
        guard !readingAutoProgressHandledForSession else { return }
        guard chapterReachedTextBottom else { return }
        guard chapterReadingActiveStartTime != nil else { return } // Do not count while audio is active.

        let requiredSeconds = textReadingAutoProgressRequiredSeconds
        let elapsed = textReadingElapsedSeconds
        if elapsed >= requiredSeconds {
            readingAutoProgressHandledForSession = true
            pendingReadingAutoMarkWorkItem?.cancel()
            pendingReadingAutoMarkWorkItem = nil
            markCurrentChapterAsRead()
            return
        }

        let remaining = max(0.1, requiredSeconds - elapsed)
        let sessionID = readingSessionID
        pendingReadingAutoMarkWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard self.readingSessionID == sessionID else { return }
            self.evaluateTextReadingAutoProgress()
        }
        pendingReadingAutoMarkWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
    }
    
    // MARK: Pause calculation between chapters
    private func calculateChapterTransitionPause() -> (delay: Double, shouldAutoPlay: Bool) {
        // Early exit when pauses are disabled
        guard settingsManager.pauseType != .none else {
            return (0.3, true) // minimal technical delay, auto-play
        }
        
        // New chapter counts as new verse and new paragraph
        // Check if it also starts a new fragment (title before verse)
        let isNewFragment = !textVerses.first!.beforeTitles.isEmpty
        
        // Decide if pause is required based on settings
        let shouldPause: Bool
        switch settingsManager.pauseBlock {
        case .verse:
            shouldPause = true // new chapter == new verse
        case .paragraph:
            shouldPause = true // new chapter == new paragraph
        case .fragment:
            shouldPause = isNewFragment // new chapter == new fragment only with title
        }
        
        guard shouldPause else {
            return (0.3, true) // minimal technical delay with auto-play
        }
        
        // Return pause duration and auto-play flag based on type
        if settingsManager.pauseType == .time {
            return (settingsManager.pauseLength, true)
        } else {
            // For .full pause playback must not auto-start
            return (0.3, false)
        }
    }

    // MARK: Player panel
    @ViewBuilder private func viewAudioPanel(proxy: ScrollViewProxy) -> some View {

        VStack(spacing: 0) {
            viewAudioHide()

            VStack {
                viewAudioInfo()

                viewChapterMarkToggle()
                
                // Warning when audio is missing (no audio file at all)
                if !hasAudio && hasText && !self.errorDescription.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color("Mustard"))
                            .font(.footnote)
                        Text(self.errorDescription)
                            .foregroundColor(Color("Mustard"))
                            .font(.footnote)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color("DarkGreen").opacity(0.5))
                    .cornerRadius(8)
                    .padding(.top, 8)
                    .accessibilityIdentifier("read-audio-warning-panel")
                }

                viewAudioTimeline()
                viewAudioButtons(proxy: proxy)
            }
            .frame(height: showAudioPanel ? nil : 0)
            .opacity(showAudioPanel ? 1 : 0)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(height: showAudioPanel ? audioPanelHeight : 45)
        .padding(.horizontal, globalBasePadding)
        .background(Color("DarkGreen-light"))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("audio-panel")
        .clipShape(TopRoundedRectangle(radius: 25))
        .gesture(DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 50 {
                    withAnimation {
                        showAudioPanel = false
                    }
                } else if value.translation.height < -50 {
                    withAnimation {
                        showAudioPanel = true
                    }
                }
            }
        )
    }

    // MARK: Panel – expand/collapse
    @ViewBuilder private func viewAudioHide() -> some View {
        Button {
            withAnimation {
                showAudioPanel.toggle()
            }
        } label: {
            VStack {
                Image(systemName: showAudioPanel ? "chevron.compact.down" : "chevron.compact.up")
                    .font(.system(size: 36))
                    .padding(.top, 7)
                    .padding(.bottom, 7)
                    .foregroundColor(Color("DarkGreen"))
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("read-chevron")
    }

    // MARK: Panel – info
    @ViewBuilder private func viewAudioInfo() -> some View {
        HStack(spacing: 10) {
            Button {
                openSetupFromRead()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.caption)
                        .foregroundColor(Color("localAccentColor"))
                    Text(settingsManager.translationName)
                        .foregroundColor(Color("localAccentColor"))
                        .font(.footnote)
                }
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color("localAccentColor").opacity(0.16))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color("localAccentColor").opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("read-translation-chip")

            Button {
                openSetupFromRead()
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text("audio.reader".localized)
                        .foregroundStyle(Color("localAccentColor").opacity(0.5))
                        .font(.caption2)
                    Text(settingsManager.voiceName)
                        .foregroundStyle(Color("localAccentColor"))
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("read-voice-chip")

            Spacer()
            
            Button {
                openSetupFromRead()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "pause.circle")
                        .font(.caption)
                        .foregroundColor(Color("localAccentColor"))
                    Text(pauseChipText())
                        .foregroundColor(Color("localAccentColor"))
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(4)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color("localAccentColor").opacity(0.16))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color("localAccentColor").opacity(0.25), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            //Spacer()
            //Image(systemName: "gearshape.fill")
            //    .imageScale(.large)
            //    .foregroundStyle(Color("localAccentColor"))
        }
    }

    private func openSetupFromRead() {
        withAnimation(Animation.easeInOut(duration: 1)) {
            oldTranslation = settingsManager.translation
            oldVoice = settingsManager.voice
            oldFontIncreasePercent = settingsManager.fontIncreasePercent
            showSetup = true
        }
    }

    private func pauseChipText() -> String {
        switch settingsManager.pauseType {
        case .none:
            return "settings.pause.type.none".localized
        case .time:
            return "\(settingsManager.pauseBlock.shortName) • \("audio.pause.seconds".localized(settingsManager.pauseLength))"
        case .full:
            return "\(settingsManager.pauseBlock.shortName) • \("audio.pause.stop".localized)"
        }
    }

    private var isAtFirstVerse: Bool {
        activeVerseIndex <= 0
    }

    private var isAtLastVerse: Bool {
        !textVerses.isEmpty && activeVerseIndex >= textVerses.count - 1
    }

    private var audioPanelHeight: CGFloat {
        let baseHeight: CGFloat = (!hasAudio && hasText ? 260 : 220)
        return baseHeight + chapterMarkRowHeight
    }

    private var chapterMarkRowHeight: CGFloat { 24 }
    private var chapterMarkIndicatorSize: CGFloat { 14 }
    private var chapterMarkProgressLineWidth: CGFloat { 2 }

    private struct ChapterProgressArc: Shape {
        var progress: Double
        var lineWidth: CGFloat
        var radiusInset: CGFloat = 0.5

        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }

        func path(in rect: CGRect) -> Path {
            let clamped = min(max(progress, 0), 1)
            let half = min(rect.width, rect.height) / 2
            let radius = max(half - lineWidth / 2 - radiusInset, 0)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let start = Angle.degrees(-90)
            let end = Angle.degrees(-90 + 360 * clamped)

            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
            return path
        }
    }

    private var ninetyPercentThresholdVerseCount: Int {
        guard audioVerseCount > 0 else { return 0 }
        return Int(ceil(Double(audioVerseCount) * 0.9))
    }

    private var ninetyPercentVisualProgress: Double {
        guard settingsManager.autoProgressFrom90Percent else { return 0 }
        let required = ninetyPercentThresholdVerseCount
        guard required > 0 else { return 0 }
        return min(Double(listenedVerseIndexes.count) / Double(required), 1)
    }

    @ViewBuilder private func viewChapterMarkToggle() -> some View {
        let isRead = isCurrentChapterRead
        let canMark = currentChapterProgressTarget != nil
        Button {
            toggleCurrentChapterReadState()
        } label: {
            HStack(spacing: 6) {
                ZStack {
                    if isRead {
                        Image(systemName: "circle.fill")
                            .font(.system(size: chapterMarkIndicatorSize))
                            .foregroundColor(Color("Mustard"))
                        Image(systemName: "checkmark")
                            .font(.system(size: chapterMarkIndicatorSize * 0.62, weight: .bold))
                            .foregroundColor(Color("DarkGreen"))
                    } else {
	                        Image(systemName: "circle")
	                            .font(.system(size: chapterMarkIndicatorSize))
	                            .foregroundColor(Color("localAccentColor").opacity(0.6))
	                        if settingsManager.autoProgressFrom90Percent && audioVerseCount > 0 {
	                            ChapterProgressArc(
	                                progress: ninetyPercentVisualProgress,
	                                lineWidth: chapterMarkProgressLineWidth
	                            )
	                                .stroke(
	                                    Color("Mustard"),
	                                    style: StrokeStyle(lineWidth: chapterMarkProgressLineWidth, lineCap: .round, lineJoin: .round)
	                                )
                                .animation(.easeOut(duration: 0.2), value: ninetyPercentVisualProgress)
                        }
                    }
                }
                .frame(width: chapterMarkIndicatorSize, height: chapterMarkIndicatorSize)
                Text("chapter.read_status".localized)
                    .font(.caption2)
                    .foregroundColor(Color("localAccentColor").opacity(0.85))
                Spacer()
                // Inline buffering/error indicator
                if audiopleer.isStalled || (hasAudio && audiopleer.isBufferingLong) {
                    HStack(spacing: 4) {
                        ProgressView()
                            .tint(Color("Mustard"))
                            .scaleEffect(0.6)
                        Text("error.audio.stalled".localized)
                            .foregroundColor(Color("Mustard"))
                            .font(.caption2)
                    }
                } else if audiopleer.errorMessage != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color("Mustard"))
                            .font(.caption2)
                        Text(audiopleer.errorMessage!)
                            .foregroundColor(Color("Mustard"))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
            .frame(minHeight: chapterMarkRowHeight)
        }
        .buttonStyle(.plain)
        .disabled(!canMark)
        .opacity(canMark ? 1 : 0) // Reserve space to avoid panel jumping while chapter loads.
        .padding(.top, 2)
        .accessibilityIdentifier("read-chapter-progress")
        .accessibilityValue(isRead ? "read" : "unread")
    }

    private var currentChapterProgressTarget: (bookAlias: String, chapter: Int)? {
        let chapter = textVerses.first?.chapterDigitCode ?? settingsManager.currentChapterId
        guard chapter > 0 else { return nil }

        let aliasFromVerse = textVerses.first.map { settingsManager.getBookAlias(bookNumber: $0.bookDigitCode) } ?? ""
        let aliasFromCurrentBookId = settingsManager.currentBookId > 0 ? settingsManager.getBookAlias(bookNumber: settingsManager.currentBookId) : ""
        let aliasFromExcerpt = settingsManager.currentExcerpt
            .split(separator: " ")
            .first
            .map(String.init)?
            .lowercased() ?? ""

        let bookAlias = [aliasFromVerse, aliasFromCurrentBookId, aliasFromExcerpt]
            .first(where: { !$0.isEmpty }) ?? ""
        guard !bookAlias.isEmpty else { return nil }

        return (bookAlias, chapter)
    }

    private var isCurrentChapterRead: Bool {
        guard let target = currentChapterProgressTarget else { return false }
        return settingsManager.isChapterRead(book: target.bookAlias, chapter: target.chapter)
    }

    private func markCurrentChapterAsRead() {
        guard let target = currentChapterProgressTarget else { return }
        settingsManager.markChapterAsRead(book: target.bookAlias, chapter: target.chapter)
    }

    private func toggleCurrentChapterReadState() {
        guard let target = currentChapterProgressTarget else { return }
        if settingsManager.isChapterRead(book: target.bookAlias, chapter: target.chapter) {
            settingsManager.markChapterAsUnread(book: target.bookAlias, chapter: target.chapter)
        } else {
            settingsManager.markChapterAsRead(book: target.bookAlias, chapter: target.chapter)
        }
    }

    // MARK: Panel – timeline
    @ViewBuilder private func viewAudioTimeline() -> some View {
        VStack(spacing: 0) {
            ZStack {
                Slider(value: $audiopleer.currentTime, in: 0...audiopleer.currentDuration, onEditingChanged: audiopleer.sliderEditingChanged)
                    .accentColor(Color("localAccentColor"))
                    .onAppear {
                        let progressCircleConfig = UIImage.SymbolConfiguration(scale: .small)
                        UISlider.appearance()
                            .setThumbImage(UIImage(systemName: "circle.fill",
                                                   withConfiguration: progressCircleConfig), for: .normal)
                    }
                    .disabled(audiopleer.state == .waitingForSelection || audiopleer.state == .buffering)
                    .accessibilityIdentifier("read-timeline-slider")

                // Highlight current excerpt
                if audiopleer.periodTo > 0 {

                    // https://stackoverflow.com/a/62641399
                    let frameWidth: Double = UIScreen.main.bounds.size.width - globalBasePadding*2
                    let point: Double = frameWidth / audiopleer.currentDuration

                    let pointStart: Double = Double(audiopleer.periodFrom) * point
                    let pointCenter: Double = audiopleer.currentTime * point
                    let pointEnd: Double = Double(audiopleer.periodTo == 0 ? audiopleer.currentDuration : audiopleer.periodTo) * point

                    let circleLeftSpace: Double = 13 * audiopleer.currentTime / audiopleer.currentDuration
                    let circleRightSpace: Double = 13 - circleLeftSpace

                    let firstLeading: Double = pointStart
                    let firstTrailing: Double = frameWidth - (pointEnd > pointCenter - circleLeftSpace ? pointCenter - circleLeftSpace : pointEnd)

                    let secondLeading: Double = (pointCenter + circleRightSpace > pointStart ? pointCenter + circleRightSpace : pointStart)
                    let secondTrailing: Double = frameWidth - pointEnd

                    if pointCenter > pointStart {
                        Rectangle()
                            .fill(Color("localAccentColor"))
                            .padding(.leading, firstLeading)
                            .padding(.trailing, firstTrailing)
                            .frame(width: frameWidth, height: 4)
                            .padding(.top, -0.9)
                        //.blendMode(.multiply)
                    }

                    if pointEnd > pointCenter {
                        Rectangle()
                            .fill(Color("localAccentColor").opacity(0.2))
                            .padding(.leading, secondLeading)
                            .padding(.trailing, secondTrailing)
                            .frame(width: frameWidth, height: 4)
                            .padding(.top, -0.9)
                        //.blendMode(.multiply)
                    }
                }
            }
            HStack {
                // time
                Text("\(formatTime(audiopleer.currentTime))")
                    .foregroundStyle(Color("Mustard"))
                    .accessibilityIdentifier("read-time-current")
                Spacer()
                #if DEBUG
                VStack(spacing: 0) {
                    Text(playbackStateName)
                        .accessibilityIdentifier("read-playback-state")
                    Text("\(currentAudioVerseIndex)")
                        .accessibilityIdentifier("read-verse-counter")
                }
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                #endif
                Spacer()
                Text("\(formatTime(audiopleer.currentDuration))")
                    .foregroundStyle(Color("localAccentColor").opacity(0.4))
                    .accessibilityIdentifier("read-time-total")
            }
            .font(.subheadline)
        }
        .padding(.top, 2)

    }

    #if DEBUG
    private var playbackStateName: String {
        switch audiopleer.state {
        case .waitingForSelection: return "waitingForSelection"
        case .waitingForPlay: return "waitingForPlay"
        case .waitingForPause: return "waitingForPause"
        case .buffering: return "buffering"
        case .playing: return "playing"
        case .pausing: return "pausing"
        case .autopausing: return "autopausing"
        case .finished: return "finished"
        case .segmentFinished: return "segmentFinished"
        case .error: return "error"
        }
    }
    #endif

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: Panel – AudioButtons
    @ViewBuilder fileprivate func viewAudioButtons(proxy: ScrollViewProxy) -> some View {

        let isDisabledState = !hasAudio || audiopleer.state == .buffering
        let buttonsColor = isDisabledState ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
        let retryColor = audiopleer.state == .error ? Color("localAccentColor") : buttonsColor
        let prevColor =  prevExcerpt == "" ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
        let nextColor =  nextExcerpt == "" ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
        let verseGoColor = (hasAudio && audiopleer.state == .playing) ? Color("localAccentColor") : Color("localAccentColor").opacity(0.4)

        HStack {

            // Previous chapter
            Button {
                if prevExcerpt != "" {
                    Task {
                        settingsManager.currentExcerpt = prevExcerpt
                        await updateExcerpt(proxy: proxy)
                    }
                }
            } label: {
                Image(systemName: "chevron.backward.2")
                    .foregroundColor(prevColor)
            }
            .accessibilityIdentifier("read-prev-chapter")
            .disabled(prevExcerpt.isEmpty)
            Spacer()

            // Restart excerpt
            Button {
                audiopleer.restart()
            } label: {
                Image(systemName: "gobackward")
                    .foregroundColor(buttonsColor)
            }
            .accessibilityIdentifier("read-restart")
            .disabled(!hasAudio)
            Spacer()

            // Previous verse
            Button {
                if audiopleer.state == .playing || audiopleer.state == .pausing || audiopleer.state == .autopausing || audiopleer.state == .buffering {
                    self.skipOnePause = true
                    audiopleer.previousVerse()
                } else if activeVerseIndex > 0 {
                    activeVerseIndex -= 1
                    currentVerseNumber = textVerses[activeVerseIndex].number
                } else if activeVerseIndex < 0 && !textVerses.isEmpty {
                    activeVerseIndex = 0
                    currentVerseNumber = textVerses[0].number
                }
            } label: {
                Image(systemName: "arrow.turn.left.up")
                    .foregroundColor(isAtFirstVerse ? Color("localAccentColor").opacity(0.4) : buttonsColor)
            }
            .accessibilityIdentifier("read-prev-verse")
            .disabled(!hasAudio || isAtFirstVerse)
            Spacer()

            // Play/Pause
            Button {
                if activeVerseIndex > 0 && audiopleer.state != .playing {
                    audiopleer.seekToVerseIndex(activeVerseIndex)
                }
                audiopleer.doPlayOrPause()
            } label: {

                HStack {
                    switch audiopleer.state {
                    case .playing:
                        Image(systemName: "pause.circle.fill")
                    case .autopausing:
                        Image(systemName: "hourglass.circle.fill")
                    case .error:
                        Image(systemName: "arrow.clockwise.circle.fill")
                    default:
                        Image(systemName: "play.circle.fill")
                    }
                }
                    .font(.system(size: 55))
                    .foregroundColor(retryColor)
            }
            .accessibilityIdentifier("read-play-pause")
            .disabled(!hasAudio)
            Spacer()

            // Next verse
            Button {
                if audiopleer.state == .playing || audiopleer.state == .pausing || audiopleer.state == .autopausing || audiopleer.state == .buffering {
                    self.skipOnePause = true
                    audiopleer.nextVerse()
                } else if activeVerseIndex + 1 < textVerses.count {
                    activeVerseIndex += 1
                    currentVerseNumber = textVerses[activeVerseIndex].number
                } else if activeVerseIndex < 0 && !textVerses.isEmpty {
                    activeVerseIndex = 0
                    currentVerseNumber = textVerses[0].number
                }
            } label: {
                Image(systemName: "arrow.turn.right.down")
                    .foregroundColor(isAtLastVerse ? Color("localAccentColor").opacity(0.4) : buttonsColor)
            }
            .accessibilityIdentifier("read-next-verse")
            .disabled(!hasAudio || isAtLastVerse)
            Spacer()

            // Speed
            Button {
                audiopleer.changeSpeed()
                settingsManager.currentSpeed = Double(audiopleer.currentSpeed)
            } label: {
                Text(audiopleer.currentSpeed == 1 ? "x1" : String(format: "%.1f", audiopleer.currentSpeed))
                    .font(.system(size: 18))
                    .foregroundColor(buttonsColor)
                    .accessibilityIdentifier("read-speed-label")
            }
            .accessibilityIdentifier("read-speed")
            .disabled(!hasAudio)
            Spacer()

            // Next chapter
            Button {
                if nextExcerpt != "" {
                    Task {
                        settingsManager.currentExcerpt = nextExcerpt
                        await updateExcerpt(proxy: proxy)
                    }
                }
            } label: {
                Image(systemName: "chevron.forward.2")
                    .foregroundColor(nextColor)
            }
            .accessibilityIdentifier("read-next-chapter")
            .disabled(nextExcerpt.isEmpty)

        }
        .foregroundColor(Color("localAccentColor"))
    }
}

// MARK: Preview

struct TestPageReadView: View {

    var body: some View {
        PageReadView()
            .environmentObject(SettingsManager())
    }
}

#Preview {
    TestPageReadView()
}
