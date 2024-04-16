//
//  VideoPlayerView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/11/24.
//

import Foundation
import SwiftUI
import AVKit
import Combine
import NewRelic

struct Media {
    let title: String
    let url: String
}

final class AVPlayerViewModel: ObservableObject {

    @Published var media: Media?

    let player = AVPlayer()
    private var cancellable: AnyCancellable?
    
    init() {
        setAudioSessionCategory(to: .playback)
        cancellable = $media
            .compactMap({ $0 })
            .compactMap({ URL(string: $0.url) })
            .sink(receiveValue: { [weak self] in
                guard let self = self else { return }
                self.player.replaceCurrentItem(with: AVPlayerItem(url: $0))
            })
        addPeriodicTimeObserver()
    }
    
    func play() {
        player.play()
        NewRelic.recordCustomEvent("play")
    }
                                  
    func addPeriodicTimeObserver() {
      // Invoke callback every half second
      let interval = CMTime(seconds: 0.5,
                            preferredTimescale: CMTimeScale(NSEC_PER_SEC))
      // Add time observer. Invoke closure on the main queue.

        _ =
          player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
              [unowned self] time in
              NewRelic.recordCustomEvent("addPeriodicTimeObserver fired" , attributes: ["time" : media!.title + String(time.seconds)])
      }
    }
    
    @objc  func playerItemDidPlayToEnd(_ notification: Notification) {
        player.seek(to: CMTime.zero)
        NewRelic.recordCustomEvent("playerItemDidPlayToEnd")
    }
    
    func pause() {
        player.pause()
        NewRelic.recordCustomEvent("pause")
    }
    
    func setAudioSessionCategory(to value: AVAudioSession.Category) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
           try audioSession.setCategory(value)
           try audioSession.setActive(true, options: [])
        } catch {
           print("Setting category to AVAudioSessionCategoryPlayback failed.")
        }
    }
}

@available(iOS 14.2, *)
struct AVVideoPlayer: UIViewControllerRepresentable {
    @ObservedObject var viewModel: AVPlayerViewModel
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = viewModel.player
        vc.delegate = context.coordinator
        vc.canStartPictureInPictureAutomaticallyFromInline = true
        return vc
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) { 
        
    }
    
    func makeCoordinator() -> Coordinator {
           return Coordinator(self)
       }
       
       class Coordinator: NSObject, AVPlayerViewControllerDelegate {
           let parent: AVVideoPlayer
           
           init(_ parent: AVVideoPlayer) {
               self.parent = parent
           }
           
           func playerViewController(_ playerViewController: AVPlayerViewController,
                                     willEndFullScreenPresentationWithAnimationCoordinator coordinator: any UIViewControllerTransitionCoordinator) {
               NewRelic.recordCustomEvent("willEndFullScreenPresentationWithAnimationCoordinator")
           }
           
           func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
               NewRelic.recordCustomEvent("playerViewControllerWillStartPictureInPicture")
           }
           
           func playerViewControllerDidStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
               NewRelic.recordCustomEvent("playerViewControllerDidStartPictureInPicture")
           }
           
           func playerViewControllerWillStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
               NewRelic.recordCustomEvent("playerViewControllerWillStopPictureInPicture")
           }
           
           func playerViewControllerDidStopPictureInPicture(_ playerViewController: AVPlayerViewController) {
               NewRelic.recordCustomEvent("playerViewControllerDidStopPictureInPicture")
           }
       }
   }

@available(iOS 14.2, *)
struct VideoPlayerView: View {
    @StateObject private var viewModel = AVPlayerViewModel()
    
    var body: some View {
        VStack {
            AVVideoPlayer(viewModel: viewModel)
        }
        .onAppear {
            viewModel.media = Media(title: "My video",
            url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
        }
        .onDisappear {
            viewModel.pause()
        }
        .NRTrackView(name: "VideoPlayerView")
    }
}
