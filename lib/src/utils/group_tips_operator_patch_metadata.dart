import 'dart:convert';

/// IM GroupTips 上由 TCP / change-events 写入的操作者补丁元数据。
class GroupTipsOperatorPatchMetadata {
  GroupTipsOperatorPatchMetadata._();

  static const patchFlag = 'groupTipsOperatorPatch';
  static const suppressFlag = 'suppressAdministratorGroupTip';

  static Map<String, dynamic>? readMap(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static bool isOperatorPatch(Map<String, dynamic> data) {
    return data[patchFlag] == true;
  }

  static bool isSuppressed(Map<String, dynamic> data) {
    return data[suppressFlag] == true;
  }

  static String? previewAbstract(Map<String, dynamic> data) {
    final preview = data['previewAbstract']?.toString().trim() ?? '';
    return preview.isEmpty ? null : preview;
  }

  static String? resolvedOperatorUserId(Map<String, dynamic> data) {
    final operator = data['resolvedOperatorUserId']?.toString().trim() ?? '';
    return operator.isEmpty ? null : operator;
  }

  static String? changeEventId(Map<String, dynamic> data) {
    final id = data['changeEventId']?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  static String mergePatch({
    required String? existingRaw,
    required String changeEventId,
    required String resolvedOperatorUserId,
    required String previewAbstract,
    required String action,
    int? timelineRank,
  }) {
    final data = readMap(existingRaw) ?? <String, dynamic>{};
    data[patchFlag] = true;
    data['changeEventId'] = changeEventId;
    data['resolvedOperatorUserId'] = resolvedOperatorUserId;
    data['previewAbstract'] = previewAbstract;
    data['action'] = action;
    if (timelineRank != null) {
      data['timelineRank'] = timelineRank;
    }
    return jsonEncode(data);
  }

  static String mergeSuppressFlag({required String? existingRaw}) {
    final data = readMap(existingRaw) ?? <String, dynamic>{};
    data[suppressFlag] = true;
    return jsonEncode(data);
  }
}
