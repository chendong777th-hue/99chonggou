import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/errors/app_error.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';

class MomentsErrorMapper {
  MomentsErrorMapper._();

  static AppError map(
    Object error, {
    String action = 'load',
  }) {
    if (error is AppException) {
      return error.error;
    }
    if (error is AppError) {
      return error;
    }
    if (error is ArgumentError) {
      return AppError(
        code: 'MOMENTS_INVALID_INPUT',
        userMessage: _i.t(
          zhHans: '内容不能为空',
          zhHant: '內容不能為空',
          en: 'Content cannot be empty.',
          ja: 'Content cannot be empty.',
          ko: 'Content cannot be empty.',
        ),
        retryable: false,
        cause: error,
      );
    }
    if (error is DioError) {
      return _fromDio(error, action: action);
    }
    return AppError(
      code: 'MOMENTS_REQUEST_FAILED',
      userMessage: _fallback(action),
      retryable: true,
      cause: error,
    );
  }

  static AppException exception(
    Object error, {
    String action = 'load',
  }) {
    return AppException(map(error, action: action));
  }

  static bool isNotFound(Object error) {
    final appError = map(error);
    return appError.code == 'MOMENT_NOT_FOUND';
  }

  static AppI18n get _i => AppI18n.current;

  static AppError _fromDio(
    DioError error, {
    required String action,
  }) {
    final status = error.response?.statusCode;
    final code = _responseCode(error).toUpperCase();
    final message = _responseMessage(error);

    if (_isAuthCode(code) || status == 401) {
      return AppError(
        code: 'MOMENTS_AUTH_EXPIRED',
        userMessage: _i.t(
          zhHans: '登录状态已过期，请重新登录',
          zhHant: '登入狀態已過期，請重新登入',
          en: 'Your session has expired. Please sign in again.',
          ja: 'Your session has expired. Please sign in again.',
          ko: 'Your session has expired. Please sign in again.',
        ),
        retryable: false,
        cause: error,
      );
    }

    if (code == 'MOMENT_NOT_FOUND' ||
        code == 'COMMENT_NOT_FOUND' ||
        status == 404) {
      return AppError(
        code: 'MOMENT_NOT_FOUND',
        userMessage: _i.t(
          zhHans: '内容已删除或不存在',
          zhHant: '內容已刪除或不存在',
          en: 'This moment was deleted or does not exist.',
          ja: 'This moment was deleted or does not exist.',
          ko: 'This moment was deleted or does not exist.',
        ),
        retryable: false,
        cause: error,
      );
    }

    if (code == 'MOMENT_FORBIDDEN' ||
        code == 'FRIEND_REQUIRED' ||
        code == 'BLOCKED' ||
        status == 403) {
      return AppError(
        code: 'MOMENTS_FORBIDDEN',
        userMessage: _i.t(
          zhHans: '暂无权限查看或操作该内容',
          zhHant: '暫無權限查看或操作該內容',
          en: 'You do not have permission for this moment.',
          ja: 'You do not have permission for this moment.',
          ko: 'You do not have permission for this moment.',
        ),
        retryable: false,
        cause: error,
      );
    }

    if (code == 'MOMENT_TEXT_TOO_LONG') {
      return AppError(
        code: code,
        userMessage: _i.t(
          zhHans: '文字内容过长，请精简后再发布',
          zhHant: '文字內容過長，請精簡後再發佈',
          en: 'The text is too long. Shorten it and try again.',
          ja: 'The text is too long. Shorten it and try again.',
          ko: 'The text is too long. Shorten it and try again.',
        ),
        retryable: false,
        cause: error,
      );
    }

    if (code == 'MEDIA_UPLOAD_FAILED' || code == 'INVALID_MEDIA') {
      return AppError(
        code: code,
        userMessage: _i.t(
          zhHans: '媒体上传失败，请检查网络后重试',
          zhHant: '媒體上傳失敗，請檢查網路後重試',
          en: 'Media upload failed. Check your network and try again.',
          ja: 'Media upload failed. Check your network and try again.',
          ko: 'Media upload failed. Check your network and try again.',
        ),
        retryable: true,
        cause: error,
      );
    }

    if (status == 429 || code == 'RATE_LIMITED') {
      return AppError(
        code: 'MOMENTS_RATE_LIMITED',
        userMessage: _i.t(
          zhHans: '操作过于频繁，请稍后再试',
          zhHant: '操作過於頻繁，請稍後再試',
          en: 'Too many requests. Try again later.',
          ja: 'Too many requests. Try again later.',
          ko: 'Too many requests. Try again later.',
        ),
        retryable: true,
        cause: error,
      );
    }

    if (DioErrorMessage.isNetworkRelated(error)) {
      return AppError(
        code: 'MOMENTS_NETWORK_UNAVAILABLE',
        userMessage: _i.t(
          zhHans: '网络不可用，请稍后重试',
          zhHant: '網路不可用，請稍後重試',
          en: 'Network unavailable. Try again later.',
          ja: 'Network unavailable. Try again later.',
          ko: 'Network unavailable. Try again later.',
        ),
        retryable: true,
        cause: error,
      );
    }

    final sanitized = DioErrorMessage.sanitizeUserText(
      message,
      fallback: _fallback(action),
    );
    return AppError(
      code: code.isEmpty ? 'MOMENTS_REQUEST_FAILED' : code,
      userMessage: sanitized,
      retryable: status == null || status >= 500,
      cause: error,
    );
  }

  static String _fallback(String action) {
    switch (action) {
      case 'publish':
        return _i.t(
          zhHans: '发布失败，请稍后重试',
          zhHant: '發佈失敗，請稍後重試',
          en: 'Failed to publish. Try again later.',
          ja: 'Failed to publish. Try again later.',
          ko: 'Failed to publish. Try again later.',
        );
      case 'comment':
        return _i.t(
          zhHans: '评论失败，请稍后重试',
          zhHant: '評論失敗，請稍後重試',
          en: 'Failed to comment. Try again later.',
          ja: 'Failed to comment. Try again later.',
          ko: 'Failed to comment. Try again later.',
        );
      case 'like':
        return _i.t(
          zhHans: '操作失败，请稍后重试',
          zhHant: '操作失敗，請稍後重試',
          en: 'Action failed. Try again later.',
          ja: 'Action failed. Try again later.',
          ko: 'Action failed. Try again later.',
        );
      case 'delete':
        return _i.t(
          zhHans: '删除失败，请稍后重试',
          zhHant: '刪除失敗，請稍後重試',
          en: 'Failed to delete. Try again later.',
          ja: 'Failed to delete. Try again later.',
          ko: 'Failed to delete. Try again later.',
        );
      default:
        return _i.t(
          zhHans: '加载失败，请稍后重试',
          zhHant: '載入失敗，請稍後重試',
          en: 'Failed to load. Try again later.',
          ja: 'Failed to load. Try again later.',
          ko: 'Failed to load. Try again later.',
        );
    }
  }

  static bool _isAuthCode(String code) {
    return code == 'UNAUTHORIZED' ||
        code == 'AUTH_EXPIRED' ||
        code == 'TOKEN_EXPIRED' ||
        code == 'TOKEN_INVALID' ||
        code == 'INVALID_TOKEN' ||
        code == 'LOGIN_EXPIRED' ||
        code == 'SESSION_EXPIRED';
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
    if (data is Map) {
      for (final key in const ['message', 'msg', 'error', 'desc', 'detail']) {
        final value = data[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }
    return error.message.trim();
  }
}
