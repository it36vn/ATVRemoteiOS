import Foundation
import UserNotifications
import Network
import Security

#if canImport(UIKit)
import UIKit
#endif

enum TVRemoteCommand {
    case power
    case home
    case back
    case settings
    case input
    case up
    case down
    case left
    case right
    case select
    case search
    case voiceAssist
    case volumeUp
    case volumeDown
    case mute

    var ecpKey: String {
        switch self {
        case .power: return "Power"
        case .home: return "Home"
        case .back: return "Back"
        case .settings: return "Settings"
        case .input: return "Input"
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .select: return "Select"
        case .search: return "Search"
        case .voiceAssist: return "Search"
        case .volumeUp: return "VolumeUp"
        case .volumeDown: return "VolumeDown"
        case .mute: return "Mute"
        }
    }
}

enum TVInputSource: CaseIterable, Identifiable {
    case hdmi1
    case hdmi2
    case hdmi3
    case hdmi4

    var id: String { titleKey }

    var titleKey: String {
        switch self {
        case .hdmi1: return "remote.input.hdmi1"
        case .hdmi2: return "remote.input.hdmi2"
        case .hdmi3: return "remote.input.hdmi3"
        case .hdmi4: return "remote.input.hdmi4"
        }
    }

    var appLinks: [String] {
        switch self {
        case .hdmi1:
            return [
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.TvPassThroughService%2FHW15",
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.passthroughinput.TvPassThroughService%2FHW1413744128"
            ]
        case .hdmi2:
            return [
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.TvPassThroughService%2FHW16",
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.passthroughinput.TvPassThroughService%2FHW1413744384"
            ]
        case .hdmi3:
            return [
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.TvPassThroughService%2FHW17",
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.passthroughinput.TvPassThroughService%2FHW1413744640"
            ]
        case .hdmi4:
            return [
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.TvPassThroughService%2FHW18",
                "content://android.media.tv/passthrough/com.tcl.tvinput%2F.passthroughinput.TvPassThroughService%2FHW1413745664"
            ]
        }
    }
}
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(FirebaseRemoteConfig)
import FirebaseRemoteConfig
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct RemoteSettingsData {
    let appName: String
    let appVersion: String
    let developerLogo: String
    let developerName: String
    let developerDescription: String
    let developerWebsite: String
    let developerPhone: String
    let developerEmail: String
}

struct GoogleServiceInfoConfig {
    let isAdsEnabled: Bool
    let isSignInEnabled: Bool
    let clientId: String?
}

final class GoogleServiceInfoService {
    func loadConfig(plistName: String) -> GoogleServiceInfoConfig {
        guard let path = Bundle.main.path(forResource: plistName, ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            return GoogleServiceInfoConfig(isAdsEnabled: true, isSignInEnabled: true, clientId: nil)
        }

        let isAdsEnabled = dict["IS_ADS_ENABLED"] as? Bool ?? true
        let isSignInEnabled = dict["IS_SIGNIN_ENABLED"] as? Bool ?? true
        let clientId = dict["CLIENT_ID"] as? String

        return GoogleServiceInfoConfig(
            isAdsEnabled: isAdsEnabled,
            isSignInEnabled: isSignInEnabled,
            clientId: clientId
        )
    }
}

final class NotificationPermissionService {
    func requestInitialPermissionIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func currentEnabled() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func openNotificationSettings() {
        #if canImport(UIKit)
        let rawURL: String
        if #available(iOS 15.4, *) {
            rawURL = UIApplication.openNotificationSettingsURLString
        } else {
            rawURL = UIApplication.openSettingsURLString
        }
        guard let url = URL(string: rawURL) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

final class LocalNetworkPermissionService {
    func requestPermission() async -> Bool? {
        await withCheckedContinuation { continuation in
            final class ProbeState: @unchecked Sendable {
                private let lock = NSLock()
                private var finished = false

                func finish(_ action: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !finished else { return }
                    finished = true
                    action()
                }
            }

            let probeState = ProbeState()
            let parameters = NWParameters()
            parameters.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: "_googlecast._tcp", domain: nil), using: parameters)

            browser.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    probeState.finish {
                        browser.cancel()
                        continuation.resume(returning: true)
                    }
                case .waiting(let error), .failed(let error):
                    if case .posix(.EACCES) = error {
                        probeState.finish {
                            browser.cancel()
                            continuation.resume(returning: false)
                        }
                    } else {
                        probeState.finish {
                            browser.cancel()
                            continuation.resume(returning: true)
                        }
                    }
                    
                case .cancelled:
                    probeState.finish {
                        continuation.resume(returning: nil)
                    }
                default:
                    break
                }
            }
            browser.start(queue: .global())

            Task {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                probeState.finish {
                    browser.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }
}

final class FirebaseBootstrapService {
    private let plistName: String

    init(plistName: String) {
        self.plistName = plistName
    }

