import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var activeDevices: [TVDevice] = []
    @Published var recents: [TVDevice] = []
    @Published var favorites: [TVDevice] = []

    @Published var isGoogleDriveLinked: Bool = false
    @Published var notificationsEnabled: Bool = false
    @Published var englishEnabled: Bool = false
    @Published var isSyncing: Bool = false
    @Published var isScanningDevices: Bool = false
    @Published var shouldShowLocalNetworkPermissionPrompt: Bool = false

    @Published var autoConnectedDevice: TVDevice?
    @Published var showGuideOnLaunch: Bool = false
    @Published var showGuideFromSettings: Bool = false
    @Published private(set) var voiceStreamingDeviceIPs: Set<String> = []

    @Published var settingsAppName: String
    @Published var settingsAppVersion: String
    @Published var settingsDeveloperLogo: String
    @Published var settingsDeveloperName: String
    @Published var settingsDeveloperDescription: String
    @Published var settingsDeveloperWebsite: String
    @Published var settingsDeveloperPhone: String
    @Published var settingsDeveloperEmail: String

    private let repository: TVRepository
    private let notificationService: NotificationPermissionService
    private let localNetworkPermissionService: LocalNetworkPermissionService
    private let driveSyncService: GoogleDriveSyncService
    private let adMobService: AdMobService
    private let remoteConfigService: FirebaseRemoteConfigService
    private let tvControlService: TVControlService

    private let connectUseCase = ConnectTVUseCase()
    private let toggleFavoriteUseCase = ToggleFavoriteUseCase()
    private let removeRecentUseCase = RemoveRecentUseCase()
    private let removeFavoriteUseCase = RemoveFavoriteUseCase()

    init() {
        let config = AppConfig.current
        let googleServiceConfig = GoogleServiceInfoService().loadConfig(plistName: config.firebaseGoogleServiceInfo)

        self.repository = LocalTVRepository()
        self.notificationService = NotificationPermissionService()
        self.localNetworkPermissionService = LocalNetworkPermissionService()
        let scopes = config.googleDriveScopes
            .split(separator: " ")
            .map({"https://www.googleapis.com/auth/\($0)"})
        self.driveSyncService = GoogleDriveSyncService(
            isEnabled: googleServiceConfig.isSignInEnabled,
            clientId: googleServiceConfig.clientId ?? config.googleDriveClientId,
            scopes: scopes
        )
        self.adMobService = AdMobService(
            isEnabled: googleServiceConfig.isAdsEnabled,
            appId: config.adMobAppId,
            interstitialUnitId: config.adMobInterstitialId
        )
        self.remoteConfigService = FirebaseRemoteConfigService()
        self.tvControlService = TVControlService()

        self.settingsAppName = config.appName
        self.settingsAppVersion = config.version
        self.settingsDeveloperLogo = ""
        self.settingsDeveloperName = ""
        self.settingsDeveloperDescription = ""
        self.settingsDeveloperWebsite = ""
        self.settingsDeveloperPhone = ""
        self.settingsDeveloperEmail = ""

        recents = repository.loadRecents()
        favorites = repository.loadFavorites()
        isGoogleDriveLinked = repository.loadGoogleDriveLinked()
        notificationsEnabled = repository.loadNotificationsEnabled()
        englishEnabled = repository.loadEnglishEnabled()

        tvControlService.voiceStreamingEnded = { [weak self] ipAddress in
            Task { @MainActor in
                self?.voiceStreamingDeviceIPs.remove(ipAddress)
            }
        }
    }

    func onLaunch() {
        syncFromGoogleDriveIfNeeded()
        adMobService.startAutoDisplay()
        fetchRemoteSettings()
        requestNotificationPermissionOnFirstLaunch()

        if !repository.hasSeenGuide() {
            showGuideOnLaunch = true
        } else if let last = repository.loadLastConnectedTV() {
            connect(device: last)
            autoConnectedDevice = last
        }
    }

    func markGuideSeen() {
        repository.saveHasSeenGuide(true)
        showGuideOnLaunch = false
    }

    func openGuideFromSettings() {
        showGuideFromSettings = true
    }

    func closeGuideFromSettings() {
        showGuideFromSettings = false
    }

    func clearAutoConnectDestination() {
        autoConnectedDevice = nil
    }

    func scanActiveTVs(retryAfterLocalNetworkPrompt: Bool = false) async {
        guard !isScanningDevices else { return }
        isScanningDevices = true
        defer { isScanningDevices = false }

        activeDevices = await repository.scanActiveTVs()
        if !activeDevices.isEmpty {
            shouldShowLocalNetworkPermissionPrompt = false
        }

        guard retryAfterLocalNetworkPrompt, activeDevices.isEmpty else { return }

        for delay in [1_000_000_000, 2_000_000_000, 4_000_000_000] {
            try? await Task.sleep(nanoseconds: UInt64(delay))
            let retryDevices = await repository.scanActiveTVs()
            guard !retryDevices.isEmpty else { continue }
            activeDevices = retryDevices
            shouldShowLocalNetworkPermissionPrompt = false
            return
        }

        shouldShowLocalNetworkPermissionPrompt = true
    }

    func requestLocalNetworkPermissionForGuide() {
        Task { @MainActor in
            guard let isAllowed = await localNetworkPermissionService.requestPermission() else { return }
            shouldShowLocalNetworkPermissionPrompt = !isAllowed
        }
    }

    func refreshLocalNetworkPermissionAndScanIfAllowed() async {
        guard let isAllowed = await localNetworkPermissionService.requestPermission() else { return }
        shouldShowLocalNetworkPermissionPrompt = !isAllowed
        if isAllowed {
            await scanActiveTVs()
        }
    }

    func refreshPermissionStatusesOnActive() async {
        try? await Task.sleep(nanoseconds: 300_000_000)

        await refreshNotificationPermissionStatus()

        for attempt in 0..<3 {
            if let isAllowed = await localNetworkPermissionService.requestPermission() {
                shouldShowLocalNetworkPermissionPrompt = !isAllowed
                if isAllowed {
                    await scanActiveTVs()
                }
                return
            }

            guard attempt < 2 else { break }
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
    }

    func refreshNotificationPermissionStatus() async {
        let notificationsGranted = await notificationService.currentEnabled()
        notificationsEnabled = notificationsGranted
        repository.saveNotificationsEnabled(notificationsGranted)
    }

    func refreshPermissionStatusesAfterAppReopen() {
        Task { @MainActor in
            await refreshPermissionStatusesOnActive()
        }
    }

    func applyPermissionStatusesFromAppDelegate(notificationsEnabled: Bool, localNetworkAllowed: Bool?) async {
        self.notificationsEnabled = notificationsEnabled
        repository.saveNotificationsEnabled(notificationsEnabled)

        guard let localNetworkAllowed else { return }
        shouldShowLocalNetworkPermissionPrompt = !localNetworkAllowed
        if localNetworkAllowed {
            await scanActiveTVs()
        }
    }

    func openLocalNetworkSettings() {
        localNetworkPermissionService.openAppSettings()
    }

    func connect(device: TVDevice) {
        recents = connectUseCase.execute(device: device, recents: recents)
        repository.saveRecents(recents)
        repository.saveLastConnectedTV(device)
        syncToGoogleDriveIfNeeded()
    }

    func toggleFavorite(device: TVDevice) {
        favorites = toggleFavoriteUseCase.execute(device: device, favorites: favorites)
        repository.saveFavorites(favorites)
        syncToGoogleDriveIfNeeded()
    }

    func removeFromRecents(_ device: TVDevice) {
        recents = removeRecentUseCase.execute(device: device, recents: recents)
        repository.saveRecents(recents)
        syncToGoogleDriveIfNeeded()
    }

    func removeFromFavorites(_ device: TVDevice) {
        favorites = removeFavoriteUseCase.execute(device: device, favorites: favorites)
        repository.saveFavorites(favorites)
        syncToGoogleDriveIfNeeded()
    }

    func hasRecent(_ device: TVDevice) -> Bool {
        recents.contains { $0.ipAddress == device.ipAddress }
    }

    func isFavorite(_ device: TVDevice) -> Bool {
        favorites.contains { $0.ipAddress == device.ipAddress }
    }

    func setGoogleDriveLinked(_ linked: Bool) {
        Task { @MainActor in
            if linked {
                isSyncing = true
                let snapshot = await driveSyncService.enableAndSync(recents: recents, favorites: favorites)
                isSyncing = false
                let success = snapshot != nil
                if let snapshot {
                    applyDriveSnapshot(snapshot)
                }
                isGoogleDriveLinked = success
                repository.saveGoogleDriveLinked(success)
            } else {
                driveSyncService.disableSync()
                isGoogleDriveLinked = false
                repository.saveGoogleDriveLinked(false)
            }
        }
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        Task { @MainActor in
            _ = enabled
            notificationService.openNotificationSettings()
            try? await Task.sleep(nanoseconds: 300_000_000)
            let granted = await notificationService.currentEnabled()
            notificationsEnabled = granted
            repository.saveNotificationsEnabled(granted)
        }
    }

    func setEnglishEnabled(_ enabled: Bool) {
        guard englishEnabled != enabled else { return }
        englishEnabled = enabled
        repository.saveEnglishEnabled(enabled)
    }

    func sendRemoteCommand(_ command: TVRemoteCommand, to device: TVDevice) async -> TVControlResult {
        await tvControlService.send(command, to: device.ipAddress)
    }

    func startTVPairing(_ device: TVDevice) async -> Bool {
        await tvControlService.startPairing(to: device.ipAddress)
    }

    func prepareTVConnection(_ device: TVDevice) async -> TVControlResult {
        await tvControlService.prepareConnection(to: device.ipAddress)
    }

    func submitTVPairingCode(_ code: String, for device: TVDevice) async -> TVControlResult {
        await tvControlService.submitPairingCode(code, to: device.ipAddress)
    }

    func isVoiceStreamingActive(for device: TVDevice) -> Bool {
        voiceStreamingDeviceIPs.contains(device.ipAddress)
    }

    func startVoiceStreaming(to device: TVDevice) async -> TVControlResult {
        let result = await tvControlService.startVoiceStreaming(to: device.ipAddress)
        if case .success = result {
            voiceStreamingDeviceIPs.insert(device.ipAddress)
        }
        return result
    }

    func stopVoiceStreaming(to device: TVDevice) {
        tvControlService.stopVoiceStreaming(to: device.ipAddress)
        voiceStreamingDeviceIPs.remove(device.ipAddress)
    }

    func switchInput(_ input: TVInputSource, on device: TVDevice) async -> TVControlResult {
        await tvControlService.switchInput(input, to: device.ipAddress)
    }

    private func fetchRemoteSettings() {
        Task { @MainActor in
            guard let remote = await remoteConfigService.fetchSettings() else { return }
            settingsAppName = remote.appName
            settingsAppVersion = remote.appVersion
            settingsDeveloperLogo = remote.developerLogo
            settingsDeveloperName = remote.developerName
            settingsDeveloperDescription = remote.developerDescription
            settingsDeveloperWebsite = remote.developerWebsite
            settingsDeveloperPhone = remote.developerPhone
            settingsDeveloperEmail = remote.developerEmail
        }
    }

    private func syncFromGoogleDriveIfNeeded() {
        guard isGoogleDriveLinked else { return }
        isSyncing = true
        Task { @MainActor in
            if let snapshot = await driveSyncService.syncFromCloudIfLinked(isGoogleDriveLinked, recents: recents, favorites: favorites) {
                applyDriveSnapshot(snapshot)
            }
            isSyncing = false
        }
    }

    private func syncToGoogleDriveIfNeeded() {
        guard isGoogleDriveLinked else { return }
        isSyncing = true
        Task { @MainActor in
            if let snapshot = await driveSyncService.syncToCloudIfLinked(isGoogleDriveLinked, recents: recents, favorites: favorites) {
                applyDriveSnapshot(snapshot)
            }
            isSyncing = false
        }
    }

    private func applyDriveSnapshot(_ snapshot: GoogleDriveSyncSnapshot) {
        recents = snapshot.recents
        favorites = snapshot.favorites
        repository.saveRecents(snapshot.recents)
        repository.saveFavorites(snapshot.favorites)
    }

    private func requestNotificationPermissionOnFirstLaunch() {
        Task { @MainActor in
            let granted = await notificationService.requestInitialPermissionIfNeeded()
            notificationsEnabled = granted
            repository.saveNotificationsEnabled(granted)
        }
    }
}
