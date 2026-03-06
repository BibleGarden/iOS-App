import SwiftUI
import AVFoundation
import Combine

struct PageMultilingualReadView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    
    // Data for each read step (keyed by step index)
    @State private var stepTextVerses: [Int: [BibleTextualVerseFull]] = [:]
    @State private var stepAudioVerses: [Int: [BibleAcousticalVerseFull]] = [:]
    @State private var stepAudioUrls: [Int: String] = [:]
    @State private var stepPlayerItems: [Int: AVPlayerItem] = [:]  // one per translation, reused across units
    
    // Navigation
    @State private var prevExcerpt: String = ""
    @State private var nextExcerpt: String = ""
    @State private var excerptTitle: String = ""
    @State private var excerptSubtitle: String = ""
    
    // State
    @State private var isLoading: Bool = true
    @State private var errorDescription: String = ""
    
    @State private var showSelection = false
    @State private var oldExcerpt: String = ""
    @State private var showAudioPanel = true
    
    // Playback state
    @State private var currentUnitIndex: Int = 0 // Which verse/paragraph/fragment are we on
    @State private var currentStepIndex: Int = 0 // Which step within the unit flow
    @State private var isPlaying: Bool = false
    @State private var isPausing: Bool = false
    @State private var isAutopausing: Bool = false
    @State private var lastSwitchTime: Date = Date()
    
    // Audio player for current step
    @StateObject private var audiopleer = PlayerModel()
    @State private var audioStateObserver: AnyCancellable?
    @State private var playbackSessionID: UUID = UUID()
    @State private var isUpdatingExcerpt: Bool = false
    @State private var chapterVerseNumbers: Set<Int> = []
    @State private var listenedVerseNumbers: Set<Int> = []
    @State private var audioVerseCount: Int = 0
    @State private var ninetyPercentHandledForSession: Bool = true
    @State private var verseTrackingSessionID: UUID = UUID()
    @State private var currentAudioVerseNumber: Int = -1
    @State private var readingSessionID: UUID = UUID()
    @State private var chapterReadingAccumulatedSeconds: Double = 0
    @State private var chapterReadingActiveStartTime: Date? = nil
    @State private var chapterReachedTextBottom: Bool = false
    @State private var readingAutoProgressHandledForSession: Bool = true
    @State private var pendingReadingAutoMarkWorkItem: DispatchWorkItem?
    
    // Units (indices into verses based on unit mode)
    @State private var unitRanges: [(start: Int, end: Int)] = [] // verse index ranges for each unit
    
    // Current verse for highlighting
    @State private var highlightVerseNumber: Int? = nil

    @State private var retryCount: Int = 0

    // Reading steps (only read steps from the template)
    private var readSteps: [MultilingualStep] {
        settingsManager.multilingualSteps.filter { $0.type == .read }
    }
    
    private var allSteps: [MultilingualStep] {
        settingsManager.multilingualSteps
    }

    /// True when there's nowhere to go backwards (first step of first unit)
    private var isAtSectionStart: Bool {
        let hasPrevReadStep = allSteps.indices.contains(where: { $0 < currentStepIndex && allSteps[$0].type == .read })
        return !hasPrevReadStep && currentUnitIndex <= 0
    }

    /// True when there's nowhere to go forwards (last step of last unit)
    private var isAtSectionEnd: Bool {
        let hasNextReadStep = allSteps.indices.contains(where: { $0 > currentStepIndex && allSteps[$0].type == .read })
        return !hasNextReadStep && currentUnitIndex >= unitRanges.count - 1
    }
    
    var body: some View {
        ZStack {
            Color("DarkGreen")
                .edgesIgnoringSafeArea(.all)
                .accessibilityIdentifier("page-multi-reading")

            VStack(spacing: 0) {
                // MARK: Header
                HStack(alignment: .center) {
                    MenuButtonView()
                        .environmentObject(settingsManager)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(Animation.easeInOut(duration: 1)) {
                            oldExcerpt = settingsManager.currentExcerpt
                            showSelection = true
                        }
                    } label: {
                        VStack(spacing: 0) {
                            Text(excerptTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text(excerptSubtitle.uppercased())
                                .foregroundColor(Color("Mustard"))
                                .font(.footnote)
                                .fontWeight(.bold)
                        }
                    }
                    .accessibilityIdentifier("multi-chapter-title")
                    
                    Spacer()
                    
                    // Back to config
                    Button {
                        settingsManager.isMultilingualReadingActive = false
                        withAnimation(.easeInOut(duration: 0.25)) {
                            settingsManager.selectedMenuItem = .multilingual
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                    }
                    .accessibilityIdentifier("multi-config-button")
                }
                .padding(.horizontal, globalBasePadding)
                .headerPadding()
                
                // MARK: Content
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Spacer()
                } else if !errorDescription.isEmpty {
                    Spacer()
                    Text(errorDescription)
                        .foregroundColor(.pink)
                        .padding(globalBasePadding)
                        .accessibilityIdentifier("multi-error-text")
                    Spacer()
                } else {
                    // Text display using WebView for proper HTML formatting
                    // highlightVerseNumber encodes stepIdx * 10000 + verseNumber for unique IDs
                    HTMLTextView(
                        htmlContent: generateMultilingualHTML(),
                        scrollToVerse: $highlightVerseNumber,
                        onScrollMetricsChanged: { _, isAtBottom in
                            handleTextScroll(isAtBottom: isAtBottom)
                        }
                    )
                    .accessibilityIdentifier("multi-text-content")
                    .mask(
                        LinearGradient(
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
                    .layoutPriority(1) // Ensure text view takes available space
                }
                
                // Audio Panel Layer - now part of the main stack
                audioControlPanel()
            }
            .edgesIgnoringSafeArea(.bottom)

            
            // Floating navigation buttons when panel is hidden
            if !showAudioPanel {
                VStack {
                    Spacer()
                    HStack {
                        // Previous Chapter
                        Button {
                            if !prevExcerpt.isEmpty {
                                Task {
                                    settingsManager.currentExcerpt = prevExcerpt
                                    await loadAllData(force: true)
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.backward.2")
                                .font(.system(size: 18))
                                .foregroundColor((prevExcerpt.isEmpty || isLoading) ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor"))
                                .padding(10)
                        }
                        .disabled(prevExcerpt.isEmpty || isLoading)

                        Spacer()

                        // Next Chapter
                        Button {
                            if !nextExcerpt.isEmpty {
                                Task {
                                    settingsManager.currentExcerpt = nextExcerpt
                                    await loadAllData(force: true)
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.forward.2")
                                .font(.system(size: 18))
                                .foregroundColor((nextExcerpt.isEmpty || isLoading) ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor"))
                                .padding(10)
                        }
                        .disabled(nextExcerpt.isEmpty || isLoading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            
        }
        .fullScreenCover(isPresented: $showSelection, onDismiss: {
            Task {
                if oldExcerpt != settingsManager.currentExcerpt {
                    // Force reload
                    stepTextVerses = [:]
                    await loadAllData()
                }
            }
        }) {
            PageSelectView(showFromRead: $showSelection)
                .environmentObject(settingsManager)
        }
        .onAppear {
            settingsManager.isMultilingualReadingActive = true
            Task {
                await loadAllData()
            }
        }
        .onDisappear {
            // Only pause if actually playing
            if audiopleer.state == .playing {
                audiopleer.doPlayOrPause()
            }
            audioStateObserver?.cancel()
            audioStateObserver = nil
            invalidateAudioProgressTracking()
            invalidateTextReadingTracking()
        }
        .onChange(of: settingsManager.autoProgressByReading) { _ in
            evaluateTextReadingAutoProgress()
        }
        .onChange(of: settingsManager.autoProgressFrom90Percent) { _ in
            evaluateNinetyPercentAutoProgress()
        }
    }
    
    // MARK: Audio Control Panel
    @ViewBuilder
    private func audioControlPanel() -> some View {
        VStack(spacing: 0) {
            
            viewAudioHide()
            
            VStack(spacing: 0) {
                // Reader info row
                HStack(spacing: 12) {
                    if let currentReadStep = getCurrentReadStep() {
                        HStack(spacing: 4) {
                            Image(systemName: "globe")
                                .font(.caption)
                                .foregroundColor(Color("localAccentColor"))
                            Text(currentReadStep.translationName)
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
                        .accessibilityIdentifier("multi-translation-chip")

                        // Reader name
                        VStack(alignment: .leading, spacing: 0) {
                            Text("page.read.reader".localized())
                                .foregroundStyle(Color("localAccentColor").opacity(0.5))
                                .font(.caption2)
                            Text(currentReadStep.voiceName)
                                .foregroundStyle(Color("localAccentColor"))
                                .font(.footnote)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        .accessibilityIdentifier("multi-voice-chip")
                    }
                    
                    Spacer()
                    
                    // Progress indicator
                    VStack(alignment: .trailing, spacing: 0) {
                        // Keep the same vertical rhythm as the "Reader" two-line block.
                        Text("page.read.reader".localized())
                            .font(.caption2)
                            .hidden()
                        Text("\(currentUnitIndex + 1) " + "page.read.of".localized() + " \(unitRanges.count)")
                            .font(.callout)
                            .fontWeight(.bold)
                            .foregroundColor(Color("localAccentColor"))
                            .offset(y: -2)
                            .accessibilityIdentifier("multi-unit-counter")
                    }

                    #if DEBUG
                    VStack(spacing: 0) {
                        Text(multiPlaybackStateName)
                            .accessibilityIdentifier("multi-playback-state")
                        Text("\(currentUnitIndex)")
                            .accessibilityIdentifier("multi-current-unit")
                        Text("\(currentStepIndex)")
                            .accessibilityIdentifier("multi-current-step")
                    }
                    .font(.system(size: 1))
                    .foregroundStyle(.clear)
                    #endif
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.vertical, 10)

                viewChapterMarkToggle()

                // Control buttons row - matching PageReadView style
                HStack {
                    let hasAudio = !stepPlayerItems.isEmpty
                    let buttonsColor = hasAudio ? Color("localAccentColor") : Color("localAccentColor").opacity(0.4)
                    let prevColor = prevExcerpt.isEmpty ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
                    let nextColor = nextExcerpt.isEmpty ? Color("localAccentColor").opacity(0.4) : Color("localAccentColor")
                    let verseGoColor = (hasAudio && isPlaying) ? Color("localAccentColor") : Color("localAccentColor").opacity(0.4)

                    // Previous chapter
                    Button {
                        if !prevExcerpt.isEmpty {
                            Task {
                                settingsManager.currentExcerpt = prevExcerpt
                                await loadAllData(force: true)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.backward.2")
                            .foregroundColor(prevColor)
                    }
                    .accessibilityIdentifier("multi-prev-chapter")
                    .disabled(prevExcerpt.isEmpty)
                    Spacer()

                    // Previous Unit (Block)
                    Button {
                        navigateToPreviousUnit()
                    } label: {
                        Image(systemName: "arrow.up.square")
                            .font(.system(size: 22))
                            .foregroundColor(currentUnitIndex > 0 ? buttonsColor : Color("localAccentColor").opacity(0.4))
                    }
                    .accessibilityIdentifier("multi-prev-unit")
                    .disabled(!hasAudio || currentUnitIndex <= 0)
                    Spacer()

                    // Previous content (step or unit)
                    Button {
                        moveToPreviousSection()
                    } label: {
                        Image(systemName: "arrow.turn.left.up")
                            .foregroundColor(isAtSectionStart ? Color("localAccentColor").opacity(0.4) : buttonsColor)
                    }
                    .accessibilityIdentifier("multi-prev-section")
                    .disabled(!hasAudio || isAtSectionStart)
                    Spacer()

                    // Play/Pause
                    Button {
                        togglePlayPause()
                    } label: {
                        HStack {
                            if isPlaying {
                                Image(systemName: "pause.circle.fill")
                            } else if isAutopausing {
                                Image(systemName: "hourglass.circle.fill")
                            } else {
                                Image(systemName: "play.circle.fill")
                            }
                        }
                        .font(.system(size: 55))
                        .foregroundColor(buttonsColor)
                    }
                    .accessibilityIdentifier("multi-play-pause")
                    .disabled(!hasAudio)
                    Spacer()

                    // Next content (step or unit)
                    Button {
                        moveToNextSection()
                    } label: {
                        Image(systemName: "arrow.turn.right.down")
                            .foregroundColor(isAtSectionEnd ? Color("localAccentColor").opacity(0.4) : buttonsColor)
                    }
                    .accessibilityIdentifier("multi-next-section")
                    .disabled(!hasAudio || isAtSectionEnd)
                    Spacer()

                    // Next Unit (Block)
                    Button {
                        navigateToNextUnit()
                    } label: {
                        Image(systemName: "arrow.down.square")
                            .font(.system(size: 22))
                            .foregroundColor(currentUnitIndex < unitRanges.count - 1 ? buttonsColor : Color("localAccentColor").opacity(0.4))
                    }
                    .accessibilityIdentifier("multi-next-unit")
                    .disabled(!hasAudio || currentUnitIndex >= unitRanges.count - 1)
                    Spacer()

                    // Next chapter
                    Button {
                        if !nextExcerpt.isEmpty {
                            Task {
                                settingsManager.currentExcerpt = nextExcerpt
                                await loadAllData(force: true)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.forward.2")
                            .foregroundColor(nextColor)
                    }
                    .accessibilityIdentifier("multi-next-chapter")
                    .disabled(nextExcerpt.isEmpty)
                }
                .foregroundColor(Color("localAccentColor"))
                .padding(.horizontal, globalBasePadding)
                .padding(.top, 15)
                .padding(.bottom, 30) // Extra padding for home indicator
            }
            .frame(height: showAudioPanel ? nil : 0)
            .opacity(showAudioPanel ? 1 : 0)

        }
        .frame(maxWidth: .infinity)
        .frame(height: showAudioPanel ? audioPanelHeight : 45)
        .background(Color("DarkGreen-light"))
        .clipShape(TopRoundedRectangle(radius: 25))
        .edgesIgnoringSafeArea(.bottom)
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
        .accessibilityIdentifier("multi-chevron")
    }

    private var audioPanelHeight: CGFloat {
        // Base panel height + a small row for the chapter mark toggle.
        180 + 24
    }
    
    private var ninetyPercentThresholdVerseCount: Int {
        guard audioVerseCount > 0 else { return 0 }
        return Int(ceil(Double(audioVerseCount) * 0.9))
    }

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

    private var ninetyPercentVisualProgress: Double {
        guard settingsManager.autoProgressFrom90Percent else { return 0 }
        let required = ninetyPercentThresholdVerseCount
        guard required > 0 else { return 0 }
        return min(Double(listenedVerseNumbers.count) / Double(required), 1)
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
                if audiopleer.isStalled || audiopleer.isBufferingLong {
                    HStack(spacing: 4) {
                        ProgressView()
                            .tint(Color("Mustard"))
                            .scaleEffect(0.6)
                        Text("error.audio.stalled".localized)
                            .foregroundColor(Color("Mustard"))
                            .font(.caption2)
                    }
                } else if let errorMsg = audiopleer.errorMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color("Mustard"))
                            .font(.caption2)
                        Text(errorMsg)
                            .foregroundColor(Color("Mustard"))
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, globalBasePadding)
            .frame(minHeight: 24)
        }
        .accessibilityIdentifier("multi-chapter-progress")
        .accessibilityValue(isRead ? "read" : "unread")
        .buttonStyle(.plain)
        .disabled(!canMark)
        .opacity(canMark ? 1 : 0)
        .padding(.top, 2)
    }

    #if DEBUG
    private var multiPlaybackStateName: String {
        if isAutopausing { return "autopausing" }
        if isPlaying {
            switch audiopleer.state {
            case .buffering: return "buffering"
            default: return "playing"
            }
        }
        switch audiopleer.state {
        case .pausing: return "pausing"
        case .finished: return "finished"
        case .segmentFinished: return "segmentFinished"
        case .error: return "error"
        default: return "idle"
        }
    }
    #endif

    // Cycle playback speed
    private func cycleSpeed() {
        let speeds: [Double] = [0.75, 1.0, 1.25, 1.5, 2.0]
        if let currentIndex = speeds.firstIndex(of: settingsManager.currentSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            settingsManager.currentSpeed = speeds[nextIndex]
        } else {
            settingsManager.currentSpeed = 1.0
        }
        audiopleer.setSpeed(speed: Float(settingsManager.currentSpeed))
    }
    
    // Format speed for display (matching PageReadView)
    private func formatSpeedDisplay() -> String {
        let speed = settingsManager.currentSpeed
        if speed == 1.0 {
            return "x1"
        } else {
            return String(format: "%.1f", speed)
        }
    }
    
    /// Returns the current (or most recent) read step for display in the audio panel.
    private func getCurrentReadStep() -> MultilingualStep? {
        if currentStepIndex < allSteps.count {
            let step = allSteps[currentStepIndex]
            if step.type == .read { return step }
            // Walk backwards to find the last read step before the current position
            for i in stride(from: currentStepIndex - 1, through: 0, by: -1) {
                if allSteps[i].type == .read { return allSteps[i] }
            }
        }
        return readSteps.first
    }

    // MARK: Data Loading
    private func loadAllData(force: Bool = false) async {
        // Avoid reloading if data exists (preserves state on return from Settings)
        if !force && !stepTextVerses.isEmpty { return }
        isUpdatingExcerpt = true
        audiopleer.stop()  // Immediately stop old audio before loading new data
        stopAudioMonitoring()
        isPlaying = false
        invalidateAudioProgressTracking()
        invalidateTextReadingTracking()
        defer { isUpdatingExcerpt = false }
        
        isLoading = true
        errorDescription = ""
        stepTextVerses = [:]
        stepAudioVerses = [:]
        stepAudioUrls = [:]
        stepPlayerItems = [:]
        
        // Load data for each read step
        for (index, step) in readSteps.enumerated() {
            do {
                if TestingEnvironment.shouldForceLoadError {
                    throw NSError(domain: "UITesting", code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Simulated load error for UI testing"])
                }

                let (textVerses, audioVerses, audioUrl, _, part) = try await getExcerptTextualVersesOnline(
                    excerpts: settingsManager.currentExcerpt,
                    client: settingsManager.client,
                    translation: step.translationCode,
                    voice: step.voiceCode
                )

                stepTextVerses[index] = textVerses
                stepAudioVerses[index] = audioVerses
                let effectiveAudioUrl = TestingEnvironment.forceNoAudio ? "" : audioUrl
                stepAudioUrls[index] = effectiveAudioUrl
                if let url = URL(string: effectiveAudioUrl), !effectiveAudioUrl.isEmpty {
                    stepPlayerItems[index] = AVPlayerItem(url: url)
                }
                
                // Use first step's data for navigation info
                if index == 0, let part = part {
                    prevExcerpt = part.prev_excerpt
                    nextExcerpt = part.next_excerpt
                    excerptTitle = part.book.name
                    excerptSubtitle = "page.read.chapter_subtitle".localized(String(part.chapter_number))
                    
                    // Sync with SettingsManager for Menu display
                    DispatchQueue.main.async {
                        settingsManager.currentExcerptTitle = excerptTitle
                        settingsManager.currentExcerptSubtitle = excerptSubtitle
                        settingsManager.currentBookId = part.book.number
                        settingsManager.currentChapterId = part.chapter_number
                    }
                }
            } catch {
                print("[PageMultilingualReadView] Failed to load step '\(step.translationName)': \(error)")
                errorDescription = userFacingLoadingErrorMessage(for: error)
            }
        }
        
        // Build unit ranges based on first translation's structure
        buildUnitRanges()
        let verseNumbers = Set(stepTextVerses.values.flatMap { $0.map(\.number) })
        chapterVerseNumbers = verseNumbers
        beginAudioProgressTracking(chapterVerseCount: max(verseNumbers.count, stepTextVerses[0]?.count ?? 0))
        beginTextReadingTracking()
        
        // Reset playback state
        currentUnitIndex = 0
        currentStepIndex = 0
        highlightVerseNumber = nil
        isPlaying = false

        isLoading = false
        
        // Setup audio completion observer
        setupAudioObserver()
    }
    
    // Build unit ranges based on selected unit type
    private func buildUnitRanges() {
        guard let verses = stepTextVerses[0], !verses.isEmpty else {
            unitRanges = []
            return
        }
         
        unitRanges = []
        
        switch settingsManager.multilingualReadUnit {
        case .verse:
            // Each verse is a unit
            for i in 0..<verses.count {
                unitRanges.append((start: i, end: i))
            }
            
        case .paragraph:
            // Group by paragraph
            var start = 0
            for i in 0..<verses.count {
                if i > 0 && verses[i].startParagraph {
                    unitRanges.append((start: start, end: i - 1))
                    start = i
                }
            }
            unitRanges.append((start: start, end: verses.count - 1))
            
        case .fragment:
            // Group by fragment (title before verse)
            var start = 0
            for i in 0..<verses.count {
                if i > 0 && !verses[i].beforeTitles.isEmpty {
                    unitRanges.append((start: start, end: i - 1))
                    start = i
                }
            }
            unitRanges.append((start: start, end: verses.count - 1))
            
        case .chapter:
            // Entire chapter is one unit
            unitRanges = [(start: 0, end: verses.count - 1)]
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

        return "error.loading.chapter".localized
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
    
    // Get verses for a specific unit from a translation's verses
    private func getVersesForUnit(unitIndex: Int, allVerses: [BibleTextualVerseFull]) -> [BibleTextualVerseFull] {
        guard unitIndex < unitRanges.count else { return [] }
        let range = unitRanges[unitIndex]
        
        // Ensure range is valid for this translation's verses
        let start = min(range.start, allVerses.count - 1)
        let end = min(range.end, allVerses.count - 1)
        
        guard start <= end && start >= 0 else { return [] }
        return Array(allVerses[start...end])
    }
    
    // MARK: Playback Control
    private func togglePlayPause() {
        if isAutopausing {
            // Cancel the auto-pause timer and skip to the next step
            isAutopausing = false
            playCurrentStep(skipPause: true)
            return
        }

        if isPlaying {
            audiopleer.doPlayOrPause()
            isPlaying = false
        } else {
            // If we are resuming manually, skip any current pause step to move on
            playCurrentStep(skipPause: true)
        }
    }
    
    private func playCurrentStep(skipPause: Bool = false) {
        guard currentStepIndex < allSteps.count else {
            moveToNextUnit()
            return
        }
        
        retryCount = 0

        let step = allSteps[currentStepIndex]
        print("[MultiRead] Playing step \(currentStepIndex): \(step.type == .read ? step.translationName : "pause")")

        if step.type == .pause {
            if skipPause {
                print("[MultiRead] Skipping pause on manual resume")
                moveToNextStep()
                return
            }
            
            // Pause step - wait for duration then move to next
            isAutopausing = true
            isPlaying = false
            print("[MultiRead] Starting pause for \(step.pauseDuration)s")
            
            // Highlight the pause indicator - UNIQUE to this unit
            // Format: stepIdx * 10000 + 5000 + unitIndex
            self.highlightVerseNumber = currentStepIndex * 10000 + 5000 + currentUnitIndex
            
            DispatchQueue.main.asyncAfter(deadline: .now() + step.pauseDuration) {
                if self.isAutopausing {
                    print("[MultiRead] Pause ended, moving to next step")
                    self.isAutopausing = false
                    self.moveToNextStep()
                }
            }
        } else {
            // Read step - play audio
            isAutopausing = false

            // Find which read step index this is
            guard let readIndex = readSteps.firstIndex(where: { $0.id == step.id }) else {
                print("[MultiRead] ERROR: Could not find read step index")
                moveToNextStep()
                return
            }
            
            guard let audioVerses = stepAudioVerses[readIndex] else {
                print("[MultiRead] ERROR: No audio verses for readIndex \(readIndex)")
                moveToNextStep()
                return
            }
            
            guard let audioUrl = stepAudioUrls[readIndex], let url = URL(string: audioUrl) else {
                print("[MultiRead] ERROR: No audio URL for readIndex \(readIndex)")
                moveToNextStep()
                return
            }
            
            print("[MultiRead] Audio URL: \(audioUrl)")
            
            // Get verse range for current unit
            guard currentUnitIndex < unitRanges.count else {
                print("[MultiRead] ERROR: currentUnitIndex out of range")
                moveToNextStep()
                return
            }

            let unitRange = unitRanges[currentUnitIndex]

            // Make sure indices are valid
            let startIdx = min(unitRange.start, audioVerses.count - 1)
            let endIdx = min(unitRange.end, audioVerses.count - 1)

            guard startIdx >= 0 && startIdx <= endIdx else {
                print("[MultiRead] ERROR: Invalid verse range \(startIdx)-\(endIdx)")
                moveToNextStep()
                return
            }

            let unitAudioVerses = Array(audioVerses[startIdx...endIdx])

            guard !unitAudioVerses.isEmpty else {
                print("[MultiRead] ERROR: No unit audio verses")
                moveToNextStep()
                return
            }

            // Reuse pre-created player item for this translation (loaded once, seeked for each unit)
            let playerItem = stepPlayerItems[readIndex] ?? AVPlayerItem(url: url)
            let from = unitAudioVerses.first!.begin
            let to = unitAudioVerses.last!.end
            let trackingSessionID = UUID()
            verseTrackingSessionID = trackingSessionID
            currentAudioVerseNumber = -1

            print("[MultiRead] Setting up audio from \(from) to \(to) with \(unitAudioVerses.count) verses")

            // Set callbacks BEFORE setItem — seekToSegment() may trigger playback immediately
            audiopleer.onStartVerse = { verseIdx in
                guard self.verseTrackingSessionID == trackingSessionID else { return }
                if verseIdx >= 0 && verseIdx < unitAudioVerses.count {
                    let verseNumber = unitAudioVerses[verseIdx].number
                    self.highlightVerseNumber = self.currentStepIndex * 10000 + verseNumber
                    self.currentAudioVerseNumber = verseNumber
                }
            }
            audiopleer.onEndVerse = {
                guard self.verseTrackingSessionID == trackingSessionID else { return }
                self.recordListenedVerse(self.currentAudioVerseNumber)
            }

            audiopleer.setItem(
                playerItem: playerItem,
                periodFrom: from,
                periodTo: to,
                audioVerses: unitAudioVerses,
                itemTitle: excerptTitle,
                itemSubtitle: step.translationName
            )

            // Set speed for this step
            audiopleer.setSpeed(speed: Float(step.playbackSpeed))

            // Start monitoring for this new session
            startAudioMonitoring()
        }
    }
    
    private func moveToNextStep() {
        let isLastStepInUnit = !allSteps.isEmpty && currentStepIndex == allSteps.count - 1
        let isLastUnit = !unitRanges.isEmpty && currentUnitIndex == unitRanges.count - 1
        if isLastStepInUnit && isLastUnit && settingsManager.autoProgressAudioEnd {
            markCurrentChapterAsRead()
        }

        currentStepIndex += 1
        
        if currentStepIndex >= allSteps.count {
            // Done with all steps for this unit, move to next unit
            moveToNextUnit()
        } else {
            playCurrentStep()
        }
    }
    
    // Manual navigation to next content (no audio start — just highlight for reading)
    private func moveToNextSection() {
        let wasActive = isPlaying || isAutopausing
        stopAudioMonitoring()
        isAutopausing = false
        isPlaying = false

        // Find next read step in current unit
        if let nextIndex = allSteps.indices.first(where: { $0 > currentStepIndex && allSteps[$0].type == .read }) {
            currentStepIndex = nextIndex
        } else if currentUnitIndex < unitRanges.count - 1 {
            currentUnitIndex += 1
            currentStepIndex = 0
        }

        if wasActive {
            playCurrentStep(skipPause: true)
        } else {
            highlightCurrentPosition()
        }
    }

    private func moveToPreviousSection() {
        let wasActive = isPlaying || isAutopausing
        stopAudioMonitoring()
        isAutopausing = false
        isPlaying = false

        // Find previous read step in current unit
        if let prevIndex = allSteps.indices.last(where: { $0 < currentStepIndex && allSteps[$0].type == .read }) {
            currentStepIndex = prevIndex
        } else if currentUnitIndex > 0 {
            currentUnitIndex -= 1
            if let lastReadIndex = allSteps.indices.last(where: { allSteps[$0].type == .read }) {
                currentStepIndex = lastReadIndex
            } else {
                currentStepIndex = 0
            }
        }

        if wasActive {
            playCurrentStep(skipPause: true)
        } else {
            highlightCurrentPosition()
        }
    }

    /// Sets highlightVerseNumber to the first verse of the current unit at the current step, without starting audio.
    private func highlightCurrentPosition() {
        guard currentUnitIndex < unitRanges.count else { return }

        let stepIdx: Int
        if currentStepIndex < allSteps.count && allSteps[currentStepIndex].type == .read {
            stepIdx = currentStepIndex
        } else {
            stepIdx = allSteps.indices.first(where: { allSteps[$0].type == .read }) ?? 0
        }

        guard stepIdx < allSteps.count,
              let readIndex = readSteps.firstIndex(where: { $0.id == allSteps[stepIdx].id }),
              let verses = stepTextVerses[readIndex] else { return }

        let unitRange = unitRanges[currentUnitIndex]
        let startIdx = min(unitRange.start, verses.count - 1)
        guard startIdx >= 0 else { return }

        highlightVerseNumber = stepIdx * 10000 + verses[startIdx].number
    }

    /// Navigate to previous unit; resume playback only if audio was already playing.
    private func navigateToPreviousUnit() {
        guard currentUnitIndex > 0 else { return }
        let wasActive = isPlaying || isAutopausing
        stopAudioMonitoring()
        isAutopausing = false
        isPlaying = false

        currentUnitIndex -= 1
        currentStepIndex = 0

        if wasActive {
            playCurrentStep(skipPause: true)
        } else {
            highlightCurrentPosition()
        }
    }

    /// Navigate to next unit; resume playback only if audio was already playing.
    private func navigateToNextUnit() {
        guard currentUnitIndex < unitRanges.count - 1 else { return }
        let wasActive = isPlaying || isAutopausing
        stopAudioMonitoring()
        isAutopausing = false
        isPlaying = false

        currentUnitIndex += 1
        currentStepIndex = 0

        if wasActive {
            playCurrentStep(skipPause: true)
        } else {
            highlightCurrentPosition()
        }
    }

    private func moveToPreviousUnit() {
        guard currentUnitIndex > 0 else { return }
        stopAudioMonitoring()
        isAutopausing = false
        isPlaying = false

        currentUnitIndex -= 1
        currentStepIndex = 0
        playCurrentStep()
    }

    private func moveToNextUnit() {
        stopAudioMonitoring()
        isAutopausing = false
        isPlaying = false

        if currentUnitIndex < unitRanges.count - 1 {
            currentUnitIndex += 1
            currentStepIndex = 0
            playCurrentStep()
        }
    }

    
    // MARK: Audio Observer
    private func stopAudioMonitoring() {
        print("[MultiRead] Stopping audio monitoring")
        audioStateObserver?.cancel()
        audioStateObserver = nil
    }
    
    private func startAudioMonitoring() {
        stopAudioMonitoring()
        
        // Create new session ID
        let sessionID = UUID()
        self.playbackSessionID = sessionID
        
        print("[MultiRead] Starting audio monitoring for session \(sessionID)")
        
        // Capture start time for safety window
        let sessionStartTime = Date()
        
        audioStateObserver = audiopleer.$state
            .receive(on: DispatchQueue.main)
            .sink { newState in
                // Verify session match (though cancellation handles most cases, this is extra safety)
                guard self.playbackSessionID == sessionID else {
                    print("[MultiRead] Ignoring event for old session")
                    return
                }
                
                print("[MultiRead] Audio state changed to: \(newState)")

                self.updateTextReadingTimerForAudioState(newState)

                // When audio is ready to play, start it
                if newState == .waitingForPlay {
                    print("[MultiRead] State is waitingForPlay")
                    // Check if PlayerModel already auto-started playback to avoid toggling to PAUSE
                    if self.audiopleer.state != .playing {
                        print("[MultiRead] Starting playback (manual)")
                        self.audiopleer.doPlayOrPause()
                    } else {
                        print("[MultiRead] Already playing (auto-started), skipping toggle")
                    }
                    self.isPlaying = true
                }

                // Handle audio loading error — auto-retry once, then skip
                if newState == .error {
                    if self.retryCount < 1 {
                        self.retryCount += 1
                        print("[MultiRead] Audio error, retrying in 3s (attempt \(self.retryCount))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            guard self.playbackSessionID == sessionID else { return }
                            self.audiopleer.retry()
                        }
                    } else {
                        print("[MultiRead] Audio error after retry: \(self.audiopleer.errorMessage ?? "unknown"), skipping step")
                        self.retryCount = 0
                        self.isPlaying = false
                        self.moveToNextStep()
                    }
                    return
                }

                // Move to next step when audio finishes naturally (logic end or file end)
                if newState == .finished || newState == .segmentFinished {
                    // SAFETY WINDOW: Ignore completion events immediately after start (0.1s)
                    if Date().timeIntervalSince(sessionStartTime) < 0.1 {
                        print("[MultiRead] Ignoring early completion event (safety window)")
                        return
                    }

                    // Only advance if we are supposed to be playing
                    if self.isPlaying {
                        // PlayerModel does not emit `onEndVerse` for the last verse; count it here.
                        self.recordListenedVerse(self.currentAudioVerseNumber)
                        self.evaluateNinetyPercentAutoProgress()
                        print("[MultiRead] Audio ended (state: \(newState)), moving to next step")
                        self.isPlaying = false // Logical stop
                        self.moveToNextStep()
                    }
                }
            }
    }
    
    // Legacy setup function redirect
    private func setupAudioObserver() {
       // No-op or start initial monitoring if needed, but playCurrentStep handles it.
    }

    private func beginAudioProgressTracking(chapterVerseCount: Int) {
        listenedVerseNumbers.removeAll(keepingCapacity: true)
        self.audioVerseCount = max(chapterVerseCount, 0)
        ninetyPercentHandledForSession = false
    }

    private func invalidateAudioProgressTracking() {
        listenedVerseNumbers.removeAll(keepingCapacity: true)
        chapterVerseNumbers.removeAll(keepingCapacity: true)
        audioVerseCount = 0
        ninetyPercentHandledForSession = true
    }

    private func recordListenedVerse(_ verseNumber: Int) {
        guard !isUpdatingExcerpt else { return }
        guard verseNumber > 0 else { return }
        // Audio can be incomplete/misaligned; count only verses that exist in the displayed chapter text.
        if !chapterVerseNumbers.isEmpty, !chapterVerseNumbers.contains(verseNumber) {
            return
        }
        listenedVerseNumbers.insert(verseNumber)
        evaluateNinetyPercentAutoProgress()
    }

    private func evaluateNinetyPercentAutoProgress() {
        guard settingsManager.autoProgressFrom90Percent else { return }
        guard !ninetyPercentHandledForSession else { return }
        guard audioVerseCount > 0 else { return }

        let requiredVerseCount = Int(ceil(Double(audioVerseCount) * 0.9))
        guard requiredVerseCount > 0 else { return }

        if listenedVerseNumbers.count >= requiredVerseCount {
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
        guard !stepTextVerses.isEmpty else { return }
        guard !isUpdatingExcerpt else { return }
        guard !isLoading else { return }

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
        guard !stepTextVerses.isEmpty else { return }
        guard !isUpdatingExcerpt else { return }
        guard !isLoading else { return }
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
        let verseCount = max(chapterVerseNumbers.count, stepTextVerses[0]?.count ?? 0)
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

    private var currentChapterProgressTarget: (bookAlias: String, chapter: Int)? {
        let chapter = stepTextVerses[0]?.first?.chapterDigitCode ?? settingsManager.currentChapterId
        guard chapter > 0 else { return nil }

        let aliasFromVerse = stepTextVerses[0]?.first.map { settingsManager.getBookAlias(bookNumber: $0.bookDigitCode) } ?? ""
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
    
    // MARK: HTML Generation
    private func generateMultilingualHTML() -> String {
        let selectedColor = getCSSColor(named: "DarkGreen-accent")
        let jesusColor = getCSSColor(named: "Jesus")
        let jesusSelectedColor = getCSSColor(named: "JesusSelected")
        let translationLabelColor = getCSSColor(named: "Mustard")
        var htmlString = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; }
                html {
                    scroll-behavior: smooth;
                }
                body {
                    background-color: transparent;
                    color: #ffffff;
                    font-family: -apple-system, Helvetica, Arial, sans-serif;
                    line-height: 1.6;
                    margin: 0;
                    padding: 0 22px;
                    padding-bottom: 10px; /* Minimal space, panel handles the rest */
                }
                .unit {
                    margin-bottom: 24px;
                    padding: 12px 22px;
                    margin-left: -22px;
                    margin-right: -22px;
                }
                .unit:last-child {
                    margin-bottom: 0;
                }
                /* Dynamic unit highlighting - unit containing highlighted verse gets background */
                .unit:has(.highlighted-verse) {
                    background-color: rgba(255,255,255,0.05);
                }
                .translation-label {
                    font-size: 0.75rem;
                    font-weight: bold;
                    color: \(translationLabelColor);
                    opacity: 0.8;
                    margin-top: 8px;
                    margin-bottom: 4px;
                }
                .verse-block {
                    margin-bottom: 4px;
                }
                .verse-number {
                    font-size: 0.7rem;
                    color: rgba(255,255,255,0.5);
                    margin-right: 4px;
                }
                .separator {
                    border: none;
                    border-top: 1px solid rgba(255,255,255,0.2);
                    margin: 8px 0;
                }
                .pause-indicator {
                    display: flex;
                    align-items: center;
                    padding: 0px 0;
                    margin: 0px 0;
                    transition: all 0.3s ease;
                    font-size: 0.75rem;
                    opacity: 0.5;
                }
                .pause-indicator.highlighted-verse {
                    color: \(selectedColor);
                    opacity: 1.0;
                }
                .pause-indicator.highlighted-verse::before, 
                .pause-indicator.highlighted-verse::after {
                    border-top-color: \(selectedColor);
                    /* Opacity is inherited/set on base element, but we want LINES to be 50% transparent */
                    opacity: 0.3;
                }
                .pause-indicator::before, .pause-indicator::after {
                    content: '';
                    flex: 1;
                    /* Default white line */
                    border-top: 1px solid white;
                    /* 50% transparency as requested */
                    opacity: 0.3;
                }
                .pause-indicator span {
                    padding: 0 12px;
                }
                em, i { font-style: italic; }
                strong, b { font-weight: bold; }
                .jesus { color: \(jesusColor); }
                .e { opacity: 0.7; }
                .gray { opacity: 0.5; }
                .highlighted-verse { color: \(selectedColor); }
                .highlighted-verse .jesus { color: \(jesusSelectedColor); }
                
                .quote-container {
                    padding-left: 1.1rem;
                    display: flex;
                    flex-direction: column;
                }
                .quote {
                    display: block;
                    font-family: serif;
                    font-style: italic;
                }
                
                /* Title Styles */
                .title {
                    font-size: 1.3rem;
                    font-weight: bold;
                    margin-top: 0.5rem;
                    margin-bottom: 0.2rem;
                }
                
                .subtitle {
                    font-size: 0.9rem;
                    color: rgba(255, 255, 255, 0.7);
                    margin-top: 0.8rem;
                    margin-bottom: 0.8rem;
                    display: block;
                    text-align: center;
                    font-weight: bold;
                }
                
                .reference {
                    font-size: 0.7rem;
                    font-weight: bold;
                    color: rgba(255, 255, 255, 0.8);
                    margin-top: 0;
                    margin-bottom: 0.5rem;
                }
                
                .metadata {
                    color: rgba(255, 255, 255, 0.7);
                    font-style: italic;
                }
            </style>
        </head>
        <body>
        """
        
        // Generate content for each unit
        for (unitIdx, unitRange) in unitRanges.enumerated() {
            htmlString += "<div id=\"unit-\(unitIdx)\" class=\"unit\">"
            
            // For each step, show the translation block
            for (stepIdx, step) in allSteps.enumerated() {
                if step.type == .read {
                    // Find read step index
                    if let readStepIndex = readSteps.firstIndex(where: { $0.id == step.id }),
                       let verses = stepTextVerses[readStepIndex] {
                        
                        let fontSize = 10 * (1 + step.fontIncreasePercent / 100)
                        
                        // Verses for this unit (no translation label, as per mockup)
                        let startIdx = min(unitRange.start, verses.count - 1)
                        let endIdx = min(unitRange.end, verses.count - 1)
                        
                        if startIdx >= 0 && startIdx <= endIdx {
                            for i in startIdx...endIdx {
                                let verse = verses[i]
                                let uniqueId = stepIdx * 10000 + verse.number
                                
                                // Display headers (titles/subtitles)
                                let regularTitles = verse.beforeTitles.filter { !$0.subtitle }
                                for title in regularTitles {
                                    htmlString += "<p class=\"title\">\(title.text)</p>"
                                    if let reference = title.reference, !reference.isEmpty {
                                        htmlString += "<p class=\"reference\">\(reference)</p>"
                                    }
                                }

                                // Subtitles at start
                                let startSubtitles = verse.beforeTitles.filter { $0.subtitle && ($0.positionHtml ?? 0) == 0 }
                                for sub in startSubtitles {
                                    htmlString += "<p class=\"subtitle\">\(sub.text)</p>"
                                }
                                
                                htmlString += """
                                <div id="verse-\(uniqueId)" class="verse-block" style="font-size: \(fontSize)px;">
                                    <span class="verse-number">\(verse.number).</span>
                                    <span>\(verse.html)</span>
                                </div>
                                """
                            }
                        }
                    }
                } else if step.type == .pause {
                    // Pause indicator between translations
                    let pauseSeconds = Int(step.pauseDuration)
                    // Unique ID needing Unit Index to avoid duplicates across units
                    let uniqueId = stepIdx * 10000 + 5000 + unitIdx
                    htmlString += "<div id=\"verse-\(uniqueId)\" class=\"pause-indicator\"><span>\(pauseSeconds) sec.</span></div>"
                }
            }
            
            htmlString += "</div>"
        }
        
        htmlString += """
        </body>
        </html>
        """
        
        return htmlString
    }
}