    func configureIfAvailable() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }

        if let filePath = Bundle.main.path(forResource: plistName, ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
        #endif

        #if canImport(FirebaseMessaging)
        Messaging.messaging().isAutoInitEnabled = true
        #endif
    }
}

final class FirebaseRemoteConfigService {
    func fetchSettings() async -> RemoteSettingsData? {
        #if canImport(FirebaseRemoteConfig)
        let appConfig = AppConfig.current
        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = 0
        remoteConfig.configSettings = settings

        var defaults: [String: NSObject] = [
            "settings_app_name": appConfig.appName as NSString,
            "settings_app_version": appConfig.version as NSString,
            "settings_dev_name": "" as NSString,
            "settings_dev_description": "" as NSString,
            "settings_dev_website": "" as NSString,
            "settings_dev_phone": "" as NSString,
            "settings_dev_email": "" as NSString,
            "settings_dev_logo": "" as NSString
        ]
        let namespace = appConfig.firebaseRemoteConfigNamespace.trimmingCharacters(in: .whitespacesAndNewlines)
        if !namespace.isEmpty {
            defaults["\(namespace)_settings_app_name"] = appConfig.appName as NSString
            defaults["\(namespace)_settings_app_version"] = appConfig.version as NSString
            defaults["\(namespace)_settings_dev_name"] = "" as NSString
            defaults["\(namespace)_settings_dev_description"] = "" as NSString
            defaults["\(namespace)_settings_dev_website"] = "" as NSString
            defaults["\(namespace)_settings_dev_phone"] = "" as NSString
            defaults["\(namespace)_settings_dev_email"] = "" as NSString
            defaults["\(namespace)_settings_dev_logo"] = "" as NSString
        }
        remoteConfig.setDefaults(defaults)

        do {
            let status = try await remoteConfig.fetchAndActivate()
            print("Firebase Remote Config fetchAndActivate status: \(status)")
        } catch {
            print("Firebase Remote Config fetch failed: \(error.localizedDescription)")
        }

        func remoteString(_ key: String) -> String {
            if !namespace.isEmpty {
                let namespacedValue = remoteConfig.configValue(forKey: "\(namespace)_\(key)").stringValue
                if !namespacedValue.isEmpty {
                    return namespacedValue
                }
            }

            return remoteConfig.configValue(forKey: key).stringValue
        }

        return RemoteSettingsData(
            appName: appConfig.appName,
            appVersion: appConfig.version,
            developerLogo: remoteString("settings_dev_logo"),
            developerName: remoteString("settings_dev_name"),
            developerDescription: remoteString("settings_dev_description"),
            developerWebsite: remoteString("settings_dev_website"),
            developerPhone: remoteString("settings_dev_phone"),
            developerEmail: remoteString("settings_dev_email")
        )
        #else
        let appConfig = AppConfig.current
        return RemoteSettingsData(
            appName: appConfig.appName,
            appVersion: appConfig.version,
            developerLogo: "",
            developerName: "",
            developerDescription: "",
            developerWebsite: "",
            developerPhone: "",
            developerEmail: ""
        )
        #endif
    }
}

final class AdMobService: NSObject {
    private let isEnabled: Bool
    private let appId: String
    private let interstitialUnitId: String

    #if canImport(GoogleMobileAds)
    private var interstitialAd: GADInterstitialAd?
    private var isLoadingInterstitial = false
    #endif

    init(isEnabled: Bool, appId: String, interstitialUnitId: String) {
        self.isEnabled = isEnabled
        self.appId = appId
        self.interstitialUnitId = interstitialUnitId
    }

    func configureIfAvailable() {
        guard isEnabled, !appId.isEmpty else { return }
        #if canImport(GoogleMobileAds)
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        loadInterstitialIfNeeded()
        #endif
    }

    func showInterstitialIfAvailable() {
        guard isEnabled, !interstitialUnitId.isEmpty else { return }
        #if canImport(GoogleMobileAds)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let interstitialAd else {
                loadInterstitialIfNeeded()
                return
            }

            let rootViewController = UIApplication.shared.topMostViewController
            do {
                try interstitialAd.canPresent(fromRootViewController: rootViewController)
                interstitialAd.present(fromRootViewController: rootViewController)
                self.interstitialAd = nil
            } catch {
                self.interstitialAd = nil
                loadInterstitialIfNeeded()
            }
        }
        #endif
    }

    #if canImport(GoogleMobileAds)
    private func loadInterstitialIfNeeded() {
        guard isEnabled, !interstitialUnitId.isEmpty, interstitialAd == nil, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true

        GADInterstitialAd.load(withAdUnitID: interstitialUnitId, request: GADRequest()) { [weak self] ad, _ in
            guard let self else { return }
            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.isLoadingInterstitial = false
        }
    }
    #endif
}

