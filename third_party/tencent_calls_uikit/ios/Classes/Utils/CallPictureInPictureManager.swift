//
//  CallPictureInPictureManager.swift
//  tencent_calls_uikit
//

import AVKit
import AVFoundation
import Foundation
import RTCRoomEngine
import TXLiteAVSDK_Professional
import UIKit

@available(iOS 15.0, *)
private final class PipSampleBufferVideoCallView: UIView {
    override class var layerClass: AnyClass {
        AVSampleBufferDisplayLayer.self
    }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        backgroundColor = .black
        sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
        sampleBufferDisplayLayer.isOpaque = true
        sampleBufferDisplayLayer.backgroundColor = UIColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 15.0, *)
private final class PipAudioCallSourceView: UIView {
    private let avatarImageView = UIImageView()
    private let iconImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 45 / 255, green: 45 / 255, blue: 45 / 255, alpha: 1)
        clipsToBounds = true
        isUserInteractionEnabled = false

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = UIColor(red: 70 / 255, green: 70 / 255, blue: 70 / 255, alpha: 1)

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white

        addSubview(avatarImageView)
        addSubview(iconImageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureFromCallState() {
        let remoteUser = TUICallState.instance.remoteUserList.value.first
        let avatarUrl = remoteUser?.avatar.value ?? ""
        avatarImageView.sd_setImage(
            with: URL(string: avatarUrl),
            placeholderImage: BundleUtils.getBundleImage(name: "userIcon")
        )
        if let icon = BundleUtils.getBundleImage(name: "icon_float_dialing") {
            iconImageView.image = icon
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let height = bounds.height
        let avatarSize = min(width, height) * 0.42
        avatarImageView.frame = CGRect(
            x: (width - avatarSize) / 2,
            y: height * 0.24,
            width: avatarSize,
            height: avatarSize
        )
        avatarImageView.layer.cornerRadius = avatarSize / 2
        let iconSize = max(28, avatarSize * 0.42)
        iconImageView.frame = CGRect(
            x: (width - iconSize) / 2,
            y: avatarImageView.frame.maxY + 14,
            width: iconSize,
            height: iconSize
        )
    }
}

@available(iOS 15.0, *)
final class CallPictureInPictureManager: NSObject {
    static let shared = CallPictureInPictureManager()

    private enum PipMode {
        case videoCall
        case audioCall
        case sampleBuffer
    }

    private var pipController: AVPictureInPictureController?
    private var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    private var pipDisplayLayer: AVSampleBufferDisplayLayer?
    private var hostView: UIView?
    private var pipInlineHostView: UIView?
    private var pipSourceVideoCallView: PipSampleBufferVideoCallView?
    private var pipAudioSourceView: PipAudioCallSourceView?
    private var videoCallSourceView: UIView?
    private var remoteUserId: String?
    private var pipMode: PipMode = .videoCall
    private var isPrepared = false
    private var isPipActive = false
    private var isPipTransitionInProgress = false
    private var isCustomRenderActive = false
    private var pendingPipStart = false
    private var isEnteringBackground = false
    private var renderFrameCount = 0
    private var enqueuedFrameCount = 0
    private var lastEnqueueError: String?
    private var presentationTime = CMTime.zero
    private let presentationTimeScale: CMTimeScale = 90_000
    private let frameDuration = CMTime(value: 3_000, timescale: 90_000)
    private var useSampleBufferFallback = false

    private var trtcCloud: TRTCCloud {
        TUICallEngine.createInstance().getTRTCCloudInstance()
    }

    private override init() {
        super.init()
    }

    func prepareIfNeeded() {
        let status = TUICallState.instance.selfUser.value.callStatus.value
        let mediaType = TUICallState.instance.mediaType.value
        let remoteId = TUICallState.instance.remoteUserList.value.first?.id.value ?? ""
        CallPipLogger.log(
            "prepareIfNeeded status=\(status.rawValue) mediaType=\(mediaType.rawValue) remoteId=\(remoteId)"
        )

        guard status == .accept, !remoteId.isEmpty else {
            CallPipLogger.log("prepareIfNeeded skipped: call not ready")
            return
        }

        if mediaType == .audio {
            if isPrepared {
                teardownKeepingFallbackFlag(false)
            }
            CallPipLogger.log("prepareIfNeeded skipped: audio call uses CallKit Dynamic Island only")
            return
        }

        guard mediaType == .video else {
            CallPipLogger.log("prepareIfNeeded skipped: unsupported mediaType")
            return
        }

        prepareVideoCallPipIfNeeded(remoteId: remoteId)
    }

    private func prepareAudioCallPipIfNeeded(remoteId: String) {
        guard #available(iOS 16.0, *) else {
            CallPipLogger.log("prepareIfNeeded aborted: audio PiP requires iOS 16+")
            return
        }
        if isPrepared, remoteUserId == remoteId, pipMode == .audioCall {
            pipAudioSourceView?.configureFromCallState()
            CallPipLogger.log("prepareIfNeeded skipped: audioCall already prepared")
            return
        }
        teardownKeepingFallbackFlag(false)
        remoteUserId = remoteId
        configureAudioSessionForPip()
        pipMode = .audioCall
        ensureAudioCallPipReady()
        logPrepareIfNeededDone()
    }

    private func prepareVideoCallPipIfNeeded(remoteId: String) {
        if shouldSkipInlinePipRebind() {
            CallPipLogger.log("prepareVideoCallPipIfNeeded skipped: pip lifecycle lock")
            startPipSourceCustomRender(userId: remoteId)
            return
        }
        if isPrepared, remoteUserId == remoteId {
            if pipMode == .videoCall {
                if shouldRetainVideoCallController() {
                    CallPipLogger.log("prepareIfNeeded skipped: videoCall already prepared")
                    startPipSourceCustomRender(userId: remoteId)
                    return
                }
                if #available(iOS 16.0, *) {
                    CallPipLogger.log("prepareIfNeeded soft rebuild videoCall for updated remote view")
                    enableBackgroundDecoding(true)
                    ensureVideoCallPipReady(userId: remoteId)
                    return
                }
            }
            if pipMode == .sampleBuffer, useSampleBufferFallback {
                CallPipLogger.log("prepareIfNeeded skipped: sampleBuffer fallback already prepared")
                return
            }
        }

        let preservedFallback = useSampleBufferFallback
        teardownKeepingFallbackFlag(preservedFallback)
        remoteUserId = remoteId
        enableBackgroundDecoding(true)
        configureAudioSessionForPip()

        if useSampleBufferFallback {
            setupSampleBufferPipController()
            pipMode = .sampleBuffer
            isPrepared = pipController != nil
        } else if #available(iOS 16.0, *) {
            pipMode = .videoCall
            ensureVideoCallPipReady(userId: remoteId)
        } else {
            CallPipLogger.log("prepareIfNeeded aborted: videoCall PiP requires iOS 16+")
            return
        }

        logPrepareIfNeededDone()
    }

    private func logPrepareIfNeededDone() {
        let pipSupported = AVPictureInPictureController.isPictureInPictureSupported()
        let isPossible = pipController?.isPictureInPicturePossible ?? false
        CallPipLogger.log(
            "prepareIfNeeded done mode=\(pipMode) isPrepared=\(isPrepared) "
                + "pipSupported=\(pipSupported) isPossible=\(isPossible)"
        )
    }

    func teardown() {
        teardownKeepingFallbackFlag(false)
    }

    private func teardownKeepingFallbackFlag(_ preserveFallback: Bool) {
        CallPipLogger.log("teardown")
        stopPictureInPictureIfNeeded()
        stopCustomRender()
        pipController = nil
        pipVideoCallViewController = nil
        pipDisplayLayer?.removeFromSuperlayer()
        pipDisplayLayer = nil
        hostView?.removeFromSuperview()
        hostView = nil
        pipInlineHostView?.removeFromSuperview()
        pipInlineHostView = nil
        isPipTransitionInProgress = false
        pipSourceVideoCallView?.removeFromSuperview()
        pipSourceVideoCallView = nil
        pipAudioSourceView?.removeFromSuperview()
        pipAudioSourceView = nil
        videoCallSourceView = nil
        remoteUserId = nil
        isPrepared = false
        pendingPipStart = false
        isEnteringBackground = false
        renderFrameCount = 0
        enqueuedFrameCount = 0
        lastEnqueueError = nil
        presentationTime = .zero
        useSampleBufferFallback = preserveFallback
        enableBackgroundDecoding(false)
    }

    func enterBackgroundIfNeeded() {
        if isEnteringBackground {
            CallPipLogger.log("enterBackgroundIfNeeded skipped: already entering")
            return
        }
        isEnteringBackground = true
        defer { isEnteringBackground = false }

        CallPipLogger.log("enterBackgroundIfNeeded begin mode=\(pipMode) isPrepared=\(isPrepared)")
        let mediaType = TUICallState.instance.mediaType.value
        if mediaType == .audio {
            if isPrepared {
                teardownKeepingFallbackFlag(false)
            }
            CallPipLogger.log("enterBackgroundIfNeeded skipped: audio call uses CallKit Dynamic Island only")
            return
        }
        if !isPrepared {
            prepareIfNeeded()
        }
        guard let userId = remoteUserId else {
            CallPipLogger.log("enterBackgroundIfNeeded aborted: no remote user")
            return
        }
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            CallPipLogger.log("enterBackgroundIfNeeded aborted: PiP unsupported")
            return
        }

        if pipController?.isPictureInPictureActive == true {
            CallPipLogger.log("enterBackgroundIfNeeded skipped: PiP already active")
            return
        }

        switch pipMode {
        case .videoCall:
            logSceneState(prefix: "enterBackgroundIfNeeded videoCall")
            let floatVisible = WindowManger.instance.isCallFloatWindowVisible()
            CallPipLogger.log(
                "enterBackgroundIfNeeded videoCall floatVisible=\(floatVisible) "
                    + "sourceWindow=\(pipSourceVideoCallView?.window != nil)"
            )
            if floatVisible {
                relocateForFloatWindowIfNeeded()
            }
            promotePipSourceViewForInlineDisplay()
            startPipSourceCustomRender(userId: userId)
            if pipController?.isPictureInPicturePossible != true {
                CallPipLogger.log(
                    "enterBackgroundIfNeeded videoCall rebuilding pip controller "
                        + "isPossible=false floatVisible=\(floatVisible)"
                )
                relocateForFloatWindowIfNeeded()
            }
            if #available(iOS 16.0, *), !isPrepared, !shouldSkipInlinePipRebind() {
                ensureVideoCallPipReady(userId: userId)
            }
            if pipController?.isPictureInPicturePossible == true {
                tryStartInlineVideoPictureInPicture(reason: "enterBackgroundVideoCall")
            }
            CallPipLogger.log(
                "enterBackgroundIfNeeded videoCall relying on automatic inline PiP "
                    + "isPossible=\(pipController?.isPictureInPicturePossible ?? false) "
                    + "sourceWindow=\(pipSourceVideoCallView?.window != nil) "
                    + "renderFrames=\(renderFrameCount) enqueuedFrames=\(enqueuedFrameCount)"
            )
        case .audioCall:
            logSceneState(prefix: "enterBackgroundIfNeeded audioCall")
            promoteAudioPipSourceViewForDisplay()
            if #available(iOS 16.0, *) {
                if !isPrepared {
                    ensureAudioCallPipReady()
                }
            }
            CallPipLogger.log(
                "enterBackgroundIfNeeded audioCall relying on automatic inline PiP "
                    + "isPossible=\(pipController?.isPictureInPicturePossible ?? false)"
            )
        case .sampleBuffer:
            logSceneState(prefix: "enterBackgroundIfNeeded sampleBuffer")
            pendingPipStart = true
            startCustomRender(userId: userId, keepInlineView: false)
            if isSceneForegroundActive(), pipController?.isPictureInPicturePossible == true {
                tryStartPictureInPicture(reason: "enterBackgroundSampleBufferFallback")
            } else {
                CallPipLogger.log("enterBackgroundIfNeeded sampleBuffer relying on automatic inline PiP")
            }
        }
    }

    func enterForegroundIfNeeded() {
        CallPipLogger.log("enterForegroundIfNeeded mode=\(pipMode) renderFrames=\(renderFrameCount)")
        pendingPipStart = false
        stopPictureInPictureIfNeeded()
        if pipMode == .videoCall {
            restorePipSourceViewToInlineParent()
        } else if pipMode == .audioCall {
            restoreAudioPipSourceViewToHost()
        } else if pipMode == .sampleBuffer {
            stopCustomRender()
        }
        if useSampleBufferFallback {
            CallPipLogger.log("enterForegroundIfNeeded reset sampleBuffer fallback to videoCall")
            useSampleBufferFallback = false
            if let userId = remoteUserId, #available(iOS 16.0, *) {
                pipMode = .videoCall
                pipController = nil
                pipVideoCallViewController = nil
                hostView?.removeFromSuperview()
                hostView = nil
                pipDisplayLayer?.removeFromSuperlayer()
                pipDisplayLayer = nil
                ensureVideoCallPipReady(userId: userId)
            }
        }
    }

    // MARK: - Setup

    private var pipSourceDisplayLayer: AVSampleBufferDisplayLayer? {
        pipSourceVideoCallView?.sampleBufferDisplayLayer
    }

    @available(iOS 16.0, *)
    private func ensureAudioCallPipReady() {
        if pipAudioSourceView == nil {
            pipAudioSourceView = PipAudioCallSourceView(frame: CGRect(x: 0, y: 0, width: 240, height: 320))
        }
        pipAudioSourceView?.configureFromCallState()

        guard let sourceView = pipAudioSourceView,
              let hostWindow = resolveHostWindow() else {
            CallPipLogger.log("ensureAudioCallPipReady aborted: missing source/host")
            return
        }

        if sourceView.superview !== hostWindow {
            sourceView.removeFromSuperview()
            hostWindow.insertSubview(sourceView, at: 0)
        }
        sourceView.bounds = CGRect(x: 0, y: 0, width: 240, height: 320)
        sourceView.center = CGPoint(x: hostWindow.bounds.midX, y: hostWindow.bounds.midY)
        sourceView.autoresizingMask = [
            UIView.AutoresizingMask.flexibleLeftMargin,
            UIView.AutoresizingMask.flexibleRightMargin,
            UIView.AutoresizingMask.flexibleTopMargin,
            UIView.AutoresizingMask.flexibleBottomMargin,
        ]
        sourceView.isHidden = false
        sourceView.alpha = 0.01

        if videoCallSourceView !== sourceView || pipController == nil {
            setupVideoCallPipController(sourceView: sourceView)
            restoreAudioPipSourceViewToHost()
        }

        isPrepared = pipController != nil
        logPipSourceState(prefix: "ensureAudioCallPipReady done")
    }

    private func promoteAudioPipSourceViewForDisplay() {
        guard let sourceView = pipAudioSourceView else { return }
        sourceView.configureFromCallState()
        sourceView.isHidden = false
        sourceView.alpha = 1
        sourceView.superview?.bringSubviewToFront(sourceView)
        CallPipLogger.log(
            "promoteAudioPipSourceViewForDisplay bounds=\(sourceView.bounds) "
                + "window=\(sourceView.window != nil)"
        )
    }

    private func restoreAudioPipSourceViewToHost() {
        guard let sourceView = pipAudioSourceView,
              let hostWindow = resolveHostWindow() else {
            CallPipLogger.log("restoreAudioPipSourceViewToHost aborted: missing source/host")
            return
        }
        sourceView.removeFromSuperview()
        hostWindow.insertSubview(sourceView, at: 0)
        sourceView.center = CGPoint(x: hostWindow.bounds.midX, y: hostWindow.bounds.midY)
        sourceView.alpha = 0.01
        CallPipLogger.log("restoreAudioPipSourceViewToHost")
    }

    func relocateForFloatWindowIfNeeded() {
        guard pipMode == .videoCall else {
            CallPipLogger.log("relocateForFloatWindowIfNeeded skipped: mode=\(pipMode)")
            return
        }
        guard let userId = remoteUserId, !userId.isEmpty else {
            CallPipLogger.log("relocateForFloatWindowIfNeeded aborted: no remote user")
            return
        }
        if shouldSkipInlinePipRebind() {
            CallPipLogger.log("relocateForFloatWindowIfNeeded skipped: pip lifecycle lock")
            return
        }
        CallPipLogger.log(
            "relocateForFloatWindowIfNeeded begin floatVisible=\(WindowManger.instance.isCallFloatWindowVisible()) "
                + "isPossible=\(pipController?.isPictureInPicturePossible ?? false) "
                + "renderFrames=\(renderFrameCount)"
        )
        guard let parent = ensurePipInlineHostView() else {
            CallPipLogger.log("relocateForFloatWindowIfNeeded aborted: no inline host")
            return
        }
        attachPipSourceViewToInlineParent(parent)
        promotePipSourceViewForInlineDisplay()
        startPipSourceCustomRender(userId: userId)
        if pipController == nil || pipController?.isPictureInPicturePossible != true {
            guard let sourceView = pipSourceVideoCallView else {
                CallPipLogger.log("relocateForFloatWindowIfNeeded aborted: missing source view")
                return
            }
            if #available(iOS 16.0, *) {
                setupVideoCallPipController(sourceView: sourceView)
                isPrepared = pipController != nil
                logPipSourceState(prefix: "relocateForFloatWindow rebuild")
            }
        } else {
            logPipSourceState(prefix: "relocateForFloatWindow done")
        }
    }

    private func shouldSkipInlinePipRebind() -> Bool {
        if isPipTransitionInProgress {
            return true
        }
        if isPipActive {
            return true
        }
        if pipController?.isPictureInPictureActive == true {
            return true
        }
        return false
    }

    @available(iOS 16.0, *)
    private func ensureVideoCallPipReady(userId: String, attempt: Int = 0) {
        if shouldSkipInlinePipRebind() {
            CallPipLogger.log("ensureVideoCallPipReady skipped: pip lifecycle lock")
            startPipSourceCustomRender(userId: userId)
            return
        }

        let remoteView = resolvePipInlineParentView()
        let remoteReady: Bool
        if let remoteView {
            remoteReady = isRemoteViewReadyForPip(remoteView)
        } else {
            remoteReady = false
        }
        let hasAttachedSource = pipSourceVideoCallView?.superview != nil

        guard let remoteView, remoteReady || hasAttachedSource else {
            if attempt < 30 {
                CallPipLogger.log(
                    "ensureVideoCallPipReady waiting attempt=\(attempt) "
                        + "remoteView=\(remoteView != nil) remoteReady=\(remoteReady) "
                        + "hasAttachedSource=\(hasAttachedSource)"
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.ensureVideoCallPipReady(userId: userId, attempt: attempt + 1)
                }
            } else {
                CallPipLogger.log("ensureVideoCallPipReady gave up after \(attempt) attempts")
            }
            return
        }

        attachPipSourceViewToInlineParent(remoteView)
        promotePipSourceViewForInlineDisplay()

        guard let sourceView = pipSourceVideoCallView else {
            CallPipLogger.log("ensureVideoCallPipReady aborted: source view not ready")
            return
        }

        if videoCallSourceView !== sourceView || pipController == nil {
            setupVideoCallPipController(sourceView: sourceView)
        }

        isPrepared = pipController != nil
        startPipSourceCustomRender(userId: userId)
        logPipSourceState(prefix: "ensureVideoCallPipReady done")
    }

    private func attachPipSourceViewToInlineParent(_ remoteView: UIView) {
        if shouldSkipInlinePipRebind() {
            CallPipLogger.log("attachPipSourceViewToInlineParent skipped: pip lifecycle lock")
            return
        }

        if pipSourceVideoCallView == nil {
            pipSourceVideoCallView = PipSampleBufferVideoCallView(frame: remoteView.bounds)
        }
        guard let sourceView = pipSourceVideoCallView else { return }

        if sourceView.superview !== remoteView {
            sourceView.removeFromSuperview()
            remoteView.addSubview(sourceView)
            CallPipLogger.log(
                "attachPipSourceViewToInlineParent remoteBounds=\(remoteView.bounds) sourceView=\(sourceView)"
            )
        }
        if sourceView.frame != remoteView.bounds {
            sourceView.frame = remoteView.bounds
        }
        promotePipSourceViewForInlineDisplay()
    }

    private func promotePipSourceViewForInlineDisplay() {
        guard let sourceView = pipSourceVideoCallView else { return }
        if shouldSkipInlinePipRebind() {
            sourceView.isHidden = false
            sourceView.alpha = 1
            CallPipLogger.log(
                "promotePipSourceViewForInlineDisplay skipped rebind: pip lifecycle lock "
                    + "bounds=\(sourceView.bounds)"
            )
            return
        }
        if let remoteView = sourceView.superview,
           isViewInActiveWindowHierarchy(remoteView) {
            remoteView.bringSubviewToFront(sourceView)
        } else if let remoteView = resolvePipInlineParentView() {
            CallPipLogger.log(
                "promotePipSourceViewForInlineDisplay rebind "
                    + "oldSuperview=\(sourceView.superview != nil) "
                    + "oldWindow=\(sourceView.window != nil)"
            )
            attachPipSourceViewToInlineParent(remoteView)
        }
        sourceView.isHidden = false
        sourceView.alpha = 1
        CallPipLogger.log(
            "promotePipSourceViewForInlineDisplay superview=\(sourceView.superview != nil) "
                + "bounds=\(sourceView.bounds) window=\(sourceView.window != nil)"
        )
    }

    private func attachPipSourceViewToContentController() {
        guard let sourceView = activeInlinePipSourceView(),
              let contentVC = pipVideoCallViewController else {
            CallPipLogger.log("attachPipSourceViewToContentController aborted: missing source/contentVC")
            return
        }
        sourceView.removeFromSuperview()
        sourceView.frame = contentVC.view.bounds
        sourceView.autoresizingMask = [
            UIView.AutoresizingMask.flexibleWidth,
            UIView.AutoresizingMask.flexibleHeight,
        ]
        contentVC.view.addSubview(sourceView)
        CallPipLogger.log(
            "attachPipSourceViewToContentController contentBounds=\(contentVC.view.bounds) "
                + "subviews=\(contentVC.view.subviews.count)"
        )
    }

    private func activeInlinePipSourceView() -> UIView? {
        switch pipMode {
        case .audioCall:
            return pipAudioSourceView
        case .videoCall:
            return pipSourceVideoCallView
        case .sampleBuffer:
            return nil
        }
    }

    private func restorePipSourceViewToInlineParent() {
        if shouldSkipInlinePipRebind() {
            CallPipLogger.log("restorePipSourceViewToInlineParent skipped: pip lifecycle lock")
            return
        }
        guard let sourceView = pipSourceVideoCallView,
              let remoteView = resolvePipInlineParentView() else {
            CallPipLogger.log("restorePipSourceViewToInlineParent aborted: missing source/remoteView")
            return
        }
        attachPipSourceViewToInlineParent(remoteView)
        promotePipSourceViewForInlineDisplay()
        CallPipLogger.log("restorePipSourceViewToInlineParent")
    }

    private func isRemoteViewReadyForPip(_ view: UIView) -> Bool {
        view.bounds.width > 1 && view.bounds.height > 1
    }

    @available(iOS 16.0, *)
    private func setupVideoCallPipController(sourceView: UIView) {
        pipController = nil
        pipVideoCallViewController = nil

        let contentVC = AVPictureInPictureVideoCallViewController()
        contentVC.preferredContentSize = CGSize(width: 9, height: 16)
        contentVC.view.addSubview(sourceView)
        sourceView.frame = contentVC.view.bounds
        sourceView.autoresizingMask = [
            UIView.AutoresizingMask.flexibleWidth,
            UIView.AutoresizingMask.flexibleHeight,
        ]

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: contentVC
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
        pipVideoCallViewController = contentVC
        videoCallSourceView = sourceView

        if pipMode == .videoCall, let remoteView = resolvePipInlineParentView() {
            attachPipSourceViewToInlineParent(remoteView)
            promotePipSourceViewForInlineDisplay()
        }

        CallPipLogger.log(
            "setupVideoCallPipController sourceView=\(sourceView) bounds=\(sourceView.bounds) "
                + "window=\(sourceView.window != nil) contentSubviews=\(contentVC.view.subviews.count) "
                + "isPossible=\(controller.isPictureInPicturePossible)"
        )
        logPipSourceState(prefix: "setupVideoCallPipController")
    }

    private func shouldRetainVideoCallController() -> Bool {
        guard pipMode == .videoCall,
              pipController != nil,
              let sourceView = pipSourceVideoCallView,
              videoCallSourceView === sourceView else {
            return false
        }
        guard let remoteView = resolvePipInlineParentView() else {
            return false
        }
        if sourceView.superview === remoteView,
           isRemoteViewReadyForPip(remoteView),
           isViewInActiveWindowHierarchy(remoteView) {
            return true
        }
        if isPipActive, pipVideoCallViewController?.view.subviews.contains(sourceView) == true {
            return true
        }
        return false
    }

    private func switchToSampleBufferFallback(userId: String) {
        CallPipLogger.log("switchToSampleBufferFallback userId=\(userId)")
        useSampleBufferFallback = true
        pipController = nil
        pipVideoCallViewController = nil
        videoCallSourceView = nil
        pipSourceVideoCallView?.removeFromSuperview()
        pipSourceVideoCallView = nil
        stopCustomRender()
        setupSampleBufferPipController()
        pipMode = .sampleBuffer
        isPrepared = pipController != nil
        pendingPipStart = true
        startCustomRender(userId: userId, keepInlineView: false)
    }

    private func setupSampleBufferPipController() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            CallPipLogger.log("setupSampleBufferPipController aborted: unsupported")
            return
        }

        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = AVLayerVideoGravity.resizeAspect
        layer.isOpaque = true
        layer.backgroundColor = UIColor.black.cgColor

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        container.alpha = 0
        container.isUserInteractionEnabled = false
        container.clipsToBounds = true
        layer.frame = container.bounds
        container.layer.addSublayer(layer)
        if let hostWindow = resolveHostWindow() {
            hostWindow.insertSubview(container, at: 0)
            CallPipLogger.log("setupSampleBufferPipController attached hostWindow=\(hostWindow)")
        } else {
            CallPipLogger.log("setupSampleBufferPipController warning: host window not found")
        }
        hostView = container
        pipDisplayLayer = layer

        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: layer,
            playbackDelegate: self
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
        CallPipLogger.log(
            "setupSampleBufferPipController isPossible=\(controller.isPictureInPicturePossible)"
        )
    }

    private func resolvePipInlineParentView() -> UIView? {
        if WindowManger.instance.isCallFloatWindowVisible() {
            if let floatView = WindowManger.instance.activeFloatRemoteVideoView(),
               floatView.window != nil,
               isRemoteViewReadyForPip(floatView) {
                CallPipLogger.log(
                    "resolvePipInlineParentView using floatRemoteView bounds=\(floatView.bounds) "
                        + "window=true"
                )
                return floatView
            }
            if let host = ensurePipInlineHostView() {
                CallPipLogger.log(
                    "resolvePipInlineParentView using pipInlineHost bounds=\(host.bounds) "
                        + "window=\(host.window != nil)"
                )
                return host
            }
            CallPipLogger.log("resolvePipInlineParentView floatVisible but no host found")
        }

        if let platformView = resolvePlatformRemoteVideoView(),
           isViewInActiveWindowHierarchy(platformView),
           isRemoteViewReadyForPip(platformView) {
            let area = platformView.bounds.width * platformView.bounds.height
            if area >= 40_000 {
                CallPipLogger.log(
                    "resolvePipInlineParentView using platformView bounds=\(platformView.bounds) "
                        + "window=true"
                )
                return platformView
            }
            CallPipLogger.log(
                "resolvePipInlineParentView platformView too small bounds=\(platformView.bounds)"
            )
        } else if let platformView = resolvePlatformRemoteVideoView() {
            CallPipLogger.log(
                "resolvePipInlineParentView skip inactive platformView bounds=\(platformView.bounds) "
                    + "window=\(platformView.window != nil)"
            )
        }
        return ensurePipInlineHostView()
    }

    private func isViewInActiveWindowHierarchy(_ view: UIView) -> Bool {
        guard view.window != nil else {
            return false
        }
        guard let activeScene = resolveActiveWindowScene() else {
            return true
        }
        return view.window?.windowScene === activeScene
    }

    private func resolvePipHostWindow() -> UIWindow? {
        if let floatHost = WindowManger.instance.pipHostWindow() {
            CallPipLogger.log(
                "resolvePipHostWindow using floatWindow frame=\(floatHost.frame) "
                    + "hidden=\(floatHost.isHidden)"
            )
            return floatHost
        }
        if let host = resolveHostWindow() {
            CallPipLogger.log("resolvePipHostWindow using keyWindow frame=\(host.frame)")
            return host
        }
        CallPipLogger.log("resolvePipHostWindow aborted: no host window")
        return nil
    }

    private func ensurePipInlineHostView() -> UIView? {
        guard let hostWindow = resolvePipHostWindow() else {
            CallPipLogger.log("ensurePipInlineHostView aborted: host window not found")
            return nil
        }
        if pipInlineHostView == nil {
            let container = UIView(frame: hostWindow.bounds)
            container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            container.isUserInteractionEnabled = false
            container.clipsToBounds = true
            container.backgroundColor = .black
            hostWindow.insertSubview(container, at: 0)
            pipInlineHostView = container
            CallPipLogger.log(
                "ensurePipInlineHostView created bounds=\(container.bounds) "
                    + "window=\(container.window != nil)"
            )
        } else if let container = pipInlineHostView {
            if container.superview !== hostWindow {
                container.removeFromSuperview()
                hostWindow.insertSubview(container, at: 0)
                CallPipLogger.log("ensurePipInlineHostView moved to new hostWindow")
            }
            container.frame = hostWindow.bounds
            CallPipLogger.log(
                "ensurePipInlineHostView reused bounds=\(container.bounds) "
                    + "window=\(container.window != nil)"
            )
        }
        return pipInlineHostView
    }

    private func resolvePlatformRemoteVideoView() -> UIView? {
        if let remoteUser = TUICallState.instance.remoteUserList.value.first {
            let viewId = remoteUser.viewID.value
            if viewId > 0,
               let platformView = PlatformVideoViewFactory.videoViewMap[String(viewId)] {
                return platformView.videoView
            }
        }

        let selfViewId = TUICallState.instance.selfUser.value.viewID.value
        var bestView: UIView?
        var bestArea: CGFloat = 0
        for (viewId, platformView) in PlatformVideoViewFactory.videoViewMap {
            if viewId == String(selfViewId) {
                continue
            }
            let view = platformView.videoView
            let area = view.bounds.width * view.bounds.height
            if area > bestArea {
                bestArea = area
                bestView = view
            }
        }
        return bestView
    }

    private func resolveHostWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let activeScene = scenes.first(where: { scene in
            let state = scene.activationState
            return state == UIScene.ActivationState.foregroundActive
                || state == UIScene.ActivationState.foregroundInactive
        })
        if let windowScene = activeScene {
            if let key = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return key
            }
            return windowScene.windows.first
        }
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
    }

    private func configureAudioSessionForPip() {
        let session = AVAudioSession.sharedInstance()
        let mediaType = TUICallState.instance.mediaType.value
        let mode: AVAudioSession.Mode = mediaType == .audio ? .voiceChat : .videoChat
        do {
            try session.setCategory(.playAndRecord, mode: mode, options: [.allowBluetooth, .defaultToSpeaker])
            try session.setActive(true)
            CallPipLogger.log("configureAudioSessionForPip ok category=playAndRecord mode=\(mode.rawValue)")
        } catch {
            CallPipLogger.log("configureAudioSessionForPip failed error=\(error.localizedDescription)")
        }
    }

    // MARK: - Render

    private func startPipSourceCustomRender(userId: String) {
        guard pipMode == .videoCall else { return }
        if isCustomRenderActive { return }
        CallPipLogger.log("startPipSourceCustomRender userId=\(userId) pixelFormat=32BGRA")
        trtcCloud.setRemoteVideoRenderDelegate(
            userId,
            delegate: self,
            pixelFormat: ._32BGRA,
            bufferType: .pixelBuffer
        )
        isCustomRenderActive = true
    }

    private func startCustomRender(userId: String, keepInlineView: Bool = false) {
        guard pipMode == .sampleBuffer else { return }
        if isCustomRenderActive, keepInlineView {
            return
        }
        if isCustomRenderActive {
            trtcCloud.setRemoteVideoRenderDelegate(
                userId,
                delegate: nil,
                pixelFormat: ._NV12,
                bufferType: .pixelBuffer
            )
            isCustomRenderActive = false
        }
        CallPipLogger.log("startCustomRender userId=\(userId) keepInlineView=\(keepInlineView)")
        if !keepInlineView {
            TUICallEngine.createInstance().stopRemoteView(userId: userId)
            trtcCloud.startRemoteView(userId, streamType: .big, view: nil)
        }
        trtcCloud.setRemoteVideoRenderDelegate(
            userId,
            delegate: self,
            pixelFormat: ._NV12,
            bufferType: .pixelBuffer
        )
        isCustomRenderActive = true
    }

    private func stopCustomRender() {
        guard isCustomRenderActive, let userId = remoteUserId else { return }
        CallPipLogger.log("stopCustomRender userId=\(userId) mode=\(pipMode)")
        trtcCloud.setRemoteVideoRenderDelegate(
            userId,
            delegate: nil,
            pixelFormat: ._NV12,
            bufferType: .pixelBuffer
        )
        isCustomRenderActive = false
        renderFrameCount = 0
        enqueuedFrameCount = 0
        presentationTime = .zero
        lastEnqueueError = nil
    }

    private func tryStartPictureInPicture(reason: String) {
        guard pipMode == .sampleBuffer else {
            CallPipLogger.log("tryStartPictureInPicture(\(reason)) skipped: video/audio call uses automatic PiP only")
            return
        }
        guard let controller = pipController else { return }
        guard !controller.isPictureInPictureActive else { return }
        guard controller.isPictureInPicturePossible else {
            pendingPipStart = true
            return
        }
        guard isSceneForegroundActive() else {
            pendingPipStart = true
            return
        }
        logSceneState(prefix: "tryStartPictureInPicture(\(reason))")
        controller.startPictureInPicture()
        CallPipLogger.log("tryStartPictureInPicture(\(reason)) invoked")
    }

    private func tryStartInlineVideoPictureInPicture(reason: String) {
        guard pipMode == .videoCall || pipMode == .audioCall else {
            return
        }
        guard let controller = pipController else {
            CallPipLogger.log("tryStartInlineVideoPictureInPicture(\(reason)) skipped: no controller")
            return
        }
        guard !controller.isPictureInPictureActive else {
            CallPipLogger.log("tryStartInlineVideoPictureInPicture(\(reason)) skipped: already active")
            return
        }
        guard controller.isPictureInPicturePossible else {
            CallPipLogger.log(
                "tryStartInlineVideoPictureInPicture(\(reason)) skipped: not possible "
                    + "sourceWindow=\(pipSourceVideoCallView?.window != nil)"
            )
            return
        }
        logSceneState(prefix: "tryStartInlineVideoPictureInPicture(\(reason))")
        controller.startPictureInPicture()
        CallPipLogger.log("tryStartInlineVideoPictureInPicture(\(reason)) invoked")
    }

    private func isSceneForegroundActive() -> Bool {
        let windowScene = resolveActiveWindowScene()
        guard let windowScene else {
            return UIApplication.shared.applicationState == .active
        }
        return windowScene.activationState == UIScene.ActivationState.foregroundActive
    }

    private func resolveActiveWindowScene() -> UIWindowScene? {
        if let scene = pipSourceVideoCallView?.window?.windowScene {
            return scene
        }
        if let scene = pipAudioSourceView?.window?.windowScene {
            return scene
        }
        if let scene = videoCallSourceView?.window?.windowScene {
            return scene
        }
        if let scene = hostView?.window?.windowScene {
            return scene
        }
        return resolveHostWindow()?.windowScene
    }

    private func logSceneState(prefix: String) {
        let appState = UIApplication.shared.applicationState.rawValue
        var sceneState = -1
        if let raw = pipSourceVideoCallView?.window?.windowScene?.activationState.rawValue {
            sceneState = raw
        } else if let raw = videoCallSourceView?.window?.windowScene?.activationState.rawValue {
            sceneState = raw
        } else if let raw = hostView?.window?.windowScene?.activationState.rawValue {
            sceneState = raw
        } else if let raw = resolveHostWindow()?.windowScene?.activationState.rawValue {
            sceneState = raw
        }
        let layerStatus: String
        if let layer = pipSourceDisplayLayer {
            layerStatus = describeLayerStatus(layer)
        } else {
            layerStatus = "nil"
        }
        let isPossible = pipController?.isPictureInPicturePossible ?? false
        let parent: String
        if let superview = pipSourceVideoCallView?.superview {
            parent = String(describing: superview)
        } else {
            parent = "nil"
        }
        CallPipLogger.log(
            "\(prefix) appState=\(appState) sceneState=\(sceneState) "
                + "isPossible=\(isPossible) layer=\(layerStatus) parent=\(parent) "
                + "renderFrames=\(renderFrameCount) enqueuedFrames=\(enqueuedFrameCount) "
                + "lastEnqueueError=\(lastEnqueueError ?? "nil")"
        )
    }

    private func logPipSourceState(prefix: String) {
        let sourceView = activeInlinePipSourceView()
        let layer = pipSourceDisplayLayer
        let width = sourceView?.bounds.width ?? 0
        let height = sourceView?.bounds.height ?? 0
        let superviewName: String
        if let superview = sourceView?.superview {
            superviewName = String(describing: type(of: superview))
        } else {
            superviewName = "nil"
        }
        let inContentVC: Bool = {
            guard let sourceView, let contentVC = pipVideoCallViewController else { return false }
            return contentVC.view.subviews.contains(sourceView)
        }()
        let layerDesc: String
        if let layer = layer {
            layerDesc = describeLayerStatus(layer)
        } else {
            layerDesc = "nil"
        }
        CallPipLogger.log(
            "\(prefix) sourceBounds=\(width)x\(height) superview=\(superviewName) "
                + "inContentVC=\(inContentVC) sourceWindow=\(sourceView?.window != nil) "
                + "layer=\(layerDesc) "
                + "isPipActive=\(isPipActive) isPossible=\(pipController?.isPictureInPicturePossible ?? false)"
        )
    }

    private func describeLayerStatus(_ layer: AVSampleBufferDisplayLayer) -> String {
        let statusText: String
        switch layer.status {
        case .unknown:
            statusText = "unknown"
        case .rendering:
            statusText = "rendering"
        case .failed:
            statusText = "failed"
        @unknown default:
            statusText = "other(\(layer.status.rawValue))"
        }
        let errorText = layer.error.map { ($0 as NSError).localizedDescription } ?? "nil"
        return "\(statusText)(\(layer.status.rawValue)) error=\(errorText)"
    }

    private func stopPictureInPictureIfNeeded() {
        guard let controller = pipController, controller.isPictureInPictureActive else { return }
        CallPipLogger.log("stopPictureInPicture")
        controller.stopPictureInPicture()
    }

    private func enableBackgroundDecoding(_ enable: Bool) {
        callTrtcExperimentalAPI("enableBackgroundDecoding", enable: enable)
    }

    private func callTrtcExperimentalAPI(_ api: String, enable: Bool) {
        let param: [String: Any] = [
            "api": api,
            "params": ["enable": enable],
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: param),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            CallPipLogger.log("callTrtcExperimentalAPI(\(api)) json encode failed")
            return
        }
        trtcCloud.callExperimentalAPI(jsonString)
        CallPipLogger.log("callTrtcExperimentalAPI(\(api)) enable=\(enable)")
    }

    private func displayPixelBuffer(_ pixelBuffer: CVPixelBuffer, in layer: AVSampleBufferDisplayLayer) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        var timing = CMSampleTimingInfo(
            duration: frameDuration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        presentationTime = CMTimeAdd(presentationTime, frameDuration)

        var videoInfo: CMVideoFormatDescription?
        let createDesc = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &videoInfo
        )
        guard createDesc == noErr, let videoInfo else {
            lastEnqueueError = "createFormatDescription failed code=\(createDesc)"
            if enqueuedFrameCount == 0 || enqueuedFrameCount % 30 == 0 {
                CallPipLogger.log(
                    "displayPixelBuffer failed createDesc=\(createDesc) "
                        + "size=\(width)x\(height) format=\(pixelFormat)"
                )
            }
            return
        }

        var sampleBuffer: CMSampleBuffer?
        let createSample = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: videoInfo,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard createSample == noErr, let sampleBuffer else {
            lastEnqueueError = "createSampleBuffer failed code=\(createSample)"
            if enqueuedFrameCount == 0 || enqueuedFrameCount % 30 == 0 {
                CallPipLogger.log(
                    "displayPixelBuffer failed createSample=\(createSample) "
                        + "size=\(width)x\(height) format=\(pixelFormat)"
                )
            }
            return
        }

        if layer.status == .failed {
            let error = (layer.error as NSError?)?.localizedDescription ?? "nil"
            CallPipLogger.log("displayPixelBuffer flushing failed layer error=\(error)")
            layer.flushAndRemoveImage()
            presentationTime = .zero
        }

        layer.enqueue(sampleBuffer)
        enqueuedFrameCount += 1
        lastEnqueueError = nil

        if enqueuedFrameCount == 1 || enqueuedFrameCount % 30 == 0 {
            CallPipLogger.log(
                "displayPixelBuffer enqueued=\(enqueuedFrameCount) size=\(width)x\(height) "
                    + "format=\(pixelFormat) pts=\(presentationTime.value) "
                    + "layer=\(describeLayerStatus(layer))"
            )
        }
    }

    private func logPipError(_ error: Error, prefix: String) {
        let nsError = error as NSError
        CallPipLogger.log(
            "\(prefix) domain=\(nsError.domain) code=\(nsError.code) "
                + "description=\(nsError.localizedDescription) "
                + "reason=\(nsError.localizedFailureReason ?? "nil")"
        )
    }
}

