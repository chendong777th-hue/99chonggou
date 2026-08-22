import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

import '../widgets/wallet_page_colors.dart';
import 'wallet_card_im_sender.dart';
import 'wallet_card_replay_guard.dart';
import 'wallet_card_send_service.dart';
import 'wallet_order.dart';
import 'wallet_order_events.dart';
import 'wallet_pending_filters.dart';
import 'wallet_pending_recovery_service.dart';
import 'wallet_pending_store.dart';

class WalletPendingListScreen extends StatefulWidget {
  const WalletPendingListScreen({super.key});

  @override
  State<WalletPendingListScreen> createState() =>
      _WalletPendingListScreenState();
}

class _WalletPendingListScreenState extends State<WalletPendingListScreen> {
  final WalletPendingStore _store = WalletPendingStore();
  final WalletCardSendService _cardSvc = WalletCardSendService();

  List<WalletOrderDraft> _items = const [];
  bool _loading = true;
  bool _recovering = false;
  String? _busyClientId;

  @override
  void initState() {
    super.initState();
    WalletOrderEvents.recordChanged.addListener(_onStoreChanged);
    _reload();
  }

  @override
  void dispose() {
    WalletOrderEvents.recordChanged.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    _reload(silent: true);
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }
    final all = await _store.load();
    final pending = all.where(walletPendingItemNeedsAttention).toList()
      ..sort((a, b) {
        final ta = DateTime.tryParse(
              b.updatedAt.isNotEmpty ? b.updatedAt : b.createdAt,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(
              a.updatedAt.isNotEmpty ? a.updatedAt : a.createdAt,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
    if (!mounted) return;
    setState(() {
      _items = pending;
      _loading = false;
    });
  }

  Future<void> _recoverAll() async {
    if (_recovering) return;
    setState(() => _recovering = true);
    try {
      await WalletPendingRecoveryService.instance.recover(
        reason: 'pending_list',
        force: true,
      );
      await _reload(silent: true);
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _refreshOne(WalletOrderDraft draft) async {
    setState(() => _busyClientId = draft.clientOrderId);
    try {
      await WalletPendingRecoveryService.instance.recover(
        reason: 'pending_list_item',
        force: true,
      );
      await _reload(silent: true);
    } finally {
      if (mounted) setState(() => _busyClientId = null);
    }
  }

  Future<void> _resendCard(WalletOrderDraft draft) async {
    setState(() => _busyClientId = draft.clientOrderId);
    try {
      final payload =
          await _cardSvc.resetForManualSendByClientId(draft.clientOrderId);
      if (payload != null) {
        await WalletCardImSender.instance.sendAfterRest(
          payload,
          source: WalletCardSendSource.manual,
        );
      }
    } finally {
      if (mounted) setState(() => _busyClientId = null);
    }
  }

  Future<void> _ignoreCard(WalletOrderDraft draft) async {
    setState(() => _busyClientId = draft.clientOrderId);
    try {
      await _cardSvc.ignoreCardFail(draft.clientOrderId);
      await _reload(silent: true);
    } finally {
      if (mounted) setState(() => _busyClientId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final i18n = AppI18n.of(context);

    return wrapWalletPage(
      context,
      Scaffold(
      backgroundColor: cs.bg,
      appBar: AppBar(
        backgroundColor: cs.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: cs.text),
        systemOverlayStyle: walletPageOverlayStyle(context),
        title: Text(
          i18n.t(
            zhHans: '待处理订单',
            zhHant: '待處理訂單',
            en: 'Pending Orders',
            ja: '処理待ち注文',
            ko: '처리 대기 주문',
          ),
          style: TextStyle(
            color: cs.text,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_recovering)
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.red,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: i18n.t(
                zhHans: '全部刷新',
                zhHant: '全部刷新',
                en: 'Refresh all',
                ja: 'すべて更新',
                ko: '전체 새로고침',
              ),
              onPressed: _items.isEmpty ? null : _recoverAll,
              icon: Icon(Icons.refresh_rounded, color: cs.text),
            ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.red))
          : RefreshIndicator(
              color: cs.red,
              onRefresh: _recoverAll,
              child: _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 120.h),
                        AppEmptyState(
                          message: i18n.t(
                            zhHans: '暂无待处理订单',
                            zhHant: '暫無待處理訂單',
                            en: 'No pending orders',
                            ja: '処理待ちの注文はありません',
                            ko: '처리 대기 주문 없음',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => SizedBox(height: 12.h),
                      itemBuilder: (context, index) {
                        final draft = _items[index];
                        return _PendingOrderTile(
                          draft: draft,
                          busy: _busyClientId == draft.clientOrderId,
                          onRefresh: () => _refreshOne(draft),
                          onResendCard: () => _resendCard(draft),
                          onIgnoreCard: () => _ignoreCard(draft),
                        );
                      },
                    ),
            ),
    ),
    );
  }
}

class _PendingOrderTile extends StatelessWidget {
  const _PendingOrderTile({
    required this.draft,
    required this.busy,
    required this.onRefresh,
    required this.onResendCard,
    required this.onIgnoreCard,
  });

  final WalletOrderDraft draft;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onResendCard;
  final VoidCallback onIgnoreCard;

  String _typeLabel(AppI18n i18n) {
    if (draft.type == WalletOrderType.redPacket ||
        draft.businessType == 'wallet_red_packet') {
      return i18n.t(
        zhHans: '红包',
        zhHant: '紅包',
        en: 'Red packet',
        ja: '红包',
        ko: '红包',
      );
    }
    return i18n.t(
      zhHans: '转账',
      zhHant: '轉賬',
      en: 'Transfer',
      ja: '送金',
      ko: '송금',
    );
  }

  String _stateLabel(AppI18n i18n) {
    final state = WalletOrderStateX.fromName(draft.orderState);
    switch (state) {
      case WalletOrderState.unknown:
        return i18n.t(
          zhHans: '状态确认中',
          zhHant: '狀態確認中',
          en: 'Confirming status',
          ja: '状態確認中',
          ko: '상태 확인 중',
        );
      case WalletOrderState.pending:
      case WalletOrderState.submitting:
        return i18n.t(
          zhHans: '处理中',
          zhHant: '處理中',
          en: 'Processing',
          ja: '処理中',
          ko: '처리 중',
        );
      case WalletOrderState.success:
        if (draft.needsChatCard && !draft.cardSent && !draft.cardIgnored) {
          return i18n.t(
            zhHans: '待发送聊天卡片',
            zhHant: '待發送聊天卡片',
            en: 'Chat card pending',
            ja: 'チャットカード送信待ち',
            ko: '채팅 카드 대기',
          );
        }
        return i18n.t(
          zhHans: '已完成',
          zhHant: '已完成',
          en: 'Completed',
          ja: '完了',
          ko: '완료',
        );
      case WalletOrderState.failed:
        return i18n.t(
          zhHans: '失败',
          zhHant: '失敗',
          en: 'Failed',
          ja: '失敗',
          ko: '실패',
        );
      default:
        return state.name;
    }
  }

  String _formatTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw.isEmpty ? '--' : raw;
    return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final i18n = AppI18n.of(context);
    final needsCard =
        draft.needsChatCard && !draft.cardSent && !draft.cardIgnored;
    final needsQuery = draft.needsOrderStatusQuery;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: cs.shadow,
            blurRadius: 10.r,
            offset: Offset(0, 3.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _typeLabel(i18n),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w800,
                    color: cs.text,
                  ),
                ),
              ),
              if (busy)
                SizedBox(
                  width: 18.w,
                  height: 18.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.red,
                  ),
                ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            '${draft.amountText.isNotEmpty ? draft.amountText : draft.amountMinor} ${draft.coin}',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF168CFF),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            _stateLabel(i18n),
            style: TextStyle(fontSize: 14.sp, color: cs.subText),
          ),
          if (draft.receiverName.isNotEmpty) ...[
            SizedBox(height: 4.h),
            Text(
              i18n.format(
                zhHans: '对方：{name}',
                zhHant: '對方：{name}',
                en: 'To: {name}',
                ja: '相手: {name}',
                ko: '상대: {name}',
                vars: {'name': draft.receiverName},
              ),
              style: TextStyle(fontSize: 13.sp, color: cs.subText),
            ),
          ],
          SizedBox(height: 4.h),
          Text(
            i18n.format(
              zhHans: '更新于 {time}',
              zhHant: '更新於 {time}',
              en: 'Updated {time}',
              ja: '更新 {time}',
              ko: '업데이트 {time}',
              vars: {
                'time': _formatTime(
                  draft.updatedAt.isNotEmpty
                      ? draft.updatedAt
                      : draft.createdAt,
                ),
              },
            ),
            style: TextStyle(fontSize: 12.sp, color: cs.subText),
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              if (needsQuery)
                OutlinedButton(
                  onPressed: busy ? null : onRefresh,
                  child: Text(
                    i18n.t(
                      zhHans: '查单',
                      zhHant: '查單',
                      en: 'Refresh',
                      ja: '照会',
                      ko: '조회',
                    ),
                  ),
                ),
              if (needsCard) ...[
                FilledButton(
                  onPressed: busy ? null : onResendCard,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF168CFF),
                  ),
                  child: Text(
                    i18n.t(
                      zhHans: '重发卡',
                      zhHant: '重發卡',
                      en: 'Resend card',
                      ja: 'カード再送',
                      ko: '카드 재전송',
                    ),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : onIgnoreCard,
                  child: Text(
                    i18n.t(
                      zhHans: '忽略',
                      zhHant: '忽略',
                      en: 'Ignore',
                      ja: '無視',
                      ko: '무시',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