#if canImport(GoogleMobileAds)
extension AdMobService: GADFullScreenContentDelegate {
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        interstitialAd = nil
        loadInterstitialIfNeeded()
    }

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        interstitialAd = nil
        loadInterstitialIfNeeded()
    }
}
#endif

#if canImport(UIKit)
private extension UIApplication {
    var topMostViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostPresentedViewController
    }
}

private extension UIViewController {
    var topMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostPresentedViewController
        }

        if let navigationController = self as? UINavigationController,
           let visibleViewController = navigationController.visibleViewController {
            return visibleViewController.topMostPresentedViewController
        }

        if let tabBarController = self as? UITabBarController,
           let selectedViewController = tabBarController.selectedViewController {
            return selectedViewController.topMostPresentedViewController
        }

        return self
    }
}
#endif

enum TVControlResult {
    case success
    case androidTVPairingRequired
    case unreachable
    case pairingInProgress
    case failure(String)
}

final class TVControlService {
    private var sessions: [String: AndroidTVSession] = [:]
    var voiceStreamingEnded: ((String) -> Void)?

    func send(_ command: TVRemoteCommand, to ipAddress: String) async -> TVControlResult {
        let session = sessionForIP(ipAddress)
        if await session.ensureConnected() {
            return await session.send(command)
        }

        if await isAndroidTVPairingAvailable(ipAddress) {
            return .androidTVPairingRequired
        }

        if await sendECP(command, to: ipAddress) {
            return .success
        }

        return .unreachable
    }

    func startPairing(to ipAddress: String) async -> Bool {
        let session = sessionForIP(ipAddress)
        return await session.startPairing()
    }

    func prepareConnection(to ipAddress: String) async -> TVControlResult {
        let session = sessionForIP(ipAddress)
        if await session.ensureConnected() {
            return .success
        }
        if session.isPairingPending {
            return .androidTVPairingRequired
        }

        if await isAndroidTVPairingAvailable(ipAddress) {
            return .androidTVPairingRequired
        }

        if await isECPReachable(ipAddress) {
            return .success
        }

        return .unreachable
    }

    func submitPairingCode(_ code: String, to ipAddress: String) async -> TVControlResult {
        let session = sessionForIP(ipAddress)
        return await session.submitPairingCode(code)
    }

    func startVoiceStreaming(to ipAddress: String) async -> TVControlResult {
        let session = sessionForIP(ipAddress)
        if await session.ensureConnected() {
            return await session.startVoiceStreaming()
        }

        if await isAndroidTVPairingAvailable(ipAddress) {
            return .androidTVPairingRequired
        }

        return .unreachable
    }

    func stopVoiceStreaming(to ipAddress: String) {
        sessionForIP(ipAddress).stopVoiceStreaming()
    }

    func switchInput(_ input: TVInputSource, to ipAddress: String) async -> TVControlResult {
        let session = sessionForIP(ipAddress)
        if await session.ensureConnected() {
            return await session.switchInput(input)
        }

        if await isAndroidTVPairingAvailable(ipAddress) {
            return .androidTVPairingRequired
        }

        return .unreachable
    }

    private func sessionForIP(_ ipAddress: String) -> AndroidTVSession {
        if let existing = sessions[ipAddress] { return existing }
        let created = AndroidTVSession(host: ipAddress)
        created.voiceStreamingEnded = { [weak self] in
            self?.voiceStreamingEnded?(ipAddress)
        }
        sessions[ipAddress] = created
        return created
    }

