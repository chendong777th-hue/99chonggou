import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import 'red_packet/red_packet_member.dart';
import 'wallet_repository.dart';
import 'wallet_repository_provider.dart';

class WalletStore {
  WalletStore._();

  static final WalletStore instance = WalletStore._();

  WalletDto? _wallet;
  List<WalletPayMethodDto>? _payMethods;
  final Map<String, List<RedPacketMember>> _members = {};
  final Map<String, Future<WalletOrderCardDto>> _cardFutures = {};
  final Map<String, WalletOrderCardDto> _cards = {};
  Future<WalletDto>? _walletFuture;
  Future<List<WalletPayMethodDto>>? _payMethodsFuture;
  DateTime? _walletAt;
  DateTime? _payMethodsAt;

  static const Duration _ttl = Duration(seconds: 20);
  static const Duration _timeout = Duration(seconds: 6);

  WalletDto? get cachedWallet => _wallet;

  List<WalletPayMethodDto>? get cachedPayMethods => _payMethods;

  Future<WalletDto> getWallet({
    WalletRepository? repo,
    bool force = false,
  }) {
    final now = DateTime.now();
    final cached = _wallet;
    final fresh = _walletAt != null && now.difference(_walletAt!) < _ttl;
    if (!force && cached != null && fresh) {
      return Future.value(cached);
    }

    final running = _walletFuture;
    if (!force && running != null) return running;

    final repository = repo ?? createWalletRepository();
    final future = repository.getWallet().timeout(_timeout).then((value) {
      _wallet = value;
      _walletAt = DateTime.now();
      return value;
    }).whenComplete(() {
      _walletFuture = null;
    });
    _walletFuture = future;
    return future;
  }

  Future<List<WalletPayMethodDto>> getPayMethods({
    WalletRepository? repo,
    bool force = false,
  }) {
    final now = DateTime.now();
    final cached = _payMethods;
    final fresh =
        _payMethodsAt != null && now.difference(_payMethodsAt!) < _ttl;
    if (!force && cached != null && fresh) {
      return Future.value(cached);
    }

    final running = _payMethodsFuture;
    if (!force && running != null) return running;

    final repository = repo ?? createWalletRepository();
    final future = repository.getPayMethods().timeout(_timeout).then((value) {
      final next = value.isNotEmpty ? value : _payMethodsFromWallet(_wallet);
      _payMethods = next;
      _payMethodsAt = DateTime.now();
      return next;
    }).catchError((Object e) {
      final fallback = _payMethods ?? _payMethodsFromWallet(_wallet);
      if (fallback.isNotEmpty) return fallback;
      throw e;
    }).whenComplete(() {
      _payMethodsFuture = null;
    });
    _payMethodsFuture = future;
    return future;
  }