@available(iOS 15.0, *)
extension CallPictureInPictureManager: TRTCVideoRenderDelegate {
    func onRenderVideoFrame(_ frame: TRTCVideoFrame, userId: String?, streamType: TRTCVideoStreamType) {
        let targetLayer: AVSampleBufferDisplayLayer?
        switch pipMode {
        case .videoCall:
            targetLayer = pipSourceDisplayLayer
        case .sampleBuffer:
            targetLayer = pipDisplayLayer
        case .audioCall:
            targetLayer = nil
        }
        guard let pixelBuffer = frame.pixelBuffer, let layer = targetLayer else {
            return
        }
        renderFrameCount += 1
        if renderFrameCount == 1 || renderFrameCount % 30 == 0 {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
            CallPipLogger.log(
                "onRenderVideoFrame mode=\(pipMode) count=\(renderFrameCount) userId=\(userId ?? "nil") "
                    + "size=\(width)x\(height) format=\(format) pipActive=\(self.isPipActive)"
            )
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.displayPixelBuffer(pixelBuffer, in: layer)
            if self.pipMode == .videoCall, self.enqueuedFrameCount == 1 {
                self.promotePipSourceViewForInlineDisplay()
                self.logPipSourceState(prefix: "firstVideoFrame")
            }
            if self.pipMode == .sampleBuffer,
               self.pendingPipStart,
               let controller = self.pipController,
               !controller.isPictureInPictureActive {
                self.tryStartPictureInPicture(reason: "firstFrame")
            }
        }
    }
}