    private func sendECP(_ command: TVRemoteCommand, to ipAddress: String) async -> Bool {
        guard let encoded = command.ecpKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "http://\(ipAddress):8060/keypress/\(encoded)") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
        } catch {
        }

        return false
    }

    private func isECPReachable(_ ipAddress: String) async -> Bool {
        guard let url = URL(string: "http://\(ipAddress):8060/query/device-info") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 1.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return true
            }
        } catch {
        }

        return false
    }

    private func isAndroidTVPairingAvailable(_ ipAddress: String) async -> Bool {
        await isPortOpen(ip: ipAddress, port: 6467)
    }

    private func isPortOpen(ip: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }

            final class OneShot: @unchecked Sendable {
                private let lock = NSLock()
                private var done = false

                func run(_ action: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !done else { return }
                    done = true
                    action()
                }
            }

            let oneShot = OneShot()
            let connection = NWConnection(host: .init(ip), port: nwPort, using: .tcp)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    oneShot.run {
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    oneShot.run {
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())

            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                oneShot.run {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

@MainActor
final class AndroidTVSession {
    private let host: String
    private let remoteManager: RemoteManager
    private let pairingManager: PairingManager
    private var hasTriedRemoteConnection = false
    private var isPaired = false
    private var pairingPending = false
    private var voiceStreamer: AndroidTVVoiceAudioStreamer?
    private var voiceSessionID: Int?
    private var isVoiceRequestCancelled = false
    var isPairingPending: Bool { pairingPending }
    var voiceStreamingEnded: (() -> Void)?

    private var waitRemoteContinuation: CheckedContinuation<Bool, Never>?
    private var waitPairContinuation: CheckedContinuation<Bool, Never>?
    private var waitVoiceContinuation: CheckedContinuation<Int?, Never>?

    init(host: String) {
        self.host = host

        let certURLs = AndroidTVCertificateStore.ensureCertificateFiles()
        let cryptoManager = CryptoManager()

        cryptoManager.clientPublicCertificate = {
            CertManager().getSecKey(certURLs.derURL)
        }

        let tlsManager = TLSManager {
            CertManager().cert(certURLs.p12URL, "")
        }

        tlsManager.secTrustClosure = { secTrust in
            cryptoManager.serverPublicCertificate = {
                if #available(iOS 14.0, *) {
                    guard let key = SecTrustCopyKey(secTrust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                } else {
                    guard let key = SecTrustCopyPublicKey(secTrust) else {
                        return .Error(.secTrustCopyKeyError)
                    }
                    return .Result(key)
                }
            }
        }

        pairingManager = PairingManager(tlsManager, cryptoManager, DefaultLogger())
        remoteManager = RemoteManager(
            tlsManager,
            CommandNetwork.DeviceInfo("tclremote", "iPhone", "1.0.0", "tcl_remote", "1"),
            DefaultLogger()
        )

        pairingManager.stateChanged = { [weak self] state in
            self?.handlePairState(state)
        }

        remoteManager.stateChanged = { [weak self] state in
            self?.handleRemoteState(state)
        }

        remoteManager.voiceSessionStarted = { [weak self] sessionID in
            self?.resumeVoiceContinuation(sessionID)
        }

        remoteManager.voiceSessionEnded = { [weak self] sessionID in
            self?.handleVoiceSessionEnded(sessionID)
        }
    }

    func ensureConnected() async -> Bool {
        if isPaired { return true }
        if hasTriedRemoteConnection { return false }
        hasTriedRemoteConnection = true

        remoteManager.connect(host, timeout: 5)
        return await waitForRemoteReady(timeoutSeconds: 5)
    }

    func startPairing() async -> Bool {
        pairingManager.disconnect()
        pairingPending = true
        pairingManager.connect(host, "TCL Remote", "atvremote", timeout: 8)
        return await waitForPairState(timeoutSeconds: 8)
    }

    func submitPairingCode(_ code: String) async -> TVControlResult {
        guard pairingPending else { return .androidTVPairingRequired }
        pairingManager.sendSecret(code.uppercased())
        let success = await waitForPairState(timeoutSeconds: 8)
        if success {
            remoteManager.connect(host, timeout: 5)
            let connected = await waitForRemoteReady(timeoutSeconds: 6)
            return connected ? .success : .failure("Paired but cannot open remote channel")
        }
        return .failure("Invalid pairing code")
    }

    func send(_ command: TVRemoteCommand) async -> TVControlResult {
        guard isPaired else { return .androidTVPairingRequired }
        remoteManager.send(KeyPress(command.androidTVKey))
        return .success
    }

    func switchInput(_ input: TVInputSource) async -> TVControlResult {
        guard isPaired else { return .androidTVPairingRequired }

        for appLink in input.appLinks {
            remoteManager.send(DeepLink(appLink))
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        return .success
    }

    func startVoiceStreaming() async -> TVControlResult {
        guard isPaired else { return .androidTVPairingRequired }
        guard voiceStreamer == nil else { return .success }

        isVoiceRequestCancelled = false
        guard let sessionID = await requestVoiceSession() else {
            voiceSessionID = nil
            return .failure("TV did not start voice input")
        }

        remoteManager.send(CommandNetwork.VoiceBegin(sessionID: sessionID))
        voiceSessionID = sessionID

        let streamer = AndroidTVVoiceAudioStreamer { [weak remoteManager] samples in
            remoteManager?.send(CommandNetwork.VoicePayload(sessionID: sessionID, samples: samples))
        }

        do {
            try await streamer.start()
            if isVoiceRequestCancelled {
                streamer.stop()
                remoteManager.send(CommandNetwork.VoiceEnd(sessionID: sessionID))
                voiceSessionID = nil
                return .failure("Voice input was cancelled")
            }
            voiceStreamer = streamer
            return .success
        } catch AndroidTVVoiceAudioStreamer.StreamError.microphonePermissionDenied {
            remoteManager.send(CommandNetwork.VoiceEnd(sessionID: sessionID))
            voiceSessionID = nil
            return .failure("Microphone permission is required for voice search")
        } catch {
            remoteManager.send(CommandNetwork.VoiceEnd(sessionID: sessionID))
            voiceSessionID = nil
            return .failure("Cannot start microphone streaming")
        }
    }

    func stopVoiceStreaming() {
        stopVoiceStreaming(sendEnd: true, notify: false)
    }

    private func stopVoiceStreaming(sendEnd: Bool, notify: Bool) {
        isVoiceRequestCancelled = true
        resumeVoiceContinuation(nil)
        voiceStreamer?.stop()
        voiceStreamer = nil

        if sendEnd, let voiceSessionID {
            remoteManager.send(CommandNetwork.VoiceEnd(sessionID: voiceSessionID))
        }

        voiceSessionID = nil

        if notify {
            voiceStreamingEnded?()
        }
    }

    private func handlePairState(_ state: PairingManager.PairingState) {
        switch state {
        case .waitingCode:
            resumePairContinuation(true)
        case .successPaired:
            pairingPending = false
            resumePairContinuation(true)
        case .error:
            pairingPending = false
            resumePairContinuation(false)
        default:
            break
        }
    }

    private func handleRemoteState(_ state: RemoteManager.RemoteState) {
        switch state {
        case .paired:
            isPaired = true
            resumeRemoteContinuation(true)
        case .error(let error):
            if case .connectionWaitingError = error {
                pairingPending = true
            }
            stopVoiceStreaming(sendEnd: false, notify: true)
            resumeRemoteContinuation(false)
        default:
            break
        }
    }

    private func handleVoiceSessionEnded(_ sessionID: Int) {
        guard voiceSessionID == nil || voiceSessionID == sessionID else { return }
        stopVoiceStreaming(sendEnd: false, notify: true)
        resumeVoiceContinuation(nil)
    }

    private func waitForRemoteReady(timeoutSeconds: UInt64) async -> Bool {
        await withCheckedContinuation { continuation in
            waitRemoteContinuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                self.resumeRemoteContinuation(false)
            }
        }
    }

    private func requestVoiceSession() async -> Int? {
        voiceSessionID = nil
        remoteManager.send(KeyPress(.KEYCODE_VOICE_ASSIST))
        if let sessionID = await waitForVoiceBegin(timeoutSeconds: 3) {
            return isVoiceRequestCancelled ? nil : sessionID
        }

        guard !isVoiceRequestCancelled else { return nil }

        remoteManager.send(KeyPress(.KEYCODE_SEARCH))
        let fallbackSessionID = await waitForVoiceBegin(timeoutSeconds: 3)
        return isVoiceRequestCancelled ? nil : fallbackSessionID
    }

    private func waitForPairState(timeoutSeconds: UInt64) async -> Bool {
        await withCheckedContinuation { continuation in
            waitPairContinuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                self.resumePairContinuation(false)
            }
        }
    }

    private func waitForVoiceBegin(timeoutSeconds: UInt64) async -> Int? {
        await withCheckedContinuation { continuation in
            waitVoiceContinuation = continuation
            Task {
                try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                self.resumeVoiceContinuation(nil)
            }
        }
    }

    private func resumeRemoteContinuation(_ value: Bool) {
        guard let waitRemoteContinuation else { return }
        self.waitRemoteContinuation = nil
        waitRemoteContinuation.resume(returning: value)
    }

    private func resumePairContinuation(_ value: Bool) {
        guard let waitPairContinuation else { return }
        self.waitPairContinuation = nil
        waitPairContinuation.resume(returning: value)
    }

    private func resumeVoiceContinuation(_ value: Int?) {
        guard let waitVoiceContinuation else { return }
        self.waitVoiceContinuation = nil
        waitVoiceContinuation.resume(returning: value)
    }
}

private struct AndroidTVCertificateURLs {
    let derURL: URL
    let p12URL: URL
}

private enum AndroidTVCertificateStore {
    private static let derBase64 = "MIICpDCCAYwCCQC6hY4K3el5oDANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAlUQ0xSZW1vdGUwHhcNMjYwNTMwMDgxMTM5WhcNMzYwNTI4MDgxMTM5WjAUMRIwEAYDVQQDDAlUQ0xSZW1vdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC3wCHHs0R9v9V+e4v6sxYvIoAQllZXaKfuG4zwz+F6LIEhIeaZMy31cdDb82N2mJwC9wMdqlDKzbeMv6xAq0Sdr3V2n2wViBfJERvq5bL2jUZR9Y8Prm6gq8J8x6KBolU3Vbwy11VVDfxM4YZ5R1fHdeV6jUsLAz7mBG+Zg+2oafVScp+qTBz4uGKw4pXD8o+hS6VvyY4pr0n/CXgQ9h6YRMNpMtK7f5dEGL0WQhTisR7+W/TW6Rg8fA9FMu56B5kI0g7Eb+MfFGT7KtWW8Veq8cx1F+6qRsQ1qk5AblA2EaISvMMS5tjls6rVb7E7Lk1Cq9DmA+5f28fCw9hLAgMBAAEwDQYJKoZIhvcNAQELBQADggEBAGm4vRMC3JzZspD/8K2QvNw9LdCJry2pVn8QnxdP8kcr1l+Li8nEo3E7y2nJvE8B+5m7I6v6W+qb4sR6kH4Jfzj0YK6E4BzyhF9Pqul1y9b9R0l8d5j+VY9lGk6TxuQY6qSkM1o2+0P4IGq5FQ9vUev+6xH4YjktW4M8Q+oQ8A5rjVRehXNo8Fe7/8a2ZX2qD5xL4wqM9c9kq0j9LdNVsEaWz4vF2e2Vf4F+V4QyDg1xg3e9t6V9A9N4a4uL6ZxkQfY1V0T+owS4cY5d0Y6wQwSlkpk6Gl4yXnO1lXoVQ5Pq8j5eY8dQyWFG0k7iJ2dQ6o5e9YVg="
    private static let p12Base64 = "MIII6wIBAzCCCLUGCSqGSIb3DQEHAaCCCKYEggiCMIIIfjCCA/IGCSqGSIb3DQEHBqCCA+MwggPfAgEAMIID2AYJKoZIhvcNAQcBMFcGCSqGSIb3DQEFDTBKMCkGCSqGSIb3DQEFDDAcBAjz1MtN9MZ6fQICCAAwDAYIKoZIhvcNAgkFADAdBglghkgBZQMEASoEEA6QFH5Eowv7JIHdQj0DiiCAwJxZVbJxWqv3wqj4bHqB4n96qH2UjFf5QX+K3bw6h3U2C1s1JkHfD8xVf7xkG4QdA0wEPlHj8UOqfXnX2mYfQ1C0f0x9zRr7y+u0v7x+QZj8h8sJ5CjF3FEMT2TnW2xXhH2f+xolNh0ztR7yVjQv7W7znm3W7vJ7rN7hS5sQG2Y1w9gJfVv2kYr5o3kN6f2xjv+5ANrT+T4+0xNQ8oD7MCl+Yr3r9MUpMBfJxM4m0f5hB9kN8FczN5YvS2a2TLQX8vM/7x7UuY4XhE7NfQ5wY1A+NOw12m5YXeLk8s0biu3g2yqf1Rb2n2m0RkQzj3Y9Zw5nM3w3ewYl3+Gm4B3qYQodWv4jvC2NdP0fZ1a+Xk4x9gqfF+yjGnN1m0d9BByf1lqkYc6+v9aL2W3M6qJfFvM5v3Z3nX6HkV8m3oG2RLFdO7iKgdE8VfD8SX+5nQ2of1ZVq3U9pYoB9O0p4j3WmLmX6j9CnQjVYt6b8Uqk0lQXj5e+l6Y0zS6f9Tz5zH+E8M5JbP4Y6QjO7BQYV9UGtYxw7o1H+1kqgGxS1j1oXfBf4c8wQxVh4zYvG6kWb6eGgdnG1k3K9j+6xjF9J3jI1hHhJf7WlQ/8EX0p1A4vvxv2Fv7nGM2uI2wq4fQ5u9uY+Slz6j+f3p8g8Cw+Yv8sPjLQp9wXfR4xj3m9wE3eYt6mG6S+6JmF6g0+3Cw7a7mX9pW1r3s+6n0v8K+fJ0V2fA3S8m5P3YhQqScqzI4HqWgQ9Hc8d2U0lp9fX8W8FjC7b7X2qBq3f27LDbf6fgfW3u4KqNf5C6hS6s4u64kG2X6YyXvD9eMNsJ2U3S3Y8wqj3VhQfX4xx8nDs1y7qnV2s9m9k8d4R+8O5S4N9V2Dk4wD8R1lW25V8nH2H5M1bN9v+Q7Jz9JzE9lQG6f7Y5m+U9lGqQh2c2H2DgkzBv8c0UQh+Y2u0V3Y5YI+I2u7QzVzY3lH5qkKzV3P8pQ9fB9oTVZTW+LwN8wM9iYxEad9S4WVnQ0eBnqv6l2Jr9T3oR0Yx8YkS4G0eK3rZlYwA8v5x4t9m2v5j2e1qYJq6f4i2Fq+oU4rH+fEwD+9nQv3mQ8kXhC3YhGv1c8Z8lqf0P0yQvX8MNhG6C0nR9s7Xz8d1o7mUe6oWkz2+zR0Rj3G1I0aB0mC3nM9r9G0q3qgP6xwK9Yv3HhPj1E3bqG1tZ+FJb0vU3U9l8W3+oG2KqT5Xl8QpJxGfM7S3oKjQ7h0y0cZr2X5oKX5ZfKX+9J7H5wRkY5uJvHj9Rz8=" 

    static func ensureCertificateFiles() -> AndroidTVCertificateURLs {
        if let bundledURLs = findBundledCertificateFiles() {
            return bundledURLs
        }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tcl_androidtv_cert", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let derURL = dir.appendingPathComponent("cert.der")
        let p12URL = dir.appendingPathComponent("cert.p12")
        if let data = Data(base64Encoded: derBase64) {
            try? data.write(to: derURL)
        }
        if let data = Data(base64Encoded: p12Base64) {
            try? data.write(to: p12URL)
        }
        return AndroidTVCertificateURLs(derURL: derURL, p12URL: p12URL)
    }

    private static func findBundledCertificateFiles() -> AndroidTVCertificateURLs? {
        let subdirectories: [String?] = [
            nil,
            "AndroidTVCerts",
            "SupportFiles/AndroidTVCerts",
            "Remote TV/SupportFiles/AndroidTVCerts"
        ]

        for subdirectory in subdirectories {
            if let derURL = Bundle.main.url(forResource: "cert", withExtension: "der", subdirectory: subdirectory),
               let p12URL = Bundle.main.url(forResource: "cert", withExtension: "p12", subdirectory: subdirectory),
               isValidPKCS12(p12URL) {
                return AndroidTVCertificateURLs(derURL: derURL, p12URL: p12URL)
            }
        }

        guard let resourceURL = Bundle.main.resourceURL,
              let enumerator = FileManager.default.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: nil
              ) else {
            return nil
        }

        for case let p12URL as URL in enumerator where p12URL.lastPathComponent == "cert.p12" {
            let derURL = p12URL.deletingLastPathComponent().appendingPathComponent("cert.der")
            guard FileManager.default.fileExists(atPath: derURL.path),
                  isValidPKCS12(p12URL) else {
                continue
            }
            return AndroidTVCertificateURLs(derURL: derURL, p12URL: p12URL)
        }

        return nil
    }

    private static func isValidPKCS12(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        var rawItems: CFArray?
        let options = [kSecImportExportPassphrase as String: ""]
        return SecPKCS12Import(data as CFData, options as CFDictionary, &rawItems) == errSecSuccess
    }
}

