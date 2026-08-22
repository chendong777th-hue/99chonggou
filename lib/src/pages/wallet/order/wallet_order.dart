import 'dart:math';

import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

class WalletSubmitException implements Exception {
  final bool requestSent;
  final String message;

  WalletSubmitException({
    required this.requestSent,
    required this.message,
  });

  @override
  String toString() => message;
}

enum WalletOrderType {
  transfer,
  redPacket,
  receive,
  swap,
}

enum WalletOrderState {
  idle,
  created,
  confirming,
  password,
  submitting,
  accepted,
  pending,
  unknown,
  success,
  failed,
  expired,
  cancelled,
  refunded,
}

enum WalletOrderErr {
  none,
  invalidReceiver,
  emptyAmount,
  invalidAmount,
  invalidPrecision,
  tooLong,
  insufficientBalance,
  insufficientFee,
  invalidCount,
  countOverLimit,
  groupNotReady,
  networkMismatch,
  passwordWrong,
  passwordLocked,
  networkError,
  duplicateSubmit,
  unknown,
}

class WalletAmount {
  final String coin;
  final int minor;
  final int scale;

  const WalletAmount({
    required this.coin,
    required this.minor,
    required this.scale,
  });

  bool get isPositive => minor > 0;

  String get text => formatMinor(minor, scale);

  static WalletAmount? parse(
    String raw, {
    required String coin,
    required int scale,
    int maxInt = 12,
  }) {
    final s = clean(raw, scale: scale, maxInt: maxInt);
    if (s.isEmpty) return null;

    final parts = s.split('.');
    if (parts.length > 2) return null;

    final intPart = parts[0].isEmpty ? '0' : parts[0];
    final decPart = parts.length == 2 ? parts[1] : '';
    if (intPart.length > maxInt) return null;
    if (decPart.length > scale) return null;

    final joined = intPart + decPart.padRight(scale, '0');
    final minor = int.tryParse(joined);
    if (minor == null) return null;

    return WalletAmount(coin: coin, minor: minor, scale: scale);
  }

  static WalletAmount? parseStrict(
    String raw, {
    required String coin,
    required int scale,
    int maxInt = 12,
  }) {
    final s = raw.trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    if (!RegExp(r'^\d+(\.\d*)?$|^\.\d+$').hasMatch(s)) return null;
    if (s.split('.').length > 2) return null;

    final parts = s.startsWith('.') ? ['0', s.substring(1)] : s.split('.');
    final intPartRaw = parts[0];
    final decPart = parts.length == 2 ? parts[1] : '';
    if (intPartRaw.isEmpty) return null;
    if (intPartRaw.length > 1 && intPartRaw.startsWith('0')) return null;
    if (intPartRaw.length > maxInt) return null;
    if (decPart.length > scale) return null;

    final intPart = intPartRaw;
    final joined = intPart + decPart.padRight(scale, '0');
    final minor = int.tryParse(joined);
    if (minor == null) return null;

    return WalletAmount(coin: coin, minor: minor, scale: scale);
  }

  static String clean(
    String raw, {
    required int scale,
    int maxInt = 12,
  }) {
    var s = raw.trim().replaceAll(',', '').replaceAll(RegExp(r'[^0-9.]'), '');
    if (s.isEmpty) return '';

    final firstDot = s.indexOf('.');
    if (firstDot >= 0) {
      final before = s.substring(0, firstDot + 1);
      final after = s.substring(firstDot + 1).replaceAll('.', '');
      s = before + after;
    }

    if (s.startsWith('.')) s = '0$s';

    final parts = s.split('.');
    var intPart = parts[0].replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intPart.isEmpty) intPart = '0';
    if (intPart.length > maxInt) intPart = intPart.substring(0, maxInt);

    if (parts.length == 1) return intPart;

