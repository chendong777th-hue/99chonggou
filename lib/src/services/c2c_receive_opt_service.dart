import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/contracts/account_scoped_conversation_key.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

/// C2C 免打扰单一写入者。
///
/// ADR 边界（docs/im09_adr_boundaries.md §3.3 / §10.1）：
/// - 腾讯 SDK `setC2CReceiveMessageOpt` 是 c2c 免打扰的实时权威。
/// - 写路径必须经过 SessionIdentityService generation fence + owner 比对。
/// - 晚到回执必须被拒绝（传入的 [capturedIdentity] 已经过期）。
/// - 四个原直调点（IM-09 phase 2 已收敛）：
///   - lib/src/conversation.dart:3327 `_toggleConversationDisturb`
///   - lib/src/conversation.dart:5898 `_toggleArchivedConversationDisturb`
///   - lib/src/pages/c2c_chat_settings_page.dart:331 `_setMuted`
///   - lib/src/services/platform_official_account_service.dart:635 `_ensureNormalReceiveOpt`
///   改走本类后，禁止任何直接调 MessageService / TencentImSDKPlugin
///   的 `setC2CReceiveMessageOpt` 入口（IM-11 静态门禁守住）。
///
/// **调用约定**：调用方在异步链入口处必须 [SessionIdentityService.capture]
/// 并通过 [capturedIdentity] 传入；服务内部不会重新捕获。这样 fence 才能
/// 跨异步间隙生效，防止切账号后旧账号的 SDK 写回被误投递。
class C2cReceiveOptService {
  C2cReceiveOptService._();

  static final C2cReceiveOptService instance = C2cReceiveOptService._();

  /// Fence 校验纯函数：generation 必须仍是当前；当前 owner 非空时必须一致。
  ///
  /// 测试或首次启动时 owner 可能为空，仅靠 generation fence；这是有意为之：
  /// 真实运行时 owner 总会有值，generation 单调递增，stale fence 必被拒。
  @visibleForTesting
  static bool fenceValid({
    required SessionIdentity captured,
    required String? currentOwnerUserId,
  }) {
    if (!SessionIdentityService.instance
        .isGenerationCurrent(captured.generation)) {
      return false;
    }
    final owner = (currentOwnerUserId ?? '').trim();
    if (owner.isEmpty || captured.ownerUserId.isEmpty) {
      return true;
    }
    return captured.ownerUserId == owner;
  }

  /// 解析测试运行时 owner（解耦便于单测）。
  @visibleForTesting
  static String resolveCurrentOwnerForTest() =>
      ApiClient.instance.authenticatedUserId.trim();

  /// 设置单个 c2c peer 的免打扰（UIKit MessageService 入口）。
  ///
  /// - [key] 必须是 c2c 类型的 [AccountScopedConversationKey]，peer 由 key 提取。
  /// - [capturedIdentity] 必须是异步链入口处捕获的 SessionIdentity；
  ///   若 generation 已推进或 owner 已切换，返回 code=-1 的失败回调。
  /// - 不改变 SDK 语义；只做 fence + 参数校验。
  static Future<V2TimCallback> setOpt({
    required MessageService messageService,
    required AccountScopedConversationKey key,
    required ReceiveMsgOptEnum opt,
    required SessionIdentity capturedIdentity,
  }) async {
    if (key.conversationType != ImConversationType.c2c) {
      debugPrint(
        'C2cReceiveOptService.setOpt: key must be c2c, got ${key.conversationType}',
      );
      return V2TimCallback(code: -1, desc: 'key_must_be_c2c');
    }
    final peer = _extractC2cPeer(key);
    if (peer.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty_peer_user_id');
    }
    if (capturedIdentity.ownerUserId.isNotEmpty &&
        key.ownerUserId != capturedIdentity.ownerUserId) {
      debugPrint(
        'C2cReceiveOptService.setOpt: owner mismatch '
        'key.owner=${key.ownerUserId} captured.owner=${capturedIdentity.ownerUserId}',
      );
      return V2TimCallback(code: -1, desc: 'owner_mismatch');
    }
    if (!fenceValid(
      captured: capturedIdentity,
      currentOwnerUserId: resolveCurrentOwnerForTest(),
    )) {
      debugPrint(
        'C2cReceiveOptService.setOpt: stale fence rejected '
        '(owner=${capturedIdentity.ownerUserId} gen=${capturedIdentity.generation})',
      );
      return V2TimCallback(code: -1, desc: 'stale_identity');
    }
    return await messageService.setC2CReceiveMessageOpt(
      userIDList: [peer],
      opt: opt,
    );
  }

