import UIKit
import Flutter
import UserNotifications
import PushKit

// Module-wide shadow for project-owned Swift.print calls. Diagnostics remain
// available through state and callbacks without writing to the Xcode console.
@inline(__always)
func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
) {}

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
    private var pushChannel: FlutterMethodChannel?
    private var tuicallChannel: FlutterMethodChannel?
    private var systemNotificationChannel: FlutterMethodChannel?
    private var voipRegistry: PKPushRegistry?
    private var pendingNotificationTap: [String: Any]?
    private var pendingVoipPush: [String: Any]?
    private var cachedApnsToken: String = ""
    private var cachedVoipToken: String = ""
    private var isNotificationTapHandlerReady = false
    private var handledMsgKeys = Set<String>()
    private var handledVoipInviteIds = Set<String>()
    private var reportingVoipInviteIds = Set<String>()
    private var activeVoipInviteId: String?
    private var systemCallKitPresentationSucceeded: Bool?
    private var systemCallKitPresentationInFlight = false
    private var voipPresentationGeneration = 0
    private let voipQueue = DispatchQueue(label: "chat99.voip.push")
    private let handledVoipInviteDefaultsKey = "voip_handled_invite_ids"
    private let handledMsgKeysDefaultsKey = "im_handled_msg_keys"
    private let loginUserIdDefaultsKey = "voip_cached_login_user_id"
    private let callNotificationEnabledDefaultsKey = "voip_call_notification_enabled"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        if let controller = window?.rootViewController as? FlutterViewController {
            setupShareChannel(controller: controller)
            setupPushChannel(controller: controller)
            setupSystemNotificationChannel(controller: controller)
            setupQrImageNormalizeChannel(controller: controller)
            setupWithdrawProgressChannel(controller: controller)
            controller.registrar(forPlugin: "GroupLiveCast")?.register(
                GroupLiveAirPlayViewFactory(),
                withId: "group_live_airplay_picker"
            )
            tuicallChannel = FlutterMethodChannel(
                name: "tuicall_kit",
                binaryMessenger: controller.binaryMessenger
            )
        }

        UNUserNotificationCenter.current().delegate = self

        // 自建 VoIP：只用 AppDelegate 这一份 PKPushRegistry + SelfHostedVoipCallKit。
        // 禁止再调 TUIVoIPExtension.setCertificateID —— 它会再建一套 PushKit，
        // 与自建通道双注册；Extension 只认 TIMPush 载荷，自建 av_call 解析失败后
        // 不报 CallKit，出现「服务端 voip push sent、手机无来电」。
        configureSelfHostedCallKit()
        loadHandledMsgKeys()
        loadHandledVoipInviteIds()
        installPushKitIfNeeded()
        printVoIPDiagnostics(tag: "didFinishLaunching")

        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            pendingNotificationTap = normalizeUserInfo(remoteNotification)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func printVoIPDiagnostics(tag: String) {
        let diagnostics = voipDiagnostics()
        print(
            "VoIPDiagnostics[\(tag)] bundleId=\(diagnostics["bundleId"] ?? "") "
                + "aps=\(diagnostics["apsEnvironment"] ?? "") "
                + "voipTopic=\(diagnostics["voipTopic"] ?? "") "
                + "bgModes=\(diagnostics["backgroundModes"] ?? "") "
                + "hasVoipToken=\(diagnostics["hasVoipToken"] ?? false)"
        )
    }

    private func voipDiagnostics() -> [String: Any] {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let modes = (Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]) ?? []
        return [
            "bundleId": bundleId,
            "apsEnvironment": apsEnvironment(),
            "voipTopic": bundleId.isEmpty ? "" : "\(bundleId).voip",
            "backgroundModes": modes.joined(separator: ","),
            "hasVoipToken": !cachedVoipToken.isEmpty,
            "voipTokenPrefix": String(cachedVoipToken.prefix(8)),
        ]
    }

    private func apsEnvironment() -> String {
        // 以设备上实际签名结果为准（Development 描述文件会强制 development，
        // 即使 RunnerRelease.entitlements 写了 production）。
        if let env = readApsEnvironmentFromEmbeddedProvision() {
            return env
        }
        // App Store / 分发包通常没有 embedded.mobileprovision。
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }

    private func readApsEnvironmentFromEmbeddedProvision() -> String? {
        guard let url = Bundle.main.url(
            forResource: "embedded",
            withExtension: "mobileprovision"
        ) else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        // mobileprovision 是 CMS；在二进制里用 ASCII 扫描 entitlements XML。
        let text = String(decoding: data, as: UTF8.self)
        guard let keyRange = text.range(of: "<key>aps-environment</key>") else {
            return nil
        }
        let after = text[keyRange.upperBound...]
        guard let start = after.range(of: "<string>"),
              let end = after.range(of: "</string>", range: start.upperBound..<after.endIndex)
        else {
            return nil
        }
        let env = String(after[start.upperBound..<end.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if env == "production" || env == "development" {
            return env
        }
        return nil
    }

    private func setupShareChannel(controller: FlutterViewController) {
        let shareChannel = FlutterMethodChannel(
            name: "wallet_share_channel",
            binaryMessenger: controller.binaryMessenger
        )
        shareChannel.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "shareText":
                guard
                    let args = call.arguments as? [String: Any],
                    let text = args["text"] as? String,
                    !text.isEmpty
                else {
                    result(false)
                    return
                }
                self?.presentSystemShare(text: text, result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    /// 相册扫码：HEIC/Exif 转正立 JPEG，长边上限后供 flutter_zxing 解码。
    private func setupQrImageNormalizeChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "qr_image_normalize",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "normalize" else {
                result(FlutterMethodNotImplemented)
                return
            }
            guard
                let args = call.arguments as? [String: Any],
                let path = args["path"] as? String,
                !path.isEmpty
            else {
                result(
                    FlutterError(
                        code: "invalid_args",
                        message: "path required",
                        details: nil
                    )
                )
                return
            }
            let maxSide = (args["maxSide"] as? Int) ?? 4096
            let qualityRaw = (args["quality"] as? Int) ?? 92
            let quality = max(50, min(100, qualityRaw))
            DispatchQueue.global(qos: .userInitiated).async {
                let payload = self?.normalizeQrImage(
                    path: path,
                    maxSide: maxSide,
                    quality: quality
                )
                DispatchQueue.main.async {
                    if let payload {
                        result(payload)
                    } else {
                        result(
                            FlutterError(
                                code: "normalize_failed",
                                message: "unable to normalize image",
                                details: nil
                            )
                        )
                    }
                }
            }
        }
    }

    private func normalizeQrImage(
        path: String,
        maxSide: Int,
        quality: Int
    ) -> [String: Any]? {
        guard let image = UIImage(contentsOfFile: path) else {
            return nil
        }
        let upright = image.qrNormalizedUp()
        var target = upright
        let longSide = max(upright.size.width, upright.size.height)
        if longSide > CGFloat(maxSide), longSide > 0 {
            let scale = CGFloat(maxSide) / longSide
            let newSize = CGSize(
                width: max(1, (upright.size.width * scale).rounded()),
                height: max(1, (upright.size.height * scale).rounded())
            )
            UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
            upright.draw(in: CGRect(origin: .zero, size: newSize))
            let scaled = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            if let scaled {
                target = scaled
            }
        }
        guard let data = target.jpegData(compressionQuality: CGFloat(quality) / 100.0) else {
            return nil
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("qr_norm", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent("qr_\(Int(Date().timeIntervalSince1970 * 1000)).jpg")
        do {
            try data.write(to: out, options: .atomic)
        } catch {
            return nil
        }
        let pixelWidth = Int((target.size.width * target.scale).rounded())
        let pixelHeight = Int((target.size.height * target.scale).rounded())
        return [
            "path": out.path,
            "width": pixelWidth,
            "height": pixelHeight,
            "isTemporary": true,
        ]
    }

    private func setupPushChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "ios_apns_push",
            binaryMessenger: controller.binaryMessenger
        )
        pushChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(nil)
                return
            }
            switch call.method {
            case "install":
                self.installPushKitIfNeeded()
                self.flushPendingVoipPushIfNeeded()
                result(nil)
            case "setNotificationTapHandlerReady":
                self.isNotificationTapHandlerReady = true
                result(nil)
            case "registerForRemoteNotifications":
                self.requestNotificationPermissionAndRegister()
                result(nil)
            case "getCachedTokens":
                result([
                    "apnsToken": self.cachedApnsToken,
                    "voipToken": self.cachedVoipToken,
                    "bundleId": Bundle.main.bundleIdentifier ?? "",
                    "apsEnvironment": self.apsEnvironment(),
                    "voipTopic": "\(Bundle.main.bundleIdentifier ?? "").voip",
                ])
            case "getVoipDiagnostics":
                result(self.voipDiagnostics())
            case "consumePendingNotificationTap":
                let payload = self.pendingNotificationTap
                self.pendingNotificationTap = nil
                result(payload)
            case "consumePendingVoipPush":
                let payload = self.pendingVoipPush
                self.pendingVoipPush = nil
                result(payload)
            case "cancelNotificationForMsgKey":
                if let args = call.arguments as? [String: Any],
                   let msgKey = args["msgKey"] as? String,
                   !msgKey.isEmpty {
                    self.cancelDeliveredNotifications(matchingMsgKey: msgKey)
                }
                result(nil)
            case "syncHandledMsgKey":
                if let args = call.arguments as? [String: Any],
                   let msgKey = args["msgKey"] as? String,
                   !msgKey.isEmpty {
                    self.markHandledMsgKey(msgKey)
                }
                result(nil)
            case "clearHandledMsgKeys":
                self.clearHandledMsgKeys()
                result(nil)
            case "clearAllImChatNotifications":
                self.clearAllImChatNotifications { count in
                    result(count)
                }
            case "clearDeliveredImChatNotifications":
                let threadId = (call.arguments as? [String: Any])?["threadId"] as? String
                self.clearDeliveredImChatNotifications(threadId: threadId) { count in
                    result(count)
                }
            case "cacheDisplayNames":
                if let names = call.arguments as? [String: String] {
                    self.cacheVoipDisplayNames(names)
                }
                result(nil)
            case "cacheLoginUserId":
                if let args = call.arguments as? [String: Any] {
                    let userId = (args["userId"] as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if userId.isEmpty {
                        UserDefaults.standard.removeObject(forKey: self.loginUserIdDefaultsKey)
                    } else {
                        UserDefaults.standard.set(userId, forKey: self.loginUserIdDefaultsKey)
                    }
                }
                result(nil)
            case "cacheCallNotificationEnabled":
                if let args = call.arguments as? [String: Any] {
                    let enabled = args["enabled"] as? Bool ?? true
                    UserDefaults.standard.set(
                        enabled,
                        forKey: self.callNotificationEnabledDefaultsKey
                    )
                }
                result(nil)
            case "getCallNotificationEnabled":
                result(self.isCallNotificationEnabled())
            case "isVoipAudioSessionActivated":
                result(SelfHostedVoipCallKit.shared.audioSessionActivated)
            case "endVoipCallKit":
                let args = call.arguments as? [String: Any]
                let inviteId = args?["inviteId"] as? String
                let keepAudioSession = args?["keepAudioSession"] as? Bool ?? false
                self.endVoipCallKit(
                    inviteId: inviteId,
                    keepAudioSession: keepAudioSession
                )
                result(nil)
            case "startVoipCallKit":
                if let args = call.arguments as? [String: Any] {
                    let inviteId = args["inviteId"] as? String
                    let handle = (args["handle"] as? String) ?? ""
                    let displayName = (args["displayName"] as? String) ?? ""
                    let hasVideo = args["hasVideo"] as? Bool ?? false
                    SelfHostedVoipCallKit.shared.startOutgoingCall(
                        inviteId: inviteId,
                        handle: handle,
                        displayName: displayName,
                        hasVideo: hasVideo
                    ) { error in
                        if let error = error {
                            result(FlutterError(
                                code: "callkit_start",
                                message: error.localizedDescription,
                                details: nil
                            ))
                        } else {
                            result(nil)
                        }
                    }
                } else {
                    result(nil)
                }
            case "connectVoipCallKit":
                let inviteId = (call.arguments as? [String: Any])?["inviteId"] as? String
                SelfHostedVoipCallKit.shared.reportConnected(inviteId: inviteId)
                result(nil)
            case "setLiveKitPip":
                if let args = call.arguments as? [String: Any] {
                    let enabled = args["enabled"] as? Bool ?? false
                    let hasVideo = args["hasVideo"] as? Bool ?? false
                    let peerName = args["peerName"] as? String
                    let trackId = args["trackId"] as? String
                    if #available(iOS 15.0, *) {
                        LiveKitCallPip.shared.setEnabled(
                            enabled,
                            peerName: peerName,
                            hasVideo: hasVideo,
                            trackId: trackId
                        )
                    }
                }
                result(nil)
            case "enterLiveKitPip":
                if #available(iOS 15.0, *) {
                    LiveKitCallPip.shared.enterBackgroundIfNeeded()
                }
                result(nil)
            case "stopLiveKitPip":
                if #available(iOS 15.0, *) {
                    LiveKitCallPip.shared.setEnabled(
                        false,
                        peerName: nil,
                        hasVideo: false,
                        trackId: nil
                    )
                }
                result(nil)
            case "completeVoipCallKitAction":
                if let args = call.arguments as? [String: Any],
                   let uuid = args["uuid"] as? String {
                    let succeeded = args["succeeded"] as? Bool ?? false
                    SelfHostedVoipCallKit.shared.completeAction(
                        uuidString: uuid,
                        succeeded: succeeded
                    )
                }
                result(nil)
            case "syncHandledVoipInviteId":
                if let args = call.arguments as? [String: Any],
                   let inviteId = args["inviteId"] as? String,
                   !inviteId.isEmpty {
                    self.markVoipInviteHandled(inviteId)
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupSystemNotificationChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "app_system_notification",
            binaryMessenger: controller.binaryMessenger
        )
        systemNotificationChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(nil)
                return
            }
            switch call.method {
            case "showChatNotification":
                guard let args = call.arguments as? [String: Any] else {
                    result(false)
                    return
                }
                let title = args["title"] as? String ?? ""
                let body = args["body"] as? String ?? ""
                let conversationID = args["conversationID"] as? String ?? ""
                let ext = args["ext"] as? String ?? ""
                let avatarUrl = args["avatarUrl"] as? String
                self.showLocalChatNotification(
                    title: title,
                    body: body,
                    conversationID: conversationID,
                    ext: ext,
                    avatarUrl: avatarUrl
                ) { ok in
                    result(ok)
                }
            case "consumeNotificationClick":
                let payload = self.pendingNotificationTap
                self.pendingNotificationTap = nil
                result(payload)
            case "setAppBadge":
                let count = max(0, (call.arguments as? [String: Any])?["count"] as? Int ?? 0)
                if #available(iOS 16.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(count) { error in
                        result(error == nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        UIApplication.shared.applicationIconBadgeNumber = count
                        result(true)
                    }
                }
            case "cancelAll":
                UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                result(true)
            case "clearImChatNotifications":
                let threadId = (call.arguments as? [String: Any])?["threadId"] as? String
                self.clearDeliveredImChatNotifications(threadId: threadId) { count in
                    result(count)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupWithdrawProgressChannel(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "wallet_withdraw_progress",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            guard #available(iOS 16.2, *) else {
                switch call.method {
                case "start":
                    result([
                        "activityId": "",
                        "pushToken": "",
                        "supported": false,
                    ])
                case "update", "end":
                    result(true)
                case "getActive":
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
                return
            }

            let args = call.arguments as? [String: Any] ?? [:]
            let manager = WithdrawProgressActivityManager.shared
            switch call.method {
            case "start":
                Task {
                    do {
                        let payload = try await manager.start(args: args)
                        result(payload)
                    } catch {
                        result(FlutterError(code: "start_failed", message: error.localizedDescription, details: nil))
                    }
                }
            case "update":
                Task {
                    do {
                        let ok = try await manager.update(args: args)
                        result(ok)
                    } catch {
                        result(FlutterError(code: "update_failed", message: error.localizedDescription, details: nil))
                    }
                }
            case "end":
                Task {
                    do {
                        let ok = try await manager.end(args: args)
                        result(ok)
                    } catch {
                        result(FlutterError(code: "end_failed", message: error.localizedDescription, details: nil))
                    }
                }
            case "getActive":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func clearAllImChatNotifications(completion: @escaping (Int) -> Void) {
        clearDeliveredImChatNotifications(threadId: nil, completion: completion)
    }

    private func clearDeliveredImChatNotifications(
        threadId: String?,
        completion: @escaping (Int) -> Void
    ) {
        let normalizedThread = threadId?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            var toRemove: [String] = []
            for notification in notifications {
                let userInfo = self.normalizeUserInfo(notification.request.content.userInfo)
                guard self.isImChatUserInfo(userInfo) else {
                    continue
                }
                if !normalizedThread.isEmpty {
                    let payloadThread = self.threadIdFromUserInfo(userInfo)
                    if !payloadThread.isEmpty && payloadThread != normalizedThread {
                        continue
                    }
                }
                toRemove.append(notification.request.identifier)
            }
            if !toRemove.isEmpty {
                UNUserNotificationCenter.current()
                    .removeDeliveredNotifications(withIdentifiers: toRemove)
            }
            DispatchQueue.main.async {
                completion(toRemove.count)
            }
        }
    }

    private func cancelDeliveredNotifications(matchingMsgKey msgKey: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            var toRemove: [String] = []
            for notification in notifications {
                let userInfo = self.normalizeUserInfo(notification.request.content.userInfo)
                // A local fallback uses the same stable msgKey identifier.
                // Suppressing a late remote Push must not remove that local
                // alert from the notification center.
                if self.isAppLocalNotification(notification, userInfo: userInfo) {
                    continue
                }
                let key = (userInfo["msgKey"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if key == msgKey {
                    toRemove.append(notification.request.identifier)
                }
            }
            if !toRemove.isEmpty {
                UNUserNotificationCenter.current()
                    .removeDeliveredNotifications(withIdentifiers: toRemove)
            }
        }
    }

    private func msgKeyFromUserInfo(_ userInfo: [String: Any]) -> String {
        return (userInfo["msgKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func loadHandledMsgKeys() {
        handledMsgKeys = Set(
            UserDefaults.standard.stringArray(forKey: handledMsgKeysDefaultsKey) ?? []
        )
    }

    private func markHandledMsgKey(_ msgKey: String) {
        let key = msgKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        handledMsgKeys.insert(key)
        if handledMsgKeys.count > 320 {
            handledMsgKeys = Set(Array(handledMsgKeys).sorted().suffix(256))
        }
        UserDefaults.standard.set(
            Array(handledMsgKeys).sorted(),
            forKey: handledMsgKeysDefaultsKey
        )
    }

    private func clearHandledMsgKeys() {
        handledMsgKeys.removeAll()
        UserDefaults.standard.removeObject(forKey: handledMsgKeysDefaultsKey)
    }

    private func isImChatUserInfo(_ userInfo: [String: Any]) -> Bool {
        let type = (userInfo["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return type == "im_chat" || type == "chat_message"
    }

    private func threadIdFromUserInfo(_ userInfo: [String: Any]) -> String {
        let direct = (userInfo["threadId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !direct.isEmpty {
            return direct
        }
        let chatType = (userInfo["chatType"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let groupId = (userInfo["groupId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if chatType == "group" && !groupId.isEmpty {
            return "group_\(groupId)"
        }
        let fromAccount = (userInfo["fromAccount"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromAccount.isEmpty {
            return "c2c_\(fromAccount)"
        }
        return ""
    }

    private func showLocalChatNotification(
        title: String,
        body: String,
        conversationID: String,
        ext: String,
        avatarUrl: String?,
        completion: @escaping (Bool) -> Void
    ) {
        // 防止插件抢走 delegate 导致前台 willPresent 不走本 App。
        UNUserNotificationCenter.current().delegate = self

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1.0
        }

        var userInfo = normalizeUserInfo(parseExtPayload(ext))
        if !conversationID.isEmpty {
            userInfo["conversationID"] = conversationID
        } else {
            fillEmptyConversationIDIfNeeded(&userInfo)
        }
        userInfo["title"] = title
        userInfo["body"] = body
        // 前台 willPresent 用此标记识别本地条，避免误判成远程被压掉。
        userInfo["local"] = "1"
        userInfo["source"] = "app_local"
        let existingType = (userInfo["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if existingType.isEmpty {
            userInfo["type"] = "im_chat"
        }

        let avatar = avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if avatar.isEmpty {
            let fromPayload = (userInfo["avatarUrl"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !fromPayload.isEmpty {
                userInfo["avatarUrl"] = fromPayload
            }
        } else {
            userInfo["avatarUrl"] = avatar
        }
        // 本地通知不会走 Notification Service Extension；头像由主 App 装饰。
        userInfo.removeValue(forKey: "aps")
        content.userInfo = userInfo

        let identifier = (userInfo["msgKey"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let requestId = (identifier?.isEmpty == false) ? identifier! : UUID().uuidString

        let post: (UNNotificationContent, @escaping (Bool) -> Void) -> Void = { finalContent, done in
            let request = UNNotificationRequest(
                identifier: requestId,
                content: finalContent,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("LOCAL_CHAT_NOTIF post id=\(requestId) error=\(error)")
                } else {
                    print("LOCAL_CHAT_NOTIF post id=\(requestId) error=nil")
                }
                DispatchQueue.main.async {
                    done(error == nil)
                }
            }
        }

        // 先无头像立刻出横幅，再异步装饰并用同一 identifier 替换。
        post(content) { ok in
            completion(ok)
            let hasAvatar = (userInfo["avatarUrl"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            guard hasAvatar else { return }
            let decorateContent = content.mutableCopy() as? UNMutableNotificationContent ?? content
            NotificationAvatarDecorator.decorate(content: decorateContent) { decorated in
                post(decorated) { _ in }
            }
        }
    }

    private func isAppLocalNotification(_ notification: UNNotification, userInfo: [String: Any]) -> Bool {
        if notification.request.trigger == nil {
            return true
        }
        let localFlag = (userInfo["local"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if localFlag == "1" || localFlag.lowercased() == "true" {
            return true
        }
        let source = (userInfo["source"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return source == "app_local"
    }

    private func parseExtPayload(_ ext: String) -> [AnyHashable: Any] {
        guard
            let data = ext.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        var output: [AnyHashable: Any] = [:]
        json.forEach { output[$0.key] = $0.value }
        return output
    }

    private func configureSelfHostedCallKit() {
        let callKit = SelfHostedVoipCallKit.shared
        callKit.onAccept = { [weak self] inviteId, uuid in
            print("SelfHostedVoipCallKit: user answered inviteId=\(inviteId ?? "")")
            self?.tuicallChannel?.invokeMethod(
                "voipChangeAccept",
                arguments: ["inviteId": inviteId ?? "", "uuid": uuid]
            )
        }
        callKit.onEnd = { [weak self] inviteId, uuid in
            print("SelfHostedVoipCallKit: user ended / declined inviteId=\(inviteId ?? "")")
            self?.tuicallChannel?.invokeMethod(
                "voipChangeHangup",
                arguments: ["inviteId": inviteId ?? "", "uuid": uuid]
            )
        }
        callKit.onMute = { [weak self] inviteId, uuid, muted in
            self?.tuicallChannel?.invokeMethod(
                "voipChangeMute",
                arguments: [
                    "inviteId": inviteId ?? "",
                    "uuid": uuid,
                    "mute": muted,
                ]
            )
        }
        callKit.onReset = { [weak self] in
            self?.tuicallChannel?.invokeMethod(
                "voipChangeHangup",
                arguments: [
                    "inviteId": self?.activeVoipInviteId ?? "",
                    "uuid": "",
                ]
            )
            self?.activeVoipInviteId = nil
        }
        callKit.onAudioSessionActivated = { [weak self] uuid in
            self?.tuicallChannel?.invokeMethod(
                "voipAudioSessionActivated",
                arguments: ["uuid": uuid ?? ""]
            )
        }
        callKit.onAudioSessionDeactivated = { [weak self] uuid in
            self?.tuicallChannel?.invokeMethod(
                "voipAudioSessionDeactivated",
                arguments: ["uuid": uuid ?? ""]
            )
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSelfHostedVoipUpdateInfo(_:)),
            name: Notification.Name("99chat.selfHostedVoip.updateInfo"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSelfHostedVoipEnd(_:)),
            name: Notification.Name("99chat.selfHostedVoip.end"),
            object: nil
        )
        print("SelfHostedVoipCallKit ready (exclusive PushKit + CallKit)")
    }

    @objc private func onSelfHostedVoipUpdateInfo(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        let inviterId = (info["inviterId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !inviterId.isEmpty else { return }
        let mediaType = info["mediaType"] as? Int ?? 1
        let cachedName = UserDefaults.standard.string(forKey: "voip_caller_name")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let callerName = cachedName.isEmpty ? inviterId : cachedName
        if let succeeded = systemCallKitPresentationSucceeded {
            notifySystemCallKitPresentation(succeeded: succeeded)
            return
        }
        // PushKit 已经在上报系统 CallKit 时，IM 信令只负责补充资料，
        // 不能再次 report，否则第二次失败会误触发自定义横幅兜底。
        if systemCallKitPresentationInFlight {
            return
        }
        systemCallKitPresentationInFlight = true
        voipPresentationGeneration += 1
        let presentationGeneration = voipPresentationGeneration
        SelfHostedVoipCallKit.shared.reportIncomingCall(
            inviteId: activeVoipInviteId,
            callerId: inviterId,
            callerName: callerName,
            hasVideo: mediaType == 2
        ) { [weak self] error in
            guard let self = self,
                  presentationGeneration == self.voipPresentationGeneration else {
                return
            }
            let succeeded = error == nil
            self.systemCallKitPresentationInFlight = false
            self.systemCallKitPresentationSucceeded = succeeded
            self.notifySystemCallKitPresentation(succeeded: succeeded)
            if let error = error {
                print("SelfHostedVoipCallKit IM-path report failed \(error.localizedDescription)")
            }
        }
    }

    @objc private func onSelfHostedVoipEnd(_ notification: Notification) {
        endVoipCallKit()
    }

    private func requestNotificationPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func installPushKitIfNeeded() {
        if voipRegistry != nil {
            return
        }
        let registry = PKPushRegistry(queue: DispatchQueue.main)
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
        voipRegistry = registry
    }

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = hexString(from: deviceToken)
        cachedApnsToken = token
        pushChannel?.invokeMethod("onApnsToken", arguments: ["token": token])
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed: \(error)")
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    override func applicationDidBecomeActive(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        super.applicationDidBecomeActive(application)
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = normalizeUserInfo(notification.request.content.userInfo)
        let type = (userInfo["type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let isLocal = isAppLocalNotification(notification, userInfo: userInfo)
        let state = UIApplication.shared.applicationState
        if type == "im_chat" || type == "chat_message" {
            let msgKey = msgKeyFromUserInfo(userInfo)
            // 仅远程 Push 通知 Dart 清残留；本地系统通知若也回调，前台 cancelByMsgKey 会立刻掐掉横幅。
            if !isLocal {
                pushChannel?.invokeMethod("onRemoteNotificationReceived", arguments: userInfo)
            }
            // handled 只压远程重复；本地通知即使已 claim 也要展示横幅。
            if !isLocal && !msgKey.isEmpty && handledMsgKeys.contains(msgKey) {
                print(
                    "LOCAL_CHAT_NOTIF willPresent type=\(type) isLocal=\(isLocal) "
                        + "state=\(state.rawValue) options=[] reason=remote_handled"
                )
                completionHandler([])
                return
            }
            if state == .active {
                if isLocal {
                    // 前台由 Dart 发的本地系统通知：允许系统横幅。
                    if #available(iOS 14.0, *) {
                        print(
                            "LOCAL_CHAT_NOTIF willPresent type=\(type) isLocal=\(isLocal) "
                                + "state=\(state.rawValue) options=banner"
                        )
                        completionHandler([.banner, .list, .sound, .badge])
                    } else {
                        print(
                            "LOCAL_CHAT_NOTIF willPresent type=\(type) isLocal=\(isLocal) "
                                + "state=\(state.rawValue) options=alert"
                        )
                        completionHandler([.alert, .sound, .badge])
                    }
                } else {
                    // 前台远程 Push：交给 Dart 本地系统通知，避免双条。
                    print(
                        "LOCAL_CHAT_NOTIF willPresent type=\(type) isLocal=\(isLocal) "
                            + "state=\(state.rawValue) options=[] reason=remote_active"
                    )
                    completionHandler([])
                }
                return
            }
        }
        if #available(iOS 14.0, *) {
            print(
                "LOCAL_CHAT_NOTIF willPresent type=\(type) isLocal=\(isLocal) "
                    + "state=\(state.rawValue) options=banner default"
            )
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            print(
                "LOCAL_CHAT_NOTIF willPresent type=\(type) isLocal=\(isLocal) "
                    + "state=\(state.rawValue) options=alert default"
            )
            completionHandler([.alert, .sound, .badge])
        }
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let payload = normalizeUserInfo(response.notification.request.content.userInfo)
        let convId = (payload["conversationID"] as? String) ?? ""
        print(
            "IOS_PUSH_TRACE nativeTap ready=\(isNotificationTapHandlerReady) "
                + "channel=\(pushChannel != nil) conv=\(convId) "
                + "keys=\(payload.keys.sorted().joined(separator: ","))"
        )
        if payload.isEmpty {
            completionHandler()
            return
        }
        // 冷启动时 MethodChannel 对象会先创建，但 Dart 点击处理器尚未安装。
        // 此时直接 invokeMethod 会静默丢失点击，先缓存到 install 后主动消费。
        if isNotificationTapHandlerReady, let channel = pushChannel {
            channel.invokeMethod("onNotificationTap", arguments: payload)
        } else {
            pendingNotificationTap = payload
        }
        completionHandler()
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = hexString(from: pushCredentials.token)
        cachedVoipToken = token
        pushChannel?.invokeMethod("onVoipToken", arguments: ["token": token])
    }

    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        guard type == .voIP else {
            completion()
            return
        }
        // 必须尽快在主线程 reportNewIncomingCall；不要先丢到后台队列再回调。
        let payloadData = normalizeUserInfo(payload.dictionaryPayload)
        let work = { [weak self] in
            guard let self = self else {
                completion()
                return
            }
            self.handleVoipPushPayload(payloadData, completion: completion)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func handleVoipPushPayload(
        _ rawData: [String: Any],
        completion: @escaping () -> Void
    ) {
        var data = rawData
        // Keep the actual PushKit arrival time with an in-memory pending
        // payload. Flutter may not be ready until the app is opened later;
        // without this stamp that stale invite looks new and reopens call UI.
        if data["_receivedAtMs"] == nil {
            data["_receivedAtMs"] = Int(Date().timeIntervalSince1970 * 1000)
        }
        // Apple：必须在 reportNewIncomingCall 完成后再调 PushKit completion。
        // 不可再用 defer 立刻 completion。
        print("VoIP push received keys=\(Array(data.keys))")

        if shouldEndVoipCall(data) {
            print("VoIP push end/cancel received")
            endVoipCallKit(inviteId: readVoipInviteId(from: data))
            if let channel = pushChannel {
                channel.invokeMethod("onVoipPush", arguments: data)
            } else {
                pendingVoipPush = data
            }
            completion()
            return
        }

        guard shouldPresentVoipCall(data) else {
            // 仍须完成 completion；无法合法展示时立刻结束，避免拖死系统。
            // 反复「收 Push 却不报 CallKit」会被 iOS 停掉 VoIP 唤醒。
            print("VoIP push present guard failed — fulfilling PushKit without UI")
            completion()
            return
        }

        let inviteId = readVoipInviteId(from: data)
        if !isCallNotificationEnabled() {
            // Apple 要求每个 VoIP Push 都必须 reportNewIncomingCall；用户关闭
            // 「语音和视频通话通知」后仍须上报再立即结束，否则系统会杀进程。
            print("VoIP push call notifications disabled — report then end inviteId=\(inviteId ?? "")")
            reportSelfHostedIncomingCall(data: data, inviteId: inviteId) { [weak self] error in
                if error == nil {
                    if let inviteId = inviteId, !inviteId.isEmpty {
                        SelfHostedVoipCallKit.shared.endCall(
                            inviteId: inviteId,
                            reason: .unanswered
                        )
                    } else {
                        SelfHostedVoipCallKit.shared.endActiveCall(reason: .unanswered)
                    }
                }
                // CallKit 已立刻结束；仍把 payload 交给 Flutter 弹应用内全屏来电页。
                if let channel = self?.pushChannel {
                    channel.invokeMethod("onVoipPush", arguments: data)
                } else {
                    self?.pendingVoipPush = data
                }
                completion()
            }
            return
        }

        let alreadyHandled = inviteId.map { isVoipInviteHandled($0) } ?? false
        if alreadyHandled {
            print("VoIP push ignored: invite already handled inviteId=\(inviteId ?? "")")
            completion()
            return
        }
        if let inviteId = inviteId, reportingVoipInviteIds.contains(inviteId) {
            print("VoIP push ignored: report already in flight inviteId=\(inviteId)")
            completion()
            return
        }

        if let active = activeVoipInviteId,
           let inviteId = inviteId,
           active != inviteId {
            endVoipCallKit()
        }

        systemCallKitPresentationSucceeded = nil
        systemCallKitPresentationInFlight = true
        voipPresentationGeneration += 1
        let presentationGeneration = voipPresentationGeneration
        if let inviteId = inviteId {
            reportingVoipInviteIds.insert(inviteId)
        }
        reportSelfHostedIncomingCall(data: data, inviteId: inviteId) { [weak self] error in
            guard let self = self else {
                completion()
                return
            }
            let succeeded = error == nil
            if let inviteId = inviteId {
                self.reportingVoipInviteIds.remove(inviteId)
            }
            let isCurrentPresentation =
                presentationGeneration == self.voipPresentationGeneration
            if isCurrentPresentation {
                self.systemCallKitPresentationInFlight = false
                self.systemCallKitPresentationSucceeded = succeeded
            }
            self.notifySystemCallKitPresentation(
                succeeded: succeeded,
                inviteId: inviteId
            )
            if error == nil, let inviteId = inviteId {
                self.markVoipInviteHandled(inviteId)
                if isCurrentPresentation {
                    self.activeVoipInviteId = inviteId
                }
            }
            if let channel = self.pushChannel {
                channel.invokeMethod("onVoipPush", arguments: data)
            } else {
                self.pendingVoipPush = data
            }
            completion()
        }
    }

    private func reportSelfHostedIncomingCall(
        data: [String: Any],
        inviteId: String?,
        completion: @escaping (Error?) -> Void
    ) {
        let rawCallerId = stringValue(data["callerId"])
        let callerId = normalizeCallUserId(rawCallerId)
        let callerName = resolveVoipCallerName(from: data, callerId: callerId)
        let hasVideo = mediaTypeRawValue(from: data["mediaType"]).intValue == 2

        UserDefaults.standard.set(callerName, forKey: "voip_caller_name")
        cacheVoipDisplayName(callerName, for: callerId)

        print(
            "VoIP push -> SelfHostedVoipCallKit callerId=\(callerId) "
                + "callerName=\(callerName) inviteId=\(inviteId ?? "") video=\(hasVideo) "
                + "payloadKeys=\(Array(data.keys).sorted())"
        )

        SelfHostedVoipCallKit.shared.reportIncomingCall(
            inviteId: inviteId,
            callerId: callerId,
            callerName: callerName,
            hasVideo: hasVideo,
            completion: completion
        )
    }

    private func notifySystemCallKitPresentation(
        succeeded: Bool,
        inviteId: String? = nil
    ) {
        tuicallChannel?.invokeMethod(
            "systemCallKitPresentation",
            arguments: [
                "succeeded": succeeded,
                "inviteId": inviteId ?? activeVoipInviteId ?? "",
            ]
        )
    }

    private func flushPendingVoipPushIfNeeded() {
        guard let payload = pendingVoipPush, let channel = pushChannel else {
            return
        }
        pendingVoipPush = nil
        channel.invokeMethod("onVoipPush", arguments: payload)
    }

    private func cachedLoginUserId() -> String {
        normalizeCallUserId(
            UserDefaults.standard.string(forKey: loginUserIdDefaultsKey) ?? ""
        )
    }

    private func isCallNotificationEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: callNotificationEnabledDefaultsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: callNotificationEnabledDefaultsKey)
    }

    private func readVoipInviteId(from data: [String: Any]) -> String? {
        for key in ["inviteId", "inviteID", "callId", "callID"] {
            let value = stringValue(data[key])
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private func stringValue(_ raw: Any?) -> String {
        if let text = raw as? String {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = raw as? NSNumber {
            return number.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let value = raw {
            return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private func loadHandledVoipInviteIds() {
        let stored = UserDefaults.standard.stringArray(forKey: handledVoipInviteDefaultsKey) ?? []
        handledVoipInviteIds = Set(stored)
    }

    private func persistHandledVoipInviteIds() {
        let list = Array(handledVoipInviteIds.suffix(64))
        UserDefaults.standard.set(list, forKey: handledVoipInviteDefaultsKey)
    }

    private func isVoipInviteHandled(_ inviteId: String) -> Bool {
        handledVoipInviteIds.contains(inviteId)
    }

    private func markVoipInviteHandled(_ inviteId: String) {
        handledVoipInviteIds.insert(inviteId)
        if handledVoipInviteIds.count > 80 {
            handledVoipInviteIds = Set(handledVoipInviteIds.suffix(64))
        }
        persistHandledVoipInviteIds()
    }

    private func shouldEndVoipCall(_ data: [String: Any]) -> Bool {
        let type = (data["type"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if type.contains("cancel") ||
            type.contains("hangup") ||
            type.contains("reject") ||
            type.contains("end") {
            return true
        }
        for key in ["action", "event", "cmd", "command", "callAction"] {
            let value = (data[key] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            if value.isEmpty {
                continue
            }
            if value.contains("cancel") ||
                value.contains("hangup") ||
                value.contains("reject") ||
                value.contains("end") {
                return true
            }
        }
        return false
    }

    private func shouldPresentVoipCall(_ data: [String: Any]) -> Bool {
        let type = stringValue(data["type"])
        guard isVoipCallPushType(type) else {
            print("VoIP push ignored: type missing or not lk_call/av_call/rtc_call raw=\(type)")
            return false
        }

        let rawCallerId = stringValue(data["callerId"])
        let callerId = normalizeCallUserId(rawCallerId)
        if callerId.isEmpty {
            print("VoIP push ignored: callerId empty")
            return false
        }

        let loginUserId = cachedLoginUserId()
        if !loginUserId.isEmpty && callerId == loginUserId {
            print("VoIP push ignored: caller is current user")
            return false
        }

        let calleeId = normalizeCallUserId(stringValue(data["calleeId"]))
        if !loginUserId.isEmpty && !calleeId.isEmpty && calleeId != loginUserId {
            print(
                "VoIP push ignored: calleeId=\(calleeId) loginUserId=\(loginUserId)"
            )
            return false
        }

        return true
    }

    private func endVoipCallKit(
        inviteId: String? = nil,
        keepAudioSession: Bool = false
    ) {
        let targetInviteId = inviteId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetInviteId = targetInviteId,
           !targetInviteId.isEmpty,
           let activeVoipInviteId = activeVoipInviteId,
           targetInviteId != activeVoipInviteId {
            SelfHostedVoipCallKit.shared.endCall(
                inviteId: targetInviteId,
                keepAudioSession: keepAudioSession
            )
            return
        }
        SelfHostedVoipCallKit.shared.endCall(
            inviteId: targetInviteId?.isEmpty == false ? targetInviteId : activeVoipInviteId,
            keepAudioSession: keepAudioSession
        )
        voipPresentationGeneration += 1
        activeVoipInviteId = nil
        systemCallKitPresentationSucceeded = nil
        systemCallKitPresentationInFlight = false
    }

    private func isVoipCallPushType(_ type: String) -> Bool {
        let lower = type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // LiveKit cutover: only lk_call presents CallKit / enters answer path.
        return lower == "lk_call"
    }

    private func mediaTypeRawValue(from raw: Any?) -> NSNumber {
        let text = (raw as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        // TUICallMediaType: audio = 1, video = 2
        if text == "video" {
            return NSNumber(value: 2)
        }
        return NSNumber(value: 1)
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

    private func voipDisplayNameCacheKey(for userId: String) -> String {
        "voip_display_name_\(userId)"
    }

    /// TRTC/IM 内部复合 ID（如 userA#0#0#userB）不是可展示昵称。
    private func isValidVoipDisplayName(_ value: String, callerId: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return false
        }
        if text.contains("#") {
            return false
        }
        if !callerId.isEmpty && normalizeCallUserId(text) == callerId && text != callerId {
            return false
        }
        return true
    }

    private func resolveVoipCallerName(from data: [String: Any], callerId: String) -> String {
        for key in ["callerName", "callerNick", "nickName", "nickname", "senderName"] {
            let value = stringValue(data[key])
            if isValidVoipDisplayName(value, callerId: callerId) {
                return value
            }
        }
        if !callerId.isEmpty {
            let cached = UserDefaults.standard.string(forKey: voipDisplayNameCacheKey(for: callerId))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if isValidVoipDisplayName(cached, callerId: callerId) {
                return cached
            }
        }
        // 兜底：至少展示规范化 userId，避免 CallKit 回退到 TRTC 复合 ID。
        return callerId
    }

    private func cacheVoipDisplayName(_ name: String, for userId: String) {
        let normalizedUserId = normalizeCallUserId(userId)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidVoipDisplayName(trimmed, callerId: normalizedUserId) else {
            return
        }
        UserDefaults.standard.set(trimmed, forKey: voipDisplayNameCacheKey(for: normalizedUserId))
    }

    private func cacheVoipDisplayNames(_ names: [String: String]) {
        for (rawUserId, rawName) in names {
            cacheVoipDisplayName(rawName, for: rawUserId)
        }
    }

    private func normalizeUserInfo(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        var output: [String: Any] = [:]
        for (key, value) in userInfo {
            let name = String(describing: key)
            if name == "aps" {
                continue
            }
            if let nested = value as? [AnyHashable: Any] {
                if name == "data" || name == "payload" || name == "custom" || name == "extras" || name == "extra" {
                    mergeNormalizedPayload(into: &output, from: nested)
                } else {
                    for (innerKey, innerValue) in nested {
                        output[String(describing: innerKey)] = innerValue
                    }
                }
            } else if let jsonString = value as? String,
                      let data = jsonString.data(using: .utf8),
                      let decoded = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] {
                mergeNormalizedPayload(into: &output, from: decoded)
            } else {
                output[name] = value
            }
        }
        fillEmptyConversationIDIfNeeded(&output)
        return output
    }

    /// TIMPush / 本地通知偶发 conversationID=""，用 threadId / fromAccount 补全。
    private func fillEmptyConversationIDIfNeeded(_ userInfo: inout [String: Any]) {
        let existing = (userInfo["conversationID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !existing.isEmpty {
            return
        }
        let threadId = (userInfo["threadId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if threadId.hasPrefix("c2c_") || threadId.hasPrefix("group_") {
            userInfo["conversationID"] = threadId
            return
        }
        let chatType = (userInfo["chatType"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let groupId = (userInfo["groupId"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if chatType == "group", !groupId.isEmpty {
            userInfo["conversationID"] = "group_\(groupId)"
            return
        }
        let fromAccount = (userInfo["fromAccount"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromAccount.isEmpty {
            userInfo["conversationID"] = "c2c_\(fromAccount)"
        }
    }

    private func mergeNormalizedPayload(into output: inout [String: Any], from source: [AnyHashable: Any]) {
        for (key, value) in source {
            output[String(describing: key)] = value
        }
    }

    private func hexString(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private func presentSystemShare(text: String, result: @escaping FlutterResult) {
        DispatchQueue.main.async { [weak self] in
            guard let presenter = self?.topViewController() else {
                result(false)
                return
            }
            let activity = UIActivityViewController(
                activityItems: [text],
                applicationActivities: nil
            )
            if let popover = activity.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 0,
                    height: 0
                )
                popover.permittedArrowDirections = []
            }
            presenter.present(activity, animated: true) {
                result(true)
            }
        }
    }

    private func topViewController() -> UIViewController? {
        var controller = window?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

private extension UIImage {
    /// 将 imageOrientation 烘焙进像素，输出正立、scale=1 的图。
    func qrNormalizedUp() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