    var decPart = parts[1];
    if (decPart.length > scale) decPart = decPart.substring(0, scale);
    return '$intPart.$decPart';
  }

  static String formatMinor(int minor, int scale) {
    final negative = minor < 0;
    var s = minor.abs().toString().padLeft(scale + 1, '0');
    final intPart = s.substring(0, s.length - scale);
    var decPart = scale == 0 ? '' : s.substring(s.length - scale);
    decPart = decPart.replaceFirst(RegExp(r'0+$'), '');
    final v = decPart.isEmpty ? intPart : '$intPart.$decPart';
    return negative ? '-$v' : v;
  }

  /// 展示用格式：至少保留 [minFraction] 位小数（默认 2 位），
  /// 更高精度的有效小数会保留，仅裁掉超出 [minFraction] 之后多余的 0。
  /// 例如 1 -> 1.00，1.5 -> 1.50，1.2345 -> 1.2345。
  static String formatDisplay(int minor, int scale, {int minFraction = 2}) {
    final negative = minor < 0;
    final digits = minor.abs().toString().padLeft(scale + 1, '0');
    final intPart = digits.substring(0, digits.length - scale);
    var decPart = scale == 0 ? '' : digits.substring(digits.length - scale);
    decPart = decPart.replaceFirst(RegExp(r'0+$'), '');
    if (decPart.length < minFraction) {
      decPart = decPart.padRight(minFraction, '0');
    }
    final v = decPart.isEmpty ? intPart : '$intPart.$decPart';
    return negative ? '-$v' : v;
  }

  static String formatFixed(int minor, int scale) {
    final negative = minor < 0;
    final s = minor.abs().toString().padLeft(scale + 1, '0');
    final intPart = s.substring(0, s.length - scale);
    final decPart = scale == 0 ? '' : s.substring(s.length - scale);
    final v = scale == 0 ? intPart : '$intPart.$decPart';
    return negative ? '-$v' : v;
  }
}

class WalletOrderDraft {
  final String clientOrderId;
  final WalletOrderType type;
  final String amountText;
  final int amountMinor;
  final String coin;
  final String network;
  final int feeMinor;
  final String feeCoin;
  final int feeScale;
  final int feeBalanceMinor;
  final String receiverId;
  final String receiverName;
  final String memo;
  final String createdAt;
  final String updatedAt;
  final int retryCount;
  final String lastQueryAt;
  final String serverOrderId;
  final String conversationId;
  final String businessType;
  final String orderState;
  final String cardSendStatus;
  final int cardSendRetryCount;
  final String lastCardSendAt;

  const WalletOrderDraft({
    required this.clientOrderId,
    required this.type,
    required this.amountText,
    required this.amountMinor,
    required this.coin,
    required this.network,
    this.feeMinor = 0,
    this.feeCoin = '',
    this.feeScale = 0,
    this.feeBalanceMinor = 0,
    this.receiverId = '',
    this.receiverName = '',
    this.memo = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.retryCount = 0,
    this.lastQueryAt = '',
    this.serverOrderId = '',
    this.conversationId = '',
    this.businessType = '',
    this.orderState = 'created',
    this.cardSendStatus = 'idle',
    this.cardSendRetryCount = 0,
    this.lastCardSendAt = '',
  });

  bool get needsChatCard {
    return conversationId.trim().isNotEmpty &&
        (businessType == 'wallet_red_packet' ||
            businessType == 'wallet_transfer' ||
            businessType == 'wallet_group_transfer');
  }

  bool get cardSent => cardSendStatus == 'sent';

  bool get cardManual => cardSendStatus == 'manual';

  bool get cardIgnored => cardSendStatus == 'ignored';

  bool get isDoneOrder {
    final state = WalletOrderStateX.fromName(orderState);
    return state == WalletOrderState.success ||
        state == WalletOrderState.failed ||
        state == WalletOrderState.expired ||
        state == WalletOrderState.cancelled ||
        state == WalletOrderState.refunded;
  }

