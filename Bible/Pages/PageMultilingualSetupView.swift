import UniformTypeIdentifiers
import SwiftUI

struct PageMultilingualSetupView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var editingStepIndex: Int? = nil
    @State private var stepToEdit: MultilingualStep? = nil
    

    @State private var showTemplatesSheet: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var templateName: String = ""
    @State private var inlineErrorMessage: String = ""
    
    // MARK: Hint Logic State
    @State private var idleTimer: Timer? = nil
    @State private var showReadHint: Bool = false
    @State private var showPauseHint: Bool = false
    
    var currentSubtitle: String {
        if let id = settingsManager.currentTemplateId,
           let template = settingsManager.multilingualTemplates.first(where: { $0.id == id }) {
            
            let isDirty = settingsManager.multilingualSteps != template.steps ||
                          settingsManager.multilingualReadUnit != template.unit
            
            return isDirty ? "\(template.name)*" : template.name
        }
        return "multilingual.subtitle".localized
    }
    
    var body: some View {
        ZStack {
            // Background
            Color("DarkGreen")
                .edgesIgnoringSafeArea(.all)
                .accessibilityIdentifier("page-multi-setup")

            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    MenuButtonView()
                        .environmentObject(settingsManager)
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("multilingual.title".localized) // Localized
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(currentSubtitle)
                            .font(.caption)
                            .foregroundColor(Color("Mustard"))
                    }
                    
                    Spacer()
                    
                    Button {
                        showTemplatesSheet = true
                    } label: {
                        Image(systemName: "books.vertical.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .accessibilityIdentifier("multi-templates-button")
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.top, 10)
                .padding(.bottom, 20)
                
                // MARK: Read By Picker
                HStack {
                    Text("multilingual.read_by".localized) // Localized
                        .foregroundColor(.white)
                    
                    Menu {
                        Picker("multilingual.read_by".localized, selection: $settingsManager.multilingualReadUnitRaw) {
                            ForEach(MultilingualReadUnit.allCases, id: \.self) { unit in
                                Text(unit.localized).tag(unit.rawValue)
                            }
                        }
                    } label: {
                        HStack {
                            Text(settingsManager.multilingualReadUnit.localized)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .accessibilityIdentifier("multi-read-unit-picker")
                .padding(.horizontal, globalBasePadding)
                .padding(.bottom, 20) // Extra spacing

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
                    .accessibilityIdentifier("multi-error-message")
                    .padding(.horizontal, globalBasePadding)
                    .padding(.bottom, 8)
                }
                
                // MARK: Steps List
                if settingsManager.multilingualSteps.isEmpty {
                    emptyStateView()
                } else {
                    List {
                        ForEach(Array(settingsManager.multilingualSteps.enumerated()), id: \.element.id) { index, step in
                            stepRow(index: index, step: step)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 5, leading: globalBasePadding, bottom: 5, trailing: 16))
                        }
                        .onMove(perform: moveSteps)
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, .constant(.active))
                    .scrollContentBackground(.hidden)
                    .environment(\.colorScheme, .dark)
                }
                
                // MARK: Action Buttons
                HStack(spacing: 15) {
                    // Add Read Step using styled button
                    Button {
                        addNewReadStep()
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                            Text("multilingual.add_read_step".localized)
                        }
                        .font(.subheadline)
                        .foregroundColor(Color("Mustard"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("Mustard").opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                        .background(Color("DarkGreen").brightness(0.05).cornerRadius(10))
                        .overlay(HintOverlay(isActive: $showReadHint, color: Color("Mustard")))
                    }
                    .accessibilityIdentifier("multi-add-read-step")
                    
                    // Add Pause Step
                    Button {
                        addNewPauseStep()
                    } label: {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("multilingual.add_pause_step".localized)
                        }
                        .font(.subheadline)
                        .foregroundColor(Color("Mustard"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color("Mustard").opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                        .background(Color("DarkGreen").brightness(0.05).cornerRadius(10))
                        .overlay(HintOverlay(isActive: $showPauseHint, color: Color("Mustard")))
                    }
                    .accessibilityIdentifier("multi-add-pause-step")
                }
                .padding(.horizontal, globalBasePadding)
                .padding(.vertical, 10)
                
                // MARK: Save & Read Button
                Button {
                    handleSaveAndRead()
                } label: {
                    Text("multilingual.save_and_read".localized)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("Marigold"))
                        .cornerRadius(12)
                }
                .accessibilityIdentifier("multilingual-save-and-read")
                .padding(.horizontal, globalBasePadding)
                .padding(.bottom, 5)
                .padding(.top, 10)
            }
            .blur(radius: showSaveAlert ? 3 : 0)
            
            
            // Custom Save Alert Overlay
            if showSaveAlert {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Optional: dismiss on tap outside? Better not to avoid accidents.
                    }
                
                VStack(spacing: 20) {
                    Text("multilingual.save_alert.title".localized)
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("multilingual.save_alert.message".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    TextField("multilingual.save_alert.placeholder".localized, text: $templateName)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .foregroundColor(.black)

                    HStack(spacing: 12) {
                        Button {
                            showSaveAlert = false
                            proceedToRead()
                        } label: {
                            Text("multilingual.save_alert.dont_save".localized)
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .accessibilityIdentifier("multi-save-alert-skip")

                        Button {
                            saveNewTemplate()
                            showSaveAlert = false
                            proceedToRead()
                        } label: {
                            Text("multilingual.save_alert.save".localized)
                                .font(.footnote)
                                .fontWeight(.bold)
                                .foregroundColor(Color("Mustard"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .accessibilityIdentifier("multi-save-alert-save")
                        .disabled(templateName.isEmpty)
                    }
                }
                .accessibilityIdentifier("multi-save-alert")
                .padding(25)
                .background(Color("DarkGreen").brightness(0.1))
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
        }
        .sheet(item: $stepToEdit) { step in
            let isAdding = !settingsManager.multilingualSteps.contains(where: { $0.id == step.id })
            PageMultilingualConfigView(step: step, isAddingStep: isAdding) { newStep in
                if let index = settingsManager.multilingualSteps.firstIndex(where: { $0.id == newStep.id }) {
                    settingsManager.multilingualSteps[index] = newStep
                } else {
                    settingsManager.multilingualSteps.append(newStep)

                    // Hint Logic: If we just added the first step, prompt for Pause
                    if settingsManager.multilingualSteps.count == 1 {
                        withAnimation { self.showPauseHint = true }
                    }
                }
                settingsManager.saveMultilingualSteps()
                stepToEdit = nil
            }
            .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showTemplatesSheet) {
            PageMultilingualTemplatesView()
                .environmentObject(settingsManager)
        }
        .onAppear {
            settingsManager.isMultilingualReadingActive = false
            startIdleTimer()
        }
        .onDisappear {
            stopIdleTimer()
        }
    }
    
    // MARK: Drop Delegate Removed - using native List EditMode

    
    // MARK: Empty State
    @ViewBuilder
    func emptyStateView() -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text("multilingual.empty.title".localized)
                .font(.headline)
                .foregroundColor(.white)

            Text("multilingual.empty.description".localized)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                let lines = "multilingual.empty.example".localized.components(separatedBy: "\n")
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    HStack(spacing: 8) {
                        if line.lowercased().contains("paus") || line.lowercased().contains("ауз") {
                            Image(systemName: "hourglass")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 16)
                        } else {
                            Image(systemName: "book.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .frame(width: 16)
                        }
                        Text(line)
                            .font(.callout)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)

            Text("multilingual.empty.hint".localized)
                .font(.subheadline)
                .foregroundColor(Color("Mustard"))
                .multilineTextAlignment(.center)

            Spacer()
            Spacer()

        }
        .padding(.horizontal, globalBasePadding)
    }

    // MARK: Rows
    @ViewBuilder
    func stepRow(index: Int, step: MultilingualStep) -> some View {
        HStack(spacing: 12) {
            
            // Icon
            if step.type == .read {
                Image(systemName: "book.fill")
                    .foregroundColor(Color("Mustard"))
                    .font(.title2)
                    .frame(width: 30)
            } else {
                Image(systemName: "hourglass")
                    .foregroundColor(Color("Mustard"))
                    .font(.title2)
                    .frame(width: 30)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                if step.type == .read {
                    Text(step.translationName.isEmpty ? "multilingual.select_translation".localized : step.translationName)
                        .font(.headline)
                        .foregroundColor(.white)

                    let languageTitle = step.languageNameNationalOnly.isEmpty ? step.languageCode : step.languageNameNationalOnly
                    Text("\(languageTitle) \(step.voiceName.isEmpty ? "" : "• " + step.voiceName)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                } else {
                    Text("multilingual.pause".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("\(String(format: "%0.0f", step.pauseDuration)) " + "multilingual.seconds".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Controls
            if step.type == .pause {
                HStack(spacing: 0) {
                    Button {
                        if settingsManager.multilingualSteps[index].pauseDuration > 1 {
                            settingsManager.multilingualSteps[index].pauseDuration -= 1
                        }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("multi-pause-minus-\(index)")

                    Divider().frame(height: 20).background(Color.white.opacity(0.3))

                    Button {
                        settingsManager.multilingualSteps[index].pauseDuration += 1
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("multi-pause-plus-\(index)")
                }
                .background(Color.white.opacity(0.1))
                .cornerRadius(5)
                .foregroundColor(.white)
            }
            
            // Edit / Drag / Delete
            // Native reorder handle will appear automatically in EditMode on the right.
            
            Button {
                withAnimation {
                    deleteStep(at: index)
                }
            } label: {
                Image(systemName: "xmark")
                    .foregroundColor(.red.opacity(0.7))
            }
            .accessibilityIdentifier("multi-step-delete-\(index)")
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color("DarkGreen").brightness(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .accessibilityIdentifier("multi-step-row-\(index)")
        .contentShape(Rectangle())
        .onTapGesture {
            if step.type == .read {
                editReadStep(index: index)
            }
        }
    }
    
    // MARK: Logic
    func addNewReadStep() {
        inlineErrorMessage = ""
        var newStep = MultilingualStep(type: .read)
        newStep.id = UUID() // Ensure unique ID for fresh sheet
        
        // Only pre-fill defaults if this is the FIRST read step
        let existingReadSteps = settingsManager.multilingualSteps.filter { $0.type == .read }
        if existingReadSteps.isEmpty {
            newStep.languageCode = settingsManager.language
            newStep.translationCode = settingsManager.translation
            newStep.translationName = settingsManager.translationName
            newStep.voiceCode = settingsManager.voice
            newStep.voiceName = settingsManager.voiceName
            newStep.voiceMusic = settingsManager.voiceMusic
            newStep.fontIncreasePercent = settingsManager.fontIncreasePercent
        }
        
        editingStepIndex = nil
        stepToEdit = newStep
        
        // Hint Logic: Read button clicked
        stopIdleTimer()
        showReadHint = false
    }
    
    func editReadStep(index: Int) {
        inlineErrorMessage = ""
        editingStepIndex = index
        stepToEdit = settingsManager.multilingualSteps[index]
    }
    
    func addNewPauseStep() {
        inlineErrorMessage = ""
        let step = MultilingualStep(type: .pause, pauseDuration: 2.0)
        withAnimation {
            settingsManager.multilingualSteps.append(step)
        }
        settingsManager.saveMultilingualSteps()
        
        // Hint Logic: Pause added -> Done
        stopIdleTimer()
        withAnimation {
            showReadHint = false
            showPauseHint = false
        }
        settingsManager.isFirstMultilingualSetup = false
    }
    
    func deleteSteps(at offsets: IndexSet) {
        settingsManager.multilingualSteps.remove(atOffsets: offsets)
        settingsManager.saveMultilingualSteps()
    }
    
    func deleteStep(at index: Int) {
        settingsManager.multilingualSteps.remove(at: index)
        settingsManager.saveMultilingualSteps()
    }
    
    func moveSteps(from source: IndexSet, to destination: Int) {
        settingsManager.multilingualSteps.move(fromOffsets: source, toOffset: destination)
        settingsManager.saveMultilingualSteps()
    }
    
    // MARK: Template Logic
    func handleSaveAndRead() {
        if settingsManager.multilingualSteps.isEmpty {
            inlineErrorMessage = "multilingual.error.no_steps".localized
            return
        }
        inlineErrorMessage = ""
        
        if settingsManager.currentTemplateId != nil {
            // Update existing
            updateCurrentTemplate()
            proceedToRead()
        } else {
            // New template
            templateName = settingsManager.multilingualSteps.multilingualCompactDescription()
            showSaveAlert = true
        }
    }
    
    func saveNewTemplate() {
        let newTemplate = MultilingualTemplate(name: templateName, steps: settingsManager.multilingualSteps, unit: settingsManager.multilingualReadUnit)
        settingsManager.multilingualTemplates.append(newTemplate)
        settingsManager.currentTemplateId = newTemplate.id
        settingsManager.saveMultilingualTemplates()
    }
    
    func updateCurrentTemplate() {
        if let index = settingsManager.multilingualTemplates.firstIndex(where: { $0.id == settingsManager.currentTemplateId }) {
            settingsManager.multilingualTemplates[index].steps = settingsManager.multilingualSteps
            settingsManager.multilingualTemplates[index].unit = settingsManager.multilingualReadUnit
            settingsManager.saveMultilingualTemplates()
        }
    }
    
    func proceedToRead() {
        settingsManager.saveMultilingualSteps()
        settingsManager.selectedMenuItem = .multilingualRead
        settingsManager.showMenu = false
    }
    
    // MARK: Hint Helpers
    func startIdleTimer() {
        // Allow hints if steps are empty, regardless of first time flag (good for retrying/demo)
        guard settingsManager.multilingualSteps.isEmpty else { return }
         stopIdleTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in // Reduced to 3s for quicker feedback
            withAnimation {
                showReadHint = true
            }
        }
    }
    
    func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
}

struct HintOverlay: View {
    @Binding var isActive: Bool
    var color: Color = .yellow
    
    @State private var isHigh: Bool = false
    
    var body: some View {
        if isActive {
            ZStack {
                // Pulsing Border
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: 2)
                    .opacity(isHigh ? 1.0 : 0.0)
            }
            .allowsHitTesting(false)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    isHigh = true
                }
            }
        }
    }
}
