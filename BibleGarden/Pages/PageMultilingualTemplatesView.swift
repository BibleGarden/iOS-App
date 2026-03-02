import SwiftUI

struct PageMultilingualTemplatesView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var renamingTemplateId: UUID? = nil
    @State private var newName: String = ""
    
    var body: some View {
        ZStack {
            Color("DarkGreen")
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    
                    Text("multilingual.library.title".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .background(Color("DarkGreen").brightness(0.05))
                
                // List
                if settingsManager.multilingualTemplates.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.2))
                        Text("multilingual.library.empty".localized)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(settingsManager.multilingualTemplates) { template in
                            Button {
                                loadTemplate(template)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(template.name)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        if settingsManager.currentTemplateId == template.id {
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(Color("Mustard"))
                                        }
                                    }
                                    
                                    // Composition preview
                                    Text(compositionDescription(for: template))
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 5)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(.white.opacity(0.1))
                            .swipeActions(edge: .leading) {
                                Button {
                                    setupRename(for: template)
                                } label: {
                                    Label("multilingual.rename".localized, systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: settingsManager.deleteTemplate)
                    }
                    .listStyle(.plain)
                }
                
                // Bottom: New Template
                VStack {
                    Divider().background(Color.white.opacity(0.2))
                    Button {
                        clearTemplate()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("multilingual.library.new".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color("Mustard").opacity(0.2))
                        .cornerRadius(10)
                    }
                    .padding()
                }
                .background(Color("DarkGreen"))
            }
            .blur(radius: renamingTemplateId != nil ? 3 : 0)
            
            // Rename Overlay
            if renamingTemplateId != nil {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Optional dismiss? Better explicit cancel.
                    }
                
                VStack(spacing: 20) {
                    Text("multilingual.rename.title".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("multilingual.rename.message".localized)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("multilingual.save_alert.placeholder".localized, text: $newName)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(8)
                        .foregroundColor(.black)
                    
                    HStack {
                        Button("settings.cancel_choice".localized) {
                            renamingTemplateId = nil
                        }
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.vertical, 10)
                        
                        Spacer()
                        
                        Button {
                            performRename()
                        } label: {
                            Text("multilingual.rename.action".localized)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(Color("Mustard"))
                        .disabled(newName.isEmpty)
                        .padding(.vertical, 10)
                    }
                }
                .padding(25)
                .background(Color("DarkGreen").brightness(0.1))
                .cornerRadius(15)
                .shadow(radius: 10)
                .padding(.horizontal, 40)
            }
        }
        .colorScheme(.dark) // Force dark mode for List
    }
    
    func loadTemplate(_ template: MultilingualTemplate) {
        settingsManager.multilingualSteps = template.steps
        settingsManager.multilingualReadUnitRaw = template.unit.rawValue
        settingsManager.currentTemplateId = template.id
        settingsManager.saveMultilingualSteps()
        presentationMode.wrappedValue.dismiss()
    }
    
    func clearTemplate() {
        settingsManager.multilingualSteps = []
        settingsManager.currentTemplateId = nil
        settingsManager.saveMultilingualSteps()
        presentationMode.wrappedValue.dismiss()
    }
    
    func setupRename(for template: MultilingualTemplate) {
        newName = template.name
        withAnimation {
            renamingTemplateId = template.id
        }
    }
    
    func performRename() {
        guard let id = renamingTemplateId else { return }
        
        if let index = settingsManager.multilingualTemplates.firstIndex(where: { $0.id == id }) {
            settingsManager.multilingualTemplates[index].name = newName
            settingsManager.saveMultilingualTemplates()
        }
        
        withAnimation {
            renamingTemplateId = nil
        }
    }
    
    func compositionDescription(for template: MultilingualTemplate) -> String {
        var parts: [String] = []
        for step in template.steps {
            if step.type == .read {
                parts.append(step.translationName)
            } else {
                parts.append("multilingual.pause".localized)
            }
        }
        return parts.joined(separator: " → ")
    }
}
