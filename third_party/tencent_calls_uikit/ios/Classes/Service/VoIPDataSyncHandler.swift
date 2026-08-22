//
//  VoIPDataSyncHandler.swift
//  Pods
//
//  Created by vincepzhang on 2024/11/25.
//

import Foundation
import TUICore
import RTCRoomEngine
import UIKit
import AVFoundation

protocol VoIPDataSyncHandlerDelegate: NSObject {
    func callMethodVoipChangeMute(mute: Bool)
    func callMethodVoipChangeAudioPlaybackDevice(audioPlaybackDevice: TUIAudioPlaybackDevice)
    func callMethodVoipHangup()
    func callMethodVoipAccept()
}

class VoIPDataSyncHandler: NSObject,TUICallObserver {
    weak var voipDataSyncHandlerDelegate: VoIPDataSyncHandlerDelegate?
    private var lastVoIPGroupId = ""
    
    override init() {
        super.init()
        TUICallEngine.createInstance().addObserver(self)
    }

    func onCall(_ method: String, param: [AnyHashable : Any]) {
        if method == TUICore_TUICallingService_SetAudioPlaybackDeviceMethod {
            guard let audioPlaybackDevice = param[TUICore_TUICallingService_SetAudioPlaybackDevice_AudioPlaybackDevice]
                    as? TUIAudioPlaybackDevice else { return }
            if self.voipDataSyncHandlerDelegate != nil && ((self.voipDataSyncHandlerDelegate?.responds(to: Selector(("callMethodVoipChangeAudioPlaybackDevice")))) != nil) {
                self.voipDataSyncHandlerDelegate?.callMethodVoipChangeAudioPlaybackDevice(audioPlaybackDevice: audioPlaybackDevice)
            }
        } else if method == TUICore_TUICallingService_SetIsMicMuteMethod {
            guard let isMicMute = param[TUICore_TUICallingService_SetIsMicMuteMethod_IsMicMute]
                    as? Bool else { return }
            if self.voipDataSyncHandlerDelegate != nil && ((self.voipDataSyncHandlerDelegate?.responds(to: Selector(("callMethodVoipChangeMute")))) != nil) {
                self.voipDataSyncHandlerDelegate?.callMethodVoipChangeMute(mute: isMicMute)
            }
        }
        
        else if method == TUICore_TUICallingService_HangupMethod {
            if self.voipDataSyncHandlerDelegate != nil && ((self.voipDataSyncHandlerDelegate?.responds(to: Selector(("callMethodVoipHangup")))) != nil) {
                self.voipDataSyncHandlerDelegate?.callMethodVoipHangup()
            }
        } else if method == TUICore_TUICallingService_AcceptMethod {
            if self.voipDataSyncHandlerDelegate != nil && ((self.voipDataSyncHandlerDelegate?.responds(to: Selector(("callMethodVoipAccept")))) != nil) {
                self.voipDataSyncHandlerDelegate?.callMethodVoipAccept()
            }
        }
    }
    
    func setVoIPMuteForTUICallKitVoIPExtension(_ mute: Bool) {
        TUICore.notifyEvent(TUICore_TUICallKitVoIPExtensionNotify,
                            subKey: mute ? TUICore_TUICore_TUICallKitVoIPExtensionNotify_CloseMicrophoneSubKey :
                                TUICore_TUICore_TUICallKitVoIPExtensionNotify_OpenMicrophoneSubKey,
                            object: nil,
                            param: nil)
    }
    
