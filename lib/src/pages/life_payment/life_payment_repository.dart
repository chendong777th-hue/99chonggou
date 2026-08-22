import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';

class LifePaymentHomeData {
  const LifePaymentHomeData({
    required this.cityName,
    required this.monthPaidAmount,
    required this.services,
    required this.recentOrders,
  });

  final String cityName;
  final String monthPaidAmount;
  final List<LifePaymentServiceItem> services;
  final List<LifePaymentRecentOrder> recentOrders;

  factory LifePaymentHomeData.fromJson(Map<String, Object?> json) {
    return LifePaymentHomeData(
      cityName: json['city_name']?.toString() ?? '',
      monthPaidAmount: json['month_paid_amount']?.toString() ?? '0.00',
      services: _list(json['services'])
          .map(LifePaymentServiceItem.fromJson)
          .toList(growable: false),
      recentOrders: _list(json['recent_orders'])
          .map(LifePaymentRecentOrder.fromJson)
          .toList(growable: false),
    );
  }
}

class LifePaymentServiceItem {
  const LifePaymentServiceItem({
    required this.serviceType,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.maintenanceMessage,
  });

  final String serviceType;
  final String title;
  final String subtitle;
  final bool enabled;
  final String maintenanceMessage;

  factory LifePaymentServiceItem.fromJson(Map<String, Object?> json) {
    return LifePaymentServiceItem(
      serviceType: json['service_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      enabled: !_isFalse(json['enabled']),
      maintenanceMessage: json['maintenance_message']?.toString() ?? '',
    );
  }
}

class LifePaymentRecentOrder {
  const LifePaymentRecentOrder({
    required this.orderNo,
    required this.serviceType,
    required this.title,
    required this.accountMask,
    required this.amount,
    required this.orderStatus,
    required this.createdAt,
  });

  final String orderNo;
  final String serviceType;
  final String title;
  final String accountMask;
  final String amount;
  final String orderStatus;
  final String createdAt;

