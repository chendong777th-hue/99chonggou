import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct WithdrawProgressLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WithdrawProgressAttributes.self) { context in
            WithdrawProgressLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.coin)
                        .font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(progressLabel(context.state))
                        .font(.caption)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.state.amountText) \(context.state.coin)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(stageTitle(context.state.stage))
                        .font(.caption)
                }
            } compactLeading: {
                Text(context.state.coin.prefix(1))
            } compactTrailing: {
                Text(compactProgress(context.state))
            } minimal: {
                Image(systemName: context.state.stage == "COMPLETED" ? "checkmark.circle.fill" : "arrow.up.circle")
            }
        }
    }
}

@available(iOS 16.2, *)
private struct WithdrawProgressLockScreenView: View {
    let context: ActivityViewContext<WithdrawProgressAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stageTitle(context.state.stage))
                .font(.headline)
            Text("\(context.state.amountText) \(context.state.coin)")
                .font(.title3.bold())
            Text(progressLabel(context.state))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

@available(iOS 16.2, *)
private func stageTitle(_ stage: String) -> String {
    switch stage.uppercased() {
    case "BROADCASTING": return "Broadcasting withdrawal"
    case "CONFIRMING": return "Confirming withdrawal"
    case "COMPLETED": return "Withdrawal completed"
    case "FAILED": return "Withdrawal failed"
    default: return "Withdrawal submitted"
    }
}

@available(iOS 16.2, *)
private func progressLabel(_ state: WithdrawProgressAttributes.ContentState) -> String {
    switch state.stage.uppercased() {
    case "CONFIRMING":
        return "\(state.confirmations)/\(state.requiredConfirmations) confirmations"
    case "BROADCASTING":
        return "Broadcasting on \(state.coin)"
    default:
        return state.txHashShort.isEmpty ? state.stage : state.txHashShort
    }
}

@available(iOS 16.2, *)
private func compactProgress(_ state: WithdrawProgressAttributes.ContentState) -> String {
    if state.stage.uppercased() == "CONFIRMING" {
        return "\(state.confirmations)/\(state.requiredConfirmations)"
    }
    return "···"
}

@available(iOS 16.2, *)
@main
struct WithdrawProgressWidgetBundle: WidgetBundle {
    var body: some Widget {
        WithdrawProgressLiveActivity()
    }
}
