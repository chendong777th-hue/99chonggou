import ActivityKit
import Foundation

@available(iOS 16.2, *)
struct WithdrawProgressAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stage: String
        var amountText: String
        var coin: String
        var confirmations: Int
        var requiredConfirmations: Int
        var txHashShort: String
    }

    var orderId: String
    var clientOrderId: String
    var network: String
}
