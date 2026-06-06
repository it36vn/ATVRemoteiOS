import Foundation
import Network
import Darwin

final class LocalTVRepository: TVRepository {
    private let recentsKey = "tcl_remote_recents"
    private let favoritesKey = "tcl_remote_favorites"
    private let lastConnectedKey = "tcl_remote_last_connected"
    private let driveLinkedKey = "tcl_remote_drive_linked"
    private let notificationsKey = "tcl_remote_notifications_enabled"
    private let englishKey = "tcl_remote_english_enabled"
    private let hasSeenGuideKey = "tcl_remote_has_seen_guide"

    func scanActiveTVs() async -> [TVDevice] {
        guard let localIP = currentWiFiIPv4Address(),
              let prefix = ipv4Prefix(localIP) else {
            return []
        }

        let ports: [UInt16] = [5555, 6466, 8008, 8060]
        let ownLast = Int(localIP.split(separator: ".").last ?? "0") ?? 0
        var discovered: [TVDevice] = []

        await withTaskGroup(of: TVDevice?.self) { group in
            for host in 1...254 where host != ownLast {
                let ip = "\(prefix).\(host)"
                group.addTask {
                    let reachable = await self.isAnyPortReachable(ip: ip, ports: ports)
                    guard reachable else { return nil }
                    return TVDevice(
                        id: UUID(),
                        ipAddress: ip,
                        macAddress: "N/A",
                        name: "Smart TV",
                        version: "9"
                    )
                }
            }

            for await device in group {
                if let device {
                    discovered.append(device)
                }
            }
        }

        return discovered.sorted { $0.ipAddress < $1.ipAddress }
    }

    func loadRecents() -> [TVDevice] { Self.loadArray(for: recentsKey) }
    func saveRecents(_ devices: [TVDevice]) { Self.saveArray(devices, for: recentsKey) }

    func loadFavorites() -> [TVDevice] { Self.loadArray(for: favoritesKey) }
    func saveFavorites(_ devices: [TVDevice]) { Self.saveArray(devices, for: favoritesKey) }

    func loadLastConnectedTV() -> TVDevice? { Self.loadObject(for: lastConnectedKey) }

    func saveLastConnectedTV(_ device: TVDevice?) {
        if let device {
            Self.saveObject(device, for: lastConnectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastConnectedKey)
        }
    }

    func loadGoogleDriveLinked() -> Bool { UserDefaults.standard.bool(forKey: driveLinkedKey) }
    func saveGoogleDriveLinked(_ linked: Bool) { UserDefaults.standard.set(linked, forKey: driveLinkedKey) }

    func loadNotificationsEnabled() -> Bool { UserDefaults.standard.bool(forKey: notificationsKey) }
    func saveNotificationsEnabled(_ enabled: Bool) { UserDefaults.standard.set(enabled, forKey: notificationsKey) }

    func loadEnglishEnabled() -> Bool { UserDefaults.standard.bool(forKey: englishKey) }
    func saveEnglishEnabled(_ enabled: Bool) { UserDefaults.standard.set(enabled, forKey: englishKey) }

    func hasSeenGuide() -> Bool { UserDefaults.standard.bool(forKey: hasSeenGuideKey) }
    func saveHasSeenGuide(_ seen: Bool) { UserDefaults.standard.set(seen, forKey: hasSeenGuideKey) }

    private func isAnyPortReachable(ip: String, ports: [UInt16]) async -> Bool {
        for port in ports {
            if await isPortReachable(ip: ip, port: port) {
                return true
            }
        }
        return false
    }

    private func isPortReachable(ip: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let host = NWEndpoint.Host(ip)
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }

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
            let connection = NWConnection(host: host, port: nwPort, using: .tcp)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    probeState.finish {
                        connection.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed, .cancelled:
                    probeState.finish {
                        connection.cancel()
                        continuation.resume(returning: false)
                    }
                default:
                    break
                }
            }

            connection.start(queue: .global())

            Task {
                try? await Task.sleep(nanoseconds: 250_000_000)
                probeState.finish {
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func currentWiFiIPv4Address() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            guard let addr = interface.ifa_addr else { continue }

            let addrFamily = addr.pointee.sa_family
            guard addrFamily == UInt8(AF_INET) else { continue }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" || name == "en1" else { continue }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            guard result == 0 else { continue }
            address = String(cString: hostname)
            break
        }

        return address
    }

    private func ipv4Prefix(_ ip: String) -> String? {
        let parts = ip.split(separator: ".")
        guard parts.count == 4 else { return nil }
        return "\(parts[0]).\(parts[1]).\(parts[2])"
    }

    private static func saveArray(_ devices: [TVDevice], for key: String) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(devices) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadArray(for key: String) -> [TVDevice] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let decoder = JSONDecoder()
        return (try? decoder.decode([TVDevice].self, from: data)) ?? []
    }

    private static func saveObject<T: Codable>(_ object: T, for key: String) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(object) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadObject<T: Codable>(for key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
}