private extension TVRemoteCommand {
    var androidTVKey: Key {
        switch self {
        case .power: return .KEYCODE_POWER
        case .home: return .KEYCODE_HOME
        case .back: return .KEYCODE_BACK
        case .settings: return .KEYCODE_SETTINGS
        case .input: return .KEYCODE_TV_INPUT
        case .up: return .KEYCODE_DPAD_UP
        case .down: return .KEYCODE_DPAD_DOWN
        case .left: return .KEYCODE_DPAD_LEFT
        case .right: return .KEYCODE_DPAD_RIGHT
        case .select: return .KEYCODE_DPAD_CENTER
        case .search: return .KEYCODE_SEARCH
        case .voiceAssist: return .KEYCODE_VOICE_ASSIST
        case .volumeUp: return .KEYCODE_VOLUME_UP
        case .volumeDown: return .KEYCODE_VOLUME_DOWN
        case .mute: return .KEYCODE_MUTE
        }
    }
}

struct GoogleDriveSyncSnapshot {
    let recents: [TVDevice]
    let favorites: [TVDevice]
}

private struct GoogleDriveBackupFile: Codable {
    var version: Int
    var updatedAt: Date
    var recents: [TVDevice]
    var favorites: [TVDevice]

    static var empty: GoogleDriveBackupFile {
        GoogleDriveBackupFile(version: 1, updatedAt: Date(), recents: [], favorites: [])
    }
}

