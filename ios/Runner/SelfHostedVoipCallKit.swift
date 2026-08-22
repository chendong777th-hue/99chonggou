import AVFoundation
import CallKit
import Flutter
import Foundation
import UIKit

/// 自建 VoIP Push 专用 CallKit。
///
/// 不能依赖 `TUIVoIPExtension.setCertificateID`：该 API 会在 Extension 内再建
/// `PKPushRegistry`，与 AppDelegate 自建 PushKit 双注册争抢同一 VoIP 推送；
/// Extension 只认腾讯 TIMPush 载荷，解析失败时不报 CallKit，表现为
///「服务端 voip push sent、手机无来电界面」。
final class SelfHostedVoipCallKit: NSObject, CXProviderDelegate {
    static let shared = SelfHostedVoipCallKit()

    private let provider: CXProvider
    private let controller = CXCallController()
    private var inviteIdToUUID: [String: UUID] = [:]
    private var uuidToInviteId: [UUID: String] = [:]
    private var uuidToHasVideo: [UUID: Bool] = [:]
    private var activeUUID: UUID?
    private var pendingActions: [UUID: CXAction] = [:]
    /// UUIDs started via [startOutgoingCall] — only those may use reportOutgoingCall(connectedAt:).
    private var outgoingUUIDs: Set<UUID> = []
    /// When true, ignore the next CallKit `didDeactivate` so ending the system
    /// UI does not `setActive(false)` on top of LiveKit's playAndRecord session.
    private var keepAudioAcrossCallKitEnd = false
    /// Survives a dropped Flutter `voipAudioSessionActivated` invoke.
    private(set) var audioSessionActivated = false

    var onAccept: ((String?, String) -> Void)?
    var onEnd: ((String?, String) -> Void)?
    var onMute: ((String?, String, Bool) -> Void)?
    var onReset: (() -> Void)?
    /// Fired after CallKit activates the shared AVAudioSession (media may start).
    var onAudioSessionActivated: ((String?) -> Void)?
    /// Fired when CallKit deactivates the session (log / bookkeeping only).
    var onAudioSessionDeactivated: ((String?) -> Void)?

