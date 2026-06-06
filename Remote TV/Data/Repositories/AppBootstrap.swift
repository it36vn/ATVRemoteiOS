import Foundation

final class AppBootstrap {
    private let firebaseService: FirebaseBootstrapService
    private let adMobService: AdMobService
    private let driveService: GoogleDriveSyncService

    init(config: AppConfig = .current) {
        firebaseService = FirebaseBootstrapService(plistName: config.firebaseGoogleServiceInfo)
        adMobService = AdMobService(
            isEnabled: true,
            appId: config.adMobAppId,
            interstitialUnitId: config.adMobInterstitialId
        )
        let scopes = config.googleDriveScopes
            .split(separator: " ")
            .map({"https://www.googleapis.com/auth/\($0)"})

        driveService = GoogleDriveSyncService(
            isEnabled: true,
            clientId: config.googleDriveClientId,
            scopes: scopes
        )
    }

    func start() {
        firebaseService.configureIfAvailable()
        adMobService.configureIfAvailable()
        _ = driveService
    }

    func adsService() -> AdMobService {
        adMobService
    }

    func googleDriveService() -> GoogleDriveSyncService {
        driveService
    }
}