  /// 是否需要向服务端查询订单状态（已成功且仅需补卡的不查单）。
  bool get needsOrderStatusQuery {
    final state = WalletOrderStateX.fromName(orderState);
    if (state == WalletOrderState.failed ||
        state == WalletOrderState.expired ||
        state == WalletOrderState.cancelled ||
        state == WalletOrderState.refunded) {
      return false;
    }
    if (state == WalletOrderState.success &&
        needsChatCard &&
        !cardSent &&
        !cardIgnored) {
      return false;
    }
    if (state == WalletOrderState.unknown ||
        state == WalletOrderState.pending ||
        state == WalletOrderState.submitting ||
        state == WalletOrderState.accepted ||
        state == WalletOrderState.confirming ||
        state == WalletOrderState.created) {
      return true;
    }
    if (state == WalletOrderState.success) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'clientOrderId': clientOrderId,
      'type': type.name,
      'amountText': amountText,
      'amountMinor': amountMinor,
      'coin': coin,
      'network': network,
      'feeMinor': feeMinor,
      'feeCoin': feeCoin,
      'feeScale': feeScale,
      'feeBalanceMinor': feeBalanceMinor,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'memo': memo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'retryCount': retryCount,
      'lastQueryAt': lastQueryAt,
      'serverOrderId': serverOrderId,
      'conversationId': conversationId,
      'businessType': businessType,
      'orderState': orderState,
      'cardSendStatus': cardSendStatus,
      'cardSendRetryCount': cardSendRetryCount,
      'lastCardSendAt': lastCardSendAt,
    };
  }

  factory WalletOrderDraft.fromJson(Map<String, dynamic> json) {
    WalletOrderType typeOf(String raw) {
      for (final item in WalletOrderType.values) {
        if (item.name == raw) return item;
      }
      return WalletOrderType.transfer;
    }

    int asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return WalletOrderDraft(
      clientOrderId: json['clientOrderId']?.toString() ?? '',
      type: typeOf(json['type']?.toString() ?? ''),
      amountText: json['amountText']?.toString() ?? '',
      amountMinor: asInt(json['amountMinor']),
      coin: json['coin']?.toString() ?? '',
      network: json['network']?.toString() ?? '',
      feeMinor: asInt(json['feeMinor']),
      feeCoin: json['feeCoin']?.toString() ?? '',
      feeScale: asInt(json['feeScale']),
      feeBalanceMinor: asInt(json['feeBalanceMinor']),
      receiverId: json['receiverId']?.toString() ?? '',
      receiverName: json['receiverName']?.toString() ?? '',
      memo: json['memo']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? '',
      retryCount: asInt(json['retryCount']),
      lastQueryAt: json['lastQueryAt']?.toString() ?? '',
      serverOrderId: json['serverOrderId']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      businessType: json['businessType']?.toString() ?? '',
      orderState: json['orderState']?.toString() ?? 'created',
      cardSendStatus: json['cardSendStatus']?.toString() ?? 'idle',
      cardSendRetryCount: asInt(json['cardSendRetryCount']),
      lastCardSendAt: json['lastCardSendAt']?.toString() ?? '',
    );
  }
  WalletOrderDraft copyWith({
    String? serverOrderId,
    int? retryCount,
    String? lastQueryAt,
    String? updatedAt,
    String? conversationId,
    String? businessType,
    String? orderState,
    String? cardSendStatus,
    int? cardSendRetryCount,
    String? lastCardSendAt,
  }) {
    return WalletOrderDraft(
      clientOrderId: clientOrderId,
      type: type,
      amountText: amountText,
      amountMinor: amountMinor,
      coin: coin,
      network: network,
      feeMinor: feeMinor,
      feeCoin: feeCoin,
      feeScale: feeScale,
      feeBalanceMinor: feeBalanceMinor,
      receiverId: receiverId,
      receiverName: receiverName,
      memo: memo,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      retryCount: retryCount ?? this.retryCount,
      lastQueryAt: lastQueryAt ?? this.lastQueryAt,
      serverOrderId: serverOrderId ?? this.serverOrderId,
      conversationId: conversationId ?? this.conversationId,
      businessType: businessType ?? this.businessType,
      orderState: orderState ?? this.orderState,
      cardSendStatus: cardSendStatus ?? this.cardSendStatus,
      cardSendRetryCount: cardSendRetryCount ?? this.cardSendRetryCount,
      lastCardSendAt: lastCardSendAt ?? this.lastCardSendAt,
    );
  }
}

class WalletOrderResult {
  final bool ok;
  final WalletOrderState state;
  final WalletOrderErr err;
  final String orderId;
  final String clientOrderId;
  final String msg;
  final Map<String, dynamic> data;

  const WalletOrderResult({
    required this.ok,
    required this.state,
    this.err = WalletOrderErr.none,
    this.orderId = '',
    this.clientOrderId = '',
    this.msg = '',
    this.data = const {},
  });
}

class WalletIdMaker {
  WalletIdMaker._();

  static String make(String prefix) {
    return '${prefix}_${_uuidV4()}';
  }

  static String _uuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int v) => v.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

extension WalletOrderStateX on WalletOrderState {
  static WalletOrderState fromName(String raw) {
    for (final item in WalletOrderState.values) {
      if (item.name == raw) return item;
    }
    return WalletOrderState.unknown;
  }
}

