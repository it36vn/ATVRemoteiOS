import SwiftUI

struct TVCardView: View {
    let device: TVDevice
    let hasRecent: Bool
    let isFavorite: Bool
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "tv")
                .font(.title2)
                .foregroundStyle(AppTheme.iconPrimary)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(device.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(device.ipAddress)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    if hasRecent { TagView(text: L10n.tr("badge.recent"), color: .orange) }
                    if isFavorite { TagView(text: L10n.tr("badge.favorite"), color: .yellow) }
                }
            }

            Spacer()

            Button(L10n.tr("home.connect"), action: onConnect)
                .buttonStyle(.borderedProminent)
                .tint(.mint)
        }
        .padding(14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct TVListRowView: View {
    let device: TVDevice
    let isFavorite: Bool
    let onConnect: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tv.fill")
                .foregroundStyle(AppTheme.iconPrimary)
            VStack(alignment: .leading) {
                Text(device.displayName)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(device.ipAddress)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
            Button(isFavorite ? L10n.tr("row.unfavorite") : L10n.tr("row.favorite"), action: onFavoriteToggle)
                .buttonStyle(.bordered)
                .font(.caption)
                .tint(.white)
            Button(L10n.tr("row.connect"), action: onConnect)
                .buttonStyle(.borderedProminent)
                .font(.caption)
                .tint(.cyan)
        }
        .padding(.vertical, 4)
    }
}

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

struct TVCardSkeletonView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.18))
                .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 14)
                    .frame(maxWidth: 140)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 10)
                    .frame(maxWidth: 100)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 72, height: 18)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.18))
                .frame(width: 72, height: 32)
        }
        .padding(14)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .redacted(reason: .placeholder)
        .opacity(isAnimating ? 0.65 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}
