//
//  TrimmerView.swift
//  VideoTrimmer
//
//  Created by kyle.jo on 07/01/2019.
//  Copyright © 2019 kyle.jo. All rights reserved.
//

import AVFoundation
import UIKit

protocol TrimmerViewDelegate: class {
    func willBeginChangePosition(to time: CMTime)
    func didChangePosition(to time: CMTime)
    func didEndChangePosition(to time: CMTime)
}

final class TrimmerView: UIView {

    public weak var delegate: TrimmerViewDelegate?

    private var asset: AVAsset? {
        didSet {
            assetVideoThumbnailScrollView.asset = asset
            guard let startTime = startTime else { return }
            delegate?.didChangePosition(to: startTime)
        }
    }

    func changeAsset(to asset: AVAsset?) {
        self.asset = asset
    }

    public var minDuration: Double = 1

    public var selectedDuration: CMTime {
        return (endTime ?? CMTime.zero) - (startTime ?? CMTime.zero)
    }

    public var selectedRange: CMTimeRange {
        return CMTimeRange(start: startTime ?? CMTime.zero, end: endTime ?? CMTime.zero)
    }

    public var startTime: CMTime? {
        let startPosition = leftHandleView.frame.origin.x + assetVideoThumbnailScrollView.contentOffset.x + handleWidth
        return calculateTime(from: startPosition)
    }

    public var endTime: CMTime? {
        let endPosition = rightHandleView.frame.origin.x + assetVideoThumbnailScrollView.contentOffset.x
        return calculateTime(from: endPosition)
    }

    public var positionBarTime: CMTime? {
        let barPosition = positionBarView.center.x + assetVideoThumbnailScrollView.contentOffset.x
        return calculateTime(from: barPosition)
    }

    private var durationSize: CGFloat {
        return assetVideoThumbnailScrollView.contentSize.width
    }

    private var minimumDistanceBetweenHandle: CGFloat {
        guard let asset = asset else { return 0 }
        return CGFloat(minDuration) * (assetVideoThumbnailScrollView.contentView.frame.width / CGFloat(asset.duration.seconds))
    }