@available(iOS 15.0, *)
extension CallPictureInPictureManager: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPipTransitionInProgress = true
        CallPipLogger.log("pictureInPictureWillStart mode=\(pipMode)")
        if pipMode == .videoCall || pipMode == .audioCall {
            attachPipSourceViewToContentController()
            logPipSourceState(prefix: "pictureInPictureWillStart")
        }
    }

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPipTransitionInProgress = false
        isPipActive = true
        pendingPipStart = false
        CallPipLogger.log("pictureInPictureDidStart mode=\(pipMode)")
        logPipSourceState(prefix: "pictureInPictureDidStart")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPipTransitionInProgress = false
        isPipActive = false
        CallPipLogger.log("pictureInPictureDidStop mode=\(pipMode)")
        if pipMode == .videoCall {
            restorePipSourceViewToInlineParent()
            logPipSourceState(prefix: "pictureInPictureDidStop")
        } else if pipMode == .audioCall {
            restoreAudioPipSourceViewToHost()
            logPipSourceState(prefix: "pictureInPictureDidStop")
        }
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        CallPipLogger.log("pictureInPictureRestoreUI")
        completionHandler(true)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        isPipTransitionInProgress = false
        logPipError(error, prefix: "pictureInPictureFailed mode=\(pipMode)")
    }
}

