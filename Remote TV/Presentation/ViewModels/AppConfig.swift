import Foundation

struct AppConfig {
    let appName: String
    let version: String
    let build: String
    let bundleId: String
    let environment: String

    let firebaseGoogleServiceInfo: String
    let firebaseRemoteConfigNamespace: String

    let adMobAppId: String
    let adMobInterstitialId: String

    let googleDriveClientId: String
    let googleDriveScopes: String

    static var current: AppConfig {
        let info = Bundle.main.infoDictionary ?? [:]

        return AppConfig(
            appName: Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "ATV Remote",
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0",
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
            bundleId: Bundle.main.bundleIdentifier ?? "",
            environment: info["AppEnvironment"] as? String ?? "unknown",
            firebaseGoogleServiceInfo: info["FirebaseGoogleServiceInfo"] as? String ?? "",
            firebaseRemoteConfigNamespace: info["FirebaseRemoteConfigNamespace"] as? String ?? "",
            adMobAppId: info["AdMobAppID"] as? String ?? "",
            adMobInterstitialId: info["AdMobInterstitialID"] as? String ?? "",
            googleDriveClientId: info["GoogleDriveClientID"] as? String ?? "",
            googleDriveScopes: info["GoogleDriveScopes"] as? String ?? ""
        )
    }
}
