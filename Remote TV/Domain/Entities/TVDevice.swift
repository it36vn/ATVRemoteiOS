import Foundation

struct TVDevice: Identifiable, Codable, Equatable {
    let id: UUID
    let ipAddress: String
    let macAddress: String
    var name: String?
    var version: String

    var displayName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            guard !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return "Smart TV"
            }
            return version
        }
        return name
    }
}
