//
//  VideoViewController.swift
//  NRTestApp
//
//  Created by Mike Bruin on 3/30/23.
//

import UIKit
import AVKit

class VideoViewController: UITableViewController {

    fileprivate var playerViewController: AVPlayerViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Videos"
        
        tableView.estimatedRowHeight = 45.0
        tableView.rowHeight = UITableView.automaticDimension
        
        tableView.register(VideosTableViewCell.self, forCellReuseIdentifier: VideosTableViewCell.reuseIdentifier)
                
        tableView.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if playerViewController != nil {
            playerViewController?.player = nil
            playerViewController = nil
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return VideoAssetListManager.shared.assets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VideosTableViewCell.reuseIdentifier, for: indexPath)

        let asset = VideoAssetListManager.shared.assets[indexPath.row]

        if let cell = cell as? VideosTableViewCell {
            cell.asset = asset
#if os(iOS)
            cell.accessoryType = UITableViewCell.AccessoryType.detailButton
#endif
        }

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? VideosTableViewCell, let asset = cell.asset
            else { return }
#if os(iOS)
        if let localAsset = VideoAssetPersistenceManager.sharedManager.localAssetForStream(withName: asset.name) {
            startVideoWithURL(url: localAsset.urlAsset.url)
        } else {
            startVideoWithURL(url: asset.urlAsset.url)
        }
#else
        startVideoWithURL(url: asset.urlAsset.url)
#endif
    }

#if os(iOS)
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? VideosTableViewCell, let asset = cell.asset
            else { return }

        let downloadState = VideoAssetPersistenceManager.sharedManager.downloadState(for: asset)
        let alertAction: UIAlertAction

        switch downloadState {
        case .notDownloaded:
            alertAction = UIAlertAction(title: "Download", style: .default) { _ in
                VideoAssetPersistenceManager.sharedManager.downloadStream(for: asset)
            }

        case .downloading,.downloaded:
            alertAction = UIAlertAction(title: "Delete", style: .default) { _ in
                VideoAssetPersistenceManager.sharedManager.deleteLocalAsset(asset)
            }
        }

        let alertController = UIAlertController(title: asset.name, message: "Select from the following options:",
                                                preferredStyle: .actionSheet)
        alertController.addAction(alertAction)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))

        if UIDevice.current.userInterfaceIdiom == .pad {
            guard let popoverController = alertController.popoverPresentationController else {
                return
            }

            popoverController.sourceView = cell
            popoverController.sourceRect = cell.bounds
        }

        present(alertController, animated: true, completion: nil)
    }
#endif
    
    func startVideoWithURL(url: URL){
        playerViewController = AVPlayerViewController()
        let player = AVPlayer(url: url)
        if let playerViewController = playerViewController {
            playerViewController.player = player
            player.play()
            present(playerViewController, animated: true)
        }
    }
}