private struct GoogleDriveFileList: Decodable {
    let files: [GoogleDriveFile]
}

private struct GoogleDriveFile: Decodable {
    let id: String
}

final class GoogleDriveSyncService {
    private let isEnabled: Bool
    private let clientId: String
    private let scopes: [String]
    private let backupFileName = "tcl_remote_backup.json"
    private let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(isEnabled: Bool, clientId: String, scopes: [String]) {
        self.isEnabled = isEnabled
        self.clientId = clientId
        self.scopes = scopes
    }

    func syncFromCloudIfLinked(_ linked: Bool, recents: [TVDevice], favorites: [TVDevice]) async -> GoogleDriveSyncSnapshot? {
        guard linked else { return nil }
        return await synchronize(recents: recents, favorites: favorites, shouldPromptSignIn: false)
    }

    func syncToCloudIfLinked(_ linked: Bool, recents: [TVDevice], favorites: [TVDevice]) async -> GoogleDriveSyncSnapshot? {
        guard linked else { return nil }
        return await synchronize(recents: recents, favorites: favorites, shouldPromptSignIn: false)
    }

    func enableAndSync(recents: [TVDevice], favorites: [TVDevice]) async -> GoogleDriveSyncSnapshot? {
        await synchronize(recents: recents, favorites: favorites, shouldPromptSignIn: true)
    }