    private let assetVideoThumbnailScrollView: AssetVideoThumbnailScrollView = {
        let scrollView = AssetVideoThumbnailScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    @available(iOS 10.0, *)
    private var impactFeedback: UIImpactFeedbackGenerator {
        return UIImpactFeedbackGenerator(style: .heavy)
    }

    private var trimmerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private var leftHandleView: HandlerView = {
        let view = HandlerView()
        view.backgroundColor = UIColor(red: 51 / 255, green: 51 / 255, blue: 51 / 255, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var leftHandleKnobView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private var rightHandleView: HandlerView = {
        let view = HandlerView()
        view.backgroundColor = UIColor(red: 51 / 255, green: 51 / 255, blue: 51 / 255, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var rightHandleKnobView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private var positionBarView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 1
        view.layer.cornerRadius = 2.5
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.5
        view.layer.shadowOffset = CGSize.zero
        view.layer.shadowRadius = 2.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var leftMaskView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private var rightMaskView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private let handleWidth: CGFloat = 15
    private let sideMargin: CGFloat = 37.5
    private var leftHandleConstraint: NSLayoutConstraint?
    private var rightHandleConstraint: NSLayoutConstraint?
    private var positionBarConstraint: NSLayoutConstraint?

    // MARK: public
    public func seek(to time: CMTime) {
        if let newPosition = calculatePosition(from: time) {
            // 17.5 = handleWidth + positionBarView.frame.width - sideMargin
            let offsetPosition = newPosition - assetVideoThumbnailScrollView.contentOffset.x - leftHandleView.frame.origin.x - 17.5
            let maxPosition = rightHandleView.frame.origin.x - (leftHandleView.frame.origin.x + handleWidth) - positionBarView.frame.width
            let normalizedPosition = min(max(0, offsetPosition), maxPosition)
            positionBarConstraint?.constant = normalizedPosition
            layoutIfNeeded()
        }
    }

    // MARK: init
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureSubviews()
    }

    // MARK: private methods
    private func configureSubviews() {
        backgroundColor = .clear
        layer.zPosition = 1

        assetVideoThumbnailScrollView.delegate = self
        addSubview(assetVideoThumbnailScrollView)

        configureGestures()
        configureTrimmerView()
        configureLeftAndRightHandleViews()
        configurePositionBarView()
        configureMaskViews()

        assetVideoThumbnailScrollView.contentInset.left = sideMargin + handleWidth
        assetVideoThumbnailScrollView.contentInset.right = sideMargin + handleWidth

        configureAssetThumbnailVideoScrollView()
    }

    private func configureAssetThumbnailVideoScrollView() {
        NSLayoutConstraint.activate([
            assetVideoThumbnailScrollView.leftAnchor.constraint(equalTo: leftAnchor),
            assetVideoThumbnailScrollView.rightAnchor.constraint(equalTo: rightAnchor),
            assetVideoThumbnailScrollView.topAnchor.constraint(equalTo: topAnchor),
            assetVideoThumbnailScrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
    }

    private func configureTrimmerView() {
        addSubview(trimmerView)

        NSLayoutConstraint.activate([
            trimmerView.topAnchor.constraint(equalTo: topAnchor),
            trimmerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            trimmerView.leftAnchor.constraint(equalTo: leftAnchor),
            trimmerView.rightAnchor.constraint(equalTo: rightAnchor)
            ])
    }

    private func configureLeftAndRightHandleViews() {
        // Left Handle
        addSubview(leftHandleView)

        let leftHandleConstraint = leftHandleView.leftAnchor.constraint(equalTo: trimmerView.leftAnchor, constant: sideMargin)

        NSLayoutConstraint.activate([
            leftHandleView.heightAnchor.constraint(equalTo: heightAnchor),
            leftHandleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftHandleView.widthAnchor.constraint(equalToConstant: handleWidth),
            leftHandleConstraint
            ])
        self.leftHandleConstraint = leftHandleConstraint

        leftHandleView.addSubview(leftHandleKnobView)

        NSLayoutConstraint.activate([
            leftHandleKnobView.heightAnchor.constraint(equalToConstant: 15),
            leftHandleKnobView.widthAnchor.constraint(equalToConstant: 1),
            leftHandleKnobView.centerXAnchor.constraint(equalTo: leftHandleView.centerXAnchor),
            leftHandleKnobView.centerYAnchor.constraint(equalTo: leftHandleView.centerYAnchor)
            ])

        // Right Handle
        addSubview(rightHandleView)

        let rightHandleConstraint = rightHandleView.rightAnchor.constraint(equalTo: trimmerView.rightAnchor, constant: -sideMargin)
        NSLayoutConstraint.activate([
            rightHandleView.heightAnchor.constraint(equalTo: heightAnchor),
            rightHandleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightHandleView.widthAnchor.constraint(equalToConstant: handleWidth),
            rightHandleConstraint
            ])
        self.rightHandleConstraint = rightHandleConstraint

        rightHandleView.addSubview(rightHandleKnobView)

        NSLayoutConstraint.activate([
            rightHandleKnobView.heightAnchor.constraint(equalToConstant: 15),
            rightHandleKnobView.widthAnchor.constraint(equalToConstant: 1),
            rightHandleKnobView.centerXAnchor.constraint(equalTo: rightHandleView.centerXAnchor),
            rightHandleKnobView.centerYAnchor.constraint(equalTo: rightHandleView.centerYAnchor)
            ])
    }

    private func configurePositionBarView() {
        addSubview(positionBarView)

        let positionBarConstraint = positionBarView.leftAnchor.constraint(equalTo: leftHandleView.rightAnchor, constant: 0)
        NSLayoutConstraint.activate([
            positionBarView.heightAnchor.constraint(equalToConstant: 52),
            positionBarView.widthAnchor.constraint(equalToConstant: 5),
            positionBarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            positionBarConstraint
            ])
        self.positionBarConstraint = positionBarConstraint
    }

    private func configureMaskViews() {
        insertSubview(leftMaskView, belowSubview: leftHandleView)

        NSLayoutConstraint.activate([
            leftMaskView.heightAnchor.constraint(equalTo: heightAnchor),
            leftMaskView.centerYAnchor.constraint(equalTo: centerYAnchor),
            leftMaskView.leftAnchor.constraint(equalTo: leftAnchor),
            leftMaskView.rightAnchor.constraint(equalTo: leftHandleView.leftAnchor)
            ])

        insertSubview(rightMaskView, belowSubview: rightHandleView)

        NSLayoutConstraint.activate([
            rightMaskView.heightAnchor.constraint(equalTo: heightAnchor),
            rightMaskView.centerYAnchor.constraint(equalTo: centerYAnchor),
            rightMaskView.rightAnchor.constraint(equalTo: rightAnchor),
            rightMaskView.leftAnchor.constraint(equalTo: rightHandleView.rightAnchor)
            ])
    }

    private func configureGestures() {
        let leftHandlePanGestureRegognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(recognizer:)))
        leftHandleView.addGestureRecognizer(leftHandlePanGestureRegognizer)

        let rightHandlePanGestureRegognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(recognizer:)))
        rightHandleView.addGestureRecognizer(rightHandlePanGestureRegognizer)

        let positionBarViewPanGestureRegognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(recognizer:)))
        positionBarView.addGestureRecognizer(positionBarViewPanGestureRegognizer)
    }

