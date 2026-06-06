import Foundation

protocol TVRepository {
    func scanActiveTVs() async -> [TVDevice]

    func loadRecents() -> [TVDevice]
    func saveRecents(_ devices: [TVDevice])

    func loadFavorites() -> [TVDevice]
    func saveFavorites(_ devices: [TVDevice])

    func loadLastConnectedTV() -> TVDevice?
    func saveLastConnectedTV(_ device: TVDevice?)

    func loadGoogleDriveLinked() -> Bool
    func saveGoogleDriveLinked(_ linked: Bool)

    func loadNotificationsEnabled() -> Bool
    func saveNotificationsEnabled(_ enabled: Bool)

    func loadEnglishEnabled() -> Bool
    func saveEnglishEnabled(_ enabled: Bool)

    func hasSeenGuide() -> Bool
    func saveHasSeenGuide(_ seen: Bool)
}
