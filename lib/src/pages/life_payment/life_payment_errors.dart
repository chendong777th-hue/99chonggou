import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';

/// 生活缴费业务错误码 → 用户文案（文档 v1.0 §5）。
class LifePaymentErrors {
  LifePaymentErrors._();

  static String? codeOf(Object error) {
    if (error is! DioError) return null;
    final data = error.response?.data;
    if (data is! Map) return null;
    for (final key in const ['code', 'errorCode', 'errCode']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }

  static String? messageOf(Object error) {
    if (error is! DioError) return null;
    final data = error.response?.data;
    if (data is! Map) return null;
    for (final key in const ['message', 'msg', 'error']) {
      final value = data[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// 是否禁止对「同户号活跃任务」自动重试创建。
  static bool isAccountTaskAlreadyActive(Object error) {
    final code = codeOf(error)?.toLowerCase() ?? '';
    return code == 'account_task_already_active';
  }

  /// 优先业务码映射，其次后端 message，最后通用 Dio 文案。
  static String userMessage(Object error, {String fallbackAction = '操作'}) {
    final code = codeOf(error);
    final mapped = _mapCode(code, serverMessage: messageOf(error));
    if (mapped != null) return mapped;
    final server = messageOf(error);
    if (server != null && server.isNotEmpty) return server;
    final generic = DioErrorMessage.forApp(error);
    if (generic.trim().isNotEmpty) return generic;
    return '$fallbackAction失败，请稍后重试';
  }

  static String? _mapCode(String? code, {String? serverMessage}) {
    if (code == null || code.isEmpty) return null;
    switch (code) {
      case 'account_task_already_active':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '该户号已有进行中的查询或缴费任务，请等待结束后再试';
      case 'service_disabled':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '服务维护中，请稍后再试';
      case 'owner_last_char_required':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '首次充值需要填写机主姓名最后一个字';
      case 'insufficient_platform_balance':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '平台余额不足，请先充值或兑换后再缴费';
      case 'pay_password_error':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '支付密码错误';
      case 'PAY_PIN_NOT_SET':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '请先设置支付密码';
      case 'PAY_PIN_LOCKED':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '支付密码已锁定，请稍后再试或前往解锁';
      case 'invalid_amount':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '金额不支持，请选择可用面额';
      case 'invalid_phone':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '手机号格式错误';
      case 'UNAUTHORIZED':
        return '请先登录';
      case 'order_cannot_cancel':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '当前订单状态不可取消';
      case 'order_not_found':
        return serverMessage?.isNotEmpty == true
            ? serverMessage!
            : '订单不存在';
      default:
        return null;
    }
  }
}
