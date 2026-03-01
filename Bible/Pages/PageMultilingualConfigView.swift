import SwiftUI
import AVFoundation
import Combine
import Foundation

struct PageMultilingualConfigView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State var step: MultilingualStep
    private let initialStep: MultilingualStep
    private let isAddingStep: Bool
    var onSave: (MultilingualStep) -> Void
    
    init(step: MultilingualStep, isAddingStep: Bool = false, onSave: @escaping (MultilingualStep) -> Void) {
        self.initialStep = step
        self.isAddingStep = isAddingStep
        self._step = State(initialValue: step)
        self.onSave = onSave
    }
    
    // MARK: Languages and translations state
    @State private var isLanguagesLoading: Bool = true
    @State private var languageTexts: [String] = []
    @State private var languageDescriptions: [String] = []
    @State private var languageKeys: [String]  = []

    @State private var translationsResponse: [Components.Schemas.TranslationModel] = []
    @State private var isTranslationsLoading: Bool = true
    @State private var translationKeys: [String]  = []
    @State private var translationTexts: [String] = []
    @State private var translationDescriptions: [String] = []
    @State private var translationNames: [String] = []
    
    @State private var voiceTexts: [String] = []
    @State private var voiceKeys: [String]  = []
    @State private var voiceMusics: [Bool]  = []
    @State private var voiceDescriptions: [String] = []
    
    @State private var inlineErrorMessage: String = ""
    
    // Temporary selections
    @State private var selectedLanguage: String = ""
    @State private var selectedTranslation: String = ""
    @State private var selectedTranslationName: String = ""
    @State private var selectedVoice: String = ""
    @State private var selectedVoiceName: String = ""
    @State private var selectedVoiceMusic: Bool = false
    
    // Preview
    @State private var previewPlayer: AVPlayer?
    @State private var previewVoiceIndex: Int? = nil
    @State private var previewTimer: AnyCancellable? = nil
    @State private var previewTimeObserver: Any? = nil
    @State private var expandedSelectionSection: SelectionAccordionSection? = nil

    private enum SelectionAccordionSection {
        case language
        case translation
        case voice
    }

    var body: some View {
        ZStack {
            Color("DarkGreen")
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                ZStack {
                    Text("multilingual.config.title".localized) // Localized
                        .font(.headline)
                        .foregroundColor(.white)

                    HStack {
                        Button {
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3.weight(.light))
                                .frame(width: 32, height: 32)
                        }
                        .foregroundColor(Color.white.opacity(0.7))

                        Spacer()

                        Button {
                            saveStep()
                        } label: {
                            Text(saveButtonTitle)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(canSave ? Color("Mustard") : Color.gray)
                        .disabled(!canSave)
                        .accessibilityIdentifier("multi-config-save")
                    }
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.vertical, 12)
                .background(Color("DarkGreen").brightness(0.05))
                
                ScrollView {
                    VStack(spacing: 0) {
                        if !inlineErrorMessage.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                Text(inlineErrorMessage)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.horizontal, globalBasePadding)
                            .padding(.top, 10)
                            .padding(.bottom, 14)
                        }
                        viewGroupHeader(text: "settings.translation_audio".localized)
                        VStack(spacing: 10) {
                            selectionAccordionSectionCard(
                                section: .language,
                                title: "settings.bible_language".localized,
                                value: selectedLanguageLabel(),
                                isPlaceholder: selectedLanguage.isEmpty,
                                isLoading: isLanguagesLoading
                            ) {
                                if isLanguagesLoading {
                                    ProgressView().tint(.white).frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    compactSelectionList(
                                        texts: languageTexts,
                                        keys: languageKeys,
                                        selectedKey: $selectedLanguage,
                                        descriptions: languageDescriptions,
                                        onSelect: { index in
                                            stopVoicePreview()
                                            let selected = languageKeys[index]
                                            transitionToSection(.translation) {
                                                selectedLanguage = selected
                                                clearTranslationSelection()
                                                clearVoiceSelection()
                                                fetchTranslations()
                                            }
                                        }
                                    )
                                }
                            }
                            
                            selectionAccordionSectionCard(
                                section: .translation,
                                title: "settings.translation".localized,
                                value: selectedTranslationLabel(),
                                isPlaceholder: selectedTranslation.isEmpty,
                                isLoading: isTranslationsLoading
                            ) {
                                if selectedLanguage.isEmpty {
                                    Text("settings.bible_language".localized)
                                        .foregroundColor(.white.opacity(0.6))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else if isTranslationsLoading {
                                    ProgressView().tint(.white).frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    compactSelectionList(
                                        texts: translationTexts,
                                        keys: translationKeys,
                                        selectedKey: $selectedTranslation,
                                        descriptions: translationDescriptions,
                                        onSelect: { index in
                                            stopVoicePreview()
                                            let selected = translationKeys[index]
                                            let selectedName = translationNames[index]
                                            transitionToSection(.voice) {
                                                selectedTranslation = selected
                                                selectedTranslationName = selectedName
                                                clearVoiceSelection()
                                                showAudios()
                                            }
                                        }
                                    )
                                }
                            }
                            
                            selectionAccordionSectionCard(
                                section: .voice,
                                title: "settings.reader".localized,
                                value: selectedVoiceLabel(),
                                isPlaceholder: selectedVoice.isEmpty,
                                isLoading: false
                            ) {
                                if selectedTranslation.isEmpty {
                                    Text("settings.select_translation".localized)
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else if voiceTexts.isEmpty {
                                    Text("settings.select_reader".localized)
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    compactSelectionListWithPreview(
                                        texts: voiceTexts,
                                        keys: voiceKeys,
                                        selectedKey: $selectedVoice,
                                        descriptions: voiceDescriptions,
                                        onSelect: { index in
                                            selectedVoice = voiceKeys[index]
                                            selectedVoiceName = voiceTexts[index]
                                            selectedVoiceMusic = voiceMusics[index]
                                            stopVoicePreview()
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                expandedSelectionSection = nil
                                            }
                                        },
                                        onPreview: { index in
                                            toggleVoicePreview(index: index)
                                        },
                                        isPlaying: { index in
                                            return previewVoiceIndex == index
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Speed Settings
                        viewGroupHeader(text: "settings.speed".localized)
                        HStack(spacing: 0) {
                            Button(action: {
                                if step.playbackSpeed > 0.5 {
                                    step.playbackSpeed -= 0.1
                                }
                            }) {
                                Image(systemName: "minus")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.clear)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 50, height: 40)
                            
                            Divider().background(Color.white)
                            
                            Text(String(format: "%.1fx", step.playbackSpeed))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, maxHeight: 40)
                            
                            Divider().background(Color.white)
                            
                            Button(action: {
                                if step.playbackSpeed < 2.5 {
                                    step.playbackSpeed += 0.1
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.title3)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .background(Color.clear)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 50, height: 40)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white, lineWidth: 1)
                        )
                        .padding(.horizontal, 3)

                        // Font Settings
                        viewGroupHeader(text: "settings.font".localized)
                        HStack {
                            Text("\(Int(step.fontIncreasePercent))%")
                                .foregroundColor(.white)
                                .frame(width: 70)
                            
                            Spacer()
                            
                            HStack(spacing: 0) {
                                Button(action: {
                                    if step.fontIncreasePercent > 10 {
                                        step.fontIncreasePercent -= 10
                                    }
                                }) {
                                    Text("A")
                                        .font(.title3)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                }
                                
                                Divider() // Divider between buttons
                                    .background(Color.white)
                                
                                Button(action: {
                                    if step.fontIncreasePercent < 500 {
                                        step.fontIncreasePercent += 10
                                    }
                                }) {
                                    Text("A")
                                        .font(.title)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.clear)
                                        .foregroundColor(.white)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .frame(maxWidth: 200)
                            .frame(maxHeight: 42)
                            
                            Spacer()
                            
                            Button {
                                step.fontIncreasePercent = 100.0
                            } label: {
                                Text("settings.font.reset".localized)
                                    .foregroundColor(Color("Mustard"))
                                    .frame(width: 70)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            initializeState()
        }
        .onDisappear {
            stopVoicePreview()
        }
    }
    
    var canSave: Bool {
        return !selectedLanguage.isEmpty && !selectedTranslation.isEmpty && !selectedVoice.isEmpty
    }

    private var saveButtonTitle: String {
        isAddingStep ? "settings.add_choice".localized : "settings.save_choice".localized
    }
    
    func initializeState() {
        // Force update state from init parameter (fix for sticky state issues in sheets)
        self.step = self.initialStep
        
        // Prepare initial state from step
        if !step.languageCode.isEmpty {
            selectedLanguage = step.languageCode
             selectedTranslation = String(step.translationCode)
             selectedTranslationName = step.translationName
            selectedVoice = String(step.voiceCode)
            selectedVoiceName = step.voiceName
            selectedVoiceMusic = step.voiceMusic
            selectedVoiceMusic = step.voiceMusic
        } else {
            // New empty step - do NOT set defaults here. 
            // Defaults are handled in setup view for first step only.
            // Leave everything empty to force user selection.
            
             // Initialize font and speed from global settings / defaults (safe to have defaults)
             if step.fontIncreasePercent == 0 { step.fontIncreasePercent = 100.0 }
             if step.playbackSpeed == 0 { step.playbackSpeed = 1.0 }
        }
        
        fetchLanguages()
    }
    
    func saveStep() {
        step.languageCode = selectedLanguage
        step.translationCode = Int(selectedTranslation) ?? 0
        step.translationName = selectedTranslationName
        step.voiceCode = Int(selectedVoice) ?? 0
        step.voiceName = selectedVoiceName
        step.voiceMusic = selectedVoiceMusic
        // fontIncreasePercent is already bound to step
        
        // Find language name
        if let idx = languageKeys.firstIndex(of: selectedLanguage) {
             // Extract English name from "National (En)"
             // The format in fetchLanguages is "\(language.name_national) (\(language.name_en))"
             // I'll just store the text I have.
             // Ideally step should have languageName.
            step.languageName = languageTexts[idx]
        }
        
        onSave(step)
        presentationMode.wrappedValue.dismiss()
    }
    
    // MARK: API Reused Logic
    func fetchLanguages() {
        inlineErrorMessage = ""
        // Optimistically use cached data if available
        if !settingsManager.cachedLanguages.isEmpty {
             // If translations are also cached or we want to trigger their fetch in background?
             // Best to just ensure they are loaded.
             if settingsManager.cachedAllTranslations.isEmpty {
                 Task {
                     try? await settingsManager.fetchAllTranslations()
                     self.updateLanguagesList()
                 }
             } else {
                 self.updateLanguagesList()
             }
        } else {
            Task {
                do {
                    self.languageKeys = []
                    self.languageTexts = []
                    
                    // Fetch both concurrently
                    async let langsFetch: Void = settingsManager.fetchLanguages()
                    async let transFetch: Void = settingsManager.fetchAllTranslations()

                    // Wait for both
                    try await langsFetch
                    try await transFetch
                    
                    self.updateLanguagesList()
                   
                    self.isLanguagesLoading = false
                } catch {
                    self.isLanguagesLoading = false
                    showInlineError(for: error)
                }
            }
        }
    }
    
    func updateLanguagesList() {
        self.languageKeys = []
        self.languageTexts = []
        self.languageDescriptions = []

        let languages = settingsManager.cachedLanguages

        for language in languages {
            self.languageKeys.append(language.alias)
            self.languageTexts.append(language.name_national)
            self.languageDescriptions.append(language.name_en)
        }

        if !selectedLanguage.isEmpty && !languageKeys.contains(selectedLanguage) {
            selectedLanguage = ""
            clearTranslationSelection()
            clearVoiceSelection()
        }
        
        if !selectedLanguage.isEmpty {
             fetchTranslations()
        } else {
            isTranslationsLoading = false
            translationKeys = []
            translationTexts = []
            translationNames = []
            translationsResponse = []
            showAudios()
        }
        self.isLanguagesLoading = false
    }
    
    func fetchTranslations() {
        // Use cached translations if available
        if !settingsManager.cachedAllTranslations.isEmpty {
            self.updateTranslationsList()
        } else {
            Task {
                try? await settingsManager.fetchAllTranslations()
                self.updateTranslationsList()
            }
        }
    }
    
    func updateTranslationsList() {
        self.isTranslationsLoading = true
        
        self.translationsResponse = settingsManager.getTranslations(for: self.selectedLanguage)
        
        self.translationKeys = []
        self.translationTexts = []
        self.translationDescriptions = []
        self.translationNames = []
        for translation in self.translationsResponse {
            self.translationKeys.append("\(translation.code)")
            let shortName = translation.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let longName = (translation.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            self.translationTexts.append(shortName)
            self.translationDescriptions.append(longName == shortName ? "" : longName)
            self.translationNames.append(translation.name)
        }

        if selectedTranslation.isEmpty {
            selectedTranslationName = ""
        } else if !translationKeys.contains(selectedTranslation) {
            clearTranslationSelection()
            clearVoiceSelection()
            showAudios()
            self.isTranslationsLoading = false
            return
        } else if let selectedIndex = translationKeys.firstIndex(of: selectedTranslation) {
            selectedTranslationName = translationNames[selectedIndex]
        }
        
        showAudios()
        self.isTranslationsLoading = false
    }
    
    func showAudios() {
        self.voiceKeys = []
        self.voiceTexts = []
        self.voiceMusics = []
        self.voiceDescriptions = []
        
        if let translation = self.translationsResponse.first(where: { "\($0.code)" == self.selectedTranslation }) {
             for voice in translation.voices {
                self.voiceKeys.append("\(voice.code)")
                self.voiceTexts.append("\(voice.name)")
                self.voiceMusics.append(voice.is_music)
                self.voiceDescriptions.append(voice.description ?? "")
            }
        }
        
        if !selectedVoice.isEmpty {
            guard let selectedIndex = voiceKeys.firstIndex(of: selectedVoice) else {
                clearVoiceSelection()
                return
            }
            selectedVoiceName = voiceTexts[selectedIndex]
            selectedVoiceMusic = voiceMusics[selectedIndex]
        }
    }

    @ViewBuilder private func selectionAccordionSectionCard<Content: View>(
        section: SelectionAccordionSection,
        title: String,
        value: String,
        isPlaceholder: Bool = false,
        isLoading: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedSelectionSection == section
        VStack(spacing: 0) {
            Button {
                toggleSelectionSection(section)
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isExpanded ? Color("Mustard") : Color.white.opacity(0.35))
                        .frame(width: 3, height: 30)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(value)
                            .font(.callout)
                            .fontWeight(isPlaceholder ? .regular : .medium)
                            .foregroundColor(.white.opacity(isPlaceholder ? 0.4 : 1))
                            .lineLimit(1)
                    }
                    Spacer()
                    cardTrailing(isExpanded: isExpanded, isLoading: isLoading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                content()
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("DarkGreen-light").opacity(isExpanded ? 0.9 : 0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isExpanded ? Color("Mustard").opacity(0.5) : Color.white.opacity(0.2),
                    lineWidth: isExpanded ? 1.1 : 1
                )
        )
    }

    @ViewBuilder private func compactSelectionList(
        texts: [String],
        keys: [String],
        selectedKey: Binding<String>,
        descriptions: [String] = [],
        onSelect: @escaping (Int) -> Void = { _ in }
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(texts.indices, id: \.self) { index in
                let text = texts[index]
                let key = keys[index]
                let description = index < descriptions.count ? descriptions[index] : ""
                Button {
                    selectedKey.wrappedValue = key
                    onSelect(index)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(text)
                                .foregroundColor(selectedKey.wrappedValue == key ? Color("Mustard") : .white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineLimit(1)
                            if !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if selectedKey.wrappedValue == key {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color("Mustard"))
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if index < texts.count - 1 {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
    }

    @ViewBuilder private func compactSelectionListWithPreview(
        texts: [String],
        keys: [String],
        selectedKey: Binding<String>,
        descriptions: [String] = [],
        onSelect: @escaping (Int) -> Void = { _ in },
        onPreview: @escaping (Int) -> Void,
        isPlaying: @escaping (Int) -> Bool
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(texts.indices, id: \.self) { index in
                let text = texts[index]
                let key = keys[index]
                let description = index < descriptions.count ? descriptions[index] : ""

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(text)
                            .foregroundColor(selectedKey.wrappedValue == key ? Color("Mustard") : .white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(1)
                        if !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Image(systemName: "checkmark")
                        .foregroundColor(Color("Mustard"))
                        .frame(width: 16)
                        .opacity(selectedKey.wrappedValue == key ? 1 : 0)
                    Button {
                        onPreview(index)
                    } label: {
                        Image(systemName: isPlaying(index) ? "stop.circle.fill" : "play.circle.fill")
                            .foregroundColor(Color("localAccentColor"))
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedKey.wrappedValue = key
                    onSelect(index)
                }
                .padding(.vertical, 10)

                if index < texts.count - 1 {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
    }

    @ViewBuilder private func cardTrailing(isExpanded: Bool, isLoading: Bool) -> some View {
        if isLoading {
            ProgressView().tint(.white).scaleEffect(0.8)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 28, height: 28)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 12, weight: .bold))
            }
        }
    }

    private func selectedLanguageLabel() -> String {
        guard let index = languageKeys.firstIndex(of: selectedLanguage), index < languageTexts.count else {
            return "settings.select_language".localized
        }
        return languageTexts[index]
    }

    private func selectedTranslationLabel() -> String {
        guard let index = translationKeys.firstIndex(of: selectedTranslation), index < translationTexts.count else {
            if !selectedTranslation.isEmpty && !selectedTranslationName.isEmpty {
                return selectedTranslationName
            }
            return "settings.select_translation".localized
        }
        return translationTexts[index]
    }

    private func selectedVoiceLabel() -> String {
        guard let index = voiceKeys.firstIndex(of: selectedVoice), index < voiceTexts.count else {
            if !selectedVoice.isEmpty && !selectedVoiceName.isEmpty {
                return selectedVoiceName
            }
            return "settings.select_reader".localized
        }
        return voiceTexts[index]
    }

    private func toggleSelectionSection(_ section: SelectionAccordionSection) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedSelectionSection == .voice {
                stopVoicePreview()
            }
            if expandedSelectionSection == section {
                expandedSelectionSection = nil
            } else {
                expandedSelectionSection = section
            }
        }
    }

    private func transitionToSection(_ next: SelectionAccordionSection, applySelection: @escaping () -> Void) {
        if expandedSelectionSection == .voice && next != .voice {
            stopVoicePreview()
        }
        applySelection()
        withAnimation(.easeInOut(duration: 0.22)) {
            expandedSelectionSection = next
        }
    }

    private func clearTranslationSelection() {
        selectedTranslation = ""
        selectedTranslationName = ""
    }

    private func clearVoiceSelection() {
        selectedVoice = ""
        selectedVoiceName = ""
        selectedVoiceMusic = false
    }
    
    // MARK: Voice preview
    func toggleVoicePreview(index: Int) {
        if previewVoiceIndex == index {
            stopVoicePreview()
            return
        }
        stopVoicePreview()
        inlineErrorMessage = ""
        
        let voiceCode = Int(voiceKeys[index]) ?? 0
        let translationCode = Int(selectedTranslation) ?? 0

        Task {
            do {
                let (_, audioVerses, firstUrl, _, _) = try await getExcerptTextualVersesOnline(
                    excerpts: "jhn 1",
                    client: settingsManager.client,
                    translation: translationCode,
                    voice: voiceCode
                )
                
                guard !firstUrl.isEmpty, let url = URL(string: firstUrl) else {
                    inlineErrorMessage = "error.audio.unavailable".localized
                    return
                }
                
                let playerItem = AVPlayerItem(url: url)
                previewPlayer = AVPlayer(playerItem: playerItem)
                previewVoiceIndex = index
                
                if let firstVerse = audioVerses.first {
                    let startTime = CMTime(seconds: firstVerse.begin, preferredTimescale: 600)
                    await previewPlayer?.seek(to: startTime, toleranceBefore: .zero, toleranceAfter: .zero)
                }
                
                if audioVerses.count >= 3 {
                    let thirdVerseEndTime = CMTime(seconds: audioVerses[2].end, preferredTimescale: 600)
                    previewTimeObserver = previewPlayer?.addBoundaryTimeObserver(
                        forTimes: [NSValue(time: thirdVerseEndTime)],
                        queue: .main
                    ) {
                        self.stopVoicePreview()
                    }
                }
                
                previewPlayer?.play()
                
            } catch {
                inlineErrorMessage = "error.loading.audio".localized
            }
        }
    }
    
    func stopVoicePreview() {
        if let observer = previewTimeObserver {
            previewPlayer?.removeTimeObserver(observer)
            previewTimeObserver = nil
        }
        previewPlayer?.pause()
        previewPlayer = nil
        previewVoiceIndex = nil
        previewTimer?.cancel()
        previewTimer = nil
    }

    private func showInlineError(for error: Error) {
        print("[PageMultilingualConfigView] Operation failed: \(error)")
        let rawErrorText = "\(error)"
        if let statusCode = extractHTTPStatusCode(from: rawErrorText) {
            inlineErrorMessage = "error.loading.setup.with_code".localized(statusCode)
            return
        }

        let nsError = error as NSError
        if nsError.domain == "getExcerptTextualVersesOnline", nsError.code == 422 {
            let detail = compactErrorText(nsError.localizedDescription)
            if !detail.isEmpty {
                inlineErrorMessage = detail
                return
            }
        }

        #if DEBUG
        inlineErrorMessage = "\("error.loading.setup".localized)\n\(compactErrorText(rawErrorText, maxLength: 300))"
        #else
        inlineErrorMessage = "error.loading.setup".localized
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
}
