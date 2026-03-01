import UniformTypeIdentifiers
import SwiftUI

struct PageMultilingualView: View {
    
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var editingStepIndex: Int? = nil
    @State private var showConfigSheet: Bool = false
    @State private var tempStep: MultilingualStep = MultilingualStep(type: .read)
    

    @State private var showTemplatesSheet: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var templateName: String = ""
    @State private var inlineErrorMessage: String = ""
    
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
                    .padding(.horizontal, globalBasePadding)
                    .padding(.bottom, 8)
                }
                
                // MARK: Steps List
                // MARK: Steps List
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
                .hideScrollContentBackground()
                .environment(\.colorScheme, .dark) // Force dark mode controls for visibility 
                
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
                    }
                    
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
                    }
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
                        .background(Color("Mustard"))
                        .cornerRadius(12)
                }
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
                        .disabled(templateName.isEmpty)
                    }
                }
                .padding(25)
                .background(Color("DarkGreen").brightness(0.1))
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
        }
        .sheet(isPresented: $showConfigSheet) {
            PageMultilingualConfigView(step: tempStep, isAddingStep: editingStepIndex == nil) { newStep in
                if let index = editingStepIndex {
                    settingsManager.multilingualSteps[index] = newStep
                } else {
                    settingsManager.multilingualSteps.append(newStep)
                }
                // When we modify steps, it might still technically be the "active" template,
                // BUT if we modify it, should we keep the currentTemplateId?
                // Visual Studio Code behavior: yes, but it becomes "dirty".
                // Here: we will keep it linked. Next Save will update it.
                settingsManager.saveMultilingualSteps()
            }
            .environmentObject(settingsManager)
        }
        .sheet(isPresented: $showTemplatesSheet) {
            PageMultilingualTemplatesView()
                .environmentObject(settingsManager)
        }
        .onAppear {
            settingsManager.isMultilingualReadingActive = false
        }
    }
    
    // MARK: Drop Delegate Removed - using native List EditMode

    
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
                    
                    Divider().frame(height: 20).background(Color.white.opacity(0.3))
                    
                    Button {
                        settingsManager.multilingualSteps[index].pauseDuration += 1
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
                }
                .background(Color.white.opacity(0.1))
                .cornerRadius(5)
                .buttonStyle(PlainButtonStyle())
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
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color("DarkGreen").brightness(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
        tempStep = MultilingualStep(type: .read)
        // Set defaults from current settings if needed
        editingStepIndex = nil
        showConfigSheet = true
    }
    
    func editReadStep(index: Int) {
        inlineErrorMessage = ""
        tempStep = settingsManager.multilingualSteps[index]
        editingStepIndex = index
        showConfigSheet = true
    }
    
    func addNewPauseStep() {
        inlineErrorMessage = ""
        let step = MultilingualStep(type: .pause, pauseDuration: 2.0)
        withAnimation {
            settingsManager.multilingualSteps.append(step)
        }
        settingsManager.saveMultilingualSteps()
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
}
