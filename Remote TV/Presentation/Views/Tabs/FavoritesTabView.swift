import SwiftUI

struct FavoritesTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var connectDevice: TVDevice?
    @State private var openRemote = false
    @State private var showConnectFailedPopup = false
    @State private var pairingDevice: TVDevice?
    @State private var pairingCode = ""
    @State private var showPairingPrompt = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                if viewModel.shouldShowLocalNetworkPermissionPrompt {
                    VStack {
                        Spacer(minLength: 0)
                        LocalNetworkPermissionEmptyView {
                            viewModel.openLocalNetworkSettings()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            if viewModel.favorites.isEmpty {
                                Text(L10n.tr("favorites.empty"))
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
                            } else {
                                ForEach(viewModel.favorites) { device in
                                    NavigationLink(destination: TVDetailView(device: device, source: .favorites)) {
                                        TVCardView(
                                            device: device,
                                            hasRecent: viewModel.hasRecent(device),
                                            isFavorite: true,
                                            onConnect: {
                                                handleConnectTap(device)
                                            }
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(L10n.tr("tab.head.favorites"))
            .navigationDestination(isPresented: $openRemote) {
                if let connectDevice {
                    RemoteControlView(device: connectDevice, autoPairOnAppear: true)
                        .environmentObject(viewModel)
                }
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
                    pairingDevice = nil
                    pairingCode = ""
                }
            } message: {
                Text(L10n.tr("remote.pairing.message"))
            }
        }
    }

    private func handleConnectTap(_ device: TVDevice) {
        Task { @MainActor in
            let result = await viewModel.prepareTVConnection(device)
            switch result {
            case .success:
                openRemote(for: device)
            case .androidTVPairingRequired, .pairingInProgress:
                await startPairing(for: device)
            case .unreachable, .failure:
                showConnectFailedPopup = true
            }
        }
    }

    private func startPairing(for device: TVDevice) async {
        pairingDevice = device
        pairingCode = ""
        let waiting = await viewModel.startTVPairing(device)
        if waiting {
            showPairingPrompt = true
        } else {
            pairingDevice = nil
            showConnectFailedPopup = true
        }
    }

    private func submitPairingCode() {
        Task { @MainActor in
            guard let pairingDevice else { return }
            let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return }

            let result = await viewModel.submitTVPairingCode(code, for: pairingDevice)
            self.pairingDevice = nil
            pairingCode = ""

            switch result {
            case .success:
                showPairingPrompt = false
                openRemote(for: pairingDevice)
            default:
                showPairingPrompt = false
                showConnectFailedPopup = true
            }
        }
    }

    private func openRemote(for device: TVDevice) {
        connectDevice = device
        openRemote = true
    }
}