  /// 批量设置多个 c2c peer 的免打扰（同一 opt，UIKit MessageService 入口）。
  ///
  /// - 任何一个 peer id 为空都直接失败（不会部分提交）。
  /// - owner 必须与 capturedIdentity.ownerUserId 一致；fence 一次，整批生效。
  /// - 不引入第二个 SDK 入口。
  static Future<V2TimCallback> setOptForBatch({
    required MessageService messageService,
    required String ownerUserId,
    required List<String> peerUserIds,
    required ReceiveMsgOptEnum opt,
    required SessionIdentity capturedIdentity,
  }) async {
    if (peerUserIds.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty_peer_user_ids');
    }
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty_owner_user_id');
    }
    if (capturedIdentity.ownerUserId.isNotEmpty &&
        owner != capturedIdentity.ownerUserId) {
      debugPrint(
        'C2cReceiveOptService.setOptForBatch: owner mismatch '
        'arg.owner=$owner captured.owner=${capturedIdentity.ownerUserId}',
      );
      return V2TimCallback(code: -1, desc: 'owner_mismatch');
    }
    final cleaned = <String>[];
    for (final raw in peerUserIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty) {
        return V2TimCallback(
          code: -1,
          desc: 'empty_peer_user_id_in_batch',
        );
      }
      cleaned.add(id);
    }
    if (!fenceValid(
      captured: capturedIdentity,
      currentOwnerUserId: resolveCurrentOwnerForTest(),
    )) {
      debugPrint(
        'C2cReceiveOptService.setOptForBatch: stale fence rejected (batch)',
      );
      return V2TimCallback(code: -1, desc: 'stale_identity');
    }
    return await messageService.setC2CReceiveMessageOpt(
      userIDList: cleaned,
      opt: opt,
    );
  }

  /// SDK 原生路径：直接调用 TencentImSDKPlugin（不经过 MessageService 抽象）。
  ///
  /// 用于 platform_official_account_service 等已经拿到 identity 上下文、不希望
  /// 走 UIKit 抽象的场景。Fence 与 setOpt 完全一致。
  static Future<V2TimCallback> setOptViaSdk({
    required AccountScopedConversationKey key,
    required ReceiveMsgOptEnum opt,
    required SessionIdentity capturedIdentity,
  }) async {
    if (key.conversationType != ImConversationType.c2c) {
      return V2TimCallback(code: -1, desc: 'key_must_be_c2c');
    }
    final peer = _extractC2cPeer(key);
    if (peer.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty_peer_user_id');
    }
    if (capturedIdentity.ownerUserId.isNotEmpty &&
        key.ownerUserId != capturedIdentity.ownerUserId) {
      return V2TimCallback(code: -1, desc: 'owner_mismatch');
    }
    if (!fenceValid(
      captured: capturedIdentity,
      currentOwnerUserId: resolveCurrentOwnerForTest(),
    )) {
      return V2TimCallback(code: -1, desc: 'stale_identity');
    }
    return await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .setC2CReceiveMessageOpt(
          userIDList: [peer],
          opt: opt,
        );
  }

  /// SDK 原生批量路径（platform_official_account_service 的 _ensureNormalReceiveOpt 使用）。
  static Future<V2TimCallback> setOptForBatchViaSdk({
    required String ownerUserId,
    required List<String> peerUserIds,
    required ReceiveMsgOptEnum opt,
    required SessionIdentity capturedIdentity,
  }) async {
    if (peerUserIds.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty_peer_user_ids');
    }
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty_owner_user_id');
    }
    if (capturedIdentity.ownerUserId.isNotEmpty &&
        owner != capturedIdentity.ownerUserId) {
      return V2TimCallback(code: -1, desc: 'owner_mismatch');
    }
    final cleaned = <String>[];
    for (final raw in peerUserIds) {
      final id = ChatIdFormat.rawUserUid(raw);
      if (id.isEmpty) {
        return V2TimCallback(
          code: -1,
          desc: 'empty_peer_user_id_in_batch',
        );
      }
      cleaned.add(id);
    }
    if (!fenceValid(
      captured: capturedIdentity,
      currentOwnerUserId: resolveCurrentOwnerForTest(),
    )) {
      return V2TimCallback(code: -1, desc: 'stale_identity');
    }
    return await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .setC2CReceiveMessageOpt(
          userIDList: cleaned,
          opt: opt,
        );
  }

  static String _extractC2cPeer(AccountScopedConversationKey key) {
    final canonical = key.canonicalConversationId;
    const prefix = 'c2c_';
    if (!canonical.startsWith(prefix)) {
      return '';
    }
    return canonical.substring(prefix.length).trim();
  }
}