@available(iOS 15.0, *)
extension CallPictureInPictureManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {}

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        false
    }

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        CMTimeRange(start: .zero, duration: .positiveInfinity)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime
    ) async {}
}

enum CallPictureInPictureBridge {
    static func prepareIfNeeded() {
        if #available(iOS 15.0, *) {
            CallPictureInPictureManager.shared.prepareIfNeeded()
        } else {
            CallPipLogger.log("prepareIfNeeded skipped: iOS < 15")
        }
    }

    static func teardown() {
        if #available(iOS 15.0, *) {
            CallPictureInPictureManager.shared.teardown()
        }
    }

    static func enterBackgroundIfNeeded() {
        if #available(iOS 15.0, *) {
            CallPictureInPictureManager.shared.enterBackgroundIfNeeded()
        } else {
            CallPipLogger.log("enterBackgroundIfNeeded skipped: iOS < 15")
        }
    }

    static func enterForegroundIfNeeded() {
        if #available(iOS 15.0, *) {
            CallPictureInPictureManager.shared.enterForegroundIfNeeded()
        }
    }

    static func relocateForFloatWindowIfNeeded() {
        if #available(iOS 15.0, *) {
            CallPictureInPictureManager.shared.relocateForFloatWindowIfNeeded()
        }
    }
}
