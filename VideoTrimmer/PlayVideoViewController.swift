//
//  ViewController.swift
//  VideoTrimmer
//
//  Created by kyle.jo on 07/01/2019.
//  Copyright © 2019 kyle.jo. All rights reserved.
//

import AVFoundation
import UIKit
import MobileCoreServices // kUTTYPEMovie
import Photos

class PlayVideoViewController: UIViewController {

    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var playerView: UIView!
    @IBOutlet weak var trimmerView: TrimmerView!
    @IBOutlet weak var rangeLabel: UILabel!

    @IBOutlet weak var openButton: UIButton! {
        didSet { openButton.layer.borderColor = UIColor.gray.cgColor }
    }

    @IBOutlet weak var saveButton: UIButton! {
        didSet { saveButton.layer.borderColor = UIColor.gray.cgColor }
    }

    @IBOutlet weak var playButton: UIButton! {
        didSet { playButton.layer.borderColor = UIColor.gray.cgColor }
    }

    @IBOutlet weak var indicator: UIActivityIndicatorView!

    var playerLayer: AVPlayerLayer?
    var playbackTimeCheckerTimer: Timer?

    var assetURL: URL? {
        didSet {
            playButton.isEnabled = assetURL != nil
            saveButton.isEnabled = assetURL != nil
        }
    }
    var selectedTimeRange: CMTimeRange = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        trimmerView.delegate = self
    }

    @IBAction func trimVideoTapped(_ sender: UIButton) {
        guard let url = self.assetURL else {
            print("url is nil")
            return
        }
        trimVideo(url: url, range: selectedTimeRange)
    }

    func trimVideo(url: URL, range: CMTimeRange) {
        indicator.startAnimating()

        let asset = AVURLAsset(url: url)
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: asset)
        if compatiblePresets.contains(AVAssetExportPresetHighestQuality) {

            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
            let path = NSTemporaryDirectory() + UUID().uuidString + ".mov"
            exportSession?.outputURL = URL(fileURLWithPath: path)
            exportSession?.outputFileType = AVFileType.mp4

            exportSession?.timeRange = range

            guard let outputURL = exportSession?.outputURL else {
                fatalError()
            }
            exportSession?.exportAsynchronously {
                print("Export Completed...")
                DispatchQueue.main.async {
                    self.indicator.stopAnimating()
                    if exportSession?.status == .completed {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                        }) { saved, error in
                            if saved {
                                let alertController = UIAlertController(title: "Your video was successfully exported", message: nil, preferredStyle: .alert)
                                let defaultAction = UIAlertAction(title: "OK", style: .default, handler: nil)
                                alertController.addAction(defaultAction)
                                self.present(alertController, animated: true, completion: nil)
                            }
                        }
                    }
                }
            }
        }
    }

    @IBAction func playVideo(_ sender: UIButton) {
        guard let player = playerLayer?.player else { return }

        if player.rate == 1.0 {
            pause()
        } else {
            play()
        }
    }

    func pause() {
        guard let player = playerLayer?.player else { return }

        player.pause()
        stopPlaybackTimeChecker()
        playButton.setTitle("Play", for: .normal)
    }

    func play() {
        guard let player = playerLayer?.player else { return }

        let bartime = trimmerView.positionBarTime
        player.play()
        player.seek(to: bartime)
        startPlaybackTimeChecker()
        playButton.setTitle("Pause", for: .normal)
    }

    @IBAction func openAction(_ sender: Any) {
        VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
    }

    func startPlaybackTimeChecker() {
        stopPlaybackTimeChecker()
        playbackTimeCheckerTimer = Timer.scheduledTimer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(onPlaybackTimeChecker), userInfo: nil, repeats: true)
        RunLoop.main.add(playbackTimeCheckerTimer!, forMode: .common)
    }

    func stopPlaybackTimeChecker() {
        playbackTimeCheckerTimer?.invalidate()
        playbackTimeCheckerTimer = nil
    }

    @objc
    func onPlaybackTimeChecker() {

        guard let startTime = trimmerView.startTime, let endTime = trimmerView.endTime, let player = playerLayer?.player else {
            return
        }

        if player.rate == 1.0 {
            let currentTime = player.currentTime()

            if trimmerView.positionBarTime < currentTime {
                self.trimmerView.seek(to: currentTime)
            }

            currentTimeLabel.text = "\(String(format: "%.1f", currentTime.seconds))s"
            if currentTime >= endTime {
                player.seek(to: startTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                trimmerView.seek(to: startTime)
                self.pause()
            }
        }
    }
}

extension PlayVideoViewController: UIImagePickerControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard
            let mediaType = info[UIImagePickerController.InfoKey.mediaType] as? String, mediaType == (kUTTypeMovie as String),
            let url = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
                return
        }

        dismiss(animated: true) {
            self.assetURL = url
            self.prepareToPlay(url: url)
        }
    }

    func prepareToPlay(url: URL) {
        playerLayer?.removeFromSuperlayer()
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = playerView.frame
        playerView.layer.insertSublayer(playerLayer!, at: 0)
        playerLayer?.frame = playerView.bounds
        playerLayer?.layoutIfNeeded()
        trimmerView.changeAsset(to: playerItem.asset)
    }
}

extension PlayVideoViewController: TrimmerViewDelegate {
    func didChangeSelectedRange(to range: CMTimeRange) {
        rangeLabel.text = String(format: "%.1f", range.duration.seconds) + "s"
        selectedTimeRange = range
    }

    func willBeginChangePosition(to time: CMTime) {
        playerLayer?.player?.pause()
        stopPlaybackTimeChecker()
    }

    func didChangePosition(to time: CMTime) {
        playerLayer?.player?.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }

    func didEndChangePosition(to time: CMTime) {
        play()
    }
}

// MARK: - UINavigationControllerDelegate
extension PlayVideoViewController: UINavigationControllerDelegate {

}
