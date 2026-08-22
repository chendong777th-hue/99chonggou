import 'wallet_order.dart';

/// 是否仍在 pending store 中需要用户关注（查单中 / 待补卡等）。
bool walletPendingItemNeedsAttention(WalletOrderDraft draft) {
  if (!draft.isDoneOrder) return true;
  if (draft.needsChatCard && !draft.cardSent && !draft.cardIgnored) {
    return true;
  }
  return false;
}

int walletPendingAttentionCount(Iterable<WalletOrderDraft> items) {
  return items.where(walletPendingItemNeedsAttention).length;
}
