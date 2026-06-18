import Foundation

final class AppBootstrap {
    private let firebaseService: FirebaseBootstrapService
    private let driveService: GoogleDriveSyncService

    init(config: AppConfig = .current) {
        firebaseService = FirebaseBootstrapService(plistName: config.firebaseGoogleServiceInfo)
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
        _ = driveService
    }

    func googleDriveService() -> GoogleDriveSyncService {
        driveService
    }
}
