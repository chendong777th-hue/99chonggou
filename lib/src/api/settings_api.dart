import 'package:dio/dio.dart';

import 'api_client.dart';

class SettingsApi {
  SettingsApi._();

  static final SettingsApi instance = SettingsApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<void> changeTradePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post('/wallet/pay-pin/change', data: {
      'oldPayPin': oldPassword,
      'newPayPin': newPassword,
    });
  }

  Future<void> setTradePassword({
    required String payPin,
  }) async {
    await _dio.post('/wallet/pay-pin/set', data: {
      'payPin': payPin,
    });
  }

  Future<void> resetTradePassword({
    required String smsCode,
    required String payPin,
  }) async {
    await _dio.post('/wallet/pay-pin/reset', data: {
      'smsCode': smsCode,
      'payPin': payPin,
    });
  }

  Future<PhoneChangeStartResult> startPhoneChange() async {
    final res = await _dio.post('/me/phone/change/start');
    return PhoneChangeStartResult.fromJson(_asMap(res.data));
  }

  Future<PhoneChangeStepResult> verifyOldPhone({
    required String changeId,
    required String smsCode,
  }) async {
    final res = await _dio.post('/me/phone/change/verify-old', data: {
      'changeId': changeId,
      'smsCode': smsCode,
    });
    return PhoneChangeStepResult.fromJson(_asMap(res.data));
  }

  Future<PhoneChangeNewResult> sendNewPhoneCode({
    required String changeId,
    required String newPhone,
    String phoneCountry = 'CN',
  }) async {
    final res = await _dio.post('/me/phone/change/send-new', data: {
      'changeId': changeId,
      'newPhone': newPhone.trim(),
      'phoneCountry': phoneCountry,
    });
    return PhoneChangeNewResult.fromJson(_asMap(res.data));
  }

  Future<PhoneChangeDoneResult> confirmPhoneChange({
    required String changeId,
    required String smsCode,
  }) async {
    final res = await _dio.post('/me/phone/change/confirm', data: {
      'changeId': changeId,
      'smsCode': smsCode,
    });
    return PhoneChangeDoneResult.fromJson(_asMap(res.data));
  }

  Future<PhoneBindStartResult> startPhoneBind({
    required String phone,
    String phoneCountry = 'CN',
  }) async {
    final res = await _dio.post('/me/phone/bind/start', data: {
      'phone': phone.trim(),
      'phoneCountry': phoneCountry,
    });
    return PhoneBindStartResult.fromJson(_asMap(res.data));
  }

  Future<PhoneChangeDoneResult> confirmPhoneBind({
    required String bindId,
    required String smsCode,
  }) async {
    final res = await _dio.post('/me/phone/bind/confirm', data: {
      'bindId': bindId,
      'smsCode': smsCode,
    });
    return PhoneChangeDoneResult.fromJson(_asMap(res.data));
  }
}

Map<String, dynamic> _asMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return {};
}

class PhoneChangeStartResult {
  const PhoneChangeStartResult({
    required this.changeId,
    required this.phoneMasked,
    required this.expiresIn,
  });

  final String changeId;
  final String phoneMasked;
  final int expiresIn;

  factory PhoneChangeStartResult.fromJson(Map<String, dynamic> json) {
    return PhoneChangeStartResult(
      changeId: json['changeId']?.toString() ?? '',
      phoneMasked: json['phoneMasked']?.toString() ?? '',
      expiresIn: _asInt(json['expiresIn']),
    );
  }
}

class PhoneChangeStepResult {
  const PhoneChangeStepResult({
    required this.changeId,
    required this.expiresIn,
  });

  final String changeId;
  final int expiresIn;

  factory PhoneChangeStepResult.fromJson(Map<String, dynamic> json) {
    return PhoneChangeStepResult(
      changeId: json['changeId']?.toString() ?? '',
      expiresIn: _asInt(json['expiresIn']),
    );
  }
}

class PhoneChangeNewResult {
  const PhoneChangeNewResult({
    required this.phoneMasked,
    required this.expiresIn,
  });

  final String phoneMasked;
  final int expiresIn;

  factory PhoneChangeNewResult.fromJson(Map<String, dynamic> json) {
    return PhoneChangeNewResult(
      phoneMasked: json['phoneMasked']?.toString() ?? '',
      expiresIn: _asInt(json['expiresIn']),
    );
  }
}

class PhoneChangeDoneResult {
  const PhoneChangeDoneResult({
    required this.phone,
    required this.phoneMasked,
  });

  final String phone;
  final String phoneMasked;

  factory PhoneChangeDoneResult.fromJson(Map<String, dynamic> json) {
    return PhoneChangeDoneResult(
      phone: json['phone']?.toString() ?? '',
      phoneMasked: json['phoneMasked']?.toString() ?? '',
    );
  }
}

class PhoneBindStartResult {
  const PhoneBindStartResult({
    required this.bindId,
    required this.phoneMasked,
    required this.expiresIn,
  });

  final String bindId;
  final String phoneMasked;
  final int expiresIn;

  factory PhoneBindStartResult.fromJson(Map<String, dynamic> json) {
    return PhoneBindStartResult(
      bindId: json['bindId']?.toString() ?? '',
      phoneMasked: json['phoneMasked']?.toString() ?? '',
      expiresIn: _asInt(json['expiresIn']),
    );
  }
}

int _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}
