import 'dart:async';
import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// IM 自定义消息：生活缴费订单状态更新（文档 §7）。
const String kLifePaymentOrderUpdateBusinessID = 'life_payment_order_update';

class LifePaymentOrderUpdateEvent {
  const LifePaymentOrderUpdateEvent({
    required this.orderNo,
    required this.orderStatus,
    required this.pluginStatus,
    required this.serviceType,
    required this.amount,
    required this.message,
    required this.updatedAt,
  });

  final String orderNo;
  final String orderStatus;
  final String pluginStatus;
  final String serviceType;
  final String amount;
  final String message;
  final String updatedAt;
}

class LifePaymentOrderUpdateBus {
  LifePaymentOrderUpdateBus._();

  static final LifePaymentOrderUpdateBus instance =
      LifePaymentOrderUpdateBus._();

  final StreamController<LifePaymentOrderUpdateEvent> _controller =
      StreamController<LifePaymentOrderUpdateEvent>.broadcast();

  Stream<LifePaymentOrderUpdateEvent> get stream => _controller.stream;

  void emit(LifePaymentOrderUpdateEvent event) {
    if (event.orderNo.isEmpty) return;
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// 从 TIM 自定义消息 payload 识别并广播；非本业务则忽略。
  void ingestMessage(V2TimMessage message) {
    final raw = message.customElem?.data;
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final businessID = data['businessID']?.toString() ?? '';
      final customType = data['customType']?.toString() ?? '';
      if (businessID != kLifePaymentOrderUpdateBusinessID &&
          customType != kLifePaymentOrderUpdateBusinessID) {
        return;
      }
      emit(
        LifePaymentOrderUpdateEvent(
          orderNo: data['order_no']?.toString() ??
              data['orderNo']?.toString() ??
              '',
          orderStatus: data['order_status']?.toString() ??
              data['orderStatus']?.toString() ??
              '',
          pluginStatus: data['plugin_status']?.toString() ??
              data['pluginStatus']?.toString() ??
              '',
          serviceType: data['service_type']?.toString() ??
              data['serviceType']?.toString() ??
              '',
          amount: data['amount']?.toString() ?? '',
          message: data['message']?.toString() ?? '',
          updatedAt: data['updated_at']?.toString() ??
              data['updatedAt']?.toString() ??
              '',
        ),
      );
    } catch (_) {
      // 非 JSON / 非本业务，忽略
    }
  }
}
