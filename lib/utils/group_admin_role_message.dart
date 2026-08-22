import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/constants/group_governance_limits.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

class GroupAdminRoleMessage {
  GroupAdminRoleMessage._();

  static AppI18n get _i => AppI18n.current;

  static String grantSuccess() {
    return _i.t(
      zhHans: '设置管理员成功',
      zhHant: '設置管理員成功',
      en: 'Admin assigned',
      ja: '管理者を設定しました',
      ko: '관리자로 지정했습니다',
    );
  }

  static String revokeSuccess() {
    return _i.t(
      zhHans: '已取消管理员身份',
      zhHant: '已取消管理員身份',
      en: 'Admin role removed',
      ja: '管理者権限を解除しました',
      ko: '관리자 권한을 해제했습니다',
    );
  }

  static String adminLimitReached() {
    final max = GroupGovernanceLimits.maxAdminCount;
    return _i.t(
      zhHans: '管理员人数已达上限（最多$max人）',
      zhHant: '管理員人數已達上限（最多$max人）',
      en: 'Admin limit reached (max $max)',
      ja: '管理者の上限に達しました（最大$max人）',
      ko: '관리자 수가 한도에 도달했습니다(최대 $max명)',
    );
  }

  static String failure({String? desc, DioError? error}) {
    if (error != null) {
      return failureFromDio(error);
    }
    final text = desc?.trim().toUpperCase() ?? '';
    return _mapCode(text, fallback: desc?.trim());
  }

  static String failureFromDio(DioError error) {
    final data = error.response?.data;
    var code = '';
    var message = '';
    if (data is Map) {
      code = (data['code'] ?? data['errorCode'] ?? data['errCode'])
              ?.toString()
              .trim()
              .toUpperCase() ??
          '';
      message = (data['message'] ?? data['msg'] ?? data['error'] ?? data['desc'])
              ?.toString()
              .trim() ??
          '';
    }
    if (code.isEmpty) {
      code = MeGroupApi.readDioCode(error).trim().toUpperCase();
    }
    return _mapCode(
      code.isNotEmpty ? code : message.toUpperCase(),
      fallback: message.isNotEmpty ? message : MeGroupApi.readDioCode(error),
    );
  }

  /// 将 TIM / Bridge 回传的英文错误码转为可读文案。
  static String normalizeFeedback(String message) {
    final text = message.trim();
    if (text.isEmpty) {
      return text;
    }
    final upper = text.toUpperCase();
    if (RegExp(r'[\u4e00-\u9fa5]').hasMatch(text) &&
        !upper.contains('INVALID_') &&
        !upper.contains('REQUEST_FAILED') &&
        !upper.contains('NOT_GROUP')) {
      return text;
    }
    return _mapCode(upper, fallback: text);
  }

  static String _mapCode(String upper, {String? fallback}) {
    if (upper.contains('NOT_GROUP_OWNER')) {
      return _i.t(
        zhHans: '仅群主可设置或取消管理员',
        zhHant: '僅群主可設置或取消管理員',
        en: 'Only the group owner can manage admins',
        ja: '管理者の設定はグループオーナーのみ可能です',
        ko: '그룹장만 관리자를 지정하거나 해제할 수 있습니다',
      );
    }
    if (upper.contains('CANNOT_CHANGE_OWNER_ROLE')) {
      return _i.t(
        zhHans: '不能通过此操作修改群主身份',
        zhHant: '不能透過此操作修改群主身份',
        en: 'Cannot change the owner role this way',
        ja: 'この操作ではオーナー権限を変更できません',
        ko: '이 방식으로는 그룹장 권한을 변경할 수 없습니다',
      );
    }
    if (upper.contains('NOT_GROUP_ADMIN') ||
        upper.contains('NOT_GROUP_OWNER_OR_ADMIN') ||
        upper.contains('PERMISSION_DENIED') ||
        upper.contains('FORBIDDEN')) {
      return _i.t(
        zhHans: '您没有权限执行此操作',
        zhHant: '您沒有權限執行此操作',
        en: 'You do not have permission for this action',
        ja: 'この操作を行う権限がありません',
        ko: '이 작업을 수행할 권한이 없습니다',
      );
    }
    if (upper.contains('NOT_GROUP_MEMBER')) {
      return _i.t(
        zhHans: '对方不是群成员',
        zhHant: '對方不是群成員',
        en: 'User is not a group member',
        ja: 'このユーザーはグループメンバーではありません',
        ko: '해당 사용자는 그룹 멤버가 아닙니다',
      );
    }
    if (upper.contains('ADMIN_LIMIT') ||
        upper.contains('MAX_ADMIN') ||
        upper.contains('TOO_MANY_ADMIN')) {
      return adminLimitReached();
    }
    if (upper.contains('BATCH_TOO_LARGE')) {
      return _i.t(
        zhHans: '单次操作人数过多，请分批设置',
        zhHant: '單次操作人數過多，請分批設置',
        en: 'Too many users in one request. Please try in smaller batches.',
        ja: '一度に設定できる人数を超えています。分割して再試行してください',
        ko: '한 번에 처리할 수 있는 인원을 초과했습니다. 나눠서 다시 시도해 주세요',
      );
    }
    if (upper.contains('GROUP_NOT_FOUND')) {
      return _i.t(
        zhHans: '群不存在或已解散',
        zhHant: '群不存在或已解散',
        en: 'Group not found or already dismissed',
        ja: 'グループが存在しないか、解散済みです',
        ko: '그룹이 없거나 이미 해산되었습니다',
      );
    }
    if (upper.contains('INVALID_INPUT') ||
        upper.contains('INVALID_RESPONSE') ||
        upper.contains('BAD_REQUEST')) {
      return _i.t(
        zhHans: '设置管理员失败，请稍后重试',
        zhHant: '設置管理員失敗，請稍後重試',
        en: 'Failed to assign admin. Please try again later.',
        ja: '管理者の設定に失敗しました。しばらくしてから再試行してください',
        ko: '관리자 지정에 실패했습니다. 잠시 후 다시 시도해 주세요',
      );
    }
    final fb = fallback?.trim() ?? '';
    if (fb.isNotEmpty && RegExp(r'[\u4e00-\u9fa5]').hasMatch(fb)) {
      return fb;
    }
    return _i.t(
      zhHans: '设置管理员失败，请稍后重试',
      zhHant: '設置管理員失敗，請稍後重試',
      en: 'Failed to assign admin. Please try again later.',
      ja: '管理者の設定に失敗しました。しばらくしてから再試行してください',
      ko: '관리자 지정에 실패했습니다. 잠시 후 다시 시도해 주세요',
    );
  }
}
