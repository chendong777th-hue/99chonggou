import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

class GroupInviteMessage {
  GroupInviteMessage._();

  static AppI18n get _i => AppI18n.current;

  static String fromResult({required int code, String? desc}) {
    final text = '${desc ?? ''} $code'.trim().toUpperCase();
    // 用户加入群数超限：必须先于泛化 LIMIT→「群成员已达上限」。
    if (text.contains('GROUP_JOIN_LIMIT_COMMUNITY')) {
      return _i.t(
        zhHans: '您加入的超级大群数量已达上限',
        zhHant: '您加入的超級大群數量已達上限',
        en: 'You have reached the super group join limit',
        ja: 'スーパーグループの参加上限に達しました',
        ko: '슈퍼 그룹 참가 한도에 도달했습니다',
      );
    }
    if (text.contains('GROUP_JOIN_LIMIT_EXCEEDED') ||
        text.contains('GROUP_JOIN_LIMIT')) {
      return _i.t(
        zhHans: '您加入的普通群数量已达上限',
        zhHant: '您加入的普通群數量已達上限',
        en: 'You have reached the standard group join limit',
        ja: '通常グループの参加上限に達しました',
        ko: '일반 그룹 참가 한도에 도달했습니다',
      );
    }
    if (text.contains('GROUP_CREATE_LIMIT_COMMUNITY') ||
        text.contains('CREATE_LIMIT_EXCEEDED')) {
      return _i.t(
        zhHans: '每位用户超级大群创建数量已达上限',
        zhHant: '每位用戶超級大群建立數量已達上限',
        en: 'You have reached your super group creation limit',
        ja: 'スーパーグループの作成上限に達しました',
        ko: '슈퍼 그룹 생성 한도에 도달했습니다',
      );
    }
    if (text.contains('PENDING_APPROVAL') || text.contains('APPLICATION_PENDING')) {
      return _i.t(
        zhHans: '已提交，等待管理员审批',
        zhHant: '已提交，等待管理員審批',
        en: 'Submitted and pending admin approval',
        ja: '送信済み。管理者の承認待ちです',
        ko: '제출되었습니다. 관리자 승인 대기 중',
      );
    }
    if (text.contains('ALREADY_MEMBER_PARTIAL')) {
      return partialAlreadyMember();
    }
    if (text.contains('ALREADY_MEMBER') &&
        !text.contains('ALREADY_GROUP_MEMBER')) {
      return alreadyMember();
    }
    if (text.contains('NOT_FRIEND')) {
      return _i.t(
        zhHans: '对方不是您的好友，无法邀请入群',
        zhHant: '對方不是您的好友，無法邀請入群',
        en: 'Cannot invite: not friends',
        ja: '友達ではないため招待できません',
        ko: '친구가 아니어서 초대할 수 없습니다',
      );
    }
    if (text.contains('INVITE_DISABLED')) {
      return _i.t(
        zhHans: '当前群已禁止成员邀请好友',
        zhHant: '目前群組已禁止成員邀請好友',
        en: 'Member invites are disabled for this group',
        ja: 'このグループではメンバー招待が無効です',
        ko: '이 그룹에서는 멤버 초대가 비활성화되어 있습니다',
      );
    }
    if (text.contains('USER_NOT_FOUND')) {
      return _i.t(
        zhHans: '用户不存在',
        zhHant: '使用者不存在',
        en: 'User not found',
        ja: 'ユーザーが見つかりません',
        ko: '사용자를 찾을 수 없습니다',
      );
    }
    if (text.contains('NOT_GROUP_MEMBER') ||
        text.contains('NOT_GROUP_OWNER') ||
        text.contains('PERMISSION')) {
      return _i.t(
        zhHans: '您没有邀请成员的权限',
        zhHant: '您沒有邀請成員的權限',
        en: 'You do not have permission to invite members',
        ja: 'メンバーを招待する権限がありません',
        ko: '멤버를 초대할 권한이 없습니다',
      );
    }
    if (text.contains('OVERLIMIT') || text.contains('LIMIT')) {
      return _i.t(
        zhHans: '群成员已达上限',
        zhHant: '群成員已達上限',
        en: 'Group member limit reached',
        ja: 'グループメンバー上限に達しました',
        ko: '그룹 멤버 한도에 도달했습니다',
      );
    }
    if (text.contains('PARTIAL_SUCCESS')) {
      return _i.t(
        zhHans: '部分成员添加失败或需审批',
        zhHant: '部分成員新增失敗或需審批',
        en: 'Some members could not be added or need approval',
        ja: '一部のメンバーは追加できないか、承認が必要です',
        ko: '일부 멤버는 추가되지 않았거나 승인이 필요합니다',
      );
    }
    if (text.contains('GROUP_INVITE_NOT_SUPPORTED')) {
      return _i.t(
        zhHans: '当前群类型不支持邀请成员',
        zhHant: '目前群組類型不支援邀請成員',
        en: 'Inviting members is not supported for this group type',
        ja: 'このグループタイプではメンバー招待に対応していません',
        ko: '이 그룹 유형에서는 멤버 초대를 지원하지 않습니다',
      );
    }
    if (text.contains('INVALID_INPUT') ||
        text.contains('INVALID_RESPONSE') ||
        text.contains('REQUEST_FAILED') ||
        text.contains('INVITE_FAILED')) {
      return _i.t(
        zhHans: '添加群成员失败，请稍后重试',
        zhHant: '新增群成員失敗，請稍後重試',
        en: 'Failed to add group members. Please try again later.',
        ja: 'メンバーの追加に失敗しました。しばらくしてから再試行してください',
        ko: '그룹 멤버 추가에 실패했습니다. 잠시 후 다시 시도해 주세요',
      );
    }
    final fallback = desc?.trim();
    if (fallback != null &&
        fallback.isNotEmpty &&
        RegExp(r'[\u4e00-\u9fa5]').hasMatch(fallback)) {
      return fallback;
    }
    return _i.t(
      zhHans: '添加群成员失败，请稍后重试',
      zhHant: '新增群成員失敗，請稍後重試',
      en: 'Failed to add group members. Please try again later.',
      ja: 'メンバーの追加に失敗しました。しばらくしてから再試行してください',
      ko: '그룹 멤버 추가에 실패했습니다. 잠시 후 다시 시도해 주세요',
    );
  }

