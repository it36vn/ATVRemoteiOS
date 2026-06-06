//
//  TVRemoteView.swift
//  Remote TV
//
//  Created by Hung Nguyen on 5/30/26.
//

import SwiftUI

struct RemoteControlView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    let device: TVDevice
    var showsBackToHomeButton: Bool = false
    var onBackToHome: (() -> Void)? = nil
    var autoPairOnAppear: Bool = false
    var onConnectionReady: (() -> Void)? = nil

    @State private var searchKey: String = ""
    @State private var isVoiceSearchActive: Bool = false
    @State private var isVoiceSearchOpening: Bool = false
    @State private var commandStatus: String = ""
    @State private var showPairingPrompt: Bool = false
    @State private var pairingCode: String = ""
    @State private var showConnectionFailedPopup: Bool = false
    @State private var showGuideSheet: Bool = false
    @State private var showInputSelector: Bool = false
    @State private var didPrepareOnAppear: Bool = false
    @State private var didMarkConnected: Bool = false

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {

                    HStack(spacing: 16)  {
                        iconButton("house.fill") { send(.home) }
                        iconButton("arrow.backward") { send(.back) }
                        iconButton("rectangle.portrait.and.arrow.right") { send(.input) }
                    }
                    .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow { Spacer(); iconButton("chevron.up") { send(.up) }; Spacer() }
                        HStack(spacing: 16) {
                            iconButton("chevron.left") { send(.left) }
                            okButton { send(.select) }
                            iconButton("chevron.right") { send(.right) }
                        }
                        GridRow { Spacer(); iconButton("chevron.down") { send(.down) }; Spacer() }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))

                    HStack (spacing: 16) {
                        iconButton("mic.fill", isActive: isVoiceSearchActive || isVoiceSearchOpening) {
                            toggleVoiceSearch()
                        }
                        iconButton("speaker.wave.3.fill") { send(.volumeUp) }
                        iconButton("speaker.wave.1.fill") { send(.volumeDown) }
                    }
                    .padding(EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))


                    if !commandStatus.isEmpty {
                        Text(commandStatus)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
        }
        .contentShape(Rectangle())
        .task {
            guard autoPairOnAppear, !didPrepareOnAppear else { return }
            didPrepareOnAppear = true
            await prepareConnectionOnOpen()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if showsBackToHomeButton {
                    Button(action: {
                        onBackToHome?()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Button(action: {
                    send(.mute)
                }) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.gray.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 50))
                        .overlay(
                            RoundedRectangle(cornerRadius: 50)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PressedScaleStyle())
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {send(.power)}) {
                    Image(systemName: "power")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .alert(L10n.tr("remote.pairing.title"), isPresented: $showPairingPrompt) {
            TextField(L10n.tr("remote.pairing.pin_placeholder"), text: $pairingCode)
                .textInputAutocapitalization(.characters)
            Button(L10n.tr("remote.pairing.confirm")) {
                submitPairingCode()
            }
            Button(L10n.tr("guide.close"), role: .cancel) {}
        } message: {
            Text(L10n.tr("remote.pairing.message"))
        }
        .alert(L10n.tr("remote.connect_failed.title"), isPresented: $showConnectionFailedPopup) {
            Button(L10n.tr("guide.close"), role: .cancel) {}
            Button(L10n.tr("remote.connect_failed.open_guide")) {
                showGuideSheet = true
            }
        } message: {
            Text(L10n.tr("remote.connect_failed.message"))
        }
        .sheet(isPresented: $showGuideSheet) {
            UserGuideView()
        }
        .onDisappear {
            stopVoiceStreamingIfNeeded()
        }
        .onChange(of: viewModel.voiceStreamingDeviceIPs) { _, activeIPs in
            guard !activeIPs.contains(device.ipAddress) else { return }
            resetVoiceSearchState(status: L10n.tr("remote.status.voice_ended"))
        }
    }

    private func send(_ command: TVRemoteCommand) {
        Task { @MainActor in
            let result = await viewModel.sendRemoteCommand(command, to: device)
            switch result {
            case .success:
                commandStatus = L10n.tr("remote.status.command_sent")
                markConnectedIfNeeded()
            case .androidTVPairingRequired:
                let waiting = await viewModel.startTVPairing(device)
                if waiting {
                    commandStatus = L10n.tr("remote.status.waiting_pair_code")
                    showPairingPrompt = true
                } else {
                    commandStatus = L10n.tr("remote.status.pair_start_failed")
                }
            case .unreachable:
                commandStatus = L10n.tr("remote.status.command_failed")
            case .pairingInProgress:
                commandStatus = L10n.tr("remote.status.pairing_in_progress")
            case .failure(let message):
                commandStatus = message
            }
        }
    }

    private func submitPairingCode() {
        Task { @MainActor in
            let code = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty else { return }
            let result = await viewModel.submitTVPairingCode(code, for: device)
            switch result {
            case .success:
                commandStatus = L10n.tr("remote.status.pair_success")
                markConnectedIfNeeded()
            case .failure(let message):
                commandStatus = message
            default:
                commandStatus = L10n.tr("remote.status.pair_failed")
            }
        }
    }

    private func prepareConnectionOnOpen() async {
        let result = await viewModel.prepareTVConnection(device)
        switch result {
        case .success:
            commandStatus = L10n.tr("remote.status.connected")
            markConnectedIfNeeded()
        case .androidTVPairingRequired:
            commandStatus = L10n.tr("remote.status.ready_pair_if_needed")
        case .unreachable:
            commandStatus = L10n.tr("remote.status.connect_failed")
            showConnectionFailedPopup = true
        case .pairingInProgress:
            commandStatus = L10n.tr("remote.status.pairing_in_progress")
        case .failure(let message):
            commandStatus = message
            showConnectionFailedPopup = true
        }
    }

    private func markConnectedIfNeeded() {
        guard !didMarkConnected else { return }
        didMarkConnected = true
        viewModel.connect(device: device)
        onConnectionReady?()
    }

    private func toggleVoiceSearch() {

        if isVoiceSearchActive {
            stopVoiceStreamingIfNeeded()
            return
        }

        guard !isVoiceSearchOpening else { return }
        isVoiceSearchOpening = true
        commandStatus = L10n.tr("remote.status.voice_opening")

        Task { @MainActor in
            let result = await viewModel.startVoiceStreaming(to: device)
            isVoiceSearchOpening = false

            switch result {
            case .success:
                isVoiceSearchActive = true
                commandStatus = L10n.tr("remote.status.voice_listening")
                markConnectedIfNeeded()
            case .androidTVPairingRequired:
                let waiting = await viewModel.startTVPairing(device)
                if waiting {
                    commandStatus = L10n.tr("remote.status.waiting_pair_code")
                    showPairingPrompt = true
                } else {
                    commandStatus = L10n.tr("remote.status.pair_start_failed")
                }
            case .unreachable:
                commandStatus = L10n.tr("remote.status.command_failed")
            case .pairingInProgress:
                commandStatus = L10n.tr("remote.status.pairing_in_progress")
            case .failure(let message):
                commandStatus = message
            }
        }
    }

    private func stopVoiceStreamingIfNeeded() {
        guard isVoiceSearchActive || isVoiceSearchOpening else { return }
        viewModel.stopVoiceStreaming(to: device)
        resetVoiceSearchState(status: L10n.tr("remote.status.voice_sent"))
    }

    private func resetVoiceSearchState(status: String? = nil) {
        guard isVoiceSearchActive || isVoiceSearchOpening else { return }
        isVoiceSearchOpening = false
        isVoiceSearchActive = false
        if let status {
            commandStatus = status
        }
    }

    private func iconButton(_ systemName: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 50, height: 50)
        }
        .buttonStyle(LuxeIconButtonStyle(foregroundColor: isActive ? AppTheme.iconPrimary : .white))
    }

    private func okButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text("OK")
                .font(.system(size: 20, weight: .bold))
                .frame(width: 64, height: 64)
        }
        .buttonStyle(LuxeOKButtonStyle())
    }
}

private struct LuxeOKButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                RadialGradient(
                    colors: configuration.isPressed
                        ? [Color(red: 0.08, green: 0.62, blue: 0.90), Color(red: 0.03, green: 0.35, blue: 0.55)]
                        : [Color(red: 0.19, green: 0.82, blue: 0.96), Color(red: 0.04, green: 0.47, blue: 0.70)],
                    center: .topLeading,
                    startRadius: 3,
                    endRadius: 52
                ),
                in: Circle()
            )
            .overlay {
                Circle()
                    .stroke(.white.opacity(configuration.isPressed ? 0.85 : 0.6), lineWidth: 1.2)
            }
            .shadow(color: Color.cyan.opacity(configuration.isPressed ? 0.2 : 0.42), radius: configuration.isPressed ? 6 : 14)
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.15 : 0.28), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 6)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
