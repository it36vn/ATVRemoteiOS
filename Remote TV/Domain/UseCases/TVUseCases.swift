import Foundation

struct ConnectTVUseCase {
    func execute(device: TVDevice, recents: [TVDevice]) -> [TVDevice] {
        var updated = recents
        updated.removeAll { $0.ipAddress == device.ipAddress }
        updated.insert(device, at: 0)
        return updated
    }
}

struct ToggleFavoriteUseCase {
    func execute(device: TVDevice, favorites: [TVDevice]) -> [TVDevice] {
        var updated = favorites
        if updated.contains(where: { $0.ipAddress == device.ipAddress }) {
            updated.removeAll { $0.ipAddress == device.ipAddress }
        } else {
            updated.insert(device, at: 0)
        }
        return updated
    }
}

struct RemoveRecentUseCase {
    func execute(device: TVDevice, recents: [TVDevice]) -> [TVDevice] {
        recents.filter { $0.ipAddress != device.ipAddress }
    }
}

struct RemoveFavoriteUseCase {
    func execute(device: TVDevice, favorites: [TVDevice]) -> [TVDevice] {
        favorites.filter { $0.ipAddress != device.ipAddress }
    }
}
