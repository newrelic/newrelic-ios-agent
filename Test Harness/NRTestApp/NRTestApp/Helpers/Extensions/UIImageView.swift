//
//  UIImageView.swift
//  NRTestApp
//
//  Created by Mike Bruin on 1/12/23.
//

import UIKit

import NewRelic
extension UIImageView {
    
    func loadImage(withUrl urlString : String) {
        guard let url = URL(string: urlString) else {return}
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.center = CGPoint(x:self.frame.width/2,
                                           y: self.frame.height/2)
        DispatchQueue.main.async {
            activityIndicator.startAnimating()
            self.addSubview(activityIndicator)
        }
        
        // Create a NRTimer object to track the amount of time a custom process takes to complete, the start time is found automatically
        let timer = NRTimer()

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                DispatchQueue.main.async {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                    
                    guard let image = UIImage(data: data) else { return }
                    image.NRSessionReplayImageURL = url // Manually associate the URL with the UIImage for Session Replay
                    self.image = image
                    
                    // Stop the timer to record the stop time, and the difference can be passed in as a value in a custom metric
                    timer.stop()
                    NewRelic.recordMetric(withName: "SpaceImageDownloadAndDecode", category: "CustomMetricCategory", value: NSNumber(value: timer.timeElapsedInMilliSeconds()))
                }
            } catch {
                NewRelic.recordError(error)
                DispatchQueue.main.async {
                    activityIndicator.stopAnimating()
                    activityIndicator.removeFromSuperview()
                }
            }
        }
    }
}