  Future<List<RedPacketMember>> getMembers(
    String conversationId, {
    WalletRepository? repo,
  }) async {
    final key = conversationId.trim();
    if (key.isEmpty) return const [];
    final cached = _members[key];
    if (cached != null) return cached;

    final repository = repo ?? createWalletRepository();
    try {
      final list = await repository.getRedPacketMembers(key).timeout(_timeout);
      _members[key] = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  String orderCardCacheKey({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    return [
      type,
      orderId,
      clientOrderId,
      currency ?? '',
      amount?.toString() ?? '',
      status ?? '',
      greeting ?? '',
    ].join('|');
  }

  /// Simplified key for in-flight request dedup: only type + orderId.
  /// The full cache key includes status/greeting which can differ across
  /// calls (null vs empty string vs COMPLETED), causing the same API
  /// endpoint to be hit 3-4 times per chat open. Using a stable request
  /// key ensures at most one concurrent fetch per order.
  String _orderCardRequestKey({
    required String type,
    required String orderId,
  }) {
    return '${type}_$orderId';
  }

  WalletOrderCardDto? peekOrderCard({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    return _cards[orderCardCacheKey(
      type: type,
      orderId: orderId,
      clientOrderId: clientOrderId,
      currency: currency,
      amount: amount,
      status: status,
      greeting: greeting,
    )];
  }

  Future<WalletOrderCardDto> getOrderCard({
    required WalletRepository repo,
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    final key = orderCardCacheKey(
      type: type,
      orderId: orderId,
      clientOrderId: clientOrderId,
      currency: currency,
      amount: amount,
      status: status,
      greeting: greeting,
    );

    final cached = _cards[key];
    if (cached != null) {
      return Future.value(cached);
    }

    // Request dedup: use a stable key (type + orderId) so that multiple
    // callers with slightly different status/greeting values (null vs
    // empty vs COMPLETED) don't each trigger a separate API call.
    final requestKey = _orderCardRequestKey(type: type, orderId: orderId);
    final running = _cardFutures[requestKey];
    if (running != null) return running;

    final local = buildLocalOrderCard(
      type: type,
      currency: currency,
      amount: amount,
      status: status,
      greeting: greeting,
    );

    final future = repo
        .getWalletOrderCard(
          type: type,
          orderId: orderId,
          clientOrderId: clientOrderId,
          currency: currency,
          amount: amount,
          status: status,
          greeting: greeting,
        )
        .timeout(_timeout)
        .then((value) {
      // 404/鉴权导致的 invalid 不覆盖 IM 本地可展示卡，避免会话刷成「无效卡片」。
      if (value.invalid) return local ?? value;
      return value.ok ? value : (local ?? value);
    })
        .catchError((_) {
      if (local != null) return local;
      return WalletOrderCardDto(
        ok: false,
        type: '',
        status: 'failed',
        amount: '',
        coin: '',
        title: AppI18n.current.t(
          zhHans: '订单异常',
          zhHant: '訂單異常',
          en: 'Order error',
          ja: '注文エラー',
          ko: '주문 오류',
        ),
        msg: AppI18n.current.t(
          zhHans: '无法加载订单状态',
          zhHant: '無法載入訂單狀態',
          en: 'Unable to load order status',
          ja: '注文状態を読み込めません',
          ko: '주문 상태를 불러올 수 없습니다',
        ),
      );
    }).then((value) {
      _cards[key] = value;
      // Also populate requestKey-based lookups for callers that used
      // different status/greeting values.
      _cards[requestKey] = value;
      return value;
    }).whenComplete(() {
      _cardFutures.remove(requestKey);
    });

    _cardFutures[requestKey] = future;
    return future;
  }

  void updateWallet(WalletDto value) {
    _wallet = value;
    _walletAt = DateTime.now();
  }

  void updatePayMethods(List<WalletPayMethodDto> value) {
    _payMethods = value;
    _payMethodsAt = DateTime.now();
  }

  void invalidateOrderCard({
    required String type,
    required String orderId,
    required String clientOrderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    final key = orderCardCacheKey(
      type: type,
      orderId: orderId,
      clientOrderId: clientOrderId,
      currency: currency,
      amount: amount,
      status: status,
      greeting: greeting,
    );
    _cards.remove(key);
    // Also remove any requestKey-based cache entry.
    final requestKey = _orderCardRequestKey(type: type, orderId: orderId);
    _cards.remove(requestKey);
    _cardFutures.remove(requestKey);
  }

  void clear() {
    _wallet = null;
    _payMethods = null;
    _members.clear();
    _cardFutures.clear();
    _cards.clear();
    _walletFuture = null;
    _payMethodsFuture = null;
    _walletAt = null;
    _payMethodsAt = null;
  }

  static WalletOrderCardDto? buildLocalOrderCard({
    required String type,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    if (type == 'wallet_red_packet') {
      return WalletOrderCardDto(
        ok: true,
        type: type,
        status: _cardStatus(status),
        amount: amount != null && currency != null && currency.isNotEmpty
            ? formatWalletAmount(currency, amount)
            : '',
        coin: currency != null && currency.isNotEmpty
            ? walletDisplayCoin(currency)
            : '',
        title: AppI18n.current.t(
          zhHans: '红包',
          zhHant: '紅包',
          en: 'Red packet',
          ja: '红包',
          ko: '红包',
        ),
        msg: (greeting == null || greeting.isEmpty)
            ? AppI18n.current.t(
                zhHans: '恭喜发财，大吉大利',
                zhHant: '恭喜發財，大吉大利',
                en: 'Best wishes and good fortune',
                ja: 'ご健勝とご多幸をお祈りします',
                ko: '복 많이 받으세요',
              )
            : greeting,
      );
    }

    if (type == 'wallet_transfer' || type == 'wallet_group_transfer') {
      // Always build a typed shell even when amount is missing — otherwise the
      // chat list flashes a gray loading card then swaps to the coral transfer
      // card after the network round-trip.
      final resolvedCurrency = (currency != null && currency.isNotEmpty)
          ? currency
          : WalletCurrency.platform;
      final isGroupTransfer = type == 'wallet_group_transfer';
      return WalletOrderCardDto(
        ok: true,
        type: type,
        status: _cardStatus(status),
        amount: amount != null
            ? formatWalletAmount(resolvedCurrency, amount)
            : '',
        coin: walletDisplayCoin(resolvedCurrency),
        title: AppI18n.current.t(
          zhHans: isGroupTransfer ? '群转账' : '转账',
          zhHant: isGroupTransfer ? '群轉帳' : '轉賬',
          en: isGroupTransfer ? 'Group Transfer' : 'Transfer',
          ja: isGroupTransfer ? 'グループ送金' : '送金',
          ko: isGroupTransfer ? '그룹 이체' : '송금',
        ),
        msg: '',
      );
    }

    return null;
  }

  static List<WalletPayMethodDto> _payMethodsFromWallet(WalletDto? wallet) {
    if (wallet == null) return const [];
    final list = <WalletPayMethodDto>[];
    for (final coin in wallet.coins) {
      final net = coin.platformCoin
          ? AppI18n.current.t(
              zhHans: '平台币',
              zhHant: '平台幣',
              en: 'Platform coin',
              ja: 'プラットフォーム通貨',
              ko: '플랫폼 코인',
            )
          : 'TRC20';
      list.add(coin.toPayMethod(net: net));
    }
    return list;
  }

  static String _cardStatus(String? status) {
    switch ((status ?? '').toUpperCase()) {
      case 'COMPLETED':
      case 'CREDITED':
      case 'SUCCESS':
        return 'success';
      case 'EMPTY':
      case 'FINISHED':
      case 'FULLY_CLAIMED':
      case 'CLAIMED_ALL':
        return 'finished';
      case 'CLAIMED':
      case 'RECEIVED':
        return 'claimed';
      case 'FAILED':
        return 'failed';
      case 'REFUNDED':
        return 'refunded';
      case 'EXPIRED':
        return 'expired';
      default:
        return 'pending';
    }
  }
}

/// 会话卡片已展示金额时，接口短暂返回空/0 不覆盖，避免发送后金额闪一下。
WalletOrderCardDto retainWalletCardDisplayAmount({
  required WalletOrderCardDto next,
  WalletOrderCardDto? previous,
}) {
  if (previous == null || previous.invalid) {
    return next;
  }
  final prevAmt = previous.amount.trim();
  final nextAmt = next.amount.trim();
  if (prevAmt.isEmpty) {
    return next;
  }
  final nextEmpty = nextAmt.isEmpty ||
      nextAmt == '0' ||
      nextAmt == '0.0' ||
      nextAmt == '0.00';
  if (!nextEmpty) {
    return next;
  }
  return next.copyWith(
    amount: previous.amount,
    coin: previous.coin.isNotEmpty ? previous.coin : next.coin,
  );
}

/// Maps wallet card status to the two visual themes used by chat cards
/// (bright/available vs dimmed/inactive). Title/msg-only API churn must not
/// cross this boundary or the card "flashes" on quiet refresh.
@visibleForTesting
String walletCardVisualFamily(String status) {
  switch ((status).trim().toLowerCase()) {
    case 'claimed':
    case 'received':
    case 'viewed':
    case 'finished':
    case 'empty':
    case 'fully_claimed':
    case 'claimed_all':
    case 'refunded':
    case 'expired':
    case 'failed':
    case 'failure':
    case 'error':
    case 'invalid':
      return 'inactive';
    default:
      return 'available';
  }
}

/// Quiet network merge should rebuild the widget only when something the user
/// can see actually changes (amount / coin / type / ok / visual family).
@visibleForTesting
bool walletCardQuietMergeNeedsRebuild({
  required WalletOrderCardDto? previous,
  required WalletOrderCardDto next,
}) {
  if (previous == null) return true;
  if (previous.ok != next.ok || previous.invalid != next.invalid) {
    return true;
  }
  if (previous.type != next.type) return true;
  if (previous.amount != next.amount || previous.coin != next.coin) {
    return true;
  }
  return walletCardVisualFamily(previous.status) !=
      walletCardVisualFamily(next.status);
}
