import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/errors/app_error.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';

class WalletErrorMapper {
  WalletErrorMapper._();

  static AppError map(
    Object error, {
    String action = 'load',
  }) {
    if (error is AppException) return error.error;
    if (error is AppError) return error;
    if (error is DioError) {
      final retryable =
          DioErrorMessage.isNetworkRelated(error) ||
              (error.response?.statusCode ?? 0) >= 500;
      return AppError(
        code: _codeFromDio(error, fallback: 'WALLET_REQUEST_FAILED'),
        userMessage: UserApiErrorMessage.fromWallet(error),
        retryable: retryable,
        cause: error,
      );
    }
    return AppError(
      code: 'WALLET_REQUEST_FAILED',
      userMessage: AppI18n.current.t(
        zhHans: action == 'load' ? '钱包加载失败，请稍后重试' : '钱包操作失败，请稍后重试',
        zhHant: action == 'load' ? '錢包載入失敗，請稍後重試' : '錢包操作失敗，請稍後重試',
        en: action == 'load'
            ? 'Failed to load wallet. Try again later.'
            : 'Wallet action failed. Try again later.',
        ja: action == 'load'
            ? 'Failed to load wallet. Try again later.'
            : 'Wallet action failed. Try again later.',
        ko: action == 'load'
            ? 'Failed to load wallet. Try again later.'
            : 'Wallet action failed. Try again later.',
      ),
      retryable: true,
      cause: error,
    );
  }

  static String _codeFromDio(DioError error, {required String fallback}) {
    final data = error.response?.data;
    if (data is Map) {
      for (final key in const ['code', 'errorCode', 'errCode']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }
    return fallback;
  }
}