  factory LifePaymentRecentOrder.fromJson(Map<String, Object?> json) {
    return LifePaymentRecentOrder(
      orderNo: json['order_no']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      accountMask: json['account_mask']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      orderStatus: json['order_status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class LifePaymentProviderItem {
  const LifePaymentProviderItem({
    required this.serviceType,
    required this.cityName,
    required this.cityCode,
    required this.providerName,
    required this.providerCode,
    required this.enabled,
  });

  final String serviceType;
  final String cityName;
  final String cityCode;
  final String providerName;
  final String providerCode;
  final bool enabled;

  factory LifePaymentProviderItem.fromJson(Map<String, Object?> json) {
    return LifePaymentProviderItem(
      serviceType: json['service_type']?.toString() ?? '',
      cityName: json['city_name']?.toString() ?? '',
      cityCode: json['city_code']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      providerCode: json['provider_code']?.toString() ?? '',
      enabled: !_isFalse(json['enabled']),
    );
  }
}

class UtilityAmountOption {
  const UtilityAmountOption({
    required this.amount,
    required this.label,
    required this.enabled,
  });

  final int amount;
  final String label;
  final bool enabled;

  factory UtilityAmountOption.fromJson(Map<String, Object?> json) {
    final rawAmount = json['amount'];
    final amount = rawAmount is num
        ? rawAmount.round()
        : int.tryParse(rawAmount?.toString().split('.').first ?? '') ?? 0;
    return UtilityAmountOption(
      amount: amount,
      label: json['label']?.toString() ?? '$amount元',
      enabled: !_isFalse(json['enabled']),
    );
  }
}

class UtilityAmountOptions {
  const UtilityAmountOptions({
    required this.serviceType,
    required this.allowCustomAmount,
    required this.items,
  });

  final String serviceType;
  final bool allowCustomAmount;
  final List<UtilityAmountOption> items;

  factory UtilityAmountOptions.fromJson(Map<String, Object?> json) {
    return UtilityAmountOptions(
      serviceType: json['service_type']?.toString() ?? '',
      allowCustomAmount: !_isFalse(json['allow_custom_amount']),
      items: _list(json['items'])
          .map(UtilityAmountOption.fromJson)
          .where((item) => item.amount > 0 && item.enabled)
          .toList(growable: false),
    );
  }

  static const empty = UtilityAmountOptions(
    serviceType: '',
    allowCustomAmount: true,
    items: [],
  );
}

class UtilityQueryResult {
  const UtilityQueryResult({
    required this.queryNo,
    required this.serviceType,
    required this.queryStatus,
    required this.pluginStatus,
    required this.cityName,
    required this.cityCode,
    required this.providerName,
    required this.providerCode,
    required this.accountNo,
    required this.userAddress,
    required this.accountBalance,
    required this.receipt,
    required this.expiredAt,
    this.suggestAmount = '',
  });

  final String queryNo;
  final String serviceType;
  final String queryStatus;
  final String pluginStatus;
  final String cityName;
  final String cityCode;
  final String providerName;
  final String providerCode;
  final String accountNo;
  final String userAddress;
  final String accountBalance;
  final String receipt;
  final String expiredAt;
  final String suggestAmount;

  /// 建议金额整元；无效则返回 null。
  int? get suggestAmountYuan {
    final raw = suggestAmount.trim();
    if (raw.isEmpty) return null;
    final asNum = num.tryParse(raw);
    if (asNum == null || asNum <= 0) return null;
    return asNum.round();
  }

  factory UtilityQueryResult.fromJson(Map<String, Object?> json) {
    final queryStatus = json['query_status']?.toString().trim() ??
        json['status']?.toString().trim() ??
        '';
    return UtilityQueryResult(
      queryNo: json['query_no']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      queryStatus: queryStatus,
      pluginStatus: json['plugin_status']?.toString() ?? '',
      cityName: json['city_name']?.toString() ?? '',
      cityCode: json['city_code']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      providerCode: json['provider_code']?.toString() ?? '',
      accountNo: json['account_no']?.toString() ?? '',
      userAddress: json['user_address']?.toString() ?? '',
      accountBalance: json['account_balance']?.toString() ?? '',
      receipt: json['receipt']?.toString() ?? '',
      expiredAt: json['expired_at']?.toString() ?? '',
      suggestAmount: json['suggest_amount']?.toString() ?? '',
    );
  }
}

class LifePaymentOrderResult {
  const LifePaymentOrderResult({
    required this.orderNo,
    required this.serviceType,
    required this.orderStatus,
    required this.platformPayStatus,
    required this.pluginStatus,
    required this.message,
    required this.receipt,
    this.accountNo = '',
    this.phone = '',
    this.userAddress = '',
    this.cityName = '',
    this.providerName = '',
    this.amount = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String orderNo;
  final String serviceType;
  final String orderStatus;
  final String platformPayStatus;
  final String pluginStatus;
  final String message;
  final String receipt;
  final String accountNo;
  final String phone;
  final String userAddress;
  final String cityName;
  final String providerName;
  final String amount;
  final String createdAt;
  final String updatedAt;

  factory LifePaymentOrderResult.fromJson(Map<String, Object?> json) {
    return LifePaymentOrderResult(
      orderNo: json['order_no']?.toString() ?? '',
      serviceType: json['service_type']?.toString() ?? '',
      orderStatus: json['order_status']?.toString() ?? '',
      platformPayStatus: json['platform_pay_status']?.toString() ?? '',
      pluginStatus: json['plugin_status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      receipt: json['receipt']?.toString() ?? '',
      accountNo: json['account_no']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      userAddress: json['user_address']?.toString() ?? '',
      cityName: json['city_name']?.toString() ?? '',
      providerName: json['provider_name']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class LifePaymentRepository {
  LifePaymentRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  final Dio _dio;

  Future<LifePaymentHomeData> getHome() async {
    final res = await _dio.get<Map<String, dynamic>>('/life-payments/home');
    return LifePaymentHomeData.fromJson(_unwrapMap(res.data));
  }

  Future<List<LifePaymentServiceItem>> getServices() async {
    final res = await _dio.get<Map<String, dynamic>>('/life-payments/services');
    final data = _unwrapMap(res.data);
    return _list(data['items'])
        .map(LifePaymentServiceItem.fromJson)
        .toList(growable: false);
  }

  Future<List<LifePaymentProviderItem>> getProviders({
    required String serviceType,
    required String cityName,
    String cityCode = '',
    String keyword = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/life-payments/providers',
      queryParameters: {
        'service_type': serviceType,
        if (cityName.isNotEmpty) 'city_name': cityName,
        if (cityCode.isNotEmpty) 'city_code': cityCode,
        if (keyword.isNotEmpty) 'keyword': keyword,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = _unwrapMap(res.data);
    return _list(data['items'])
        .map(LifePaymentProviderItem.fromJson)
        .toList(growable: false);
  }

  Future<UtilityAmountOptions> getUtilityAmountOptions({
    required String serviceType,
    String cityCode = '',
    String providerCode = '',
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/life-payments/utility/amount-options',
        queryParameters: {
          'service_type': serviceType,
          if (cityCode.isNotEmpty) 'city_code': cityCode,
          if (providerCode.isNotEmpty) 'provider_code': providerCode,
        },
      );
      return UtilityAmountOptions.fromJson(_unwrapMap(res.data));
    } on DioError {
      return UtilityAmountOptions.empty;
    }
  }

  Future<UtilityQueryResult> createUtilityQuery({
    required String serviceType,
    required String cityName,
    required String providerName,
    required String accountNo,
    String cityCode = '',
    String providerCode = '',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/life-payments/utility/queries',
      data: {
        'service_type': serviceType,
        'city_name': cityName,
        'city_code': cityCode,
        'provider_name': providerName,
        'provider_code': providerCode,
        'account_no': accountNo,
      },
    );
    return UtilityQueryResult.fromJson(_unwrapMap(res.data));
  }

  Future<UtilityQueryResult> getUtilityQuery(String queryNo) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/life-payments/utility/queries/${Uri.encodeComponent(queryNo)}',
    );
    return UtilityQueryResult.fromJson(_unwrapMap(res.data));
  }

  Future<LifePaymentOrderResult> createUtilityOrder({
    required String clientOrderId,
    required String queryNo,
    required String serviceType,
    required String cityName,
    required String providerName,
    required String accountNo,
    required String confirmedUserAddress,
    required String amount,
    required String payMethod,
    required String payPassword,
    String cityCode = '',
    String providerCode = '',
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/life-payments/utility/orders',
      data: {
        'client_order_id': clientOrderId,
        'query_no': queryNo,
        'service_type': serviceType,
        'city_name': cityName,
        'city_code': cityCode,
        'provider_name': providerName,
        'provider_code': providerCode,
        'account_no': accountNo,
        'confirmed_user_address': confirmedUserAddress,
        // 接口契约要求 amount 为数字（对齐话费充值），传字符串会被 INVALID_INPUT 拒绝
        'amount': int.tryParse(amount.trim()) ?? 0,
        'pay_method': _apiPayMethod(payMethod),
        'pay_password': payPassword,
      },
    );
    return LifePaymentOrderResult.fromJson(_unwrapMap(res.data));
  }

  Future<LifePaymentOrderResult> getOrder(String orderNo) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/life-payments/orders/${Uri.encodeComponent(orderNo)}',
    );
    return LifePaymentOrderResult.fromJson(_unwrapMap(res.data));
  }

  /// 未成功且尚未进入支付宝收银台的订单可撤销。
  /// 服务端会释放已预扣的平台余额，并将 platform_pay_status 更新为 refunded。
  Future<LifePaymentOrderResult> cancelOrder({
    required String orderNo,
    required String reason,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/life-payments/orders/${Uri.encodeComponent(orderNo)}/cancel',
      data: {'reason': reason},
    );
    return LifePaymentOrderResult.fromJson(_unwrapMap(res.data));
  }

  Map<String, Object?> _unwrapMap(Map<String, dynamic>? raw) {
    final map = raw ?? const <String, dynamic>{};
    final data = map['data'];
    if (data is Map) return Map<String, Object?>.from(data);
    return Map<String, Object?>.from(map);
  }
}

String _apiPayMethod(String raw) {
  final value = raw.trim().toUpperCase();
  if (value == 'USDT') return 'usdt';
  return 'coin_99';
}

List<Map<String, Object?>> _list(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList();
}

bool _isFalse(Object? value) {
  if (value == false || value == 0) return true;
  final text = value?.toString().toLowerCase().trim();
  return text == 'false' || text == '0' || text == 'no';
}
