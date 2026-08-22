import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';
import 'package:tencent_cloud_chat_demo/utils/auth_error_codes.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';

class DioErrorMessage {
  DioErrorMessage._();

  static String forApp(
    Object error, {
    AppLocale? locale,
  }) {
    final strings = AuthLocalizations.fromAppLocale(
      locale ?? AppI18n.current.locale,
    );
    return fromThrowable(error, strings);
  }

  static String loadFailed({AppLocale? locale}) {
    return AuthLocalizations.fromAppLocale(
      locale ?? AppI18n.current.locale,
    ).loadFailed;
  }

  /// 将后端原始 message / IM desc 转为用户可读文案，过滤路径、错误码等技术信息。
  static String sanitizeUserText(String? raw, {required String fallback}) {
    return _safeMessage(raw?.trim() ?? '', fallback);
  }

  static String fromThrowable(Object error, AuthLocalizations strings) {
    if (error is DioError) {
      return fromAuth(error, strings);
    }
    if (error is FormatException) {
      return strings.requestFailed;
    }
    if (isNetworkRelated(error)) {
      return strings.networkUnavailable;
    }
    return strings.requestFailed;
  }

  static String fromAuth(DioError e, AuthLocalizations strings) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final code = _readErrorCode(map);
      if (code != null) {
        final mapped = _businessTextFromCode(code);
        if (mapped != null) return mapped;
        final authMapped = AuthErrorCodes.map(code, strings);
        if (authMapped.trim() != code.trim()) {
          return authMapped;
        }
        final message = _responseMessageFromMap(map);
        if (message.isNotEmpty) {
          final msgMapped = _businessTextFromMessage(message);
          return msgMapped ?? _safeMessage(message, strings.requestFailed);
        }
        return strings.requestFailed;
      }
      final message = _responseMessageFromMap(data);
      if (message.isNotEmpty) {
        final mapped = _businessTextFromMessage(message);
        return mapped ?? _safeMessage(message, strings.requestFailed);
      }
    }
    if (status == 403) {
      return strings.httpForbidden;
    }
    if (isNetworkRelated(e)) {
      return strings.networkUnavailable;
    }
    final raw = e.message?.trim() ?? '';
    if (raw.isEmpty || _looksLikeTechnicalError(raw)) {
      return strings.requestFailed;
    }
    return _safeMessage(raw, strings.requestFailed);
  }

  /// 网页扫码登录专用：按 `code` 分支，禁止把 401 / expired token 译成滑块「验证已过期」。
  static String fromQrWebLogin(DioError e, AuthLocalizations strings) {
    final status = e.response?.statusCode;
    if (status == 404) {
      return strings.qrLoginUnavailable;
    }
    final data = e.response?.data;
    String? code;
    if (data is Map) {
      code = _readErrorCode(Map<String, dynamic>.from(data));
    }
    final upper = (code ?? '').trim().toUpperCase();
    switch (upper) {
      case 'QR_SESSION_EXPIRED':
        return strings.qrWebLoginSessionExpired;
      case 'QR_SESSION_BOUND':
        return strings.qrWebLoginSessionBound;
      case 'QR_SESSION_INVALID_STATUS':
        return strings.qrWebLoginSessionInvalidStatus;
      case 'QR_SCANNER_MISMATCH':
        return strings.qrWebLoginScannerMismatch;
      case 'DEVICE_BANNED':
        return strings.qrWebLoginDeviceBanned;
      case 'ACCOUNT_DISABLED':
        return strings.accountDisabled;
      case 'UNAUTHORIZED':
      case 'AUTH_EXPIRED':
      case 'TOKEN_EXPIRED':
      case 'TOKEN_INVALID':
      case 'INVALID_TOKEN':
      case 'LOGIN_EXPIRED':
      case 'SESSION_EXPIRED':
        return strings.qrWebLoginNeedAppLogin;
    }
    if (status == 401) {
      return strings.qrWebLoginNeedAppLogin;
    }
    if (isNetworkRelated(e)) {
      return strings.networkUnavailable;
    }
    // 其余走通用映射，但再挡一层 token-expired 文案。
    final generic = fromAuth(e, strings);
    if (generic.contains('验证已过期') ||
        generic.contains('驗證已過期') ||
        generic.toLowerCase().contains('verification expired')) {
      return strings.qrWebLoginNeedAppLogin;
    }
    return generic;
  }

  static String _safeMessage(String raw, String fallback) {
    final value = raw.trim();
    if (value.isEmpty) return fallback;
    final lower = value.toLowerCase();
    final upper = value.toUpperCase();
    if (upper == 'UNAUTHORIZED' ||
        upper == 'AUTH_EXPIRED' ||
        upper == 'TOKEN_EXPIRED' ||
        upper == 'TOKEN_INVALID' ||
        upper == 'INVALID_TOKEN' ||
        upper == 'LOGIN_EXPIRED' ||
        upper == 'SESSION_EXPIRED' ||
        lower.contains('invalid or expired token') ||
        ((lower.contains('invalid') || lower.contains('expired')) &&
            lower.contains('token')) ||
        lower.contains('http status error [401]')) {
      return '登录状态已过期，请重新登录';
    }
    if (upper == 'NICKNAME_EXISTS' || upper.contains('NICKNAME_EXISTS')) {
      return '用户名已存在';
    }
    if (upper == 'SMS_COUNTRY_NOT_SUPPORTED') {
      return '该地区暂不支持注册';
    }
    if (upper == 'INVALID_PHONE') {
      return '请输入正确的手机号';
    }
    if (upper == 'SMS_PROVIDER_UNAVAILABLE') {
      return '验证码发送失败，请稍后重试';
    }
    if (upper == 'SMS_RATE_LIMITED') {
      return '发送过于频繁，请稍后再试';
    }
    if (upper == 'SMS_CODE_INVALID') {
      return '验证码错误';
    }
    if (upper == 'SMS_CODE_EXPIRED') {
      return '验证码已过期，请重新获取';
    }
    if (upper == 'PHONE_EXISTS' ||
        upper == 'PHONE_REGISTERED' ||
        upper == 'PHONE_ALREADY_EXISTS' ||
        upper == 'PHONE_ALREADY_REGISTERED' ||
        upper == 'MOBILE_EXISTS' ||
        upper == 'ACCOUNT_EXISTS' ||
        upper == 'USER_EXISTS') {
      return '该手机号已注册';
    }
    if (upper == 'FORBIDDEN' ||
        upper == 'PERMISSION_DENIED' ||
        lower.contains('forbidden') ||
        lower.contains('permission denied') ||
        lower.contains('http status error [403]')) {
      return '暂无权限操作';
    }
    if (lower.startsWith('dioerror') ||
        lower.contains('exception') ||
        lower.contains('stacktrace') ||
        lower.contains('http status error') ||
        _looksLikeApiOrTechnicalText(value)) {
      return fallback;
    }
    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(value);
    if (hasChinese && value.length <= 40 && !value.contains('code')) {
      return value;
    }
    return fallback;
  }

  static bool isAuthFailure(DioError error) {
    final status = error.response?.statusCode;
    if (status == null) return false;
    if (_isExplicitAuthError(error)) return true;
    if (_isWalletPath(error.requestOptions.path)) return false;
    if (status == 401) return !_isBusinessError(error);
    return false;
  }

  static bool _isExplicitAuthError(DioError error) {
    final code = _responseCode(error).toUpperCase();
    return code == 'UNAUTHORIZED' ||
        code == 'AUTH_EXPIRED' ||
        code == 'TOKEN_EXPIRED' ||
        code == 'TOKEN_INVALID' ||
        code == 'INVALID_TOKEN' ||
        code == 'LOGIN_EXPIRED' ||
        code == 'SESSION_EXPIRED';
  }

  static bool _isBusinessError(DioError error) {
    final code = _responseCode(error).toUpperCase();
    if (_businessTextFromCode(code) != null) {
      return true;
    }
    final message = _responseMessage(error);
    return _businessTextFromMessage(message) != null;
  }

  static String _responseCode(DioError error) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['code', 'errorCode', 'errCode']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      final inner = data['data'];
      if (inner is Map) {
        for (final key in const ['code', 'errorCode', 'errCode']) {
          final value = inner[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      }
    }
    return '';
  }

  static String _responseMessage(DioError error) {
    final data = error.response?.data;
    if (data is Map) return _responseMessageFromMap(data);
    return error.message?.trim() ?? '';
  }

  static String _responseMessageFromMap(Map data) {
    for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    final inner = data['data'];
    if (inner is Map) {
      for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
        final value = inner[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }
    return '';
  }

  static String? _businessTextFromCode(String code) {
    switch (code.trim().toUpperCase()) {
      case 'PASSWORD_WRONG':
      case 'PAY_PIN_INVALID':
      case 'INVALID_PAY_PIN':
      case 'PAY_PIN_WRONG':
      case 'PAY_PASSWORD_WRONG':
      case 'PAY_PASSWORD_INVALID':
      case 'TRADE_PASSWORD_WRONG':
      case 'TRADE_PASSWORD_INVALID':
      case 'FUND_PASSWORD_WRONG':
        return '支付密码错误';
      case 'PASSWORD_LOCKED':
      case 'PAY_PIN_LOCKED':
        return '支付密码已锁定';
      case 'PAY_PIN_NOT_SET':
        return '请先设置支付密码';
      case 'INSUFFICIENT_BALANCE':
        return '余额不足，请先上分';
      case 'SETUP_FAILED':
        return '定庄失败，请确认本局状态或开新局后再试';
      case 'DRAW_FAILED':
        return '开彩录入失败';
      case 'SUBMIT_FAILED':
        return '截止提交失败';
      case 'RECUTOFF_NOT_ALLOWED':
      case 'RECUTOFF_BLOCKED':
      case 'DRAWS_ENTERED':
        return '已录入开彩，不可重新截止下注';
      case 'PREVIEW_FAILED':
        return '下注预览失败';
      case 'REPORT_IMAGE_FAILED':
      case 'BET_IMAGE_FAILED':
        return '统计清单图片发送失败';
      case 'SETTLE_IMAGE_FAILED':
        return '结算明细图片发送失败';
      case 'SETTLE_BILL_FAILED':
        return '流水/抽水账单发送失败';
      case 'POINTS_IMAGE_FAILED':
      case 'USER_POINTS_IMAGE_FAILED':
        return '用户积分图发送失败';
      case 'NO_SESSION':
        return '当前未开机，无法发送走势图';
      case 'NO_DATA':
        return '暂无已结算局数据';
      case 'IMAGE_FAILED':
      case 'TREND_IMAGE_FAILED':
        return '走势图生成失败';
      case 'IM_SEND_FAILED':
        return '走势图发送到游戏群失败';
      case 'SETTLE_FAILED':
        return '结算失败，请确认开彩是否录满';
      case 'CO_BANK_FAILED':
        return '合庄录入失败';
      case 'BET_REJECTED':
        return null;
      case 'SETTINGS_KEY_REQUIRED':
        return '操作密钥无效或未配置';
      case 'TENANT_REQUIRED':
        return '请先选择游戏群（租户）';
      case 'TENANT_NOT_FOUND':
        return '游戏群租户不存在，请刷新后重试';
      case 'GAME_PRIVILEGE_REQUIRED':
        return '需要有效的游戏特权';
      case 'PRIVILEGE_CHECK_UNAVAILABLE':
        return '特权校验暂不可用，请稍后重试';
      case 'INVALID_SETTINGS':
        return '规则参数无效（门数须为 2-10）';
      case 'INSUFFICIENT_FEE':
      case 'FEE_EXCEEDS_AMOUNT':
        return '手续费余额不足';
      case 'DUPLICATE_SUBMIT':
        return '请勿重复提交';
      case 'INVALID_AMOUNT':
      case 'EXCHANGE_AMOUNT_TOO_SMALL':
      case 'WITHDRAW_MIN_NOT_MET':
        return '金额不正确';
      case 'EXCHANGE_MAINTENANCE':
        return '正在维护';
      case 'INVALID_RECEIVER':
      case 'INVALID_TRON_ADDRESS':
      case 'RECIPIENT_NOT_FOUND':
        return '收款人无效';
      case 'LIMIT_EXCEEDED':
        return '金额或次数超过限制';
    }
    return null;
  }

  static String? _businessTextFromMessage(String text) {
    final value = text.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (value.contains('支付密码') ||
        value.contains('交易密码') ||
        value.contains('资金密码') ||
        lower.contains('pay pin') ||
        lower.contains('payment password') ||
        lower.contains('trade password')) {
      if (value.contains('锁定') || lower.contains('locked')) {
        return '支付密码已锁定';
      }
      if (value.contains('未设置') || lower.contains('not set')) {
        return '请先设置支付密码';
      }
      return '支付密码错误';
    }
    if (value.contains('余额不足') || lower.contains('insufficient balance')) {
      return '余额不足';
    }
    if (value.contains('正在维护') ||
        value.contains('维护中') ||
        lower.contains('maintenance') ||
        lower.contains('under maintenance')) {
      return '正在维护';
    }
    if (value.contains('超过最大下注') ||
        value.contains('超过最大限额') ||
        value.contains('单注最大')) {
      return value.contains('单注最大') ? '超过最大下注' : value;
    }
    if (value.contains('低于最小下注') || value.contains('单注最小')) {
      return value.contains('单注最小') ? '低于最小下注' : value;
    }
    if (value.contains('重复提交') || lower.contains('duplicate submit')) {
      return '请勿重复提交';
    }
    if (value.contains('已录入开彩') &&
        (value.contains('重新截止') || value.contains('不可重新截止'))) {
      return '已录入开彩，不可重新截止下注';
    }
    if ((value.contains('手机号') || lower.contains('phone') || lower.contains('mobile')) &&
        (value.contains('已注册') ||
            value.contains('已存在') ||
            lower.contains('registered') ||
            lower.contains('exists') ||
            lower.contains('already used'))) {
      return '该手机号已注册';
    }
    if (lower.contains('sms_country_not_supported')) {
      return '该地区暂不支持注册';
    }
    if (lower.contains('sms_provider_unavailable')) {
      return '验证码发送失败，请稍后重试';
    }
    if (lower.contains('sms_rate_limited')) {
      return '发送过于频繁，请稍后再试';
    }
    if (lower.contains('sms_code_invalid')) {
      return '验证码错误';
    }
    if (lower.contains('sms_code_expired')) {
      return '验证码已过期，请重新获取';
    }
    if ((lower.contains('invalid') && lower.contains('token')) ||
        (lower.contains('expired') && lower.contains('token')) ||
        lower.contains('invalid or expired token')) {
      return '验证已过期，请重新验证';
    }
    return null;
  }

  static bool _isWalletPath(String path) {
    final p = path.trim().toLowerCase();
    return p == '/wallet' || p.startsWith('/wallet/');
  }

  static bool isNetworkRelated(Object error) {
    if (error is DioError) {
      switch (error.type) {
        case DioErrorType.connectTimeout:
        case DioErrorType.sendTimeout:
        case DioErrorType.receiveTimeout:
          return true;
        default:
          break;
      }
      if (error.error != null && isNetworkRelated(error.error!)) {
        return true;
      }
    }
    final typeName = error.runtimeType.toString();
    if (typeName == 'SocketException' ||
        typeName == 'HandshakeException' ||
        typeName == 'HttpException') {
      return true;
    }
    return _looksLikeTechnicalError(error.toString());
  }

  static String? _readErrorCode(Map<String, dynamic> map) {
    for (final key in const ['code', 'errorCode', 'errCode']) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isEmpty) continue;
      if (value is num && value == 0) continue;
      if (text == '0') continue;
      return text;
    }
    final inner = map['data'];
    if (inner is Map) {
      return _readErrorCode(Map<String, dynamic>.from(inner));
    }
    return null;
  }

  static bool _looksLikeTechnicalError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection timed out') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('errno =') ||
        lower.contains('os error') ||
        lower.contains('handshakeexception') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('failed to fetch') ||
        lower.contains('cors') ||
        lower.contains('timed out') ||
        _looksLikeApiOrTechnicalText(text);
  }

  static bool _looksLikeApiOrTechnicalText(String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return false;
    }
    final lower = value.toLowerCase();
    if (lower.contains('http status error')) {
      return true;
    }
    if (value.contains('接口') ||
        value.contains('介面') ||
        lower.contains(' endpoint') ||
        lower.contains('endpoint ') ||
        lower.contains('api returns') ||
        lower.contains('returns data')) {
      return true;
    }
    if (RegExp(r'/[a-z0-9_\-/]+', caseSensitive: false).hasMatch(value)) {
      return true;
    }
    if (RegExp(r'^[A-Z][A-Z0-9_]{2,}$').hasMatch(value)) {
      return true;
    }
    return false;
  }
}
