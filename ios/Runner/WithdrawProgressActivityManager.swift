import ActivityKit
import Foundation
import UserNotifications

@available(iOS 16.2, *)
final class WithdrawProgressActivityManager {
    static let shared = WithdrawProgressActivityManager()

    private var activities: [String: Activity<WithdrawProgressAttributes>] = [:]
    private var pushTokenTasks: [String: Task<Void, Never>] = [:]
    private var latestPushToken: [String: String] = [:]

    private init() {}

    func start(args: [String: Any]) async throws -> [String: Any] {
        let orderId = stringValue(args["orderId"])
        let clientOrderId = stringValue(args["clientOrderId"])
        let stage = stringValue(args["stage"], fallback: "SUBMITTED")
        let amountText = stringValue(args["amountText"])
        let coin = stringValue(args["coin"], fallback: "USDT")
        let network = stringValue(args["network"], fallback: "TRC20")
        let confirmations = intValue(args["confirmations"])
        let requiredConfirmations = intValue(args["requiredConfirmations"], fallback: 19)
        let txHashShort = stringValue(args["txHashShort"])

        if !ActivityAuthorizationInfo().areActivitiesEnabled {
            try await showFallbackNotification(
                orderId: orderId,
                stage: stage,
                amountText: amountText,
                coin: coin,
                confirmations: confirmations,
                requiredConfirmations: requiredConfirmations,
            )
            return [
                "activityId": "notification:\(orderId)",
                "pushToken": "",
                "supported": false,
            ]
        }

        if let existing = activities[orderId] {
            return [
                "activityId": existing.id,
                "pushToken": latestPushToken[orderId] ?? "",
                "supported": true,
            ]
        }

        let attributes = WithdrawProgressAttributes(
            orderId: orderId,
            clientOrderId: clientOrderId,
            network: network,
        )
        let contentState = WithdrawProgressAttributes.ContentState(
            stage: stage,
            amountText: amountText,
            coin: coin,
            confirmations: confirmations,
            requiredConfirmations: requiredConfirmations,
            txHashShort: txHashShort,
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: .token,
            )
            activities[orderId] = activity
            observePushToken(orderId: orderId, activity: activity)
            return [
                "activityId": activity.id,
                "pushToken": latestPushToken[orderId] ?? "",
                "supported": true,
            ]
        } catch {
            try await showFallbackNotification(
                orderId: orderId,
                stage: stage,
                amountText: amountText,
                coin: coin,
                confirmations: confirmations,
                requiredConfirmations: requiredConfirmations,
            )
            return [
                "activityId": "notification:\(orderId)",
                "pushToken": "",
                "supported": false,
            ]
        }
    }

    func update(args: [String: Any]) async throws -> Bool {
        let orderId = stringValue(args["orderId"])
        let stage = stringValue(args["stage"], fallback: "SUBMITTED")
        let amountText = stringValue(args["amountText"])
        let coin = stringValue(args["coin"], fallback: "USDT")
        let confirmations = intValue(args["confirmations"])
        let requiredConfirmations = intValue(args["requiredConfirmations"], fallback: 19)
        let txHashShort = stringValue(args["txHashShort"])

        if let activity = activities[orderId] {
            let next = WithdrawProgressAttributes.ContentState(
                stage: stage,
                amountText: amountText,
                coin: coin,
                confirmations: confirmations,
                requiredConfirmations: requiredConfirmations,
                txHashShort: txHashShort,
            )
            await activity.update(.init(state: next, staleDate: nil))
            return true
        }

        try await showFallbackNotification(
            orderId: orderId,
            stage: stage,
            amountText: amountText,
            coin: coin,
            confirmations: confirmations,
            requiredConfirmations: requiredConfirmations,
        )
        return true
    }

    func end(args: [String: Any]) async throws -> Bool {
        let orderId = stringValue(args["orderId"])
        let stage = stringValue(args["stage"], fallback: "COMPLETED")
        let amountText = stringValue(args["amountText"])
        let coin = stringValue(args["coin"], fallback: "USDT")
        let confirmations = intValue(args["confirmations"])
        let requiredConfirmations = intValue(args["requiredConfirmations"], fallback: 19)
        let txHashShort = stringValue(args["txHashShort"])
        let dismissalSeconds = intValue(args["dismissalSeconds"], fallback: 4)

        pushTokenTasks[orderId]?.cancel()
        pushTokenTasks.removeValue(forKey: orderId)
        latestPushToken.removeValue(forKey: orderId)

        if let activity = activities.removeValue(forKey: orderId) {
            let finalState = WithdrawProgressAttributes.ContentState(
                stage: stage,
                amountText: amountText,
                coin: coin,
                confirmations: confirmations,
                requiredConfirmations: requiredConfirmations,
                txHashShort: txHashShort,
            )
            let policy: ActivityUIDismissalPolicy = dismissalSeconds > 0
                ? .after(Date().addingTimeInterval(TimeInterval(dismissalSeconds)))
                : .immediate
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: policy,
            )
            return true
        }

        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [notificationId(orderId)])
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationId(orderId)])
        return true
    }

    private func observePushToken(
        orderId: String,
        activity: Activity<WithdrawProgressAttributes>,
    ) {
        pushTokenTasks[orderId]?.cancel()
        pushTokenTasks[orderId] = Task {
            for await tokenData in activity.pushTokenUpdates {
                latestPushToken[orderId] = tokenData.base64EncodedString()
            }
        }
    }

    private func showFallbackNotification(
        orderId: String,
        stage: String,
        amountText: String,
        coin: String,
        confirmations: Int,
        requiredConfirmations: Int,
    ) async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        }

        let content = UNMutableNotificationContent()
        content.title = stageTitle(stage)
        content.body = stageBody(
            amountText: amountText,
            coin: coin,
            stage: stage,
            confirmations: confirmations,
            requiredConfirmations: requiredConfirmations,
        )
        content.threadIdentifier = "wallet_withdraw_progress"
        content.userInfo = [
            "orderId": orderId,
            "stage": stage,
        ]

        let request = UNNotificationRequest(
            identifier: notificationId(orderId),
            content: content,
            trigger: nil,
        )
        try await center.add(request)
    }

    private func notificationId(_ orderId: String) -> String {
        "wallet_withdraw_progress_\(orderId)"
    }

    private func stageTitle(_ stage: String) -> String {
        switch stage.uppercased() {
        case "BROADCASTING":
            return "Broadcasting withdrawal"
        case "CONFIRMING":
            return "Confirming withdrawal"
        case "COMPLETED":
            return "Withdrawal completed"
        case "FAILED":
            return "Withdrawal failed"
        default:
            return "Withdrawal submitted"
        }
    }

    private func stageBody(
        amountText: String,
        coin: String,
        stage: String,
        confirmations: Int,
        requiredConfirmations: Int,
    ) -> String {
        let amount = [amountText, coin].filter { !$0.isEmpty }.joined(separator: " ")
        switch stage.uppercased() {
        case "CONFIRMING":
            return "\(amount) · \(confirmations)/\(requiredConfirmations)"
        case "BROADCASTING":
            return "\(amount) · Broadcasting on chain"
        case "COMPLETED":
            return "\(amount) · Completed"
        case "FAILED":
            return "\(amount) · Failed"
        default:
            return "\(amount) · Submitted"
        }
    }

    private func stringValue(_ raw: Any?, fallback: String = "") -> String {
        guard let raw else { return fallback }
        let text = String(describing: raw).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? fallback : text
    }

    private func intValue(_ raw: Any?, fallback: Int = 0) -> Int {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        if let text = raw as? String, let value = Int(text) { return value }
        return fallback
    }
}
