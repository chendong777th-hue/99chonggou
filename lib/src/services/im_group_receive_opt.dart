import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

/// 国内腾讯云 IM 社群免打扰：先纠偏真实群 ID，再按候选依次尝试。
///
/// 会话里常见错误加成 `@TGS#_@TGS#m2…`（10010）；本地资料真源多为 `@TGS#_mc…`。
class ImGroupReceiveOpt {
  ImGroupReceiveOpt._();

  /// 纯函数：把本地纠偏真源与形态候选合并排序（便于单测）。
  @visibleForTesting
  static List<String> orderCandidates({
    required String raw,
    required String resolved,
    List<String>? morphCandidates,
  }) {
    final ordered = <String>[];
    void add(String? value) {
      final text = value?.trim() ?? '';
      if (text.isEmpty || ordered.contains(text)) {
        return;
      }
      ordered.add(text);
    }

    final input = raw.trim();
    if (input.isEmpty) {
      return ordered;
    }

    final resolvedId = resolved.trim();
    if (resolvedId.isNotEmpty) {
      add(resolvedId);
    }

    final morph = morphCandidates ?? ChatIdFormat.imGroupIdCandidates(input);
    // 真源为短码 / @TGS#_mc… 时，把误加成 `@TGS#_@TGS#…` 放到最后。
    String? demotedBadExpand;
    final inputShort = ChatIdFormat.apiGroupId(input);
    if (inputShort.isNotEmpty &&
        ChatIdFormat.isCommunityShortToken(inputShort) &&
        !ChatIdFormat.isCustomCommunityToken(inputShort)) {
      demotedBadExpand = '${ChatIdFormat.communityFullPrefix}$inputShort';
    }

    for (final id in morph) {
      if (demotedBadExpand != null && id == demotedBadExpand) {
        continue;
      }
      add(id);
    }
    if (demotedBadExpand != null) {
      add(demotedBadExpand);
    }
    return ordered;
  }

  /// 构造 IM 候选：本地 [GroupLocalStore.resolveImGroupId] 真源优先，再回退形态候选。
  static Future<List<String>> resolveCandidates(String? groupID) async {
    final raw = groupID?.trim() ?? '';
    if (raw.isEmpty) {
      return const <String>[];
    }

    var resolved = '';
    try {
      resolved = await GroupLocalStore.instance.resolveImGroupId(raw);
    } catch (e) {
      debugPrint('ImGroupReceiveOpt: resolveImGroupId err=$e');
    }
    return orderCandidates(raw: raw, resolved: resolved);
  }

  static Future<V2TimCallback> setGroupReceiveMessageOpt({
    required MessageService messageService,
    required String groupID,
    required ReceiveMsgOptEnum opt,
  }) async {
    final candidates = await resolveCandidates(groupID);
    if (candidates.isEmpty) {
      return V2TimCallback(code: -1, desc: 'empty groupID');
    }
    V2TimCallback? last;
    for (final id in candidates) {
      last = await messageService.setGroupReceiveMessageOpt(
        groupID: id,
        opt: opt,
      );
      if (last.code == 0) {
        debugPrint('ImGroupReceiveOpt: ok id=$id');
        return last;
      }
      debugPrint(
        'ImGroupReceiveOpt: fail id=$id code=${last.code} desc=${last.desc}',
      );
    }
    return last!;
  }
}
