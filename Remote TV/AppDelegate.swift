//
//  AppDelegate.swift
//  Remote TV
//
//  Created by Hung Nguyen on 5/30/26.
//

import UIKit
import FirebaseCore

let isLoggingEnabled: Bool = {
    #if DEBUG
    return true
    #else
    return (Bundle.main.infoDictionary?["AppEnvironment"] as? String)?.lowercased() == "staging"
    #endif
}()

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        let fileName = AppConfig.current.environment.lowercased() == "staging"
            ? "GoogleService-Info-Staging"
            : "GoogleService-Info-Production"

        guard let path = Bundle.main.path(
            forResource: fileName,
            ofType: "plist"
        ) else {
            fatalError("Firebase plist not found")
        }

        let options = FirebaseOptions(contentsOfFile: path)!
        FirebaseApp.configure(options: options)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        return configuration
    }
}


extension UIApplication {
    func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes.compactMap{ $0 as? UIWindowScene}.flatMap{ $0.windows }.first(where: { $0.isKeyWindow })?.rootViewController) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topViewController(base: navigationController.visibleViewController)
        }
        
        if let tabController = base as? UITabBarController {
            return topViewController(base: tabController.selectedViewController)
        }
        
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        
        return base
    }
}
