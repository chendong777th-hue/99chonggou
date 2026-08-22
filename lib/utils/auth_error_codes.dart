import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';

class AuthErrorCodes {
  AuthErrorCodes._();

  static String map(String code, AuthLocalizations strings) {
    switch (code.trim().toUpperCase()) {
      case 'BAD_CREDENTIALS':
        return strings.accountOrPasswordWrong;
      case 'USER_NOT_FOUND':
        return strings.accountNotFound;
      case 'ACCOUNT_DISABLED':
        return strings.accountDisabled;
      case 'SMS_COUNTRY_NOT_SUPPORTED':
        return strings.smsCountryNotSupported;
      case 'INVALID_PHONE':
        return strings.invalidPhone;
      case 'SMS_PROVIDER_UNAVAILABLE':
        return strings.smsProviderUnavailable;
      case 'SMS_RATE_LIMITED':
        return strings.smsSendRateLimited;
      case 'SMS_CODE_INVALID':
        return strings.smsCodeInvalid;
      case 'SMS_CODE_EXPIRED':
        return strings.smsCodeExpired;
      case 'PHONE_EXISTS':
      case 'PHONE_REGISTERED':
      case 'PHONE_ALREADY_EXISTS':
      case 'PHONE_ALREADY_REGISTERED':
      case 'MOBILE_EXISTS':
      case 'ACCOUNT_EXISTS':
      case 'USER_EXISTS':
        return strings.phoneRegistered;
      case 'CHALLENGE_EXPIRED':
      case 'INVALID_TOKEN':
      case 'TOKEN_INVALID':
      case 'TOKEN_EXPIRED':
      case 'AUTH_EXPIRED':
      case 'SESSION_EXPIRED':
        return strings.challengeExpired;
      case 'RATE_LIMITED':
        return strings.rateLimited;
      case 'INVALID_INPUT':
        return strings.invalidInput;
      default:
        return code;
    }
  }
}
