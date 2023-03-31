//
//  VideoAssetPersistenceManager.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/30/23.
//

import AVFoundation
import NewRelic

class VideoAssetPersistenceManager: NSObject {
    
    static let sharedManager = VideoAssetPersistenceManager()
    
    fileprivate var assetDownloadURLSession: AVAssetDownloadURLSession!
    fileprivate var activeDownloadsDictionary = [AVAggregateAssetDownloadTask: VideoAsset]()
    fileprivate var willDownloadToUrlDictionary = [AVAggregateAssetDownloadTask: URL]()

    override init() {
        super.init()

        let backgroundConfiguration = URLSessionConfiguration.background(withIdentifier: "NRMA-Identifier")

        assetDownloadURLSession = AVAssetDownloadURLSession(configuration: backgroundConfiguration, assetDownloadDelegate: self, delegateQueue: OperationQueue.main)
    }
    
    func downloadStream(for asset:  VideoAsset) {

        let preferredMediaSelection = asset.urlAsset.preferredMediaSelection

        guard let task =
            assetDownloadURLSession.aggregateAssetDownloadTask(with: asset.urlAsset,
                                                               mediaSelections: [preferredMediaSelection],
                                                               assetTitle: asset.name,
                                                               assetArtworkData: nil,
                                                               options:
                [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000]) else { return }

        task.taskDescription = asset.name

        activeDownloadsDictionary[task] = asset

        task.resume()
    }
    
    func localAssetForStream(withName name: String) -> VideoAsset? {
        let userDefaults = UserDefaults.standard
        guard let localFileLocation = userDefaults.value(forKey: name) as? Data else { return nil }
        
        var bookmarkDataIsStale = false
        do {
            let url = try URL(resolvingBookmarkData: localFileLocation,
                                    bookmarkDataIsStale: &bookmarkDataIsStale)

            if bookmarkDataIsStale {
                fatalError("Bookmark is stale")
            }
            
            let urlAsset = AVURLAsset(url: url)
            let asset = VideoAsset(name: name, urlAsset: urlAsset)

            return asset
        } catch {
            NewRelic.recordError(error)
            return nil
        }
    }

    func downloadState(for asset: VideoAsset) -> VideoAsset.DownloadState {
        if let localFileLocation = localAssetForStream(withName: asset.name)?.urlAsset.url {
            if FileManager.default.fileExists(atPath: localFileLocation.path) {
                return .downloaded
            }
        }

        for (_, assetValue) in activeDownloadsDictionary where asset.name == assetValue.name {
            return .downloading
        }

        return .notDownloaded
    }

    func deleteLocalAsset(_ asset: VideoAsset) {
        let userDefaults = UserDefaults.standard

        do {
            if let localFileLocation = localAssetForStream(withName: asset.name)?.urlAsset.url {
                try FileManager.default.removeItem(at: localFileLocation)

                userDefaults.removeObject(forKey: asset.name)
                
            }
        } catch {
            NewRelic.recordError(error)
            print("An error occured deleting the file: \(error)")
        }
    }
}

extension VideoAssetPersistenceManager: AVAssetDownloadDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let userDefaults = UserDefaults.standard

        guard let task = task as? AVAggregateAssetDownloadTask, let asset = activeDownloadsDictionary.removeValue(forKey: task) else { return }
        
        guard let downloadURL = willDownloadToUrlDictionary.removeValue(forKey: task) else { return }
                
        if let error = error as NSError? {
            NewRelic.recordError(error)
            switch (error.domain, error.code) {
            case (NSURLErrorDomain, NSURLErrorCancelled):
                
                guard let localFileLocation = localAssetForStream(withName: asset.name)?.urlAsset.url else { return }
                
                do {
                    try FileManager.default.removeItem(at: localFileLocation)
                    
                    userDefaults.removeObject(forKey: asset.name)
                } catch {
                    NewRelic.recordError(error)
                    print("An error occured trying to delete the contents on disk for \(asset.name): \(error)")
                }
                                
            case (NSURLErrorDomain, NSURLErrorUnknown):
                fatalError("Downloading HLS streams is not supported in the simulator.")
                
            default:
                fatalError("An unexpected error occured \(error.domain)")
            }
        } else {
            do {
                let bookmark = try downloadURL.bookmarkData()
                
                userDefaults.set(bookmark, forKey: asset.name)
            } catch {
                NewRelic.recordError(error)
                print("Failed to create bookmarkData for download URL.")
            }
        }
    }
    
    func urlSession(_ session: URLSession, aggregateAssetDownloadTask: AVAggregateAssetDownloadTask, willDownloadTo location: URL) {
        willDownloadToUrlDictionary[aggregateAssetDownloadTask] = location
    }
}
