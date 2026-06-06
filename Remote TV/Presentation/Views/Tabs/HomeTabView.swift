import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var connectDevice: TVDevice?
    @State private var openRemote = false
    @State private var showConnectFailedPopup = false
    @State private var pairingDevice: TVDevice?
    @State private var pairingCode = ""
    @State private var showPairingPrompt = false
    @State private var showLocalNetworkPermissionPopup = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 14) {
                    headerView

                    if viewModel.shouldShowLocalNetworkPermissionPrompt {
                        Spacer(minLength: 0)
                        LocalNetworkPermissionEmptyView {
                            openLocalNetworkSettingsFromHome()
                        }
                        Spacer(minLength: 0)
                    } else {
                        ScrollView {
                            VStack(spacing: 14) {
                                if viewModel.isScanningDevices {
                                    ForEach(0..<4, id: \.self) { _ in
                                        TVCardSkeletonView()
                                    }
                                } else {
                                    ForEach(viewModel.activeDevices) { device in
                                        NavigationLink(destination: TVDetailView(device: device, source: .home)) {
                                            TVCardView(
                                                device: device,
                                                hasRecent: viewModel.hasRecent(device),
                                                isFavorite: viewModel.isFavorite(device),
                                                onConnect: {
                                                    handleConnectTap(device)
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L10n.tr("home.title"))
            .navigationDestination(isPresented: $openRemote) {
                if let connectDevice {
                    RemoteControlView(device: connectDevice, autoPairOnAppear: true)
                        .environmentObject(viewModel)
                }
            }
            .onAppear {
                Task { await viewModel.scanActiveTVs(retryAfterLocalNetworkPrompt: true) }
            }
//            .toolbar {
//                ToolbarItem(placement: .topBarTrailing) {
//                    Button {
//                        Task { await viewModel.scanActiveTVs() }
//                    } label: {
//                        Image(systemName: "arrow.clockwise")
//                            .foregroundStyle(.white)
//                    }
//                    .accessibilityLabel(L10n.tr("home.refresh"))
//                }
//            }
            .alert(L10n.tr("remote.connect_failed.title"), isPresented: $showConnectFailedPopup) {
                Button(L10n.tr("guide.close"), role: .cancel) {}
                Button(L10n.tr("remote.connect_failed.open_guide")) {
                    viewModel.openGuideFromSettings()
                }
            } message: {
                Text(L10n.tr("remote.connect_failed.message"))
            }
            .alert(L10n.tr("local_network_permission.title"), isPresented: $showLocalNetworkPermissionPopup) {
                Button(L10n.tr("common.cancel"), role: .cancel) {}
                Button(L10n.tr("common.continue")) {
                    openLocalNetworkSettingsFromHome()
                }
            } message: {
                Text(L10n.tr("local_network_permission.message"))
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

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("home.active_tvs"))
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(L10n.tr("home.scan_local"))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !viewModel.isScanningDevices, !viewModel.shouldShowLocalNetworkPermissionPrompt {
                Button(action: {
                    handleRefreshTap()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 50, height: 50)
                }
                .buttonStyle(LuxeIconButtonStyle())
                .accessibilityLabel(L10n.tr("home.refresh"))
            }
            
        }
    }

    private func openLocalNetworkSettingsFromHome() {
        showLocalNetworkPermissionPopup = false
        viewModel.openLocalNetworkSettings()
    }

    private func handleRefreshTap() {
        if viewModel.shouldShowLocalNetworkPermissionPrompt {
            showLocalNetworkPermissionPopup = true
            return
        }

        Task { @MainActor in
            await viewModel.scanActiveTVs()
            if viewModel.shouldShowLocalNetworkPermissionPrompt {
                showLocalNetworkPermissionPopup = true
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
