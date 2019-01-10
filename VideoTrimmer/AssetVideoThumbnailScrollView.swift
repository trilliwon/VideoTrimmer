//
//  AssetVideoScrollView.swift
//  VideoTrimmer
//
//  Created by kyle.jo on 07/01/2019.
//  Copyright © 2019 kyle.jo. All rights reserved.
//

import AVFoundation
import UIKit

class AssetVideoThumbnailScrollView: UIScrollView {

    let contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.tag = -1
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var widthConstraint: NSLayoutConstraint?
    private var assetImageGenerator: AVAssetImageGenerator?

    var maxDuration: Double = 30
    var sideInset: CGFloat = 105 // left: 52.5, right: 52.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureViews()
    }

    private func configureViews() {

        backgroundColor = .clear
        layer.borderColor = UIColor.green.cgColor
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = true
        clipsToBounds = true

        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: leftAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.rightAnchor.constraint(equalTo: rightAnchor)
            ])

        widthConstraint = contentView.widthAnchor.constraint(equalTo: widthAnchor, constant: sideInset)
        widthConstraint?.isActive = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentSize = contentView.bounds.size
    }

    var asset: AVAsset? {
        didSet {
            if let asset = asset {
                generateThumbnails(for: asset)
            }
        }
    }

    private func getThumbnailFrameSize(from asset: AVAsset) -> CGSize? {
        guard let track = asset.tracks(withMediaType: .video).first else { return nil }

        let assetSize = track.naturalSize.applying(track.preferredTransform)
        let ratio = assetSize.width / assetSize.height
        return CGSize(width: abs(frame.height * ratio), height: abs(frame.height))
    }

    private func generateThumbnails(for asset: AVAsset) {
        guard let thumbnailSize = getThumbnailFrameSize(from: asset), thumbnailSize.width != 0 else { return }

        assetImageGenerator?.cancelAllCGImageGeneration()
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let newContentSize = layoutContentSize(for: asset)
        let visibleThumbnailsCount = Int(ceil(frame.width / thumbnailSize.width))
        let thumbnailCount = Int(ceil(newContentSize.width / thumbnailSize.width))

        // add thumbnailViews
        for index in 0..<thumbnailCount {
            let thumbnailView = UIImageView(frame: .zero)
            thumbnailView.clipsToBounds = true

            let viewEndX = CGFloat(index) * thumbnailSize.width + thumbnailSize.width
            if viewEndX > contentView.frame.width {
                thumbnailView.frame.size = CGSize(width: thumbnailSize.width + (contentView.frame.width - viewEndX), height: thumbnailSize.height)
                thumbnailView.contentMode = .scaleAspectFill
            } else {
                thumbnailView.frame.size = thumbnailSize
                thumbnailView.contentMode = .scaleAspectFit
            }

            thumbnailView.frame.origin = CGPoint(x: CGFloat(index) * thumbnailSize.width, y: 0)
            thumbnailView.tag = index
            contentView.addSubview(thumbnailView)
        }

        // get thumbnail times [NSValue]
        let timeIncrement = (asset.duration.seconds * 1000) / Double(thumbnailCount)
        let timesForThumbnails = Array(0..<thumbnailCount).map({ NSValue(time: CMTime(value: Int64(timeIncrement * Float64($0)), timescale: 1000)) })

        // Generate Images
        generateThumbnails(for: asset, at: timesForThumbnails, maxSize: thumbnailSize, visibleThumbnails: visibleThumbnailsCount)
    }

    private func generateThumbnails(for asset: AVAsset, at times: [NSValue], maxSize: CGSize, visibleThumbnails: Int) {

        assetImageGenerator = AVAssetImageGenerator(asset: asset)
        assetImageGenerator?.appliesPreferredTrackTransform = true
        assetImageGenerator?.maximumSize = CGSize(width: maxSize.width * UIScreen.main.scale, height: maxSize.height * UIScreen.main.scale)

        var count = 0
        let completionHandler: AVAssetImageGeneratorCompletionHandler = { [weak self] _, cgImage, _, result, error in
            if let cgImage = cgImage, error == nil && result == .succeeded {
                DispatchQueue.main.async { [weak self] in
                    if count == 0 {
                        Array(0...visibleThumbnails).forEach { self?.displayImage(cgImage, at: $0) }
                    }
                    self?.displayImage(cgImage, at: count)
                    count += 1
                }
            }
        }

        assetImageGenerator?.generateCGImagesAsynchronously(forTimes: times, completionHandler: completionHandler)
    }

    private func layoutContentSize(for asset: AVAsset) -> CGSize {

        widthConstraint?.isActive = false

        if floor(asset.duration.seconds) < maxDuration {
            widthConstraint = contentView.widthAnchor.constraint(equalToConstant: frame.width - sideInset)
        } else {
            widthConstraint = contentView.widthAnchor.constraint(equalToConstant: (frame.width - sideInset) * CGFloat(asset.duration.seconds / maxDuration))
        }

        widthConstraint?.isActive = true
        layoutIfNeeded()
        return contentView.bounds.size
    }

    private func displayImage(_ cgImage: CGImage, at index: Int) {
        if let imageView = contentView.viewWithTag(index) as? UIImageView {
            imageView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: UIImage.Orientation.up)
        }
    }
}
