import AVFoundation
import AVKit
import Foundation
import UIKit
import WebRTC

/// System PiP for LiveKit video calls when the app backgrounds.
///
/// Renders real WebRTC frames into `AVPictureInPictureVideoCallViewController`
/// via a secondary `RTCVideoRenderer` → `AVSampleBufferDisplayLayer` pipeline.
@available(iOS 15.0, *)
final class LiveKitCallPip: NSObject, AVPictureInPictureControllerDelegate {
    static let shared = LiveKitCallPip()

    private var pipController: AVPictureInPictureController?
    private var pipVideoCallVC: AVPictureInPictureVideoCallViewController?
    private var sourceView: UIView?
    private var displayView: PipSampleBufferVideoCallView?
    private var fallbackLabel: UILabel?
    private var videoTrack: RTCVideoTrack?
    private var boundTrackId: String?
    private var prepared = false
    private var enabled = false
    private var peerName: String?
    private var presentationTime = CMTime.zero
    private let frameDuration = CMTime(value: 3_000, timescale: 90_000)

    private override init() {
        super.init()
    }

    func setEnabled(
        _ enabled: Bool,
        peerName: String?,
        hasVideo: Bool,
        trackId: String?
    ) {
        self.peerName = peerName
        self.enabled = enabled && hasVideo
        if !self.enabled {
            stop()
            teardown()
            return
        }
        prepareIfNeeded()
        bindTrack(trackId: trackId)
        updateFallbackLabel()
    }

    func enterBackgroundIfNeeded() {
        guard enabled else { return }
        prepareIfNeeded()
        guard let pipController = pipController,
              pipController.isPictureInPicturePossible,
              !pipController.isPictureInPictureActive else {
            return
        }
        pipController.startPictureInPicture()
        print("LiveKitCallPip: startPictureInPicture track=\(boundTrackId ?? "nil")")
    }

    func stop() {
        guard let pipController = pipController, pipController.isPictureInPictureActive else {
            return
        }
        pipController.stopPictureInPicture()
    }

    // MARK: - Prepare / teardown

    private func prepareIfNeeded() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        if prepared { return }

        guard let window = Self.keyWindow else { return }

        let source = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        source.isUserInteractionEnabled = false
        source.backgroundColor = .clear
        window.addSubview(source)
        sourceView = source

        let vc = AVPictureInPictureVideoCallViewController()
        vc.preferredContentSize = CGSize(width: 9, height: 16)

        let host = PipSampleBufferVideoCallView(frame: .zero)
        host.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            host.topAnchor.constraint(equalTo: vc.view.topAnchor),
            host.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])

        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: host.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: host.trailingAnchor, constant: -8),
        ])
        fallbackLabel = label
        displayView = host
        updateFallbackLabel()

        pipVideoCallVC = vc

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: source,
            contentViewController: vc
        )
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        pipController = controller
        prepared = true
        print("LiveKitCallPip: prepared")
    }

    private func teardown() {
        stop()
        unbindTrack()
        pipController = nil
        pipVideoCallVC = nil
        fallbackLabel = nil
        displayView = nil
        sourceView?.removeFromSuperview()
        sourceView = nil
        prepared = false
        presentationTime = .zero
        boundTrackId = nil
    }

    private func updateFallbackLabel() {
        let name = (peerName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        fallbackLabel?.text = name.isEmpty ? "视频通话中" : "\(name)\n视频通话中"
        fallbackLabel?.isHidden = videoTrack != nil
    }

    // MARK: - WebRTC track bind

    private func bindTrack(trackId: String?) {
        let id = (trackId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if id.isEmpty {
            unbindTrack()
            updateFallbackLabel()
            return
        }
        if boundTrackId == id, videoTrack != nil {
            return
        }

        guard let plugin = FlutterWebRTCPlugin.sharedSingleton() else {
            print("LiveKitCallPip: FlutterWebRTCPlugin.sharedSingleton nil")
            return
        }
        guard let mediaTrack = plugin.track(forId: id, peerConnectionId: nil),
              mediaTrack.kind == "video",
              let rtcTrack = mediaTrack as? RTCVideoTrack else {
            print("LiveKitCallPip: track not found id=\(id)")
            unbindTrack()
            updateFallbackLabel()
            return
        }

        unbindTrack()
        videoTrack = rtcTrack
        boundTrackId = id
        rtcTrack.add(self)
        updateFallbackLabel()
        print("LiveKitCallPip: bound track id=\(id)")
    }

    private func unbindTrack() {
        if let track = videoTrack {
            track.remove(self)
        }
        videoTrack = nil
        boundTrackId = nil
        displayView?.flush()
        presentationTime = .zero
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    // MARK: - AVPictureInPictureControllerDelegate

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("LiveKitCallPip: didStart")
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        print("LiveKitCallPip: didStop")
    }
}

// MARK: - RTCVideoRenderer

@available(iOS 15.0, *)
extension LiveKitCallPip: RTCVideoRenderer {
    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame else { return }

        let pixelBuffer: CVPixelBuffer?
        if let cvBuffer = frame.buffer as? RTCCVPixelBuffer {
            pixelBuffer = cvBuffer.pixelBuffer
        } else if let unmanaged = FlutterRTCFrameCapturer.convert(toCVPixelBuffer: frame) {
            // ObjC Create-rule return → take ownership once.
            pixelBuffer = unmanaged.takeRetainedValue()
        } else {
            pixelBuffer = nil
        }
        guard let pixelBuffer else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.fallbackLabel?.isHidden = true
            self.displayView?.enqueue(pixelBuffer: pixelBuffer, owner: self)
        }
    }

    fileprivate func nextTiming() -> CMSampleTimingInfo {
        let timing = CMSampleTimingInfo(
            duration: frameDuration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        presentationTime = CMTimeAdd(presentationTime, frameDuration)
        return timing
    }

    fileprivate func resetPresentationTime() {
        presentationTime = .zero
    }
}

// MARK: - Sample buffer view

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

    func flush() {
        sampleBufferDisplayLayer.flushAndRemoveImage()
    }

    func enqueue(pixelBuffer: CVPixelBuffer, owner: LiveKitCallPip) {
        if sampleBufferDisplayLayer.status == .failed {
            sampleBufferDisplayLayer.flushAndRemoveImage()
            owner.resetPresentationTime()
        }
        if sampleBufferDisplayLayer.requiresFlushToResumeDecoding {
            sampleBufferDisplayLayer.flushAndRemoveImage()
        }

        var timing = owner.nextTiming()
        var formatDesc: CMVideoFormatDescription?
        let descStatus = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )
        guard descStatus == noErr, let formatDesc else { return }

        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else { return }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true),
           CFArrayGetCount(attachments) > 0 {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        sampleBufferDisplayLayer.enqueue(sampleBuffer)
    }
}