    private var currentLeftConstraintConstant: CGFloat = 0
    private var currentRightConstraintConstant: CGFloat = 0
    private var currentPositionBarConstraintConstant: CGFloat = 0

    @objc
    private func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view, let superview = view.superview else { return }

        switch recognizer.state {
        case .began:
            if view == leftHandleView {
                currentLeftConstraintConstant = leftHandleConstraint?.constant ?? 0
            } else if view == rightHandleView {
                currentRightConstraintConstant = rightHandleConstraint?.constant ?? 0
            } else if view == positionBarView {
                currentPositionBarConstraintConstant = positionBarConstraint?.constant ?? 0
            }

            if #available(iOS 10.0, *) {
                impactFeedback.impactOccurred()
            }

            guard let playerTime = positionBarTime else { return }
            delegate?.willBeginChangePosition(to: playerTime)

        case .changed:
            let translation = recognizer.translation(in: superview)
            if view == leftHandleView {
                updateLeftConstraint(by: translation)
            } else if view == rightHandleView {
                updateRightConstraint(by: translation)
            } else if view == positionBarView {
                updatePositionConstraint(by: translation)
            }

            layoutIfNeeded()

            if let startTime = startTime, view == leftHandleView { seek(to: startTime) }
            else if let endTime = endTime, view == rightHandleView { seek(to: endTime) }

            guard let playerTime = positionBarTime else { return }
            delegate?.didChangePosition(to: playerTime)

        case .cancelled, .ended, .failed:
            guard let playerTime = positionBarTime else { return }
            delegate?.didEndChangePosition(to: playerTime)

        default:
            return
        }
    }

    private func updateLeftConstraint(by translation: CGPoint) {
        let maxConstraint = max(rightHandleView.frame.origin.x - handleWidth - minimumDistanceBetweenHandle, 0)
        let newConstraint = min(max(sideMargin, currentLeftConstraintConstant + translation.x), maxConstraint)
        leftHandleConstraint?.constant = newConstraint
    }

    private func updateRightConstraint(by translation: CGPoint) {
        let maxConstraint = max(-frame.width + handleWidth + leftHandleView.frame.maxX + minimumDistanceBetweenHandle, -frame.width + sideMargin)
        let newConstraint = max(min(currentRightConstraintConstant + translation.x, -sideMargin), maxConstraint)
        rightHandleConstraint?.constant = newConstraint
    }

    private func updatePositionConstraint(by translation: CGPoint) {
        let maxConstraint = rightHandleView.frame.origin.x - leftHandleView.frame.maxX - positionBarView.frame.width
        positionBarConstraint?.constant = min(max(currentPositionBarConstraintConstant + translation.x, 0), maxConstraint)
    }

    private func calculateTime(from position: CGFloat) -> CMTime? {
        guard let asset = asset else { return nil }
        let normalizedRatio = max(min(1, position / durationSize), 0)
        let positionTimeValue = Double(normalizedRatio) * Double(asset.duration.value)
        return CMTime(value: Int64(positionTimeValue), timescale: asset.duration.timescale)
    }

    private func calculatePosition(from time: CMTime) -> CGFloat? {
        guard let asset = asset else { return nil }
        let normalizedRatio = (CGFloat(time.value) / CGFloat(time.timescale)) * (CGFloat(asset.duration.timescale) / CGFloat(asset.duration.value))
        return normalizedRatio * durationSize
    }
}

extension TrimmerView: UIScrollViewDelegate {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let playerTime = positionBarTime else { return }
        delegate?.willBeginChangePosition(to: playerTime)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let playerTime = positionBarTime else { return }
        delegate?.didChangePosition(to: playerTime)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let playerTime = positionBarTime else { return }
        delegate?.didEndChangePosition(to: playerTime)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let playerTime = positionBarTime, !decelerate else { return }
        delegate?.didEndChangePosition(to: playerTime)
    }
}

// MARK: - More touchable UIView
extension TrimmerView {

    fileprivate class HandlerView: UIView {

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let hitFrame = bounds.insetBy(dx: -20, dy: -20)
            return hitFrame.contains(point) ? self : nil
        }

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            let hitFrame = bounds.insetBy(dx: -20, dy: -20)
            return hitFrame.contains(point)
        }
    }
}
