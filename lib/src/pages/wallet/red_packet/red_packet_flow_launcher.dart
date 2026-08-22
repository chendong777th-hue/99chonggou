import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/full_screen_back_route.dart';

import 'red_packet_detail_pop_result.dart';
import 'red_packet_flow_detail_page.dart';
import 'red_packet_open_flow_page.dart';

/// 聊天红包点击后的统一入口：开包动画 + 详情页。
/// 账单记录等场景使用 [buildOverlayPage] 并设 `showOpenAnimation: false`。
class RedPacketFlowLauncher {
  RedPacketFlowLauncher._();

  static Widget _detailPage({
    required String orderId,
    required String packetType,
    required String senderName,
    required String senderAvatar,
    required String greeting,
    required bool autoClaim,
    Map<String, dynamic> seedPacket = const {},
  }) {
    return RedPacketProjectDetailPage(
      orderId: orderId,
      packetType: packetType,
      senderName: senderName,
      senderAvatar: senderAvatar,
      greeting: greeting,
      autoClaim: autoClaim,
      seedPacket: seedPacket,
    );
  }

  static RedPacketOpenPreviewData _openData({
    required String orderId,
    required String packetType,
    required String senderName,
    required String senderAvatar,
    required String greeting,
    required bool autoClaim,
    required bool closeWhenResultPopped,
    Map<String, dynamic> seedPacket = const {},
  }) {
    return RedPacketOpenPreviewData(
      orderId: orderId,
      packetType: packetType,
      senderName: senderName,
      senderAvatar: senderAvatar,
      greeting: greeting,
      autoClaim: autoClaim,
      closeWhenResultPopped: closeWhenResultPopped,
      resultBuilder: (context) => _detailPage(
        orderId: orderId,
        packetType: packetType,
        senderName: senderName,
        senderAvatar: senderAvatar,
        greeting: greeting,
        autoClaim: autoClaim,
        seedPacket: seedPacket,
      ),
    );
  }

  /// 供聊天 overlay 使用：返回应作为路由根的 Widget。
  static Widget buildOverlayPage({
    required String orderId,
    required String packetType,
    required String senderName,
    required String senderAvatar,
    required String greeting,
    bool autoClaim = true,
    bool showOpenAnimation = true,
    Map<String, dynamic> seedPacket = const {},
  }) {
    if (!showOpenAnimation) {
      return _detailPage(
        orderId: orderId,
        packetType: packetType,
        senderName: senderName,
        senderAvatar: senderAvatar,
        greeting: greeting,
        autoClaim: autoClaim,
        seedPacket: seedPacket,
      );
    }
    return RedPacketPreviewPage(
      data: _openData(
        orderId: orderId,
        packetType: packetType,
        senderName: senderName,
        senderAvatar: senderAvatar,
        greeting: greeting,
        autoClaim: autoClaim,
        closeWhenResultPopped: true,
        seedPacket: seedPacket,
      ),
    );
  }

  /// [showOpenAnimation] 为 true 时先展示开包动画，否则直接进入详情。
  static Future<RedPacketDetailPopResult?> open(
    BuildContext context, {
    required String orderId,
    required String packetType,
    required String senderName,
    required String senderAvatar,
    required String greeting,
    bool autoClaim = true,
    bool showOpenAnimation = true,
    Map<String, dynamic> seedPacket = const {},
  }) {
    if (!showOpenAnimation) {
      return Navigator.of(context).push<RedPacketDetailPopResult>(
        FullScreenBackPageRoute<RedPacketDetailPopResult>(
          settings: const RouteSettings(name: 'red_packet_flow_detail'),
          builder: (_) => _detailPage(
            orderId: orderId,
            packetType: packetType,
            senderName: senderName,
            senderAvatar: senderAvatar,
            greeting: greeting,
            autoClaim: autoClaim,
            seedPacket: seedPacket,
          ),
        ),
      );
    }

    return Navigator.of(context).push<RedPacketDetailPopResult>(
      FullScreenBackPageRoute<RedPacketDetailPopResult>(
        settings: const RouteSettings(name: 'red_packet_open_flow'),
        builder: (_) => RedPacketPreviewPage(
          data: _openData(
            orderId: orderId,
            packetType: packetType,
            senderName: senderName,
            senderAvatar: senderAvatar,
            greeting: greeting,
            autoClaim: autoClaim,
            closeWhenResultPopped: true,
            seedPacket: seedPacket,
          ),
        ),
      ),
    );
  }
}
