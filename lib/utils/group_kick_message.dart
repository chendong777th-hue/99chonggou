import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

class GroupKickMessage {
  GroupKickMessage._();

  static AppI18n get _i => AppI18n.current;

  static String success() {
    return _i.t(
      zhHans: '已移除群成员',
      zhHant: '已移除群成員',
      en: 'Group member removed',
      ja: 'メンバーを削除しました',
      ko: '그룹 멤버를 제거했습니다',
    );
  }

  static String partialSuccess() {
    return _i.t(
      zhHans: '部分成员已移除',
      zhHant: '部分成員已移除',
      en: 'Some members were removed',
      ja: '一部のメンバーを削除しました',
      ko: '일부 멤버가 제거되었습니다',
    );
  }

  static String failure({String? desc}) {
    final text = desc?.trim().toUpperCase() ?? '';
    if (text.contains('CANNOT_KICK_ADMIN')) {
      return _i.t(
        zhHans: '无法移除管理员',
        zhHant: '無法移除管理員',
        en: 'Cannot remove an admin',
        ja: '管理者は削除できません',
        ko: '관리자는 제거할 수 없습니다',
      );
    }
    if (text.contains('NOT_GROUP_ADMIN') ||
        text.contains('NOT_GROUP_OWNER') ||
        text.contains('PERMISSION')) {
      return _i.t(
        zhHans: '您没有移除成员的权限',
        zhHant: '您沒有移除成員的權限',
        en: 'You do not have permission to remove members',
        ja: 'メンバーを削除する権限がありません',
        ko: '멤버를 제거할 권한이 없습니다',
      );
    }
    if (text.contains('NOT_GROUP_MEMBER')) {
      return _i.t(
        zhHans: '对方不是群成员',
        zhHant: '對方不是群成員',
        en: 'User is not a group member',
        ja: 'このユーザーはグループメンバーではありません',
        ko: '해당 사용자는 그룹 멤버가 아닙니다',
      );
    }
    final fallback = desc?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return _i.t(
      zhHans: '移除群成员失败，请稍后重试',
      zhHant: '移除群成員失敗，請稍後重試',
      en: 'Failed to remove group member. Please try again later.',
      ja: 'メンバーの削除に失敗しました。しばらくしてから再試行してください',
      ko: '그룹 멤버 제거에 실패했습니다. 잠시 후 다시 시도해 주세요',
    );
  }
}
