import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    private let config = AppConfig.current

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                SwiftUI.Form {

                Section(L10n.tr("settings.section.options")) {
                    Toggle(L10n.tr("settings.link_drive"), isOn: Binding(
                        get: { viewModel.isGoogleDriveLinked },
                        set: { viewModel.setGoogleDriveLinked($0) }
                    ))

                    Toggle(L10n.tr("settings.notifications"), isOn: Binding(
                        get: { viewModel.notificationsEnabled },
                        set: { viewModel.setNotificationsEnabled($0) }
                    ))
                    
                    
                    Picker(
                        L10n.tr("settings.language_title"),
                        selection: Binding<Bool>(
                            get: {
                                viewModel.englishEnabled ? true : false
                            },
                            set: { language in
                                viewModel.setEnglishEnabled(language)
                            }
                        )
                    ) {
                        Text(L10n.tr("remote.language.vi")).tag(false)
                        Text(L10n.tr("remote.language.en")).tag(true)
                    }
                    .pickerStyle(.menu)

                    Button(L10n.tr("settings.guide")) {
                        viewModel.openGuideFromSettings()
                    }

                    if viewModel.isSyncing {
                        HStack {
                            ProgressView()
                            Text(L10n.tr("settings.syncing"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(L10n.tr("settings.section.dev")) {
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: viewModel.settingsDeveloperLogo)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()

                            case .failure(_):
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.green)

                            case .empty:
                                ProgressView()

                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(viewModel.settingsDeveloperName).font(.headline)
                            Text(viewModel.settingsDeveloperDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let websiteURL = URL(string: viewModel.settingsDeveloperWebsite) {
                        Link(String(format:L10n.tr("settings.website"), viewModel.settingsDeveloperWebsite.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")), destination: websiteURL)
                    }
                    if let phoneURL = URL(string: "tel://\(viewModel.settingsDeveloperPhone)") {
                        Link(String(format: L10n.tr("settings.phone"), viewModel.settingsDeveloperPhone), destination: phoneURL)
                    }
                    if let emailURL = URL(string: "mailto:\(viewModel.settingsDeveloperEmail)") {
                        Link(String(format: L10n.tr("settings.email"), viewModel.settingsDeveloperEmail), destination: emailURL)
                    }
                }
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "tv.music.note")
                                .font(.largeTitle)
                                .foregroundStyle(AppTheme.iconPrimary)
                            VStack(alignment: .leading) {
                                Text(viewModel.settingsAppName).font(.headline)
                                Text(String(format: L10n.tr("settings.version"), viewModel.settingsAppVersion, config.build))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .foregroundStyle(AppTheme.textPrimary)
            }
            .navigationTitle(L10n.tr("tab.head.settings"))
            .task {
                await viewModel.refreshNotificationPermissionStatus()
            }
        }
    }

    private func configRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