    func disableSync() {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
    }

    private func synchronize(recents: [TVDevice], favorites: [TVDevice], shouldPromptSignIn: Bool) async -> GoogleDriveSyncSnapshot? {
        guard isEnabled,
              let accessToken = await accessToken(shouldPromptSignIn: shouldPromptSignIn) else {
            return nil
        }

        do {
            let existingFileID = try await findBackupFileID(accessToken: accessToken)
            let cloudBackup: GoogleDriveBackupFile
            if let existingFileID {
                cloudBackup = try await downloadBackup(fileID: existingFileID, accessToken: accessToken) ?? .empty
            } else {
                cloudBackup = .empty
            }

            let mergedBackup = GoogleDriveBackupFile(
                version: 1,
                updatedAt: Date(),
                recents: mergeDevices(primary: recents, secondary: cloudBackup.recents),
                favorites: mergeDevices(primary: favorites, secondary: cloudBackup.favorites)
            )

            if let existingFileID {
                try await updateBackup(fileID: existingFileID, backup: mergedBackup, accessToken: accessToken)
            } else {
                try await createBackup(backup: mergedBackup, accessToken: accessToken)
            }

            return GoogleDriveSyncSnapshot(recents: mergedBackup.recents, favorites: mergedBackup.favorites)
        } catch {
            return nil
        }
    }

