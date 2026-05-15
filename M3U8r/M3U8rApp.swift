import SwiftUI
import UIKit
import AVFoundation

/// AppDelegate to configure audio session early in app lifecycle
/// This is critical for PiP and background audio to work correctly
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureAudioSession()
        return true
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback category is required for background audio and PiP
            // .moviePlayback mode optimizes for video content
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
            #if DEBUG
            print("✅ Audio session configured for playback")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to configure audio session: \(error)")
            #endif
        }
    }
}

@main
struct M3U8rApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
