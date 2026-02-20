import SwiftUI

struct PageContactsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Binding var showFromRead: Bool
    
    init(showFromRead: Binding<Bool> = .constant(false)) {
        self._showFromRead = showFromRead
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    if showFromRead {
                        Button {
                            showFromRead = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title)
                                .fontWeight(.light)
                        }
                        .foregroundColor(Color.white.opacity(0.5))
                    }
                    else {
                        MenuButtonView()
                            .environmentObject(settingsManager)
                    }
                    Spacer()
                    
                    Text("page.contacts.title".localized)
                        .fontWeight(.bold)
                        .padding(.trailing, 32) // compensate menu so title stays centered
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, globalBasePadding)
                
                ScrollView {
                    VStack(spacing: 20) {
                        viewGroupHeader(text: "contacts.contact_us".localized)
                        
                        Button {
                            if let url = URL(string: "https://t.me/Mandarinka4") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                    .foregroundColor(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("contacts.telegram".localized)
                                        .foregroundColor(.white)
                                    Text("@Mandarinka4")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("DarkGreen-light").opacity(0.6))
                            .cornerRadius(8)
                        }
                        .accessibilityIdentifier("contacts-telegram")
                        
                        Button {
                            if let url = URL(string: "https://bibleapi.space") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundColor(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("contacts.website".localized)
                                        .foregroundColor(.white)
                                    Text("bibleapi.space")
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.65))
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color("DarkGreen-light").opacity(0.6))
                            .cornerRadius(8)
                        }
                        .accessibilityIdentifier("contacts-website")
                        
                        viewGroupHeader(text: "contacts.about".localized)
                        
                        Text("contacts.about.text".localized)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, globalBasePadding)
                    .padding(.vertical, 10)
                }
            }
            
            // Background layer
            .background(
                Color("DarkGreen")
            )
            
        }
    }
}

struct TestPageContactsView: View {
    @State private var showFromRead: Bool = false
    
    var body: some View {
        PageContactsView(showFromRead: $showFromRead)
            .environmentObject(SettingsManager())
    }
}

#Preview {
    TestPageContactsView()
}
