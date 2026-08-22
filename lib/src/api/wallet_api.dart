import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_order.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/record/wallet_record_models.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_member.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/order/wallet_card_integrity.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_repository.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';
import 'wallet_amount.dart';
import 'wallet_models.dart';

class RedPacketClaimStateDto {
  final String claimState;
  final int? myClaimAmount;
  final String packetStatus;
  final int remainingCount;

  const RedPacketClaimStateDto({
    required this.claimState,
    required this.myClaimAmount,
    required this.packetStatus,
    required this.remainingCount,
  });

  bool get canOpen => claimState == 'CAN_OPEN';

  bool get received => claimState == 'RECEIVED';

  bool get empty => claimState == 'EMPTY';

  /// 红包已被领完，且当前用户未领到。
  bool get depleted => empty || (!canOpen && !received && remainingCount <= 0);
}

class WalletApi {
  WalletApi._();
  static final WalletApi instance = WalletApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<WalletMe> getMe() async {
    return _fetchWalletMe('/wallet/me');
  }

  Future<WalletMe> _fetchWalletMe(String path) async {
    final res = await _dio.get(path);
    final payload = resolveWalletMePayload(res.data);
    assert(() {
      debugPrint(
        'wallet/me parsed: usdtPrice=${payload['usdtPrice']}, '
        'platformCurrency=${payload['platformCurrency']}, '
        'platformFen=${(payload['balances'] as Map?)?['platformFen']}',
      );
      return true;
    }());
    return WalletMe.fromJson(payload);
  }

  /// 合并 HTTP 包装层与 `data` 内层，避免 `usdtPrice` 等落在外层时被丢弃。
  static Map<String, dynamic> resolveWalletMePayload(dynamic raw) {
    if (raw == null) return {};
    final outer = _asMap(raw);
    final inner = _asMap(unwrapApiPayload(raw));

    final merged = WalletMe.mergeWalletPayload(
      inner.isNotEmpty ? inner : outer,
    );

    for (final entry in outer.entries) {
      final key = entry.key;
      if (_isWalletWrapperKey(key)) continue;
      if (key == 'data' ||
          key == 'result' ||
          key == 'payload' ||
          key == 'wallet') {
        continue;
      }
      merged[key] = entry.value;
    }

    return WalletMe.mergeWalletPayload(merged);
  }

  static bool _isWalletWrapperKey(String key) {
    return const {'code', 'message', 'msg', 'success', 'ok', 'status'}
        .contains(key);
  }

  Future<void> setPayPin(String payPin) async {
    await _dio.post('/wallet/pay-pin/set', data: {'payPin': payPin});
  }

  Future<void> changePayPin({
    required String oldPayPin,
    required String newPayPin,
  }) async {
    await _dio.post('/wallet/pay-pin/change', data: {
      'oldPayPin': oldPayPin,
      'newPayPin': newPayPin,
    });
  }

  Future<void> resetPayPinWithSms({
    required String payPin,
    required String smsCode,
  }) async {
    await _dio.post('/wallet/pay-pin/reset', data: {
      'payPin': payPin,
      'smsCode': smsCode,
    });
  }

  Future<WalletCurrenciesResponse> getCurrencies() async {
    final res = await _dio.get('/wallet/currencies');
    return WalletCurrenciesResponse.fromJson(
      _asMap(unwrapApiPayload(res.data)),
    );
  }

  Future<WalletDto> getWallet() async {
    final results = await Future.wait([getMe(), getCurrencies()]);
    return _walletDtoFromMeAndCurrencies(
      results[0] as WalletMe,
      results[1] as WalletCurrenciesResponse,
    );
  }

  Future<List<WalletPayMethodDto>> getPayMethods() async {
    final currencies = await getCurrencies();
    return _payMethodsFromCurrencies(currencies);
  }

  Future<WalletOrderResult> createTransfer({
    required String toUserId,
    required String currency,
    required int amount,
    required String payPin,
    String clientOrderId = '',
    String? memo,
  }) async {
    final res = await _dio.post('/wallet/transfer', data: {
      'toUserId': toUserId,
      'currency': currency.toUpperCase(),
      'amount': amount,
      'payPin': payPin,
      if (clientOrderId.trim().isNotEmpty)
        'clientOrderId': clientOrderId.trim(),
      if (memo != null && memo.trim().isNotEmpty) 'memo': memo.trim(),
    });
    return _successOrderFromMap(
      _asMap(unwrapApiPayload(res.data)),
      fallbackType: 'wallet_transfer',
    );
  }

  Future<WalletOrderResult> createWithdraw({
    required String toAddress,
    required int amountMicro,
    required String payPin,
    String clientOrderId = '',
  }) async {
    final res = await _dio.post('/wallet/withdraw', data: {
      'toAddress': toAddress,
      'amountMicro': amountMicro,
      'payPin': payPin,
      if (clientOrderId.trim().isNotEmpty)
        'clientOrderId': clientOrderId.trim(),
    });
    return _successOrderFromMap(
      _asMap(unwrapApiPayload(res.data)),
      fallbackType: 'wallet_withdraw',
    );
  }

  Future<WalletOrderResult> getWithdrawOrder(String orderId) async {
    final res = await _dio.get(
      '/wallet/withdraw/${Uri.encodeComponent(orderId.trim())}',
    );
    return _withdrawOrderFromMap(
      _asMap(unwrapApiPayload(res.data)),
      fallbackOrderId: orderId,
    );
  }

  Future<WalletOrderResult> getWithdrawOrderByClientId(
    String clientOrderId,
  ) async {
    final res = await _dio.get(
      '/wallet/withdraw/by-client-id/${Uri.encodeComponent(clientOrderId.trim())}',
    );
    return _withdrawOrderFromMap(
      _asMap(unwrapApiPayload(res.data)),
      fallbackClientOrderId: clientOrderId,
    );
  }

