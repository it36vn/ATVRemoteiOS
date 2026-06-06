import SwiftUI

struct LocalNetworkPermissionEmptyView: View {
    let onGrantPermission: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(L10n.tr("home.local_network_permission.empty"))
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onGrantPermission) {
                Text(L10n.tr("home.local_network_permission.grant_now"))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(AppTheme.iconPrimary, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
    }
}
