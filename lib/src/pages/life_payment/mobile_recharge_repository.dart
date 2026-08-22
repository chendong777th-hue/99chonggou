import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';

class MobileRechargePhoneProfile {
  const MobileRechargePhoneProfile({
    required this.phone,
    required this.verified,
    this.ownerLastChar,
    this.lastRechargeAt,
  });

  final String phone;
  final bool verified;
  final String? ownerLastChar;
  final DateTime? lastRechargeAt;

  factory MobileRechargePhoneProfile.fromJson(Map<String, Object?> json) {
    final rawVerified = json['verified'];
    return MobileRechargePhoneProfile(
      phone: json['phone']?.toString() ?? json['account_no']?.toString() ?? '',
      verified: _bool(rawVerified) ||
          !_bool(json['need_owner_last_char']) ||
          _bool(json['owner_last_char_exists']) ||
          _int(json['success_count']) > 0,
      ownerLastChar: json['owner_last_char']?.toString(),
      lastRechargeAt: DateTime.tryParse(
        json['last_paid_at']?.toString() ??
            json['last_recharge_at']?.toString() ??
            '',
      ),
    );
  }

  static const empty = MobileRechargePhoneProfile(
    phone: '',
    verified: false,
  );

  static bool _bool(Object? value) {
    if (value == true || value == 1) return true;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes';
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class MobileRechargeAmountOption {
  const MobileRechargeAmountOption({
    required this.amount,
    required this.label,
    required this.enabled,
  });

  final int amount;
  final String label;
  final bool enabled;

  factory MobileRechargeAmountOption.fromJson(Map<String, Object?> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString().split('.').first ?? '') ?? 0;
    return MobileRechargeAmountOption(
      amount: amount,
      label: json['label']?.toString() ?? amount.toString(),
      enabled: !_isFalse(json['enabled']),
    );
  }

  static bool _isFalse(Object? value) {
    if (value == false || value == 0) return true;
    final text = value?.toString().toLowerCase().trim();
    return text == 'false' || text == '0' || text == 'no';
  }
}

class MobileRechargeOrder {
  const MobileRechargeOrder({
    required this.orderNo,
    required this.status,
    required this.message,
  });

  final String orderNo;
  final String status;
  final String message;

  factory MobileRechargeOrder.fromJson(Map<String, Object?> json) {
    return MobileRechargeOrder(
      orderNo: json['order_no']?.toString() ?? '',
      status: json['order_status']?.toString() ??
          json['plugin_status']?.toString() ??
          json['status']?.toString() ??
          '',
      message: json['message']?.toString() ??
          json['receipt']?.toString() ??
          json['fail_reason']?.toString() ??
          '',
    );
  }
}

class CreateMobileRechargeOrderReq {
  const CreateMobileRechargeOrderReq({
    required this.clientOrderId,
    this.serviceType = 'mobile',
    required this.phone,
    required this.amount,
    required this.paymentMethod,
    required this.payPin,
    required this.phoneConfirmed,
    required this.verificationType,
    this.ownerLastChar,
  });

  final String clientOrderId;
  final String serviceType;
  final String phone;
  final int amount;
  final String paymentMethod;
  final String payPin;
  final bool phoneConfirmed;
  final String verificationType;
  final String? ownerLastChar;

  Map<String, Object?> toJson() {
    return {
      'client_order_id': clientOrderId,
      'service_type': serviceType,
      'phone': phone,
      'amount': amount,
      'pay_method': _apiPayMethod(paymentMethod),
      'pay_password': payPin,
      // 风控契约字段：后端靠这两个字段区分「老户确认号码」与「新户姓名验证」，
      // 缺失会导致 life_payment_accounts 档案的 verified 语义失真。
      'verification_type': verificationType,
      'phone_confirmed': phoneConfirmed,
      if (ownerLastChar?.trim().isNotEmpty == true)
        'owner_last_char': ownerLastChar!.trim(),
    };
  }
}

String _apiPayMethod(String raw) {
  final value = raw.trim().toUpperCase();
  if (value == 'USDT') return 'usdt';
  return 'coin_99';
}

class MobileRechargeRepository {
  MobileRechargeRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<List<MobileRechargeAmountOption>> getAmountOptions(
      String phone) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/life-payments/mobile/amount-options',
      queryParameters: {'phone': phone},
    );
    final data = _unwrapMap(res.data);
    final rawItems = data['items'];
    if (rawItems is! List) return const [];
    return rawItems
        .whereType<Map>()
        .map((item) => MobileRechargeAmountOption.fromJson(
              Map<String, Object?>.from(item),
            ))
        .where((item) => item.amount > 0 && item.enabled)
        .toList(growable: false);
  }

  Future<MobileRechargePhoneProfile> getPhoneProfile(String phone) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/life-payments/accounts/profile',
        queryParameters: {
          'service_type': 'mobile',
          'account_no': phone,
        },
      );
      final data = _unwrapMap(res.data);
      if (data.isEmpty) {
        return MobileRechargePhoneProfile.empty;
      }
      return MobileRechargePhoneProfile.fromJson(data);
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        return MobileRechargePhoneProfile.empty;
      }
      rethrow;
    }
  }

  Future<MobileRechargeOrder> createOrder(
    CreateMobileRechargeOrderReq req,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/life-payments/mobile/orders',
      data: req.toJson(),
    );
    return MobileRechargeOrder.fromJson(_unwrapMap(res.data));
  }

  Future<MobileRechargeOrder> getOrder(String orderNo) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/life-payments/orders/${Uri.encodeComponent(orderNo)}',
    );
    return MobileRechargeOrder.fromJson(_unwrapMap(res.data));
  }

  /// 插件回写 need_owner_last_char 后，前端补交机主姓名最后一个字。
  /// 文档 v1.0：`POST /life-payments/mobile/orders/{order_no}/owner-last-char`；
  /// 旧路径无 `mobile` 段，404 时 fallback 以兼容现网。
  Future<MobileRechargeOrder> submitOwnerLastChar({
    required String orderNo,
    required String ownerLastChar,
  }) async {
    final body = {'owner_last_char': ownerLastChar.trim()};
    final encoded = Uri.encodeComponent(orderNo);
    final primary = '/life-payments/mobile/orders/$encoded/owner-last-char';
    final legacy = '/life-payments/orders/$encoded/owner-last-char';
    try {
      final res = await _dio.post<Map<String, dynamic>>(primary, data: body);
      return MobileRechargeOrder.fromJson(_unwrapMap(res.data));
    } on DioError catch (e) {
      final status = e.response?.statusCode ?? 0;
      if (status != 404) rethrow;
      final res = await _dio.post<Map<String, dynamic>>(legacy, data: body);
      return MobileRechargeOrder.fromJson(_unwrapMap(res.data));
    }
  }

  Map<String, Object?> _unwrapMap(Map<String, dynamic>? raw) {
    final map = raw ?? const <String, dynamic>{};
    final data = map['data'];
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
    return Map<String, Object?>.from(map);
  }
}
