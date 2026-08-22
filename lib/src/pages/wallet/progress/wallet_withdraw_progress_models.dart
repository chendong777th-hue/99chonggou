/// 链上提现进度 · 客户端模型（与 docs/wallet-withdraw-live-activity-plan.md 对齐）
enum WalletWithdrawProgressStage {
  submitted,
  broadcasting,
  confirming,
  completed,
  failed;

  static WalletWithdrawProgressStage fromApi({
    String? stage,
    String? status,
  }) {
    final normalizedStage = stage?.trim().toUpperCase();
    if (normalizedStage != null && normalizedStage.isNotEmpty) {
      switch (normalizedStage) {
        case 'SUBMITTED':
          return WalletWithdrawProgressStage.submitted;
        case 'BROADCASTING':
          return WalletWithdrawProgressStage.broadcasting;
        case 'CONFIRMING':
          return WalletWithdrawProgressStage.confirming;
        case 'COMPLETED':
          return WalletWithdrawProgressStage.completed;
        case 'FAILED':
          return WalletWithdrawProgressStage.failed;
      }
    }

    final normalizedStatus = status?.trim().toUpperCase() ?? '';
    switch (normalizedStatus) {
      case 'COMPLETED':
      case 'CREDITED':
        return WalletWithdrawProgressStage.completed;
      case 'FAILED':
      case 'REFUNDED':
      case 'EXPIRED':
        return WalletWithdrawProgressStage.failed;
      case 'BROADCASTING':
        return WalletWithdrawProgressStage.broadcasting;
      case 'CONFIRMING':
        return WalletWithdrawProgressStage.confirming;
      case 'PENDING':
      case 'ACTIVE':
        return WalletWithdrawProgressStage.submitted;
      default:
        return WalletWithdrawProgressStage.submitted;
    }
  }

  String get wireName {
    switch (this) {
      case WalletWithdrawProgressStage.submitted:
        return 'SUBMITTED';
      case WalletWithdrawProgressStage.broadcasting:
        return 'BROADCASTING';
      case WalletWithdrawProgressStage.confirming:
        return 'CONFIRMING';
      case WalletWithdrawProgressStage.completed:
        return 'COMPLETED';
      case WalletWithdrawProgressStage.failed:
        return 'FAILED';
    }
  }

  bool get isTerminal =>
      this == WalletWithdrawProgressStage.completed ||
      this == WalletWithdrawProgressStage.failed;
}

class WalletWithdrawProgressSnapshot {
  final String orderId;
  final String clientOrderId;
  final WalletWithdrawProgressStage stage;
  final String amountText;
  final String coin;
  final String network;
  final int confirmations;
  final int requiredConfirmations;
  final String txHashShort;
  final String nativeActivityId;

  const WalletWithdrawProgressSnapshot({
    required this.orderId,
    required this.clientOrderId,
    required this.stage,
    required this.amountText,
    required this.coin,
    required this.network,
    this.confirmations = 0,
    this.requiredConfirmations = 19,
    this.txHashShort = '',
    this.nativeActivityId = '',
  });

  WalletWithdrawProgressSnapshot copyWith({
    String? orderId,
    String? clientOrderId,
    WalletWithdrawProgressStage? stage,
    String? amountText,
    String? coin,
    String? network,
    int? confirmations,
    int? requiredConfirmations,
    String? txHashShort,
    String? nativeActivityId,
  }) {
    return WalletWithdrawProgressSnapshot(
      orderId: orderId ?? this.orderId,
      clientOrderId: clientOrderId ?? this.clientOrderId,
      stage: stage ?? this.stage,
      amountText: amountText ?? this.amountText,
      coin: coin ?? this.coin,
      network: network ?? this.network,
      confirmations: confirmations ?? this.confirmations,
      requiredConfirmations:
          requiredConfirmations ?? this.requiredConfirmations,
      txHashShort: txHashShort ?? this.txHashShort,
      nativeActivityId: nativeActivityId ?? this.nativeActivityId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'clientOrderId': clientOrderId,
      'stage': stage.wireName,
      'amountText': amountText,
      'coin': coin,
      'network': network,
      'confirmations': confirmations,
      'requiredConfirmations': requiredConfirmations,
      'txHashShort': txHashShort,
      'nativeActivityId': nativeActivityId,
    };
  }

  factory WalletWithdrawProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return WalletWithdrawProgressSnapshot(
      orderId: json['orderId']?.toString() ?? '',
      clientOrderId: json['clientOrderId']?.toString() ?? '',
      stage: WalletWithdrawProgressStage.fromApi(
        stage: json['stage']?.toString(),
        status: json['status']?.toString(),
      ),
      amountText: json['amountText']?.toString() ?? '',
      coin: json['coin']?.toString() ?? '',
      network: json['network']?.toString() ?? '',
      confirmations: _asInt(json['confirmations']),
      requiredConfirmations: _asInt(json['requiredConfirmations'], fallback: 19),
      txHashShort: json['txHashShort']?.toString() ?? '',
      nativeActivityId: json['nativeActivityId']?.toString() ?? '',
    );
  }

  factory WalletWithdrawProgressSnapshot.fromOrderMap(
    Map<String, dynamic> map, {
    required String amountText,
    required String coin,
    required String network,
    String nativeActivityId = '',
  }) {
    final txId = map['txId']?.toString().trim() ?? '';
    return WalletWithdrawProgressSnapshot(
      orderId: _firstNonEmpty([
        map['id']?.toString(),
        map['orderId']?.toString(),
      ]),
      clientOrderId: map['clientOrderId']?.toString() ?? '',
      stage: WalletWithdrawProgressStage.fromApi(
        stage: map['stage']?.toString(),
        status: map['status']?.toString(),
      ),
      amountText: amountText,
      coin: coin,
      network: network.isNotEmpty
          ? network
          : (map['network']?.toString() ?? 'TRC20'),
      confirmations: _asInt(map['confirmations']),
      requiredConfirmations: _asInt(map['requiredConfirmations'], fallback: 19),
      txHashShort: _shortHash(txId),
      nativeActivityId: nativeActivityId,
    );
  }

  static String shortHash(String hash) => _shortHash(hash);

  static int _asInt(Object? raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? fallback;
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty && text != '--') return text;
    }
    return '';
  }

  static String _shortHash(String hash) {
    final value = hash.trim();
    if (value.length <= 12) return value;
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}';
  }
}