    func setVoIPMute(_ mute: Bool) {
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_MuteSubKey,
                            object: nil,
                            param: [TUICore_TUICore_TUIVoIPExtensionNotify_MuteSubKey_IsMuteKey: mute])
    }
    
    func closeVoIP() {
        lastVoIPGroupId = ""
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_EndSubKey,
                            object: nil,
                            param: nil)
        NotificationCenter.default.post(
            name: Notification.Name("99chat.selfHostedVoip.end"),
            object: nil,
            userInfo: nil
        )
    }
    
    func connectVoIP() {
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_ConnectedKey,
                            object: nil,
                            param: nil)
    }
    
    private func normalizeCallUserId(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("c2c_") {
            text = String(text.dropFirst(4)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let hashIndex = text.firstIndex(of: "#"), hashIndex > text.startIndex {
            text = String(text[..<hashIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text
    }

    func updateVoIPInfo(callerId: String, calleeList: [String], groupId: String, mediaType: TUICallMediaType) {
        lastVoIPGroupId = groupId
        let normalizedCallerId = normalizeCallUserId(callerId)
        let normalizedInvitees = calleeList
            .map { normalizeCallUserId($0) }
            .filter { !$0.isEmpty }
        TUICore.notifyEvent(TUICore_TUIVoIPExtensionNotify,
                            subKey: TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey,
                            object: nil,
                            param: [TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_InviterIdKey: normalizedCallerId,
                                  TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_InviteeListKey: normalizedInvitees,
                                      TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_GroupIDKey: groupId,
                                    VoIPExtensionNotifyKeys.mediaType: mediaType.rawValue])
        // 自建 CallKit：不依赖 TUIVoIPExtension.setCertificateID（会双注册 PushKit）。
        NotificationCenter.default.post(
            name: Notification.Name("99chat.selfHostedVoip.updateInfo"),
            object: nil,
            userInfo: [
                "inviterId": normalizedCallerId,
                "inviteeList": normalizedInvitees,
                "groupId": groupId,
                "mediaType": mediaType.rawValue,
            ]
        )
    }

    private enum VoIPExtensionNotifyKeys {
        static let mediaType = "TUICore_TUICore_TUIVoIPExtensionNotify_UpdateInfoSubKey_MediaTypeKey"
        static let callerNameDefaultsKey = "voip_caller_name"
        static func displayNameCacheKey(for userId: String) -> String {
            "voip_display_name_\(userId)"
        }
    }

    private func syncVoIPCallKitForActiveCall(callMediaType: TUICallMediaType, callRole: TUICallRole) {
        let selfId = normalizeCallUserId(TUICallState.instance.selfUser.value.id.value)
        let groupId = lastVoIPGroupId
        let remoteUsers = TUICallState.instance.remoteUserList.value

        var inviterId = ""
        var inviteeList: [String] = []

        switch callRole {
        case .call:
            inviterId = selfId
            inviteeList = remoteUsers
                .map { normalizeCallUserId($0.id.value) }
                .filter { !$0.isEmpty }
        case .called:
            inviterId = normalizeCallUserId(remoteUsers.first?.id.value ?? "")
            if !selfId.isEmpty {
                inviteeList = [selfId]
            }
        default:
            inviterId = normalizeCallUserId(remoteUsers.first?.id.value ?? selfId)
            inviteeList = remoteUsers
                .map { normalizeCallUserId($0.id.value) }
                .filter { !$0.isEmpty && $0 != inviterId }
        }

        if inviterId.isEmpty, let firstRemote = remoteUsers.first {
            inviterId = normalizeCallUserId(firstRemote.id.value)
        }
        if inviteeList.isEmpty, !selfId.isEmpty, selfId != inviterId {
            inviteeList = [selfId]
        }

        let peerId = resolvePeerUserId(callRole: callRole, selfId: selfId, inviterId: inviterId, invitees: inviteeList)
        let peerDisplayName = resolvePeerDisplayName(peerId: peerId, callRole: callRole)
        cacheVoipDisplayName(peerDisplayName, for: peerId)
        UserDefaults.standard.set(peerDisplayName, forKey: VoIPExtensionNotifyKeys.callerNameDefaultsKey)

        // Self-hosted CallKit currently models incoming calls only. Reporting
        // an outgoing active call through updateInfo creates a false incoming
        // system call.
        if callRole == .called {
            updateVoIPInfo(
                callerId: inviterId,
                calleeList: inviteeList,
                groupId: groupId,
                mediaType: callMediaType
            )
        }
        CallPipLogger.log(
            "syncVoIPCallKit role=\(callRole.rawValue) inviter=\(inviterId) "
                + "invitees=\(inviteeList) peerId=\(peerId) peerName=\(peerDisplayName) "
                + "media=\(callMediaType.rawValue)"
        )
    }

    private func resolvePeerUserId(
        callRole: TUICallRole,
        selfId: String,
        inviterId: String,
        invitees: [String]
    ) -> String {
        if callRole == .call {
            return invitees.first(where: { $0 != selfId }) ?? invitees.first ?? inviterId
        }
        if callRole == .called {
            return inviterId
        }
        if let remote = TUICallState.instance.remoteUserList.value.first {
            let remoteId = normalizeCallUserId(remote.id.value)
            if !remoteId.isEmpty {
                return remoteId
            }
        }
        return inviterId
    }

    private func resolvePeerDisplayName(peerId: String, callRole: TUICallRole) -> String {
        let normalizedPeerId = normalizeCallUserId(peerId)
        if let remote = TUICallState.instance.remoteUserList.value.first(where: {
            normalizeCallUserId($0.id.value) == normalizedPeerId
        }) {
            let display = User.getUserDisplayName(user: remote).trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidVoipDisplayName(display, userId: normalizedPeerId) {
                return display
            }
        }
        let cached = UserDefaults.standard.string(forKey: VoIPExtensionNotifyKeys.displayNameCacheKey(for: normalizedPeerId))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isValidVoipDisplayName(cached, userId: normalizedPeerId) {
            return cached
        }
        return normalizedPeerId
    }

    private func isValidVoipDisplayName(_ value: String, userId: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return false
        }
        if text.contains("#") {
            return false
        }
        let normalized = normalizeCallUserId(text)
        if !userId.isEmpty && normalized == userId && text != userId {
            return false
        }
        return true
    }

    private func cacheVoipDisplayName(_ name: String, for userId: String) {
        let normalizedUserId = normalizeCallUserId(userId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidVoipDisplayName(trimmed, userId: normalizedUserId) else {
            return
        }
        UserDefaults.standard.set(
            trimmed,
            forKey: VoIPExtensionNotifyKeys.displayNameCacheKey(for: normalizedUserId)
        )
    }

    private func cacheVoipDisplayNamesForCall(callerId: String, calleeList: [String]) {
        let normalizedCallerId = normalizeCallUserId(callerId)
        if let remote = TUICallState.instance.remoteUserList.value.first(where: {
            normalizeCallUserId($0.id.value) == normalizedCallerId
        }) {
            cacheVoipDisplayName(User.getUserDisplayName(user: remote), for: normalizedCallerId)
        }
        for calleeId in calleeList {
            let normalizedCalleeId = normalizeCallUserId(calleeId)
            if let remote = TUICallState.instance.remoteUserList.value.first(where: {
                normalizeCallUserId($0.id.value) == normalizedCalleeId
            }) {
                cacheVoipDisplayName(User.getUserDisplayName(user: remote), for: normalizedCalleeId)
            }
        }
    }
    
//     MARK: TUIObserver
    func onCallReceived(callerId: String, calleeIdList: [String], groupId: String?, callMediaType: TUICallMediaType, userData: String?) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.cacheVoipDisplayNamesForCall(callerId: callerId, calleeList: calleeIdList)
            let peerId = self.normalizeCallUserId(callerId)
            let peerName = self.resolvePeerDisplayName(peerId: peerId, callRole: .called)
            UserDefaults.standard.set(peerName, forKey: VoIPExtensionNotifyKeys.callerNameDefaultsKey)
            self.updateVoIPInfo(callerId: callerId, calleeList: calleeIdList, groupId: groupId ?? "", mediaType: callMediaType)
        }
    }
    
    func onCallCancelled(callerId: String) {
        closeVoIP()
    }
    
    func onCallEnd(roomId: TUIRoomId, callMediaType: TUICallMediaType, callRole: TUICallRole, totalTime: Float) {
        closeVoIP()
    }
    
    func onCallBegin(roomId: TUIRoomId, callMediaType: TUICallMediaType, callRole: TUICallRole) {
        syncVoIPCallKitForActiveCall(callMediaType: callMediaType, callRole: callRole)
        connectVoIP()
    }
}
