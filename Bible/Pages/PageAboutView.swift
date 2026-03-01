import SwiftUI

struct PageAboutView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @ObservedObject private var localizationManager = LocalizationManager.shared
    @Binding var showFromRead: Bool

    @State private var aboutData: Components.Schemas.AboutModel? = nil

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
                                .font(.title.weight(.light))
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

                        if let data = aboutData {
                            ForEach(data.contacts.sorted(by: { $0.sort_order < $1.sort_order }), id: \.id) { contact in
                                contactButton(
                                    icon: contact.icon,
                                    label: localizedText(contact.label),
                                    subtitle: localizedText(contact.subtitle),
                                    urlString: contact.url,
                                    accessibilityId: "contacts-\(contact.id)"
                                )
                            }
                        } else {
                            contactButton(
                                icon: "paperplane.fill",
                                label: "contacts.telegram".localized,
                                subtitle: "@Mandarinka4",
                                urlString: "https://t.me/Mandarinka4",
                                accessibilityId: "contacts-telegram"
                            )

                            contactButton(
                                icon: "globe",
                                label: "contacts.website".localized,
                                subtitle: "bibleapi.space",
                                urlString: "https://bibleapi.space",
                                accessibilityId: "contacts-website"
                            )
                        }

                        viewGroupHeader(text: "contacts.about".localized)

                        Text(aboutData != nil ? localizedText(aboutData!.about_text) : "contacts.about.text".localized)
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
                    .accessibilityIdentifier("page-about")
            )

        }
        .onAppear {
            fetchAboutData()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func contactButton(icon: String, label: String, subtitle: String, urlString: String, accessibilityId: String) -> some View {
        Button {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .foregroundColor(.white)
                    Text(subtitle)
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
        .accessibilityIdentifier(accessibilityId)
    }

    private func localizedText(_ text: Components.Schemas.LocalizedText) -> String {
        switch localizationManager.currentLanguage {
        case .russian:  return text.ru
        case .english:  return text.en
        case .ukrainian: return text.uk
        }
    }

    private func fetchAboutData() {
        guard aboutData == nil else { return }
        Task {
            do {
                let response = try await settingsManager.client.getAbout()
                let data = try response.ok.body.json
                await MainActor.run { self.aboutData = data }
            } catch {
                // Silently fallback to hardcoded content
            }
        }
    }
}

struct TestPageAboutView: View {
    @State private var showFromRead: Bool = false

    var body: some View {
        PageAboutView(showFromRead: $showFromRead)
            .environmentObject(SettingsManager())
    }
}

#Preview {
    TestPageAboutView()
}
