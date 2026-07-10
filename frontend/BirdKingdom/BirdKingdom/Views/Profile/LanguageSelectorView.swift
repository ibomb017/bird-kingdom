import SwiftUI

struct LanguageSelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var langManager = LanguageManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section(footer: Text(L10n.languageChangeHint)) {
                    ForEach(AppLanguage.allCases, id: \.self) { lang in
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            langManager.current = lang
                            BirdVoiceRecognitionService.shared.reloadLabels()
                        } label: {
                            HStack {
                                Text(lang.icon)
                                    .font(.title3)
                                Text(lang.displayName)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if langManager.current == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeManager.primaryColor)
                                        .fontWeight(.bold)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.selectLanguage)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.done) {
                        dismiss()
                    }
                    .foregroundColor(themeManager.primaryColor)
                    .fontWeight(.medium)
                }
            }
        }
    }
}

#Preview {
    LanguageSelectorView()
        .environmentObject(ThemeManager.shared)
}
