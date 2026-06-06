import SwiftUI

enum TVDetailSource {
    case home
    case recents
    case favorites
}

struct TVDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    let device: TVDevice
    let source: TVDetailSource

    @State private var openRemote: Bool = false
    @State private var showConnectFailedPopup: Bool = false
    @State private var pairingCode: String = ""
    @State private var showPairingPrompt: Bool = false

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            Form {
                Section(L10n.tr("tv.info")) {
                    infoRow(L10n.tr("tv.name"), device.displayName)
                    infoRow(L10n.tr("tv.ip"), device.ipAddress)
                    infoRow(L10n.tr("tv.mac"), device.macAddress)
                    infoRow(L10n.tr("tv.version"), device.version)
                }

                Section(L10n.tr("tv.actions")) {
                    Button(L10n.tr("home.connect")) {
                        handleConnectTap()
                    }

                    Button(viewModel.isFavorite(device) ? L10n.tr("tv.remove_favorite") : L10n.tr("tv.add_favorite")) {
                        viewModel.toggleFavorite(device: device)
                    }

                    if source == .recents {
                        Button(L10n.tr("tv.remove_recents"), role: .destructive) {
                            viewModel.removeFromRecents(device)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .foregroundStyle(AppTheme.textPrimary)
        }
        .navigationTitle(device.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $openRemote) {
            RemoteControlView(device: device, autoPairOnAppear: true)
                .environmentObject(viewModel)
        }
        .alert(L10n.tr("remote.connect_failed.title"), isPresented: $showConnectFailedPopup) {
            Button(L10n.tr("guide.close"), role: .cancel) {}
            Button(L10n.tr("remote.connect_failed.open_guide")) {
                viewModel.openGuideFromSettings()
            }
        } message: {
            Text(L10n.tr("remote.connect_failed.message"))
        }
        .alert(L10n.tr("remote.pairing.title"), isPresented: $showPairingPrompt) {
            TextField(L10n.tr("remote.pairing.pin_placeholder"), text: $pairingCode)
                .textInputAutocapitalization(.characters)
            Button(L10n.tr("remote.pairing.confirm")) {
                submitPairingCode()
            }
            Button(L10n.tr("guide.close"), role: .cancel) {
                pairingCode = ""
            }
        } message: {
            Text(L10n.tr("remote.pairing.message"))
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func handleConnectTap() {
        Task { @MainActor in
            let result = await viewModel.prepareTVConnection(device)
            switch result {
            case .success:
                openRemote = true
            case .androidTVPairingRequired, .pairingInProgress:
                await startPairing()
            case .unreachable, .failure:
                showConnectFailedPopup = true
            }
        }
    }

    private func startPairing() async {
        pairingCode = ""
        let waiting = await viewModel.startTVPairing(device)
        if waiting {
            showPairingPrompt = true
        } else {
            showConnectFailedPopup = true
        }
    }

    private func submitPairingCode() {
        Task { @MainActor in
            let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return }

            let result = await viewModel.submitTVPairingCode(code, for: device)
            pairingCode = ""

            switch result {
            case .success:
                showPairingPrompt = false
                openRemote = true
            default:
                showPairingPrompt = false
                showConnectFailedPopup = true
            }
        }
    }
}
