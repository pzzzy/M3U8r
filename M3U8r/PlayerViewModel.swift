import Foundation
import UIKit
import AVKit
import Combine
import MediaPlayer

/// PlayerViewModel using AVPlayerViewController's BUILT-IN PiP support.
///
/// Key insight: AVPlayerViewController handles PiP automatically when:
/// 1. Audio session is configured with .playback category
/// 2. UIBackgroundModes includes "audio"
/// 3. We DON'T create a conflicting AVPictureInPictureController
@MainActor
final class PlayerViewModel: NSObject, ObservableObject, AVPlayerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var history: [String]
    
    var player: AVPlayer?
    private var playerViewController: AVPlayerViewController?
    private var statusObservation: NSKeyValueObservation?
    private var errorObservation: NSObjectProtocol?
    private var isInPiP: Bool = false
    
    private static let historyKey = "M3U8r_StreamHistory"
    private static let maxHistoryItems = 10
    
    override init() {
        history = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
        super.init()
        #if DEBUG
        print("🔍 Device supports PiP: \(AVPictureInPictureController.isPictureInPictureSupported())")
        #endif
    }

    func play(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            errorMessage = "No URL provided. Copy a stream URL to your clipboard and try again."
            return
        }
        
        guard let urlObj = URL(string: trimmed) else {
            errorMessage = "Invalid URL format. Please check the URL and try again."
            return
        }
        
        guard let scheme = urlObj.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            errorMessage = "URL must start with http:// or https://"
            return
        }

        guard urlObj.host != nil else {
            errorMessage = "URL must include a valid host."
            return
        }
        
        if !isInPiP {
            cleanup()
        }
        
        isLoading = true
        errorMessage = nil
        
        #if DEBUG
        print("▶️ Starting playback for: \(urlObj)")
        #endif
        
        // Create player
        let item = AVPlayerItem(url: urlObj)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        self.player = newPlayer
        
        // Observe status
        statusObservation = item.observe(\.status, options: [.new, .initial]) { observedItem, _ in
            let itemStatus = observedItem.status
            let itemError = observedItem.error
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch itemStatus {
                case .unknown:
                    #if DEBUG
                    print("📼 Player status: unknown")
                    #endif
                case .readyToPlay:
                    #if DEBUG
                    print("📼 Player status: readyToPlay ✅")
                    #endif
                    self.isLoading = false
                    self.addToHistory(trimmed)
                    self.updateNowPlaying(url: trimmed)
                case .failed:
                    #if DEBUG
                    print("📼 Player status: failed ❌ - \(String(describing: itemError))")
                    #endif
                    self.isLoading = false
                    self.errorMessage = itemError?.localizedDescription ?? "Failed to load stream. The URL may be invalid or the stream may be offline."
                @unknown default:
                    break
                }
            }
        }
        
        // Observe playback failure notification
        errorObservation = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            let errorDesc = error?.localizedDescription ?? "Playback interrupted. The stream may have ended or the connection was lost."
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.errorMessage = errorDesc
                self.isLoading = false
            }
        }
        
        // Create AVPlayerViewController - let IT handle PiP
        let vc = AVPlayerViewController()
        vc.player = newPlayer
        vc.allowsPictureInPicturePlayback = true
        vc.updatesNowPlayingInfoCenter = true
        vc.delegate = self
        vc.presentationController?.delegate = self
        
        // Enable auto-PiP on background
        if #available(iOS 14.2, *) {
            vc.canStartPictureInPictureAutomaticallyFromInline = true
            #if DEBUG
            print("🔧 canStartPictureInPictureAutomaticallyFromInline = true")
            #endif
        }
        
        self.playerViewController = vc
        
        // Present full screen using UIKit
        presentPlayer(vc)
        
        newPlayer.play()
        isPlaying = true
    }
    
    private func presentPlayer(_ vc: AVPlayerViewController, completion: ((Bool) -> Void)? = nil) {
        guard let rootVC = activeRootViewController() else {
            #if DEBUG
            print("❌ No root view controller")
            #endif
            errorMessage = "Unable to present player. Please try again."
            isLoading = false
            completion?(false)
            return
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        guard topVC !== vc, vc.presentingViewController == nil, vc.view.window == nil else {
            completion?(true)
            return
        }
        
        vc.modalPresentationStyle = .fullScreen
        vc.presentationController?.delegate = self
        topVC.present(vc, animated: true) {
            #if DEBUG
            print("✅ Player presented")
            #endif
            completion?(true)
        }
    }

    private func activeRootViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }

        let windows = scenes.flatMap(\.windows)
        return windows.first(where: \.isKeyWindow)?.rootViewController ?? windows.first?.rootViewController
    }
    
    private func cleanup() {
        #if DEBUG
        print("🧹 Cleanup")
        #endif
        statusObservation?.invalidate()
        statusObservation = nil
        if let errorObservation {
            NotificationCenter.default.removeObserver(errorObservation)
        }
        errorObservation = nil
        player?.pause()
        player = nil
        if let playerViewController,
           playerViewController.presentingViewController != nil,
           !playerViewController.isBeingDismissed {
            playerViewController.dismiss(animated: false)
        }
        playerViewController?.delegate = nil
        playerViewController?.presentationController?.delegate = nil
        playerViewController = nil
        isPlaying = false
        isLoading = false
        isInPiP = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
    
    // MARK: - Stream History
    
    private func addToHistory(_ url: String) {
        var updatedHistory = history
        // Remove duplicate if exists, then prepend
        updatedHistory.removeAll { $0 == url }
        updatedHistory.insert(url, at: 0)
        // Cap at max items
        if updatedHistory.count > Self.maxHistoryItems {
            updatedHistory = Array(updatedHistory.prefix(Self.maxHistoryItems))
        }
        history = updatedHistory
        UserDefaults.standard.set(updatedHistory, forKey: Self.historyKey)
    }
    
    func removeFromHistory(_ url: String) {
        history.removeAll { $0 == url }
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }
    
    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
    }
    
    // MARK: - Now Playing
    
    private func updateNowPlaying(url: String) {
        var info = [String: Any]()
        // Extract a display name from the URL
        if let urlObj = URL(string: url) {
            let name = urlObj.lastPathComponent
                .replacingOccurrences(of: ".m3u8", with: "")
                .replacingOccurrences(of: ".mp4", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            info[MPMediaItemPropertyTitle] = name.isEmpty ? "M3U8r Stream" : name
        } else {
            info[MPMediaItemPropertyTitle] = "M3U8r Stream"
        }
        info[MPMediaItemPropertyArtist] = "M3U8r"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    // MARK: - AVPlayerViewControllerDelegate
    // These delegate methods track PiP state without interfering with AVPlayerViewController's internal PiP controller
    
    nonisolated func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        #if DEBUG
        print("📺 PiP WILL START")
        #endif
        Task { @MainActor in
            self.isInPiP = true
        }
    }
    
    nonisolated func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        #if DEBUG
        print("📺 PiP DID START ✅")
        #endif
    }
    
    nonisolated func playerViewControllerDidFailToStartPictureInPicture(_ playerViewController: AVPlayerViewController, withError error: Error) {
        #if DEBUG
        print("❌ PiP FAILED: \(error)")
        let nsError = error as NSError
        print("❌ Domain: \(nsError.domain), Code: \(nsError.code)")
        #endif
    }
    
    nonisolated func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        #if DEBUG
        print("📺 PiP WILL STOP")
        #endif
    }
    
    nonisolated func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
        #if DEBUG
        print("📺 PiP DID STOP")
        #endif
        Task { @MainActor in
            self.isInPiP = false
        }
    }
    
    // Keep the VC visible when entering PiP - DON'T auto-dismiss
    nonisolated func playerViewControllerShouldAutomaticallyDismissAtPictureInPictureStart(_ playerViewController: AVPlayerViewController) -> Bool {
        #if DEBUG
        print("📺 Should auto-dismiss? → false")
        #endif
        return false
    }
    
    nonisolated func playerViewController(
        _ playerViewController: AVPlayerViewController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        #if DEBUG
        print("📺 Restore UI")
        #endif
        Task { @MainActor in
            self.presentPlayer(playerViewController)
        }
        completionHandler(true)
    }

    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        Task { @MainActor in
            if !self.isInPiP {
                self.cleanup()
            }
        }
    }
}