  Future<void> reportWithdrawLiveActivityToken({
    required String orderId,
    required String activityId,
    required String pushToken,
    required String bundleId,
    String platform = 'ios',
    String environment = '',
  }) async {
    try {
      await _dio.put(
        '/wallet/withdraw/${Uri.encodeComponent(orderId.trim())}/live-activity-token',
        data: {
          'platform': platform,
          'activityId': activityId,
          'pushToken': pushToken,
          'bundleId': bundleId,
          if (environment.trim().isNotEmpty) 'environment': environment.trim(),
        },
      );
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) return;
      rethrow;
    }
  }

  static WalletOrderResult _withdrawOrderFromMap(
    Map<String, dynamic> map, {
    String fallbackOrderId = '',
    String fallbackClientOrderId = '',
  }) {
    final status = map['status']?.toString() ?? map['state']?.toString() ?? '';
    final orderId = map['id']?.toString().trim().isNotEmpty == true
        ? map['id']!.toString()
        : fallbackOrderId;
    final clientOrderId =
        map['clientOrderId']?.toString().trim().isNotEmpty == true
            ? map['clientOrderId']!.toString()
            : fallbackClientOrderId;
    return WalletOrderResult(
      ok: true,
      state: _orderStateFromWalletStatus(status),
      orderId: orderId,
      clientOrderId: clientOrderId,
      msg: map['memo']?.toString() ?? '',
      data: {
        ...map,
        'type': 'wallet_withdraw',
        'orderId': orderId,
        if (!map.containsKey('stage'))
          'stage': _stageFromWalletStatus(status),
      },
    );
  }

  static String _stageFromWalletStatus(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'CREDITED':
        return 'COMPLETED';
      case 'FAILED':
      case 'REFUNDED':
      case 'EXPIRED':
        return 'FAILED';
      case 'BROADCASTING':
        return 'BROADCASTING';
      case 'CONFIRMING':
        return 'CONFIRMING';
      case 'PENDING':
      case 'ACTIVE':
        return 'SUBMITTED';
      default:
        return 'SUBMITTED';
    }
  }

  Future<WalletOrderResult> sendRedPacket(Map<String, dynamic> body) async {
    const path = '/wallet/red-packet/send';
    try {
      final res = await _dio.post(path, data: body);
      _logRedPacketApi('POST $path', request: body, response: res.data);
      return _successOrderFromMap(
        _asMap(unwrapApiPayload(res.data)),
        fallbackType: 'wallet_red_packet',
      );
    } catch (e) {
      _logRedPacketApi('POST $path', request: body, error: e);
      rethrow;
    }
  }

  Future<WalletExchangeOrderDto> createExchange({
    required WalletExchangeDirection direction,
    required int amount,
    required String payPin,
  }) async {
    final res = await _dio.post('/wallet/exchange', data: {
      'direction': direction.code,
      'amount': amount,
      'payPin': payPin,
    });
    return _parseExchangeOrder(_asMap(unwrapApiPayload(res.data)));
  }

  Future<List<WalletExchangeOrderDto>> getExchangeOrders({
    int page = 0,
    int size = 20,
  }) async {
    final res = await _dio.get(
      '/wallet/exchanges',
      queryParameters: {'page': page, 'size': size},
    );
    return _pageItems(res.data)
        .whereType<Map>()
        .map((e) => _parseExchangeOrder(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<WalletOrderResult> getRedPacketOrder(String orderId) async {
    final id = _redPacketServerIdOrThrow(orderId);
    final path = '/wallet/red-packet/${Uri.encodeComponent(id)}';
    try {
      final res = await _dio.get(path);
      _logRedPacketApi('GET $path', response: res.data);
      final map = _redPacketMap(_asMap(unwrapApiPayload(res.data)));
      final status =
          map['status']?.toString() ?? map['state']?.toString() ?? '';
      return WalletOrderResult(
        ok: true,
        state: _orderStateFromWalletStatus(status),
        orderId: map['id']?.toString() ?? orderId,
        msg: map['greeting']?.toString() ?? '',
        data: map,
      );
    } catch (e) {
      _logRedPacketApi('GET $path', error: e);
      rethrow;
    }
  }

  Future<WalletOrderResult> getTransferOrder(String orderId) async {
    final res = await _dio.get(
      '/wallet/transfer/${Uri.encodeComponent(orderId.trim())}',
    );
    return _transferOrderFromMap(
      _asMap(unwrapApiPayload(res.data)),
      fallbackOrderId: orderId,
    );
  }

  Future<WalletOrderResult> getTransferOrderByClientId(
      String clientOrderId) async {
    final res = await _dio.get(
      '/wallet/transfer/by-client-id/${Uri.encodeComponent(clientOrderId.trim())}',
    );
    return _transferOrderFromMap(
      _asMap(unwrapApiPayload(res.data)),
      fallbackClientOrderId: clientOrderId,
    );
  }

  static WalletOrderResult _transferOrderFromMap(
    Map<String, dynamic> map, {
    String fallbackOrderId = '',
    String fallbackClientOrderId = '',
  }) {
    final status = map['status']?.toString() ?? map['state']?.toString() ?? '';
    return WalletOrderResult(
      ok: true,
      state: _orderStateFromWalletStatus(status),
      orderId: map['id']?.toString().trim().isNotEmpty == true
          ? map['id']!.toString()
          : fallbackOrderId,
      clientOrderId: map['clientOrderId']?.toString().trim().isNotEmpty == true
          ? map['clientOrderId']!.toString()
          : fallbackClientOrderId,
      msg: map['memo']?.toString() ?? '',
      data: {
        ...map,
        'type': 'wallet_transfer',
        'orderId': map['id']?.toString() ?? fallbackOrderId,
      },
    );
  }

  Future<RedPacketClaimStateDto> getRedPacketClaimState(String orderId) async {
    final id = _redPacketServerIdOrThrow(orderId);
    final path = '/wallet/red-packet/${Uri.encodeComponent(id)}/claim-state';
    try {
      final res = await _dio.get(path);
      _logRedPacketApi('GET $path', response: res.data);
      final map = _asMap(unwrapApiPayload(res.data));
      final claimState =
          map['claimState']?.toString().trim().toUpperCase() ?? '';
      final amountRaw = map['myClaimAmount'];
      return RedPacketClaimStateDto(
        claimState: claimState,
        myClaimAmount: amountRaw == null ? null : _asInt(amountRaw),
        packetStatus:
            map['packetStatus']?.toString().trim().toUpperCase() ?? '',
        remainingCount: _asInt(map['remainingCount']),
      );
    } catch (e) {
      _logRedPacketApi('GET $path', error: e);
      rethrow;
    }
  }

  Future<WalletOrderCardDto> getWalletOrderCard({
    required String type,
    required String orderId,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) async {
    // 群转账底座为红包表 GROUP_TRANSFER，查单必须走 /wallet/red-packet/{id}，
    // 不可走 /wallet/transfer（会 404 → 会话刷成「无效卡片」）。
    if (type == 'wallet_group_transfer') {
      final lookupId = orderId.trim();
      if (lookupId.isNotEmpty) {
        try {
          final map = await _getRedPacketMapByLookupId(
            lookupId,
            logContext: 'group-transfer-card',
          );
          return _parseTransferCard(
            type: 'wallet_group_transfer',
            map: map,
            fallbackCurrency: currency,
            fallbackAmount: amount,
            fallbackGreeting: greeting,
            fallbackStatus: status ?? 'success',
          );
        } catch (e) {
          if (WalletCardIntegrity.isNotFoundOrForbiddenStatus(_dioStatus(e))) {
            return _transferCardFallbackOrInvalid(
              type: type,
              currency: currency,
              amount: amount,
              status: status ?? 'success',
              greeting: greeting,
            );
          }
        }
      }
      return _transferCardFallbackOrInvalid(
        type: type,
        currency: currency,
        amount: amount,
        status: status ?? 'success',
        greeting: greeting,
      );
    }

    if (type == 'wallet_transfer') {
      final lookupId = orderId.trim();
      if (lookupId.isNotEmpty) {
        try {
          final ret = await getTransferOrder(lookupId);
          return _parseTransferCard(
            type: type,
            map: ret.data,
            fallbackCurrency: currency,
            fallbackAmount: amount,
            fallbackGreeting: greeting,
            fallbackStatus: status,
          );
        } catch (e) {
          if (WalletCardIntegrity.isNotFoundOrForbiddenStatus(_dioStatus(e))) {
            return _transferCardFallbackOrInvalid(
              type: type,
              currency: currency,
              amount: amount,
              status: status,
              greeting: greeting,
            );
          }
        }
      }
      return _transferCardFallbackOrInvalid(
        type: type,
        currency: currency,
        amount: amount,
        status: status,
        greeting: greeting,
      );
    }

    if (type == 'wallet_red_packet') {
      final lookupId = orderId.trim();
      if (lookupId.isNotEmpty) {
        try {
          final map = await _getRedPacketMapByLookupId(
            lookupId,
            logContext: 'order-card',
          );
          return _parseRedPacketCard(map);
        } catch (e) {
          if (amount != null && currency != null && currency.isNotEmpty) {
            return _placeholderRedPacketCard(
              currency: currency,
              amount: amount,
              status: status,
              greeting: greeting,
            );
          }
          if (WalletCardIntegrity.isNotFoundOrForbiddenStatus(_dioStatus(e))) {
            return WalletOrderCardDto.invalidCard();
          }
        }
      }
    }

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
        zhHans: '无法加载订单',
        zhHant: '無法載入訂單',
        en: 'Unable to load order',
        ja: '注文を読み込めません',
        ko: '주문을 불러올 수 없습니다',
      ),
    );
  }

  Future<Map<String, dynamic>> _getRedPacketMapByLookupId(
    String lookupId, {
    required String logContext,
  }) async {
    final id = lookupId.trim();
    final path = '/wallet/red-packet/${Uri.encodeComponent(id)}';
    try {
      final res = await _dio.get(path);
      _logRedPacketApi('GET $path ($logContext)', response: res.data);
      return _redPacketMap(_asMap(unwrapApiPayload(res.data)));
    } catch (e) {
      _logRedPacketApi('GET $path ($logContext)', error: e);
      if (isRedPacketClientOrderId(id) && _shouldTryRedPacketClientIdPath(e)) {
        final fallbackPath =
            '/wallet/red-packet/by-client-id/${Uri.encodeComponent(id)}';
        try {
          final res = await _dio.get(fallbackPath);
          _logRedPacketApi(
            'GET $fallbackPath ($logContext)',
            response: res.data,
          );
          return _redPacketMap(_asMap(unwrapApiPayload(res.data)));
        } catch (fallbackError) {
          _logRedPacketApi(
            'GET $fallbackPath ($logContext)',
            error: fallbackError,
          );
          rethrow;
        }
      }
      rethrow;
    }
  }

  static bool _shouldTryRedPacketClientIdPath(Object error) {
    final status = _dioStatus(error);
    return status == null ||
        status == 400 ||
        WalletCardIntegrity.isNotFoundOrForbiddenStatus(status);
  }

  /// 404/403 或无可查 id 时：IM payload 有金额则出占位卡，避免刷成「无效卡片」。
  static WalletOrderCardDto _transferCardFallbackOrInvalid({
    required String type,
    String? currency,
    int? amount,
    String? status,
    String? greeting,
  }) {
    if (amount != null && currency != null && currency.isNotEmpty) {
      return _placeholderTransferCard(
        type: type,
        currency: currency,
        amount: amount,
        status: status,
        greeting: greeting,
      );
    }
    return WalletOrderCardDto.invalidCard();
  }

  Future<List<WalletRecordDto>> getLedger({
    int page = 0,
    int size = 20,
    List<String> ledgerTypes = const [],
    String? source,
    String? currency,
    String? startTime,
    String? endTime,
  }) async {
    final query = <String, dynamic>{'page': page, 'size': size};
    if (ledgerTypes.isNotEmpty) {
      query['ledgerType'] = ledgerTypes;
    }
    final sourceValue = source?.trim();
    if (sourceValue != null && sourceValue.isNotEmpty) {
      query['source'] = sourceValue;
    }
    final currencyValue = currency?.trim();
    if (currencyValue != null && currencyValue.isNotEmpty) {
      query['currency'] = currencyValue;
    }
    final startTimeValue = startTime?.trim();
    if (startTimeValue != null && startTimeValue.isNotEmpty) {
      query['startTime'] = startTimeValue;
    }
    final endTimeValue = endTime?.trim();
    if (endTimeValue != null && endTimeValue.isNotEmpty) {
      query['endTime'] = endTimeValue;
    }
    final res = await _dio.get(
      '/wallet/ledger',
      queryParameters: query,
    );
    final payload = unwrapApiPayload(res.data);
    final list = extractApiList(payload, listKeys: const ['content']);
    return list
        .whereType<Map>()
        .map((e) => _parseLedgerItem(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<List<WalletRecordDto>> getLedgerAll({
    List<String> ledgerTypes = const [],
    String? source,
    String? currency,
    String? startTime,
    String? endTime,
    int pageSize = 100,
    int maxPages = 20,
  }) async {
    final records = <WalletRecordDto>[];
    final seenIds = <String>{};

    for (var page = 0; page < maxPages; page++) {
      final batch = await getLedger(
        page: page,
        size: pageSize,
        ledgerTypes: ledgerTypes,
        source: source,
        currency: currency,
        startTime: startTime,
        endTime: endTime,
      );
      if (batch.isEmpty) break;

      for (final item in batch) {
        if (seenIds.add(item.id)) {
          records.add(item);
        }
      }

      if (batch.length < pageSize) {
        break;
      }
    }

    return _sortRecords(records);
  }

  Future<List<WalletRecordDto>> getRecords({String type = 'all'}) async {
    switch (type) {
      case 'receive':
        return getLedgerAll(
          ledgerTypes: const [
            'DEPOSIT',
            'TRANSFER_IN',
            'RED_PACKET_RECEIVE',
            'WITHDRAW_REFUND',
          ],
        );
      case 'transfer':
        return getLedgerAll(
          ledgerTypes: const ['TRANSFER_OUT', 'TRANSFER_IN'],
        );
      case 'redPacket':
        return getLedgerAll(
          ledgerTypes: const [
            'RED_PACKET_SEND',
            'RED_PACKET_RECEIVE',
            'RED_PACKET_REFUND',
          ],
        );
      case 'swap':
        return getLedgerAll(
          ledgerTypes: const ['EXCHANGE_OUT', 'EXCHANGE_IN', 'FEE'],
        );
      case 'all':
      default:
        return getLedgerAll();
    }
  }

  Future<List<WalletRecordDto>> getHistoryRecords() async {
    return getLedgerAll();
  }

  Future<List<WalletRecordDto>> getHistoryRecordsByFilter(
    HistoryRecordFilter filter, {
    int page = 0,
    int size = 20,
  }) async {
    Future<List<WalletRecordDto>> loadLedger({
      List<String> ledgerTypes = const [],
      String? source,
    }) {
      final shouldLoadAll = page == 0 && size == 20;
      if (shouldLoadAll) {
        return getLedgerAll(
          ledgerTypes: ledgerTypes,
          source: source,
        );
      }
      return getLedger(
        page: page,
        size: size,
        ledgerTypes: ledgerTypes,
        source: source,
      ).then(_sortRecords);
    }

    switch (filter) {
      case HistoryRecordFilter.all:
        return page == 0 && size == 20
            ? getHistoryRecords()
            : getLedger(
                page: page,
                size: size,
              ).then(_sortRecords);
      case HistoryRecordFilter.chainDeposit:
        return loadLedger(
          ledgerTypes: const ['DEPOSIT'],
          source: 'CHAIN',
        );
      case HistoryRecordFilter.internalDeposit:
        return loadLedger(
          ledgerTypes: const ['DEPOSIT'],
          source: 'INTERNAL',
        );
      case HistoryRecordFilter.chainWithdraw:
        return loadLedger(
          ledgerTypes: const ['WITHDRAW'],
          source: 'CHAIN',
        );
      case HistoryRecordFilter.internalWithdraw:
        return loadLedger(
          ledgerTypes: const ['WITHDRAW'],
          source: 'INTERNAL',
        );
      case HistoryRecordFilter.redPacket:
        return loadLedger(
          ledgerTypes: const ['RED_PACKET_SEND', 'RED_PACKET_RECEIVE'],
        );
      case HistoryRecordFilter.redPacketRefund:
        return loadLedger(
          ledgerTypes: const ['RED_PACKET_REFUND'],
        );
      case HistoryRecordFilter.transfer:
        return loadLedger(
          ledgerTypes: const ['TRANSFER_OUT', 'TRANSFER_IN'],
        );
      case HistoryRecordFilter.transferRefund:
        return const [];
    }
  }

  Future<List<WalletRecordDto>> getDeposits({
    int page = 0,
    int size = 20,
  }) async {
    return getHistoryRecordsByFilter(
      HistoryRecordFilter.chainDeposit,
      page: page,
      size: size,
    ).then((records) {
      final chain = records.where((item) => item.isChainDeposit).toList();
      if (page == 0 && size == 20) {
        return _sortRecords(chain);
      }
      return chain;
    });
  }

  Future<List<WalletRecordDto>> getWithdrawals({
    int page = 0,
    int size = 20,
  }) async {
    return getHistoryRecordsByFilter(
      HistoryRecordFilter.chainWithdraw,
      page: page,
      size: size,
    ).then((records) {
      final chain = records.where((item) => item.isChainWithdraw).toList();
      if (page == 0 && size == 20) {
        return _sortRecords(chain);
      }
      return chain;
    });
  }

  Future<List<WalletRecordDto>> getTransfers({
    String direction = 'all',
    int page = 0,
    int size = 20,
  }) async {
    final ledgerTypes = switch (direction) {
      'sent' => const ['TRANSFER_OUT'],
      'received' => const ['TRANSFER_IN'],
      _ => const ['TRANSFER_OUT', 'TRANSFER_IN'],
    };
    return (page == 0 && size == 20
            ? getLedgerAll(ledgerTypes: ledgerTypes)
            : getLedger(
                page: page,
                size: size,
                ledgerTypes: ledgerTypes,
              ))
        .then(_sortRecords);
  }

  Future<List<WalletRecordDto>> getRedPacketRecords({
    String role = 'sent',
    int page = 0,
    int size = 20,
  }) async {
    final ledgerTypes = switch (role) {
      'received' => const ['RED_PACKET_RECEIVE'],
      'sent' => const ['RED_PACKET_SEND'],
      _ => const ['RED_PACKET_SEND', 'RED_PACKET_RECEIVE'],
    };
    return (page == 0 && size == 20
            ? getLedgerAll(ledgerTypes: ledgerTypes)
            : getLedger(
                page: page,
                size: size,
                ledgerTypes: ledgerTypes,
              ))
        .then(_sortRecords);
  }

  Future<List<Map<String, dynamic>>> getRedPacketClaims(String orderId) async {
    final id = _redPacketServerIdOrThrow(orderId);
    final path = '/wallet/red-packet/${Uri.encodeComponent(id)}/claims';
    try {
      final res = await _dio.get(path);
      _logRedPacketApi('GET $path', response: res.data);
      return _parseClaimMaps(res.data);
    } catch (e) {
      _logRedPacketApi('GET $path', error: e);
      rethrow;
    }
  }

  static String _redPacketServerIdOrThrow(String raw) {
    final id = raw.trim();
    if (isRedPacketServerId(id)) return id;
    if (isRedPacketClientOrderId(id)) {
      throw ArgumentError(
        'red packet API requires numeric server id, got clientOrderId=$id',
      );
    }
    throw ArgumentError('invalid red packet server id: $id');
  }

  /// 兼容 `{ content: [] }` / `{ claims: [] }` / 直接数组等多种领取列表包装。
  static List<Map<String, dynamic>> _parseClaimMaps(dynamic raw) {
    final items = extractApiList(
      unwrapApiPayload(raw),
      listKeys: const ['claims', 'content', 'items', 'list', 'records'],
    );
    return items
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// 红包接口调试日志，在控制台过滤 `[red-packet]`。
  static void _logRedPacketApi(
    String label, {
    Object? request,
    Object? response,
    Object? error,
  }) {
    final buffer = StringBuffer('[red-packet] $label');
    if (request != null) {
      buffer.write(
          '\n  request: ${_redPacketJson(_redactRedPacketLog(request))}');
    }
    if (response != null) {
      buffer.write('\n  response: ${_redPacketJson(response)}');
    }
    if (error != null) {
      if (error is DioError) {
        buffer
          ..write('\n  error: ${error.message}')
          ..write('\n  status: ${error.response?.statusCode}')
          ..write('\n  errorBody: ${_redPacketJson(error.response?.data)}');
      } else {
        buffer.write('\n  error: $error');
      }
    }
    debugPrint(buffer.toString());
  }

  static Object? _redactRedPacketLog(Object? value) {
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    for (final key in const ['payPin', 'password', 'payPassword', 'pin']) {
      if (map[key] != null && map[key].toString().isNotEmpty) {
        map[key] = '***';
      }
    }
    return map;
  }

  static String _redPacketJson(Object? value) {
    if (value == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<WalletOrderResult> claimRedPacket({
    required String orderId,
    String? payPin,
  }) async {
    final id = _redPacketServerIdOrThrow(orderId);
    final path = '/wallet/red-packet/${Uri.encodeComponent(id)}/claim';
    final body = <String, dynamic>{
      if (payPin != null && payPin.trim().isNotEmpty) 'payPin': payPin,
    };
    try {
      final res = await _dio.post(path, data: body);
      _logRedPacketApi('POST $path', request: body, response: res.data);
      final map = _asMap(unwrapApiPayload(res.data));
      return WalletOrderResult(
        ok: true,
        state: WalletOrderState.success,
        orderId: map['packetId']?.toString() ?? orderId,
        msg: AppI18n.current.t(
          zhHans: '领取成功',
          zhHant: '領取成功',
          en: 'Claimed successfully',
          ja: '受取に成功しました',
          ko: '수령 성공',
        ),
        data: map,
      );
    } catch (e) {
      _logRedPacketApi('POST $path', request: body, error: e);
      rethrow;
    }
  }

  Future<List<RedPacketMember>> getRedPacketMembers(
      String conversationId) async {
    final groupId = conversationId.trim();
    if (groupId.isEmpty) return const [];
    if (groupId == 'wallet_home') {
      return _getFriendMembers();
    }

    final members = <RedPacketMember>[];
    var nextSeq = '0';
    do {
      final result = await TencentImSDKPlugin.v2TIMManager
          .getGroupManager()
          .getGroupMemberList(
            groupID: groupId,
            filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
            nextSeq: nextSeq,
          );
      if (result.code != 0) break;
      final data = result.data;
      final list = data?.memberInfoList ?? [];
      for (final item in list) {
        final userId = _text(item.userID);
        if (userId.isEmpty) continue;
        final nickName = _text(item.nickName);
        final name = nickName.isNotEmpty ? nickName : userId;
        members.add(RedPacketMember(
          userId: userId,
          name: name,
          avatar: _text(item.faceUrl),
        ));
      }
      nextSeq = data?.nextSeq?.toString() ?? '0';
    } while (nextSeq != '0');

    return members;
  }

  Future<List<RedPacketMember>> _getFriendMembers() async {
    final list = await MeFriendApi.instance.loadFriendsForPickers();
    return list
        .map((item) {
          final userId = _text(item.userID);
          final remark = _text(item.friendRemark);
          final nickName = _text(item.userProfile?.nickName);
          final name = remark.isNotEmpty
              ? remark
              : (nickName.isNotEmpty ? nickName : userId);
          return RedPacketMember(
            userId: userId,
            name: name,
            avatar: _text(item.userProfile?.faceUrl),
          );
        })
        .where((item) => item.userId.isNotEmpty)
        .toList();
  }

  static Map<String, dynamic> buildRedPacketBody({
    required WalletRedPacketReq req,
    required bool isGroup,
  }) {
    final currency = _currencyFromPay(req.payId, req.coin);
    final payPin = req.pwd;
    final greeting = req.msg;
    final totalAmount = int.tryParse(req.totalMinor) ?? 0;
    final perAmount = int.tryParse(req.amountMinor) ?? 0;
    final packetCount = int.tryParse(req.cnt) ?? 0;

    final clientOrderId = req.clientOrderId.trim();

    if (!isGroup) {
      return {
        if (clientOrderId.isNotEmpty) 'clientOrderId': clientOrderId,
        'packetType': 'NORMAL_C2C',
        'conversationType': 'C2C',
        'toUserId': req.toUserId,
        'currency': currency,
        'totalAmount': totalAmount > 0 ? totalAmount : perAmount,
        'greeting': greeting,
        'payPin': payPin,
      };
    }

    switch (req.rpType) {
      case 'lucky':
        return {
          if (clientOrderId.isNotEmpty) 'clientOrderId': clientOrderId,
          'packetType': 'LUCKY_GROUP',
          'conversationType': 'GROUP',
          'groupId': req.convId,
          'currency': currency,
          'totalAmount': totalAmount,
          'packetCount': packetCount,
          'greeting': greeting,
          'payPin': payPin,
        };
      case 'exclusive':
        return {
          if (clientOrderId.isNotEmpty) 'clientOrderId': clientOrderId,
          'packetType': 'EXCLUSIVE',
          'conversationType': 'GROUP',
          'groupId': req.convId,
          'toUserId': req.toUserId,
          'currency': currency,
          'totalAmount': totalAmount > 0 ? totalAmount : perAmount,
          'greeting': greeting,
          'payPin': payPin,
        };
      case 'group_transfer':
        return {
          if (clientOrderId.isNotEmpty) 'clientOrderId': clientOrderId,
          'packetType': 'GROUP_TRANSFER',
          'conversationType': 'GROUP',
          'groupId': req.convId,
          'toUserId': req.toUserId,
          'currency': currency,
          'totalAmount': totalAmount > 0 ? totalAmount : perAmount,
          'greeting': greeting,
          'payPin': payPin,
        };
      case 'normal':
      default:
        return {
          if (clientOrderId.isNotEmpty) 'clientOrderId': clientOrderId,
          'packetType': 'NORMAL_GROUP',
          'conversationType': 'GROUP',
          'groupId': req.convId,
          'currency': currency,
          'perAmount': perAmount,
          'packetCount': packetCount,
          'greeting': greeting,
          'payPin': payPin,
        };
    }
  }

  static WalletDto _walletDtoFromMeAndCurrencies(
    WalletMe me,
    WalletCurrenciesResponse currencies,
  ) {
    final usdtCnyFen = walletUsdtCnyFen(
      usdtMicro: me.usdtMicro,
      rate: me.exchangeRate,
      serverUsdtCnyFen: me.usdtCnyFen,
    );
    final totalFen =
        me.totalAssetsFen > 0 ? me.totalAssetsFen : me.platformFen + usdtCnyFen;
    return WalletDto(
      totalBal: formatPlatformFen(totalFen),
      totalBalUsd: _formatTotalBalUsd(totalFen, me),
      trxAddr: me.depositAddress,
      coins: currencies.currencies.map(_coinDtoFromCurrency).toList(),
    );
  }

  /// 总资产（分）按 USDT/CNY 中间价折算为 USD 展示字符串。
  static String _formatTotalBalUsd(int totalFen, WalletMe me) {
    final rate =
        me.exchangeRate?.effectiveCnyPerUsdt ?? me.usdtPrice?.cnyPerUsdt ?? 0;
    if (rate <= 0) return '';
    if (totalFen <= 0) return '0.00';
    return (totalFen / 100.0 / rate).toStringAsFixed(2);
  }

  static CoinDto _coinDtoFromCurrency(WalletCurrencyItem c) {
    final type = c.platformCoin
        ? CoinType.cny
        : (c.code.toUpperCase() == 'USDT' ? CoinType.usdt : CoinType.trx);

    String sub;
    if (c.price != null && c.price! > 0) {
      sub = formatCnyYuan(
        c.price!,
        fractionDigits: c.platformCoin ? 2 : 4,
      );
    } else {
      sub = '--';
    }

    String fiat;
    if (c.price != null && c.price! > 0) {
      final amount = double.tryParse(c.amountDisplay) ?? 0;
      final value = amount * c.price!;
      // 零余额仍展示 ¥0.00，避免列表右侧出现 `--`。
      fiat = value <= 0 ? '¥0.00' : formatCnyYuan(value, fractionDigits: 2);
    } else {
      fiat = '--';
    }

    final isUsdt = type == CoinType.usdt;
    return CoinDto(
      name: c.name,
      sub: sub,
      bal: isUsdt ? formatUsdtBalanceDisplay(c.amountDisplay) : c.amountDisplay,
      fiat: fiat,
      type: type,
      code: c.code,
      logoUrl: c.logoUrl.isEmpty ? null : c.logoUrl,
      platformCoin: c.platformCoin,
      depositEnabled: c.depositEnabled,
      withdrawEnabled: c.withdrawEnabled,
      balMinor: c.availableAmount,
      scale: c.amountUnit == 'micro'
          ? WalletCurrency.usdtScale
          : WalletCurrency.platformScale,
      priceChangePercent: c.priceChangePercent,
    );
  }

  static List<WalletPayMethodDto> _payMethodsFromCurrencies(
    WalletCurrenciesResponse response,
  ) {
    return response.currencies.map(_payMethodFromCurrency).toList();
  }

  static WalletPayMethodDto _payMethodFromCurrency(WalletCurrencyItem c) {
    final isPlatform = c.platformCoin;
    final scale = c.amountUnit == 'micro'
        ? WalletCurrency.usdtScale
        : WalletCurrency.platformScale;

    String fiat;
    if (c.price != null && c.price! > 0) {
      final amount = double.tryParse(c.amountDisplay) ?? 0;
      fiat = formatCnyYuan(amount * c.price!, fractionDigits: 2);
    } else {
      fiat = '--';
    }

    final net = isPlatform
        ? AppI18n.current.t(
            zhHans: '平台币',
            zhHant: '平台幣',
            en: 'Platform coin',
            ja: 'プラットフォーム通貨',
            ko: '플랫폼 코인',
          )
        : 'TRC20';

    final isUsdt = !isPlatform && c.code.toUpperCase() == 'USDT';
    return WalletPayMethodDto(
      id: isPlatform ? WalletCurrency.platform : c.code.toUpperCase(),
      coin: c.name,
      net: net,
      bal: isUsdt ? formatUsdtBalanceDisplay(c.amountDisplay) : c.amountDisplay,
      fiat: fiat,
      balMinor: c.availableAmount,
      scale: scale,
      logoUrl: c.logoUrl.isEmpty ? null : c.logoUrl,
      code: c.code,
      platformCoin: isPlatform,
      color: isPlatform ? const Color(0xFF2B72FF) : const Color(0xFF26A17B),
      badgeColor:
          isPlatform ? const Color(0xFF45C3FF) : const Color(0xFFFF001F),
      badge: isPlatform ? '99' : 'T',
    );
  }

  static WalletOrderCardDto _parseRedPacketCard(Map<String, dynamic> map) {
    final i18n = AppI18n.current;
    final currency = map['currency']?.toString() ?? WalletCurrency.platform;
    final amount = _asInt(map['totalAmount'] ?? map['amount']);
    return WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: _cardStatusFromWalletStatus(map['status']?.toString() ?? ''),
      amount: formatWalletAmount(currency, amount),
      coin: walletDisplayCoin(currency),
      title: i18n.t(
        zhHans: '红包',
        zhHant: '紅包',
        en: 'Red packet',
        ja: '红包',
        ko: '红包',
      ),
      msg: map['greeting']?.toString() ??
          i18n.t(
            zhHans: '恭喜发财，大吉大利',
            zhHant: '恭喜發財，大吉大利',
            en: 'Best wishes and good fortune',
            ja: 'ご健勝とご多幸をお祈りします',
            ko: '복 많이 받으세요',
          ),
      senderUserId: _orderSenderUserId(map),
      groupId: _orderGroupId(map),
    );
  }

  static WalletOrderCardDto _parseTransferCard({
    required String type,
    required Map<String, dynamic> map,
    String? fallbackCurrency,
    int? fallbackAmount,
    String? fallbackGreeting,
    String? fallbackStatus,
  }) {
    final isGroupTransfer = type == 'wallet_group_transfer';
    final currency = (map['currency']?.toString().trim().isNotEmpty == true
            ? map['currency'].toString()
            : fallbackCurrency) ??
        WalletCurrency.platform;
    final amount =
        _asInt(map['amount'] ?? map['totalAmount'] ?? fallbackAmount);
    final status = map['status']?.toString() ??
        map['state']?.toString() ??
        fallbackStatus ??
        'COMPLETED';
    final displayTitle = map['displayTitle']?.toString().trim() ?? '';
    final defaultTitle = AppI18n.current.t(
      zhHans: isGroupTransfer ? '群转账' : '转账',
      zhHant: isGroupTransfer ? '群轉帳' : '轉賬',
      en: isGroupTransfer ? 'Group Transfer' : 'Transfer',
      ja: isGroupTransfer ? 'グループ送金' : '送金',
      ko: isGroupTransfer ? '그룹 이체' : '송금',
    );
    return WalletOrderCardDto(
      ok: true,
      type: type,
      status: _cardStatusFromWalletStatus(status),
      amount: formatWalletAmount(currency, amount),
      coin: walletDisplayCoin(currency),
      title: isGroupTransfer && displayTitle.isNotEmpty
          ? displayTitle
          : defaultTitle,
      msg: (map['memo'] ?? map['greeting'] ?? fallbackGreeting)
              ?.toString()
              .trim() ??
          '',
      senderUserId: _orderSenderUserId(map),
      groupId: _orderGroupId(map),
    );
  }

  static WalletOrderCardDto _placeholderTransferCard({
    required String type,
    required String currency,
    required int amount,
    String? status,
    String? greeting,
  }) {
    final isGroupTransfer = type == 'wallet_group_transfer';
    return WalletOrderCardDto(
      ok: true,
      type: type,
      status: _cardStatusFromWalletStatus(status ?? 'COMPLETED'),
      amount: formatWalletAmount(currency, amount),
      coin: walletDisplayCoin(currency),
      title: AppI18n.current.t(
        zhHans: isGroupTransfer ? '群转账' : '转账',
        zhHant: isGroupTransfer ? '群轉帳' : '轉賬',
        en: isGroupTransfer ? 'Group Transfer' : 'Transfer',
        ja: isGroupTransfer ? 'グループ送金' : '送金',
        ko: isGroupTransfer ? '그룹 이체' : '송금',
      ),
      msg: greeting?.trim() ?? '',
    );
  }

  static WalletOrderCardDto _placeholderRedPacketCard({
    required String currency,
    required int amount,
    String? status,
    String? greeting,
  }) {
    return WalletOrderCardDto(
      ok: true,
      type: 'wallet_red_packet',
      status: _cardStatusFromWalletStatus(status ?? 'ACTIVE'),
      amount: formatWalletAmount(currency, amount),
      coin: walletDisplayCoin(currency),
      title: AppI18n.current.t(
        zhHans: '红包',
        zhHant: '紅包',
        en: 'Red packet',
        ja: '红包',
        ko: '红包',
      ),
      msg: greeting ??
          AppI18n.current.t(
            zhHans: '恭喜发财，大吉大利',
            zhHant: '恭喜發財，大吉大利',
            en: 'Best wishes and good fortune',
            ja: 'ご健勝とご多幸をお祈りします',
            ko: '복 많이 받으세요',
          ),
    );
  }

  static String _orderSenderUserId(Map<String, dynamic> map) {
    for (final key in const [
      'senderUserId',
      'fromUserId',
      'senderId',
      'payerUserId',
      'payer',
    ]) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _orderGroupId(Map<String, dynamic> map) {
    for (final key in const [
      'groupId',
      'chatGroupId',
      'imGroupId',
    ]) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    final conversationId = map['conversationId']?.toString().trim() ?? '';
    if (conversationId.startsWith('group_') ||
        conversationId.contains('TGS#')) {
      return conversationId;
    }
    return '';
  }

  static int? _dioStatus(Object error) {
    if (error is DioError) {
      return error.response?.statusCode;
    }
    return null;
  }

  static Map<String, dynamic> _redPacketMap(Map<String, dynamic> map) {
    final packet = map['packet'];
    if (packet is Map) {
      final next = Map<String, dynamic>.from(packet);
      final claims = map['claims'];
      if (claims != null) next['claims'] = claims;
      return next;
    }
    return map;
  }

  static bool _isAdminAdjust(Map<String, dynamic> json) {
    final refType = json['refType']?.toString() ?? '';
    if (refType == 'ADMIN_ADJUST') return true;
    final txId = json['txId']?.toString().trim() ?? '';
    return txId.startsWith('SYS-ADJ-');
  }

  static bool _isInternalDepositRecord(Map<String, dynamic> json) {
    if (_isAdminAdjust(json)) return true;
    final txId = json['txId']?.toString().trim() ?? '';
    if (txId.startsWith('SYS-ADJ-')) return true;
    final id = int.tryParse(json['id']?.toString() ?? '');
    return id != null && id >= 7000000000;
  }

  static bool _isInternalWithdrawRecord(Map<String, dynamic> json) {
    if (_isAdminAdjust(json)) return true;
    final txId = json['txId']?.toString().trim() ?? '';
    if (txId.startsWith('SYS-ADJ-')) return true;
    if (_text(json['toAddress']) == 'OPERATIONS') return true;
    final id = int.tryParse(json['id']?.toString() ?? '');
    return id != null && id >= 8000000000;
  }

  static String _platformNetworkLabel() {
    return AppI18n.current.t(
      zhHans: '平台',
      zhHant: '平台',
      en: 'Platform',
      ja: 'プラットフォーム',
      ko: '플랫폼',
    );
  }

  static WalletRecordDto _parseLedgerItem(Map<String, dynamic> json) {
    final i18n = AppI18n.current;
    final ledgerType = _text(json['ledgerType']).toUpperCase();
    final source = _text(json['source']).toUpperCase();
    final status = _text(json['status']);
    final currency = _text(json['currency']).isEmpty
        ? WalletCurrency.usdt
        : _text(json['currency']);
    final amount = _asInt(json['amount']);
    final direction = _text(json['direction']).toUpperCase();
    final income =
        direction == 'IN' ? true : (direction == 'OUT' ? false : amount > 0);
    final absAmount = amount.abs();
    final isAdminAdjust = _isAdminAdjust(json);
    final isInternalDeposit =
        source == 'INTERNAL' || _isInternalDepositRecord(json);
    final isInternalWithdraw =
        source == 'INTERNAL' || _isInternalWithdrawRecord(json);
    final network = _ledgerNetworkLabel(
      _text(json['network']),
      fallbackToPlatform: source != 'CHAIN',
    );
    final feeAmount = _asInt(json['feeAmount']);
    final confirmations = _asInt(json['confirmations']);
    final packetId = _firstNonEmpty([
      json['packetId'],
      json['refId'],
      json['id'],
    ]);
    final orderId = _firstNonEmpty([
      json['refId'],
      json['id'],
      json['txId'],
    ]);
    final clientOrderId = _text(json['clientOrderId']);
    final remark = _firstNonEmpty([
      json['remark'],
      json['memo'],
      json['failReason'],
    ]);
    final time = _firstNonEmpty([
      json['creditedAt'],
      json['blockTimestamp'],
      json['createdAt'],
    ]);

    switch (ledgerType) {
      case 'DEPOSIT':
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['txId']]),
          type: WalletRecordType.receive,
          status: _recordStatusFromWalletStatus(status),
          title: _ledgerTitle(
            ledgerType,
            income,
            isAdminAdjust: isInternalDeposit,
          ),
          subTitle: status,
          amount: formatWalletAmount(currency, absAmount),
          coin: walletDisplayCoin(currency),
          income: true,
          network: network,
          fee: '',
          payer: _text(json['fromAddress']),
          payee: _text(json['toAddress']),
          addr: _text(json['toAddress']),
          hash: _text(json['txId']),
          block: confirmations > 0 ? '$confirmations' : '',
          time: time,
          orderNo: orderId,
          serverOrderId: orderId,
          clientOrderId: clientOrderId,
          memo: remark.isNotEmpty
              ? remark
              : (status.toUpperCase() == 'CONFIRMING' && confirmations > 0
                  ? i18n.format(
                      zhHans: '确认中 {current}/19',
                      zhHant: '確認中 {current}/19',
                      en: 'Confirming {current}/19',
                      ja: '確認中 {current}/19',
                      ko: '확인 중 {current}/19',
                      vars: {'current': '$confirmations'},
                    )
                  : ''),
        );
      case 'WITHDRAW':
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['refId']]),
          type: WalletRecordType.transfer,
          status: _recordStatusFromWalletStatus(status),
          title: _ledgerTitle(
            ledgerType,
            income,
            isAdminAdjust: isInternalWithdraw,
          ),
          subTitle: status,
          amount: formatWalletAmount(currency, absAmount),
          coin: walletDisplayCoin(currency),
          income: false,
          network: network,
          fee: feeAmount > 0 ? formatWalletAmount(currency, feeAmount) : '',
          payer: _text(json['fromAddress']),
          payee: _text(json['toAddress']),
          addr: _text(json['toAddress']),
          hash: _text(json['txId']),
          block: '',
          time: time,
          orderNo: orderId,
          serverOrderId: orderId,
          clientOrderId: clientOrderId,
          memo: remark,
        );
      case 'WITHDRAW_REFUND':
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['refId']]),
          type: _ledgerTypeFrom(ledgerType, income: income),
          status: _recordStatusFromWalletStatus(status),
          title: _ledgerTitle(ledgerType, income),
          subTitle: status,
          amount: formatWalletAmount(currency, absAmount),
          coin: walletDisplayCoin(currency),
          income: income,
          network: network,
          fee: '',
          payer: _text(json['fromAddress']),
          payee: _text(json['toAddress']),
          addr: _text(json['toAddress']),
          hash: _text(json['txId']),
          block: '',
          time: time,
          orderNo: orderId,
          serverOrderId: orderId,
          clientOrderId: clientOrderId,
          memo: remark,
        );
      case 'TRANSFER_IN':
      case 'TRANSFER_OUT':
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['refId']]),
          type: _ledgerTypeFrom(ledgerType, income: income),
          status: _recordStatusFromWalletStatus(status),
          title: _ledgerTitle(ledgerType, income),
          subTitle: i18n.t(
            zhHans: '平台内转账',
            zhHant: '平台內轉賬',
            en: 'In-app transfer',
            ja: 'アプリ内送金',
            ko: '앱 내 송금',
          ),
          amount: formatWalletAmount(currency, absAmount),
          coin: walletDisplayCoin(currency),
          income: income,
          network: _platformNetworkLabel(),
          fee: feeAmount > 0 ? formatWalletAmount(currency, feeAmount) : '',
          payer: _text(json['fromUserId']),
          payee: _text(json['toUserId']),
          addr: '',
          hash: _text(json['txId']),
          block: '',
          time: time,
          orderNo: orderId,
          serverOrderId: orderId,
          clientOrderId: clientOrderId,
          memo: remark,
        );
      case 'RED_PACKET_SEND':
      case 'RED_PACKET_RECEIVE':
      case 'RED_PACKET_REFUND':
        final packetCount = _asInt(json['packetCount']);
        final remainingCount = _asInt(json['remainingCount']);
        final claimedCount = packetCount > 0
            ? (packetCount - remainingCount).clamp(0, packetCount)
            : 0;
        final totalAmount = _asInt(json['totalAmount']);
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['refId'], packetId]),
          type: WalletRecordType.redPacket,
          status: _recordStatusFromWalletStatus(status),
          title: _redPacketLedgerTitle(
            ledgerType: ledgerType,
            income: income,
            packetType: _text(json['packetType']),
            displayTitle: _text(json['displayTitle']),
          ),
          subTitle: status,
          amount: formatWalletAmount(
            currency,
            ledgerType == 'RED_PACKET_SEND' && totalAmount > 0
                ? totalAmount
                : absAmount,
          ),
          coin: walletDisplayCoin(currency),
          income: income,
          network: i18n.t(
            zhHans: '平台内红包',
            zhHant: '平台內紅包',
            en: 'In-app red packet',
            ja: 'アプリ内红包',
            ko: '앱 내 红包',
          ),
          fee: '',
          payer: _firstNonEmpty([json['senderUserId'], json['fromUserId']]),
          payee: _text(json['packetType']).toUpperCase() == 'GROUP_TRANSFER'
              ? _text(json['toUserId'])
              : _firstNonEmpty([json['toUserId'], json['groupId']]),
          addr: '',
          hash: _text(json['txId']),
          block: '',
          time: time,
          orderNo: packetId,
          serverOrderId: packetId,
          clientOrderId: clientOrderId,
          memo: _text(json['greeting']),
          rpType: _text(json['packetType']),
          rpCnt: packetCount > 0
              ? i18n.format(
                  zhHans: '{count} 个',
                  zhHant: '{count} 個',
                  en: '{count}',
                  ja: '{count} 個',
                  ko: '{count}개',
                  vars: {'count': '$packetCount'},
                )
              : '',
          rpTotal: (ledgerType == 'RED_PACKET_SEND' && totalAmount > 0) ||
                  totalAmount > 0
              ? '${formatWalletAmount(currency, totalAmount > 0 ? totalAmount : absAmount)} ${walletDisplayCoin(currency)}'
              : '',
          rpClaim: packetCount > 0 ? '$claimedCount/$packetCount' : '',
          rpMsg: _text(json['greeting']),
          rpStatus: status,
          createdAt: _text(json['createdAt']),
          expiredAt: _text(json['expiresAt']),
        );
      case 'EXCHANGE_IN':
      case 'EXCHANGE_OUT':
      case 'FEE':
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['refId']]),
          type: WalletRecordType.swap,
          status: _recordStatusFromWalletStatus(status),
          title: _ledgerTitle(ledgerType, income),
          subTitle: status,
          amount: formatWalletAmount(currency, absAmount),
          coin: walletDisplayCoin(currency),
          income: income,
          network: _platformNetworkLabel(),
          fee: '',
          payer: _text(json['fromUserId']),
          payee: _text(json['toUserId']),
          addr: '',
          hash: _text(json['txId']),
          block: '',
          time: time,
          orderNo: orderId,
          serverOrderId: orderId,
          clientOrderId: clientOrderId,
          memo: _firstNonEmpty([json['remark'], json['rateSnapshot']]),
        );
      default:
        return WalletRecordDto(
          id: _firstNonEmpty([json['id'], json['refId']]),
          type: _ledgerTypeFrom(ledgerType, income: income),
          status: _recordStatusFromWalletStatus(status),
          title: _ledgerTitle(
            ledgerType,
            income,
            isAdminAdjust: isAdminAdjust,
          ),
          subTitle: status,
          amount: formatWalletAmount(currency, absAmount),
          coin: walletDisplayCoin(currency),
          income: income,
          network: network,
          fee: feeAmount > 0 ? formatWalletAmount(currency, feeAmount) : '',
          payer: _firstNonEmpty([
            json['fromUserId'],
            json['fromAddress'],
            json['counterpartUserId'],
          ]),
          payee: _firstNonEmpty([
            json['toUserId'],
            json['toAddress'],
            json['counterpartUserId'],
          ]),
          addr: _text(json['toAddress']),
          hash: _text(json['txId']),
          block: confirmations > 0 ? '$confirmations' : '',
          time: time,
          orderNo: orderId,
          serverOrderId: orderId,
          clientOrderId: clientOrderId,
          memo: remark,
        );
    }
  }

  static WalletExchangeOrderDto _parseExchangeOrder(Map<String, dynamic> json) {
    final direction = _exchangeDirectionFrom(json['direction']?.toString());
    return WalletExchangeOrderDto(
      id: _text(json['id']),
      userId: _text(json['userId']),
      direction: direction,
      inputAmount: _asInt(json['inputAmount']),
      outputAmount: _asInt(json['outputAmount']),
      surplusFen: _asInt(json['surplusFen']),
      rateSnapshot: _text(json['rateSnapshot']),
      createdAt: _text(json['createdAt']),
    );
  }

  static String _redPacketLedgerTitle({
    required String ledgerType,
    required bool income,
    required String packetType,
    required String displayTitle,
  }) {
    final titled = displayTitle.trim();
    if (titled.isNotEmpty) return titled;
    if (packetType.trim().toUpperCase() == 'GROUP_TRANSFER') {
      return AppI18n.current.t(
        zhHans: '群转账',
        zhHant: '群轉帳',
        en: 'Group Transfer',
        ja: 'グループ送金',
        ko: '그룹 이체',
      );
    }
    return _ledgerTitle(ledgerType, income);
  }

  static String _ledgerTitle(
    String ledgerType,
    bool income, {
    bool isAdminAdjust = false,
  }) {
    final i18n = AppI18n.current;
    switch (ledgerType) {
      case 'DEPOSIT':
        return isAdminAdjust
            ? i18n.t(
                zhHans: '内部充币',
                zhHant: '內部充幣',
                en: 'Internal deposit',
                ja: '内部入金',
                ko: '내부 입금',
              )
            : i18n.t(
                zhHans: '链上充值',
                zhHant: '鏈上充值',
                en: 'On-chain deposit',
                ja: 'オンチェーン入金',
                ko: '온체인 입금',
              );
      case 'WITHDRAW':
        return isAdminAdjust
            ? i18n.t(
                zhHans: '内部提币',
                zhHant: '內部提幣',
                en: 'Internal withdrawal',
                ja: '内部出金',
                ko: '내부 출금',
              )
            : i18n.t(
                zhHans: '提现',
                zhHant: '提現',
                en: 'Withdrawal',
                ja: '出金',
                ko: '출금',
              );
      case 'WITHDRAW_REFUND':
        return i18n.t(
          zhHans: '提现退款',
          zhHant: '提現退款',
          en: 'Withdrawal refund',
          ja: '出金返金',
          ko: '출금 환불',
        );
      case 'TRANSFER_IN':
        return i18n.t(
          zhHans: '收到转账',
          zhHant: '收到轉賬',
          en: 'Transfer received',
          ja: '送金を受取',
          ko: '송금 수령',
        );
      case 'TRANSFER_OUT':
        return i18n.t(
          zhHans: '发起转账',
          zhHant: '發起轉賬',
          en: 'Transfer sent',
          ja: '送金を送信',
          ko: '송금 발송',
        );
      case 'RED_PACKET_SEND':
        return i18n.t(
          zhHans: '发红包',
          zhHant: '發紅包',
          en: 'Send red packet',
          ja: '红包を送る',
          ko: '红包 보내기',
        );
      case 'RED_PACKET_RECEIVE':
        return i18n.t(
          zhHans: '领取红包',
          zhHant: '領取紅包',
          en: 'Claim red packet',
          ja: '红包を受取',
          ko: '红包 받기',
        );
      case 'RED_PACKET_REFUND':
        return i18n.t(
          zhHans: '红包退回',
          zhHant: '紅包退回',
          en: 'Red packet refund',
          ja: '红包返金',
          ko: '红包 환불',
        );
      case 'EXCHANGE_IN':
        return i18n.t(
          zhHans: '互兑入账',
          zhHant: '互兌入賬',
          en: 'Swap credit',
          ja: 'スワップ入金',
          ko: '스왑 입금',
        );
      case 'EXCHANGE_OUT':
        return i18n.t(
          zhHans: '互兑出账',
          zhHant: '互兌出賬',
          en: 'Swap debit',
          ja: 'スワップ出金',
          ko: '스왑 출금',
        );
      case 'FEE':
        return i18n.t(
          zhHans: '手续费',
          zhHant: '手續費',
          en: 'Fee',
          ja: '手数料',
          ko: '수수료',
        );
      default:
        return income
            ? i18n.t(
                zhHans: '入账',
                zhHant: '入賬',
                en: 'Credit',
                ja: '入金',
                ko: '입금',
              )
            : i18n.t(
                zhHans: '出账',
                zhHant: '出賬',
                en: 'Debit',
                ja: '出金',
                ko: '출금',
              );
    }
  }

  static WalletRecordType _ledgerTypeFrom(
    String raw, {
    bool income = false,
  }) {
    switch (raw) {
      case 'DEPOSIT':
        return WalletRecordType.receive;
      case 'TRANSFER_IN':
      case 'RED_PACKET_RECEIVE':
        return WalletRecordType.receive;
      case 'TRANSFER_OUT':
        return WalletRecordType.transfer;
      case 'RED_PACKET_SEND':
        return WalletRecordType.redPacket;
      case 'EXCHANGE_OUT':
        return WalletRecordType.swap;
      case 'EXCHANGE_IN':
        return WalletRecordType.swap;
      case 'FEE':
        return WalletRecordType.swap;
      case 'WITHDRAW':
        return WalletRecordType.transfer;
      case 'WITHDRAW_REFUND':
        return income ? WalletRecordType.receive : WalletRecordType.transfer;
      case 'RED_PACKET_REFUND':
        return WalletRecordType.redPacket;
      default:
        return WalletRecordType.all;
    }
  }

  static WalletOrderResult _successOrderFromMap(
    Map<String, dynamic> map, {
    required String fallbackType,
  }) {
    final id = map['id']?.toString() ?? '';
    final status = map['status']?.toString() ?? map['state']?.toString() ?? '';
    final stage = map['stage']?.toString().trim();
    return WalletOrderResult(
      ok: true,
      state: _orderStateFromWalletStatus(status),
      orderId: id,
      clientOrderId: map['clientOrderId']?.toString() ?? '',
      msg: map['greeting']?.toString() ?? map['memo']?.toString() ?? '',
      data: {
        ...map,
        'type': fallbackType,
        'orderId': id,
        if (stage == null || stage.isEmpty)
          'stage': fallbackType == 'wallet_withdraw'
              ? _stageFromWalletStatus(status)
              : map['stage'],
      },
    );
  }

  static WalletOrderResult parseOrderResult(dynamic raw) {
    final map = _asMap(raw);
    if (map.containsKey('id') && !map.containsKey('ok')) {
      return _successOrderFromMap(
        map,
        fallbackType: map['type']?.toString() ?? 'wallet_transfer',
      );
    }
    final ok = map['ok'] as bool? ?? false;
    return WalletOrderResult(
      ok: ok,
      state: WalletOrderStateX.fromName(map['state']?.toString() ?? ''),
      err: WalletOrderErrX.fromCode(map['code']?.toString()),
      orderId: map['orderId']?.toString() ?? map['id']?.toString() ?? '',
      clientOrderId: map['clientOrderId']?.toString() ?? '',
      msg: map['message']?.toString() ?? map['msg']?.toString() ?? '',
      data: Map<String, dynamic>.from(map),
    );
  }

  static String _currencyFromPay(String payId, String coin) {
    final id = payId.trim();
    if (isWalletPlatformCurrency(id)) return WalletCurrency.platform;
    if (isWalletPlatformCurrency(coin)) {
      return WalletCurrency.platform;
    }
    return WalletCurrency.usdt;
  }

  static WalletOrderState _orderStateFromWalletStatus(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'CREDITED':
        return WalletOrderState.success;
      case 'ACTIVE':
      case 'PENDING':
      case 'BROADCASTING':
      case 'CONFIRMING':
        return WalletOrderState.pending;
      case 'FAILED':
      case 'REFUNDED':
        return WalletOrderState.failed;
      case 'EXPIRED':
        return WalletOrderState.expired;
      default:
        return WalletOrderState.unknown;
    }
  }

  static String _cardStatusFromWalletStatus(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'CREDITED':
        return 'success';
      case 'EMPTY':
      case 'FINISHED':
      case 'FULLY_CLAIMED':
      case 'CLAIMED_ALL':
        return 'finished';
      case 'CLAIMED':
      case 'RECEIVED':
        return 'claimed';
      case 'ACTIVE':
      case 'PENDING':
      case 'CONFIRMING':
        return 'pending';
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

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  static List<dynamic> _pageItems(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    return extractApiList(payload, listKeys: const ['content']);
  }

  static List<WalletRecordDto> _sortRecords(List<WalletRecordDto> list) {
    final next = List<WalletRecordDto>.from(list);
    next.sort((a, b) => b.time.compareTo(a.time));
    return next;
  }

  static WalletRecordStatus _recordStatusFromWalletStatus(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
      case 'PENDING':
      case 'BROADCASTING':
      case 'CONFIRMING':
        return WalletRecordStatus.pending;
      case 'FAILED':
      case 'EXPIRED':
        return WalletRecordStatus.failed;
      default:
        return WalletRecordStatus.success;
    }
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty && text != '--') {
        return text;
      }
    }
    return '';
  }

  static String _ledgerNetworkLabel(
    String raw, {
    bool fallbackToPlatform = false,
  }) {
    final text = raw.trim();
    if (text.isEmpty) {
      return fallbackToPlatform ? _platformNetworkLabel() : '';
    }
    if (text.toUpperCase() == 'PLATFORM') {
      return _platformNetworkLabel();
    }
    return text;
  }

  static int _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static String _text(Object? v) {
    final text = v?.toString().trim() ?? '';
    return text == 'null' ? '' : text;
  }

  static WalletExchangeDirection _exchangeDirectionFrom(String? raw) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'PLATFORM_TO_USDT':
        return WalletExchangeDirection.platformToUsdt;
      case 'USDT_TO_PLATFORM':
      default:
        return WalletExchangeDirection.usdtToPlatform;
    }
  }
}