  static String success() {
    return _i.t(
      zhHans: '已添加群成员',
      zhHant: '已新增群成員',
      en: 'Group members added',
      ja: 'メンバーを追加しました',
      ko: '그룹 멤버를 추가했습니다',
    );
  }

  /// 邀请结果：对方已在群内（非「您自己已是群成员」）。
  static String alreadyMember() {
    return _i.t(
      zhHans: '对方已是群成员',
      zhHant: '對方已是群成員',
      en: 'Already a group member',
      ja: 'すでにグループメンバーです',
      ko: '이미 그룹 멤버입니다',
    );
  }

  static String partialAlreadyMember() {
    return _i.t(
      zhHans: '部分成员已在群内',
      zhHant: '部分成員已在群內',
      en: 'Some members are already in the group',
      ja: '一部のメンバーはすでにグループにいます',
      ko: '일부 멤버는 이미 그룹에 있습니다',
    );
  }

  static String joinResultMessage({required String? code, String? outcome}) {
    final text = '${outcome ?? ''} ${code ?? ''}'.trim().toUpperCase();
    if (text.contains('GROUP_JOIN_LIMIT_COMMUNITY')) {
      return fromResult(code: -1, desc: 'GROUP_JOIN_LIMIT_COMMUNITY');
    }
    if (text.contains('GROUP_JOIN_LIMIT_EXCEEDED') ||
        text.contains('GROUP_JOIN_LIMIT')) {
      return fromResult(code: -1, desc: 'GROUP_JOIN_LIMIT');
    }
    if (text.contains('GROUP_CREATE_LIMIT_COMMUNITY') ||
        text.contains('CREATE_LIMIT_EXCEEDED')) {
      return fromResult(code: -1, desc: code);
    }
    if (text.contains('PENDING') || text.contains('APPLICATION_PENDING')) {
      return _i.t(
        zhHans: '申请已提交，等待管理员审批',
        zhHant: '申請已提交，等待管理員審批',
        en: 'Request submitted and pending admin approval',
        ja: '申請を送信しました。管理者の承認待ちです',
        ko: '신청이 제출되었습니다. 관리자 승인 대기 중',
      );
    }
    if (text.contains('JOIN_DISABLED')) {
      return _i.t(
        zhHans: '该群已禁止申请加入',
        zhHant: '該群已禁止申請加入',
        en: 'This group does not accept join requests',
        ja: 'このグループは参加申請を受け付けていません',
        ko: '이 그룹은 가입 신청을 받지 않습니다',
      );
    }
    if (text.contains('ALREADY_GROUP_MEMBER')) {
      return _i.t(
        zhHans: '您已是群成员',
        zhHant: '您已是群成員',
        en: 'You are already a group member',
        ja: 'すでにグループメンバーです',
        ko: '이미 그룹 멤버입니다',
      );
    }
    return fromResult(code: -1, desc: code);
  }
}
