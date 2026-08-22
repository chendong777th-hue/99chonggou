import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_session_service.dart';

import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

class ToastUtils {
  static void init(BuildContext context) {}

  static bool shouldSuppress(String? message) {
    if (message == null) return true;
    final normalized = message.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    // Tencent IM SDK sometimes reports internal reconnect/login-ticket messages
    // during iOS network switching or automatic relogin. These are not useful
    // for end users and should not be shown as raw English toasts.
    const internalSdkMessages = [
      'send packet interrupt',
      'login ticket has changed',
      'because of relogin',
      'packet interrupt because of relogin',
      'login ticket changed',
      'delete friend',
      'friend deleted',
      'friend removed',
      'deletefromfriendlist',
      'remove friend',
      'plugin failed',
      '插件失败',
      'waiting for friend approval',
      '等待好友审核同意',
    ];
    for (final key in internalSdkMessages) {
      if (normalized.contains(key)) return true;
    }

    return false;
  }

  static void toast(String msg, {BuildContext? context}) {
    if (shouldSuppress(msg)) return;
    final text = normalizeMessage(msg);
    if (shouldSuppress(text)) return;
    toastForce(text, context: context);
  }

  static void toastForce(String msg, {BuildContext? context}) {
    final text = normalizeMessage(msg);
    if (text.isEmpty) return;

    final shown = AppDialog.showNotice(
      message: text,
      duration: const Duration(milliseconds: 1800),
    );
    if (shown) return;

    final messenger = _resolveMessenger(context);
    if (messenger != null) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
        ),
      );
      return;
    }

    if (kDebugMode) {
      debugPrint('ToastUtils: $text');
    }
  }

  static ScaffoldMessengerState? _resolveMessenger(BuildContext? context) {
    if (context != null && context.mounted) {
      final local = ScaffoldMessenger.maybeOf(context);
      if (local != null) {
        return local;
      }
    }
    final rootContext = AppNavigator.context;
    if (rootContext != null && rootContext.mounted) {
      return ScaffoldMessenger.maybeOf(rootContext);
    }
    return null;
  }

  static String normalizeMessage(String? message) {
    final raw = (message ?? '').trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    final upper = raw.toUpperCase();

    if (_shouldSilenceRawToast(lower, upper)) return '';

    if (upper == 'NICKNAME_EXISTS' ||
        upper.contains('NICKNAME_EXISTS') ||
        lower.contains('nickname already') ||
        lower.contains('username already') ||
        lower.contains('nickname exists') ||
        lower.contains('username exists')) {
      return '用户名已存在';
    }

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

    if (upper == 'FORBIDDEN' ||
        upper == 'PERMISSION_DENIED' ||
        lower.contains('forbidden') ||
        lower.contains('permission denied') ||
        lower.contains('http status error [403]')) {
      return '暂无权限操作';
    }

    if (upper == 'USER_NOT_FOUND' ||
        upper == 'USER_NOT_EXIST' ||
        lower.contains('user not found') ||
        lower.contains('user not exist') ||
        lower.contains('receiver not found') ||
        lower.contains('invalid receiver')) {
      return '用户不存在';
    }

    if (upper == 'INVALID_INPUT' ||
        upper == 'BAD_REQUEST' ||
        lower.contains('http status error [400]')) {
      return '输入内容有误，请检查后重试';
    }

    if (upper == 'RATE_LIMIT' ||
        upper == 'TOO_MANY_REQUESTS' ||
        lower.contains('too many requests') ||
        lower.contains('rate limit') ||
        lower.contains('http status error [429]')) {
      return '请求太频繁，请稍后再试';
    }

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return '网络超时，请稍后重试';
    }
    if (lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('connection') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('dioerrortype.connection') ||
        lower.contains('dioerrortype.other')) {
      return '网络异常，请检查网络';
    }
    if (lower.contains('http status error [500]') ||
        lower.contains('internal server error') ||
        upper == 'INTERNAL_SERVER_ERROR') {
      return '服务繁忙，请稍后再试';
    }

    if (lower.startsWith('dioerror') ||
        lower.contains('exception') ||
        lower.contains('stacktrace') ||
        lower.contains('null check operator') ||
        lower.contains('nosuchmethod') ||
        lower.contains('format exception') ||
        lower.contains('typeerror') ||
        lower.contains('type error')) {
      return '操作失败，请稍后重试';
    }

    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(raw);
    if (hasChinese && raw.length <= 40 && !raw.contains('code')) {
      return raw;
    }

    final looksLikeBackendCode = RegExp(r'^[A-Z0-9_\-\.]+$').hasMatch(raw);
    if (looksLikeBackendCode || !hasChinese) {
      return '操作失败，请稍后重试';
    }
    return raw;
  }

  static bool _shouldSilenceRawToast(String lower, String upper) {
    const silentCodes = [
      'SYNC_SESSION_NOT_FOUND',
      'CONTACT_SYNC_FAILED',
      'PRESENCE_SYNC_FAILED',
      'LAST_SEEN_SYNC_FAILED',
      'GROUP_PRIVACY_CHECK_FAILED',
      'MESSAGE_READ_SYNC_FAILED',
      'CONVERSATION_SYNC_FAILED',
    ];
    for (final code in silentCodes) {
      if (upper.contains(code)) return true;
    }
    const silentFragments = [
      '/me/sync/',
      'sync session not found',
      'device sync service',
      'backgroundsyncing',
      'presence/last-seen',
      'last-seen',
      'checkunreadmessagecountfromcache',
      'timpush-tokenrequester',
    ];
    for (final key in silentFragments) {
      if (lower.contains(key)) return true;
    }
    return false;
  }

  static void toastError(int code, String desc) {
    if (_shouldSuppressTransientImError(code, desc)) return;
    final msg = friendlyErrorMessage(code, desc);
    if (shouldSuppress(msg)) return;
    toast(msg);
  }

  static String friendlyErrorMessage(int code, String? desc) {
    final raw = (desc ?? '').trim();
    final normalized = raw.toLowerCase();

    if (_shouldSuppressTransientImError(code, raw)) {
      return '';
    }

    if (code == 0) return '操作成功';
    if (code == 401 || normalized.contains('auth')) {
      return '登录状态已过期，请重新登录';
    }
    if (code == 403) {
      return '暂无权限操作';
    }
    if (code == 6014 || normalized.contains('not login')) {
      return '登录状态异常，请重新登录';
    }
    if (code == 30539 || normalized.contains('friend') && normalized.contains('pending')) {
      return '好友申请已发送';
    }
    if (code == 30010 || normalized.contains('already') && normalized.contains('friend')) {
      return '你们已经是好友';
    }
    if (normalized.contains('message missing necessary download info') ||
        normalized.contains('missing necessary download info')) {
      return '';
    }
    if (normalized.contains('user not found') ||
        normalized.contains('user not exist') ||
        normalized.contains('receiver not found') ||
        normalized.contains('invalid receiver')) {
      return '用户不存在';
    }
    if (normalized.contains('not found') || normalized.contains('no such')) {
      if (normalized.contains('message') || normalized.contains('download')) {
        return '';
      }
      return '用户不存在';
    }
    if (normalized.contains('timeout') || normalized.contains('timed out')) {
      return '网络超时，请稍后重试';
    }
    if (normalized.contains('network') || normalized.contains('socket')) {
      return '网络异常，请稍后重试';
    }
    if (normalized.contains('permission') || normalized.contains('forbidden')) {
      return '暂无权限操作';
    }
    if (shouldSuppress(raw)) {
      return '';
    }

    final hasChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(raw);
    if (hasChinese && raw.length <= 40 && !raw.contains('code')) {
      return raw;
    }
    return '操作失败，请稍后重试';
  }

  static bool _shouldSuppressTransientImError(int code, String? desc) {
    final normalized = (desc ?? '').trim().toLowerCase();
    if (normalized.isEmpty && code != 6013 && code != 6014) {
      return false;
    }

    final looksLikeTransientImError = code == 6013 ||
        code == 6014 ||
        normalized.contains('6013') ||
        normalized.contains('6014') ||
        normalized.contains('sdk not initialized') ||
        normalized.contains('sdk uninitialized') ||
        normalized.contains('sdk is not initialized') ||
        normalized.contains('not initialized') ||
        normalized.contains('未初始化') ||
        normalized.contains('not login') ||
        normalized.contains('not logged in') ||
        normalized.contains('please login') ||
        normalized.contains('please log in') ||
        normalized.contains('未登录') ||
        normalized.contains('请先登录') ||
        normalized.contains('请重新登录') ||
        normalized.contains('请重新登陆') ||
        normalized.contains('relogin');
    if (!looksLikeTransientImError) {
      return false;
    }

    final transitional = AuthSessionService.instance.isInAuthFlow ||
        AuthBootstrapService.instance.backgroundSyncing.value ||
        !AuthBootstrapService.instance.isCoreServicesUserReady();
    if (transitional && kDebugMode) {
      debugPrint(
        'ToastUtils: suppress transient IM toast '
        'code=$code desc=$normalized '
        'authFlow=${AuthSessionService.instance.isInAuthFlow} '
        'syncing=${AuthBootstrapService.instance.backgroundSyncing.value} '
        'uikitReady=${AuthBootstrapService.instance.isCoreServicesUserReady()}',
      );
    }
    return transitional;
  }

  static void log(Object? data) {
    if (!kDebugMode) {
      return;
    }
    const bool prod =
        bool.fromEnvironment('ISPRODUCT_ENV', defaultValue: false);
    if (!prod) {
      // ignore: avoid_print
      print("===================================");
      // ignore: avoid_print
      print("IM_DEMO_PRINT:$data");
      // ignore: avoid_print
      print("===================================");
    } else {}
  }
}