extension WalletOrderErrX on WalletOrderErr {
  static WalletOrderErr fromCode(String? code) {
    switch (code?.toUpperCase()) {
      case 'PASSWORD_WRONG':
      case 'PAY_PIN_INVALID':
      case 'INVALID_PAY_PIN':
      case 'PAY_PIN_WRONG':
      case 'PAY_PASSWORD_WRONG':
      case 'PAY_PASSWORD_INVALID':
      case 'TRADE_PASSWORD_WRONG':
      case 'TRADE_PASSWORD_INVALID':
      case 'FUND_PASSWORD_WRONG':
        return WalletOrderErr.passwordWrong;
      case 'PASSWORD_LOCKED':
      case 'PAY_PIN_LOCKED':
        return WalletOrderErr.passwordLocked;
      case 'PAY_PIN_NOT_SET':
        return WalletOrderErr.passwordWrong;
      case 'INSUFFICIENT_BALANCE':
        return WalletOrderErr.insufficientBalance;
      case 'INSUFFICIENT_FEE':
      case 'FEE_EXCEEDS_AMOUNT':
        return WalletOrderErr.insufficientFee;
      case 'INVALID_AMOUNT':
      case 'EXCHANGE_AMOUNT_TOO_SMALL':
      case 'WITHDRAW_MIN_NOT_MET':
        return WalletOrderErr.invalidAmount;
      case 'EXCHANGE_MAINTENANCE':
        return WalletOrderErr.none;
      case 'DUPLICATE_SUBMIT':
      case 'ALREADY_CLAIMED':
        return WalletOrderErr.duplicateSubmit;
      case 'LIMIT_EXCEEDED':
        return WalletOrderErr.invalidAmount;
      case 'INVALID_RECEIVER':
      case 'INVALID_TRON_ADDRESS':
      case 'RECIPIENT_NOT_FOUND':
      case 'USER_NOT_FOUND':
        return WalletOrderErr.invalidReceiver;
      default:
        return WalletOrderErr.none;
    }
  }
}
