import UserNotifications
import Intents
import UIKit
import os

/// 通知头像装饰：下载 avatarUrl，优先 Communication Notification，失败则附件兜底。
/// 主 App 本地通知与 Notification Service Extension 共用。
enum NotificationAvatarDecorator {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "vip.99chat.pro",
        category: "notification-avatar"
    )

    /// 就地装饰通知内容；无头像或失败时原样回调。
    static func decorate(
        content: UNMutableNotificationContent,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        let userInfo = content.userInfo
        let payload = flattenPayload(userInfo)
        let isGroup = isGroupChat(payload)
        let avatarUrl = resolveAvatarUrl(payload: payload, isGroup: isGroup)
        let conversationID = resolveConversationId(payload: payload, isGroup: isGroup)
        let displayName = content.title
        let msgKey = trimmed(payload["msgKey"])
        let avatarHost = URL(string: avatarUrl)?.host ?? ""
        logger.info(
            "decorate msgKey=\(msgKey, privacy: .public) group=\(isGroup) avatarPresent=\(!avatarUrl.isEmpty) host=\(avatarHost, privacy: .public)"
        )

        if isGroup {
            let senderName = trimmed(payload["senderName"])
            if !senderName.isEmpty {
                let prefix = "\(senderName): "
                if !content.body.hasPrefix(prefix) {
                    content.body = "\(prefix)\(content.body)"
                }
            }
        }

        loadAvatarData(urlString: avatarUrl) { data in
            guard let imageData = data, !imageData.isEmpty else {
                logger.error("avatar unavailable msgKey=\(msgKey, privacy: .public)")
                completion(content)
                return
            }

            if #available(iOS 15.0, *) {
                applyCommunicationIntent(
                    content: content,
                    displayName: displayName,
                    isGroup: isGroup,
                    conversationID: conversationID,
                    imageData: imageData,
                    completion: completion
                )
            } else {
                applyAttachmentFallback(
                    content: content,
                    imageData: imageData,
                    completion: completion
                )
            }
        }
    }

    // MARK: - Communication / Attachment

    @available(iOS 15.0, *)
    private static func applyCommunicationIntent(
        content: UNMutableNotificationContent,
        displayName: String,
        isGroup: Bool,
        conversationID: String,
        imageData: Data,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        let avatar = INImage(imageData: imageData)
        let handle = INPersonHandle(
            value: conversationID.isEmpty ? displayName : conversationID,
            type: .unknown
        )
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: displayName,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: nil
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: isGroup ? INSpeakableString(spokenPhrase: displayName) : nil,
            conversationIdentifier: conversationID.isEmpty ? nil : conversationID,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        intent.setImage(avatar, forParameterNamed: \.sender)
        if isGroup {
            intent.setImage(avatar, forParameterNamed: \.speakableGroupName)
        }

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        logger.info(
            "interaction donation start conversation=\(conversationID, privacy: .public)"
        )

        let completionLock = NSLock()
        var completed = false
        let claimCompletion: () -> Bool = {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !completed else { return false }
            completed = true
            return true
        }

        let donationWatchdog = DispatchWorkItem {
            guard claimCompletion() else { return }
            logger.error(
                "interaction donation timed out conversation=\(conversationID, privacy: .public)"
            )
            applyAttachmentFallback(
                content: content,
                imageData: imageData,
                completion: completion
            )
        }
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + 4,
            execute: donationWatchdog
        )

        interaction.donate { error in
            guard claimCompletion() else { return }
            donationWatchdog.cancel()

            if let error = error {
                logger.error(
                    "interaction donation failed conversation=\(conversationID, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
                applyAttachmentFallback(
                    content: content,
                    imageData: imageData,
                    completion: completion
                )
                return
            }

            logger.info(
                "interaction donation succeeded conversation=\(conversationID, privacy: .public)"
            )
            do {
                let updated = try content.updating(from: intent)
                if let mutableUpdated =
                    updated.mutableCopy() as? UNMutableNotificationContent {
                    // updating(from:) 由系统重建通知内容；显式恢复原始自定义字段，
                    // 确保点击后仍能按 fromAccount / groupId 路由到会话。
                    mutableUpdated.userInfo = content.userInfo
                    logger.info(
                        "communication notification updated conversation=\(conversationID, privacy: .public)"
                    )
                    completion(mutableUpdated)
                } else {
                    logger.info(
                        "communication notification updated immutable conversation=\(conversationID, privacy: .public)"
                    )
                    completion(updated)
                }
            } catch {
                logger.error(
                    "communication notification update failed conversation=\(conversationID, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
                applyAttachmentFallback(
                    content: content,
                    imageData: imageData,
                    completion: completion
                )
            }
        }
    }

    private static func applyAttachmentFallback(
        content: UNMutableNotificationContent,
        imageData: Data,
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("push-avatar-\(UUID().uuidString).png")
        do {
            try imageData.write(to: fileURL)
            let attachment = try UNNotificationAttachment(
                identifier: "avatar",
                url: fileURL,
                options: nil
            )
            content.attachments = [attachment]
            logger.info("attachment fallback succeeded")
        } catch {
            logger.error(
                "attachment fallback failed error=\(String(describing: error), privacy: .public)"
            )
        }
        completion(content)
    }

    // MARK: - Payload

    private static func flattenPayload(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        var payload = [String: Any]()
        mergePayload(into: &payload, from: userInfo, depth: 0)
        return payload
    }

    private static func mergePayload(
        into payload: inout [String: Any],
        from source: [AnyHashable: Any],
        depth: Int
    ) {
        guard depth <= 4 else { return }
        for (key, value) in source {
            guard let name = key as? String else { continue }
            if name == "aps" { continue }

            if let nested = value as? [AnyHashable: Any] {
                if ["data", "payload", "custom", "extras", "extra"].contains(name) {
                    mergePayload(into: &payload, from: nested, depth: depth + 1)
                } else {
                    for (innerKey, innerValue) in nested {
                        payload[String(describing: innerKey)] = innerValue
                    }
                }
                continue
            }

            if let text = value as? String,
               let data = text.data(using: .utf8),
               let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if ["ext", "data", "payload", "custom", "extras", "extra", "n_extra", "cn.jpush.android.EXTRA"].contains(name) {
                    mergePayload(into: &payload, from: decoded, depth: depth + 1)
                } else {
                    payload[name] = text
                }
                continue
            }

            payload[name] = value
        }
    }

    private static func isGroupChat(_ payload: [String: Any]) -> Bool {
        let chatType = trimmed(payload["chatType"]).lowercased()
        if chatType == "group" { return true }
        let convType = trimmed(payload["convType"]).lowercased()
        if convType == "group" { return true }
        let legacyType = trimmed(payload["chat_type"]).lowercased()
        if legacyType == "group" { return true }
        let groupId = trimmed(payload["groupId"])
        if !groupId.isEmpty && chatType.isEmpty && convType.isEmpty && legacyType.isEmpty {
            return true
        }
        return false
    }

    private static func resolveAvatarUrl(payload: [String: Any], isGroup: Bool) -> String {
        let direct = resolveAbsoluteUrl(trimmed(payload["avatarUrl"]))
        if !direct.isEmpty {
            return direct
        }
        if isGroup {
            let groupFace = resolveAbsoluteUrl(trimmed(payload["groupFaceUrl"]))
            if !groupFace.isEmpty { return groupFace }
        }
        let senderFace = resolveAbsoluteUrl(trimmed(payload["senderFaceUrl"]))
        if !senderFace.isEmpty { return senderFace }
        return resolveAbsoluteUrl(trimmed(payload["faceUrl"]))
    }

    private static func resolveConversationId(payload: [String: Any], isGroup: Bool) -> String {
        let explicit = trimmed(payload["conversationID"])
        if !explicit.isEmpty { return explicit }
        if isGroup {
            let groupId = trimmed(payload["groupId"])
            if !groupId.isEmpty { return "group_\(groupId)" }
        }
        let fromAccount = trimmed(payload["fromAccount"])
        if !fromAccount.isEmpty { return "c2c_\(fromAccount)" }
        return ""
    }

    // MARK: - Avatar loading

    private static func loadAvatarData(
        urlString: String,
        completion: @escaping (Data?) -> Void
    ) {
        let resolved = resolveAbsoluteUrl(urlString)
        guard !resolved.isEmpty, let url = URL(string: resolved) else {
            logger.error("avatar URL missing or invalid")
            completion(nil)
            return
        }
        let host = url.host ?? ""
        logger.info("avatar download start host=\(host, privacy: .public)")

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("99Chat/1.0", forHTTPHeaderField: "User-Agent")

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 10
        URLSession(configuration: config).dataTask(with: request) {
            data, response, error in
            if let error = error {
                logger.error(
                    "avatar download failed host=\(host, privacy: .public) error=\(String(describing: error), privacy: .public)"
                )
                completion(nil)
                return
            }
            guard let data = data,
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  !data.isEmpty,
                  let image = UIImage(data: data),
                  let circularData = makeCircularAvatarData(image) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let mime = response?.mimeType ?? ""
                logger.error(
                    "avatar response invalid host=\(host, privacy: .public) status=\(status) mime=\(mime, privacy: .public) bytes=\(data?.count ?? 0)"
                )
                completion(nil)
                return
            }
            logger.info(
                "avatar processed host=\(host, privacy: .public) status=\(http.statusCode) bytes=\(data.count) pngBytes=\(circularData.count)"
            )
            completion(circularData)
        }.resume()
    }

    /// 通知头像统一输出为带透明圆角遮罩的正方形 PNG。
    /// Communication Notification 仍会由系统执行最终圆形裁剪。
    private static func makeCircularAvatarData(_ image: UIImage) -> Data? {
        let diameter: CGFloat = 256
        let canvasSize = CGSize(width: diameter, height: diameter)
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return nil
        }

        let scale = max(
            diameter / imageSize.width,
            diameter / imageSize.height
        )
        let drawSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        let drawRect = CGRect(
            x: (diameter - drawSize.width) / 2,
            y: (diameter - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let circularImage = renderer.image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: canvasSize)).addClip()
            image.draw(in: drawRect)
        }
        return circularImage.pngData()
    }

    private static func resolveAbsoluteUrl(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return ""
        }
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            return text
        }
        let base = (Bundle.main.object(forInfoDictionaryKey: "AppApiBaseUrl") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if base.isEmpty {
            return text
        }
        if text.hasPrefix("/") {
            return "\(base)\(text)"
        }
        return "\(base)/\(text)"
    }

    private static func trimmed(_ value: Any?) -> String {
        guard let str = value as? String else { return "" }
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
