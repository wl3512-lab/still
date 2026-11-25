import SwiftUI
import FirebaseCore
import FirebaseAppCheck

@main
struct StillApp: App {
    init() {
        // Firebase is optional: without GoogleService-Info.plist the app still coaches
        // fully offline (on-device model or plain rules).
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            #if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
            #else
            AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
            #endif
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup { CameraScreen() }
    }
}

final class AppAttestProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        AppAttestProvider(app: app)
    }
}