    private override init() {
        let config = CXProviderConfiguration(localizedName: "99chat")
        if #available(iOS 14.0, *) {
            config.supportsVideo = true
        }
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = true
        if let icon = UIImage(named: "CallKitIcon") {
            config.iconTemplateImageData = icon.pngData()
        }
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: DispatchQueue.main)
    }

    func reportIncomingCall(
        inviteId: String?,
        callerId: String,
        callerName: String,
        hasVideo: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        let uuid: UUID
        if let inviteId = inviteId, !inviteId.isEmpty,
           let existing = inviteIdToUUID[inviteId] {
            uuid = existing
            // 已在系统通话中：按 Apple 要求仍须完成 PushKit completion，不再重复 report。
            if provider.hasActiveCall(uuid: uuid) || activeUUID == uuid {
                print(
                    "SelfHostedVoipCallKit: already reporting inviteId=\(inviteId) uuid=\(uuid)"
                )
                completion(nil)
                return
            }
        } else {
            uuid = UUID()
            if let inviteId = inviteId, !inviteId.isEmpty {
                inviteIdToUUID[inviteId] = uuid
                uuidToInviteId[uuid] = inviteId
            }
        }

        let update = CXCallUpdate()
        let handleValue = callerId.isEmpty ? "unknown" : callerId
        update.remoteHandle = CXHandle(type: .generic, value: handleValue)
        let display = callerName.trimmingCharacters(in: .whitespacesAndNewlines)
        update.localizedCallerName = display.isEmpty ? handleValue : display
        update.hasVideo = hasVideo
        update.supportsHolding = false
        uuidToHasVideo[uuid] = hasVideo
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false

        print(
            "SelfHostedVoipCallKit: reportNewIncomingCall inviteId=\(inviteId ?? "") "
                + "callerId=\(callerId) name=\(update.localizedCallerName ?? "") video=\(hasVideo)"
        )

        provider.reportNewIncomingCall(with: uuid, update: update) { [weak self] error in
            if let error = error {
                print("SelfHostedVoipCallKit: report failed \(error.localizedDescription)")
                self?.forget(uuid: uuid)
                completion(error)
                return
            }
            self?.activeUUID = uuid
            print("SelfHostedVoipCallKit: report ok uuid=\(uuid)")
            completion(nil)
        }
    }

    func endActiveCall(
        reason: CXCallEndedReason = .remoteEnded,
        keepAudioSession: Bool = false
    ) {
        guard let uuid = activeUUID else {
            // 兼容：按 invite 映射清掉残余。
            for uuid in uuidToInviteId.keys {
                provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
            }
            inviteIdToUUID.removeAll()
            uuidToInviteId.removeAll()
            return
        }
        if keepAudioSession {
            keepAudioAcrossCallKitEnd = true
        }
        provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
        forget(uuid: uuid)
        activeUUID = nil
        if !keepAudioSession {
            deactivateAudioSession()
        } else {
            print("SelfHostedVoipCallKit: endActiveCall keepAudioSession=true")
        }
    }

    func endCall(
        inviteId: String?,
        reason: CXCallEndedReason = .remoteEnded,
        keepAudioSession: Bool = false
    ) {
        if let inviteId = inviteId, !inviteId.isEmpty, let uuid = inviteIdToUUID[inviteId] {
            if keepAudioSession {
                keepAudioAcrossCallKitEnd = true
            }
            provider.reportCall(with: uuid, endedAt: Date(), reason: reason)
            forget(uuid: uuid)
            if activeUUID == uuid {
                activeUUID = nil
            }
            if !keepAudioSession {
                deactivateAudioSession()
            } else {
                print(
                    "SelfHostedVoipCallKit: endCall keepAudioSession=true inviteId=\(inviteId)"
                )
            }
            return
        }
        if inviteId == nil || inviteId?.isEmpty == true {
            endActiveCall(reason: reason, keepAudioSession: keepAudioSession)
        }
    }

    /// Start an in-app outgoing CallKit call (powers Dynamic Island / status bar).
    func startOutgoingCall(
        inviteId: String?,
        handle: String,
        displayName: String,
        hasVideo: Bool,
        completion: @escaping (Error?) -> Void
    ) {
        let id = inviteId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !id.isEmpty, let existing = inviteIdToUUID[id], activeUUID == existing {
            completion(nil)
            return
        }
        // Already in a CallKit call (e.g. answered incoming) — just keep it.
        if activeUUID != nil, id.isEmpty || inviteIdToUUID[id] == activeUUID {
            completion(nil)
            return
        }

        let uuid = UUID()
        if !id.isEmpty {
            inviteIdToUUID[id] = uuid
            uuidToInviteId[uuid] = id
        }
        activeUUID = uuid

        let handleValue = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cxHandle = CXHandle(
            type: .generic,
            value: handleValue.isEmpty ? "unknown" : handleValue
        )
        let start = CXStartCallAction(call: uuid, handle: cxHandle)
        start.isVideo = hasVideo
        uuidToHasVideo[uuid] = hasVideo
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            start.contactIdentifier = name
        }

        let tx = CXTransaction(action: start)
        controller.request(tx) { [weak self] error in
            if let error = error {
                print("SelfHostedVoipCallKit: startOutgoing failed \(error.localizedDescription)")
                self?.forget(uuid: uuid)
                if self?.activeUUID == uuid {
                    self?.activeUUID = nil
                }
                completion(error)
                return
            }
            let update = CXCallUpdate()
            update.remoteHandle = cxHandle
            update.localizedCallerName = name.isEmpty ? handleValue : name
            update.hasVideo = hasVideo
            update.supportsHolding = false
            update.supportsGrouping = false
            update.supportsUngrouping = false
            update.supportsDTMF = false
            self?.outgoingUUIDs.insert(uuid)
            self?.provider.reportCall(with: uuid, updated: update)
            print("SelfHostedVoipCallKit: startOutgoing ok uuid=\(uuid) video=\(hasVideo)")
            completion(nil)
        }
    }

    /// Mark CallKit call as connected (shows ongoing Dynamic Island for audio).
    func reportConnected(inviteId: String? = nil) {
        let uuid: UUID?
        if let inviteId = inviteId?.trimmingCharacters(in: .whitespacesAndNewlines),
           !inviteId.isEmpty {
            uuid = inviteIdToUUID[inviteId] ?? activeUUID
        } else {
            uuid = activeUUID
        }
        guard let uuid = uuid else { return }
        if outgoingUUIDs.contains(uuid) {
            provider.reportOutgoingCall(with: uuid, connectedAt: Date())
            print("SelfHostedVoipCallKit: reportConnected outgoing uuid=\(uuid)")
            return
        }
        // Incoming answered: call is already active after CXAnswerCallAction;
        // refresh update so system UI stays consistent (do not use outgoing API).
        let update = CXCallUpdate()
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        update.supportsDTMF = false
        provider.reportCall(with: uuid, updated: update)
        print("SelfHostedVoipCallKit: reportConnected incoming uuid=\(uuid)")
    }

    /// Whether this invite already has an active CallKit UUID.
    func hasActiveCall(inviteId: String?) -> Bool {
        let id = inviteId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !id.isEmpty, let uuid = inviteIdToUUID[id], activeUUID == uuid {
            return true
        }
        return activeUUID != nil && id.isEmpty
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        pendingActions.values.forEach { $0.fail() }
        pendingActions.removeAll()
        activeUUID = nil
        inviteIdToUUID.removeAll()
        uuidToInviteId.removeAll()
        outgoingUUIDs.removeAll()
        keepAudioAcrossCallKitEnd = false
        audioSessionActivated = false
        deactivateAudioSession()
        onReset?()
    }

    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        configureAudioSession()
        action.fulfill()
        provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
        activeUUID = action.callUUID
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        configureAudioSession()
        action.fulfill()
        onAccept?(uuidToInviteId[action.callUUID], action.callUUID.uuidString)
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        holdCallAction(action)
        onEnd?(uuidToInviteId[action.callUUID], action.callUUID.uuidString)
    }

    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        holdCallAction(action)
        onMute?(uuidToInviteId[action.callUUID], action.callUUID.uuidString, action.isMuted)
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        audioSessionActivated = true
        configureAudioSession()
        let uuid = activeUUID?.uuidString
        onAudioSessionActivated?(uuid)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        let uuid = activeUUID?.uuidString
        if keepAudioAcrossCallKitEnd {
            keepAudioAcrossCallKitEnd = false
            print(
                "SelfHostedVoipCallKit: didDeactivate ignored — keepAudioAcrossCallKitEnd"
            )
            // Still notify Flutter so LiveKit can re-apply route / restart renderers.
            onAudioSessionDeactivated?(uuid)
            return
        }
        audioSessionActivated = false
        deactivateAudioSession()
        onAudioSessionDeactivated?(uuid)
    }

    func completeAction(uuidString: String, succeeded: Bool) {
        // Flutter passes callUUID; actions are keyed the same way.
        guard let uuid = UUID(uuidString: uuidString),
              let action = pendingActions.removeValue(forKey: uuid) else {
            return
        }
        if succeeded {
            action.fulfill()
        } else {
            action.fail()
        }
        if action is CXEndCallAction {
            forget(uuid: uuid)
            if activeUUID == uuid {
                activeUUID = nil
            }
            deactivateAudioSession()
        }
    }

    // MARK: - Helpers

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        let isVideo = activeUUID.flatMap { uuidToHasVideo[$0] } ?? false
        do {
            var options: AVAudioSession.CategoryOptions = [
                .allowBluetooth,
                .allowBluetoothA2DP,
            ]
            if isVideo {
                options.insert(.defaultToSpeaker)
            }
            try session.setCategory(
                .playAndRecord,
                mode: isVideo ? .videoChat : .voiceChat,
                options: options
            )
            try session.setActive(true, options: [])
        } catch {
            print("SelfHostedVoipCallKit: audio session error \(error.localizedDescription)")
        }
    }

    private func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            print("SelfHostedVoipCallKit: deactivate audio session error \(error.localizedDescription)")
        }
    }

    /// Store pending CallKit actions by **callUUID** (matches Flutter complete payload).
    private func holdCallAction(_ action: CXCallAction) {
        pendingActions[action.callUUID] = action
        let callUUID = action.callUUID
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak action] in
            guard let self = self,
                  let action = action,
                  self.pendingActions.removeValue(forKey: callUUID) != nil else {
                return
            }
            action.fail()
        }
    }

    private func forget(uuid: UUID) {
        if let inviteId = uuidToInviteId.removeValue(forKey: uuid) {
            inviteIdToUUID.removeValue(forKey: inviteId)
        }
        uuidToHasVideo.removeValue(forKey: uuid)
        outgoingUUIDs.remove(uuid)
    }
}

private extension CXProvider {
    func hasActiveCall(uuid: UUID) -> Bool {
        // CXProvider 无公开查询；由上层 activeUUID / 映射表兜底。
        _ = uuid
        return false
    }
}
