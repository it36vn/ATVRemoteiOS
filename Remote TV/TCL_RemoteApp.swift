import SwiftUI
import Firebase

@main
struct TCL_RemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var viewModel = AppViewModel()
    
    @State private var bootstrap = AppBootstrap()
    
    init() {}

    var body: some Scene {
        WindowGroup {
            RootView()
                    .environmentObject(viewModel)
                .task {
                    bootstrap.start()
                }
        }
    
    }
}


struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        ContentView()
            .onChange(of: scenePhase, {
                if scenePhase == .active {
                    viewModel.refreshPermissionStatusesAfterAppReopen()
                }
            })
    }
}
