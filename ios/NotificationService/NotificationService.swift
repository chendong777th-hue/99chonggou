import UserNotifications
import os

/// 自建 Push 离线通知扩展（v3.1）：
/// - 读取 payload 顶层 `avatarUrl`（单聊=发送者，群聊=群头像）
/// - 下载头像并展示；无 URL 或下载失败时保留系统默认样式
/// - iOS 15+ 优先 Communication Notification；否则 UNNotificationAttachment
///
/// 注意：当前发布版（Release/Profile）不嵌入本扩展；在线前后台头像由主 App
/// `NotificationAvatarDecorator` + 本地通知完成。重新启用时：在 Runner 中恢复
/// 「Embed App Extensions」与对 NotificationService 的 Target Dependency。
class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private let finishLock = NSLock()
    private var didFinish = false
    private let logger = Logger(
        subsystem: "vip.99chat.pro.NotificationService",
        category: "communication-notification"
    )

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        finishLock.lock()
        didFinish = false
        finishLock.unlock()
        self.contentHandler = contentHandler
        guard let content = (request.content.mutableCopy() as? UNMutableNotificationContent) else {
            logger.error("didReceive mutable content copy failed")
            finish(with: request.content)
            return
        }
        logger.info("didReceive request=\(request.identifier, privacy: .public)")
        self.bestAttemptContent = content
        NotificationAvatarDecorator.decorate(content: content) { [weak self] updated in
            self?.finish(with: updated)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        logger.error("service extension time will expire")
        if let content = bestAttemptContent {
            finish(with: content)
        }
    }

    private func finish(with content: UNNotificationContent) {
        finishLock.lock()
        guard !didFinish else {
            finishLock.unlock()
            return
        }
        didFinish = true
        let handler = contentHandler
        finishLock.unlock()
        handler?(content)
    }
}