    private func mergeDevices(primary: [TVDevice], secondary: [TVDevice]) -> [TVDevice] {
        var merged = primary
        for device in secondary where !merged.contains(where: { $0.ipAddress == device.ipAddress }) {
            merged.append(device)
        }
        return merged
    }

    private func accessToken(shouldPromptSignIn: Bool) async -> String? {
        #if canImport(GoogleSignIn) && canImport(UIKit)
        guard !clientId.isEmpty else { return nil }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)

        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            do {
                let refreshedUser = try await currentUser.refreshTokensIfNeeded()
                return refreshedUser.accessToken.tokenString
            } catch {
                return currentUser.accessToken.tokenString
            }
        }

        do {
            let restoredUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            let refreshedUser = try await restoredUser.refreshTokensIfNeeded()
            return refreshedUser.accessToken.tokenString
        } catch {
            guard shouldPromptSignIn else { return nil }
            guard let rootVC = topViewController() else {
                return nil
            }
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(
                    withPresenting: rootVC,
                    hint: nil,
                    additionalScopes: scopes.isEmpty ? nil : scopes
                )
                let refreshedUser = try await result.user.refreshTokensIfNeeded()
                return refreshedUser.accessToken.tokenString
            } catch {
                return nil
            }
        }
        #else
        // Fallback for builds without GoogleSignIn linked.
        return nil
        #endif
    }

    private func findBackupFileID(accessToken: String) async throws -> String? {
        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "name='\(backupFileName)' and trashed=false"),
            URLQueryItem(name: "spaces", value: "drive"),
            URLQueryItem(name: "fields", value: "files(id)")
        ]
        guard let url = components?.url else { return nil }

        var request = authorizedRequest(url: url, accessToken: accessToken)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard isSuccess(response) else { return nil }
        return try jsonDecoder.decode(GoogleDriveFileList.self, from: data).files.first?.id
    }

    private func downloadBackup(fileID: String, accessToken: String) async throws -> GoogleDriveBackupFile? {
        guard let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileID)?alt=media") else {
            return nil
        }

        var request = authorizedRequest(url: url, accessToken: accessToken)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard isSuccess(response), !data.isEmpty else { return nil }
        return try jsonDecoder.decode(GoogleDriveBackupFile.self, from: data)
    }

    private func createBackup(backup: GoogleDriveBackupFile, accessToken: String) async throws {
        guard let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id") else {
            return
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let metadata = ["name": backupFileName, "mimeType": "application/json"]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        let backupData = try jsonEncoder.encode(backup)

        var body = Data()
        appendMultipartPart(data: metadataData, contentType: "application/json; charset=UTF-8", boundary: boundary, to: &body)
        appendMultipartPart(data: backupData, contentType: "application/json", boundary: boundary, to: &body)
        body.append(Data("--\(boundary)--\r\n".utf8))

        var request = authorizedRequest(url: url, accessToken: accessToken)
        request.httpMethod = "POST"
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)
        guard isSuccess(response) else { throw URLError(.badServerResponse) }
    }

    private func updateBackup(fileID: String, backup: GoogleDriveBackupFile, accessToken: String) async throws {
        guard let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files/\(fileID)?uploadType=media") else {
            return
        }

        var request = authorizedRequest(url: url, accessToken: accessToken)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(backup)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard isSuccess(response) else { throw URLError(.badServerResponse) }
    }

    private func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func isSuccess(_ response: URLResponse) -> Bool {
        guard let http = response as? HTTPURLResponse else { return false }
        return (200...299).contains(http.statusCode)
    }

    private func appendMultipartPart(data: Data, contentType: String, boundary: String, to body: inout Data) {
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Type: \(contentType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n".utf8))
    }

    #if canImport(UIKit)
    private func topViewController(base: UIViewController? = UIApplication.shared
        .connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow })?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    #endif
}
