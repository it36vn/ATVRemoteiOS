import SwiftUI

private func tr(_ key: String) -> String {
    L10n.tr(key)
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        TabView {
            HomeTabView()
                .tabItem { Label(tr("tab.home"), systemImage: "house.fill") }

            RecentsTabView()
                .tabItem { Label(tr("tab.recents"), systemImage: "clock.fill") }

            FavoritesTabView()
                .tabItem { Label(tr("tab.favorites"), systemImage: "star.fill") }

            SettingsTabView()
                .tabItem { Label(tr("tab.settings"), systemImage: "gearshape.fill") }
        }
        .environmentObject(viewModel)
        .environment(\.locale, Locale(identifier: viewModel.englishEnabled ? "en" : "vi"))
        .onAppear { viewModel.onLaunch() }
        .tint(Color(red: 0.05, green: 0.62, blue: 0.93))
        .fullScreenCover(isPresented: $viewModel.showGuideOnLaunch) {
            UserGuideView(
                showsLocalNetworkPermissionWarning: viewModel.shouldShowLocalNetworkPermissionPrompt,
                onAppear: { viewModel.requestLocalNetworkPermissionForGuide() }
            ) {
                viewModel.markGuideSeen()
            }
        }
        .fullScreenCover(item: $viewModel.autoConnectedDevice) { device in
            NavigationStack {
                RemoteControlView(device: device, showsBackToHomeButton: true, onBackToHome: {
                    viewModel.clearAutoConnectDestination()
                })
                .environmentObject(viewModel)
            }
            .environmentObject(viewModel)
        }
        .sheet(isPresented: $viewModel.showGuideFromSettings) {
            UserGuideView(
                showsLocalNetworkPermissionWarning: viewModel.shouldShowLocalNetworkPermissionPrompt,
                onAppear: { viewModel.requestLocalNetworkPermissionForGuide() }
            ) {
                viewModel.closeGuideFromSettings()
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct UserGuideView: View {
    var showsLocalNetworkPermissionWarning = false
    var onAppear: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        guideHeader
                        if showsLocalNetworkPermissionWarning {
                            guideCard(
                                icon: "network.badge.shield.half.filled",
                                title: tr("guide.card.local_network_permission.title"),
                                description: tr("guide.card.local_network_permission.desc")
                            )
                        }
                        guideCard(
                            icon: "wifi",
                            title: tr("guide.card.network.title"),
                            description: tr("guide.card.network.desc")
                        )
                        guideCard(
                            icon: "dot.radiowaves.left.and.right",
                            title: tr("guide.card.scan.title"),
                            description: tr("guide.card.scan.desc")
                        )
                        guideCard(
                            icon: "tv",
                            title: tr("guide.card.connect.title"),
                            description: tr("guide.card.connect.desc")
                        )
                        guideCard(
                            icon: "clock.arrow.circlepath",
                            title: tr("guide.card.auto.title"),
                            description: tr("guide.card.auto.desc")
                        )
                    }
                    .padding()
                }
            }
            .onAppear {
                onAppear?()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onClose?()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
        }
    }

    private var guideHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("guide.title"))
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(tr("guide.subtitle"))
                .foregroundStyle(.white.opacity(0.9))
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 18))
    }

    private func guideCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 42, height: 42)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