extension WalletOrderErrText on WalletOrderErr {
  String get text {
    switch (this) {
      case WalletOrderErr.none:
        return '';
      case WalletOrderErr.invalidReceiver:
        return AppI18n.current.t(
          zhHans: '收款人无效',
          zhHant: '收款人無效',
          en: 'Invalid recipient.',
          ja: '受取人が無効です。',
          ko: '수취인이 올바르지 않습니다.',
        );
      case WalletOrderErr.emptyAmount:
        return AppI18n.current.t(
          zhHans: '请输入金额',
          zhHant: '請輸入金額',
          en: 'Enter an amount.',
          ja: '金額を入力してください。',
          ko: '금액을 입력해 주세요.',
        );
      case WalletOrderErr.invalidAmount:
        return AppI18n.current.t(
          zhHans: '金额必须大于 0',
          zhHant: '金額必須大於 0',
          en: 'The amount must be greater than 0.',
          ja: '金額は0より大きい必要があります。',
          ko: '금액은 0보다 커야 합니다.',
        );
      case WalletOrderErr.invalidPrecision:
        return AppI18n.current.t(
          zhHans: '金额精度不正确',
          zhHant: '金額精度不正確',
          en: 'The amount precision is invalid.',
          ja: '金額の小数桁が正しくありません。',
          ko: '금액 자릿수가 올바르지 않습니다.',
        );
      case WalletOrderErr.tooLong:
        return AppI18n.current.t(
          zhHans: '金额过大',
          zhHant: '金額過大',
          en: 'The amount is too large.',
          ja: '金額が大きすぎます。',
          ko: '금액이 너무 큽니다.',
        );
      case WalletOrderErr.insufficientBalance:
        return AppI18n.current.t(
          zhHans: '余额不足',
          zhHant: '餘額不足',
          en: 'Insufficient balance.',
          ja: '残高が不足しています。',
          ko: '잔액이 부족합니다.',
        );
      case WalletOrderErr.insufficientFee:
        return AppI18n.current.t(
          zhHans: '手续费余额不足',
          zhHant: '手續費餘額不足',
          en: 'Insufficient balance for network fees.',
          ja: '手数料の残高が不足しています。',
          ko: '수수료 잔액이 부족합니다.',
        );
      case WalletOrderErr.invalidCount:
        return AppI18n.current.t(
          zhHans: '请输入正确数量',
          zhHant: '請輸入正確數量',
          en: 'Enter a valid quantity.',
          ja: '正しい数量を入力してください。',
          ko: '올바른 수량을 입력해 주세요.',
        );
      case WalletOrderErr.countOverLimit:
        return AppI18n.current.t(
          zhHans: '数量超过限制',
          zhHant: '數量超過限制',
          en: 'The quantity exceeds the limit.',
          ja: '数量が上限を超えています。',
          ko: '수량이 제한을 초과했습니다.',
        );
      case WalletOrderErr.groupNotReady:
        return AppI18n.current.t(
          zhHans: '群成员信息未加载，请稍后重试',
          zhHant: '群成員資訊尚未載入，請稍後再試',
          en: 'Group member information is still loading. Please try again later.',
          ja: 'グループメンバー情報を読み込み中です。しばらくしてからもう一度お試しください。',
          ko: '그룹 멤버 정보를 불러오는 중입니다. 잠시 후 다시 시도해 주세요.',
        );
      case WalletOrderErr.networkMismatch:
        return AppI18n.current.t(
          zhHans: '网络与币种不匹配',
          zhHant: '網路與幣種不匹配',
          en: 'The network does not match the selected token.',
          ja: 'ネットワークと通貨が一致していません。',
          ko: '네트워크와 코인이 일치하지 않습니다.',
        );
      case WalletOrderErr.passwordWrong:
        return AppI18n.current.t(
          zhHans: '支付密码错误',
          zhHant: '支付密碼錯誤',
          en: 'Incorrect payment password.',
          ja: '支払いパスワードが正しくありません。',
          ko: '결제 비밀번호가 올바르지 않습니다.',
        );
      case WalletOrderErr.passwordLocked:
        return AppI18n.current.t(
          zhHans: '支付密码已锁定',
          zhHant: '支付密碼已鎖定',
          en: 'Your payment password has been locked.',
          ja: '支払いパスワードはロックされています。',
          ko: '결제 비밀번호가 잠겼습니다.',
        );
      case WalletOrderErr.networkError:
        return AppI18n.current.t(
          zhHans: '网络异常，请稍后重试',
          zhHant: '網路異常，請稍後再試',
          en: 'Network error. Please try again later.',
          ja: 'ネットワークエラーです。しばらくしてからもう一度お試しください。',
          ko: '네트워크 오류입니다. 잠시 후 다시 시도해 주세요.',
        );
      case WalletOrderErr.duplicateSubmit:
        return AppI18n.current.t(
          zhHans: '请勿重复提交',
          zhHant: '請勿重複提交',
          en: 'Please do not submit repeatedly.',
          ja: '重複して送信しないでください。',
          ko: '중복 제출하지 마세요.',
        );
      case WalletOrderErr.unknown:
        return AppI18n.current.t(
          zhHans: '操作失败，请重试',
          zhHant: '操作失敗，請重試',
          en: 'The operation failed. Please try again.',
          ja: '操作に失敗しました。もう一度お試しください。',
          ko: '작업에 실패했습니다. 다시 시도해 주세요.',
        );
    }
  }
}
