import 'package:tencent_cloud_chat_demo/src/api/group_create_limit_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_quota_limit_error.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

class GroupCreateLimitMessage {
  GroupCreateLimitMessage._();

  static const int standardGroupMemberLimit = 2000;
  static const int superGroupMemberLimit = 100000;

  static AppI18n get _i => AppI18n.current;

  static String typeDisplayName(String groupType) {
    switch (groupType) {
      case GroupType.Public:
      case GroupType.Work:
        return _i.t(
          zhHans: '普通群',
          zhHant: '普通群',
          en: 'standard group',
          ja: '通常グループ',
          ko: '일반 그룹',
        );
      case GroupType.Community:
        return _i.t(
          zhHans: '超级大群',
          zhHant: '超級大群',
          en: 'super group',
          ja: 'スーパーグループ',
          ko: '슈퍼 그룹',
        );
      default:
        return _i.t(
          zhHans: '群聊',
          zhHant: '群聊',
          en: 'group',
          ja: 'グループ',
          ko: '그룹',
        );
    }
  }

  static int memberLimitForGroupType(String groupType) {
    switch (groupType) {
      case GroupType.Community:
        return superGroupMemberLimit;
      case GroupType.Public:
      case GroupType.Work:
      case GroupType.Meeting:
        return standardGroupMemberLimit;
      default:
        return standardGroupMemberLimit;
    }
  }

  static String memberCapacityHint(String groupType) {
    final limit = memberLimitForGroupType(groupType);
    return _i.format(
      zhHans: '最多可容纳 {limit} 名成员',
      zhHant: '最多可容納 {limit} 名成員',
      en: 'Up to {limit} members',
      ja: '最大 {limit} 名まで参加可能',
      ko: '최대 {limit}명까지 참여 가능',
      vars: {'limit': _formatMemberCount(limit)},
    );
  }

  static String memberCapacityShortHint(String groupType) {
    final limit = memberLimitForGroupType(groupType);
    return _i.format(
      zhHans: '≤{limit}人',
      zhHant: '≤{limit}人',
      en: '≤{limit}',
      ja: '≤{limit}人',
      ko: '≤{limit}명',
      vars: {'limit': _formatMemberCount(limit)},
    );
  }

  static String createQuotaHint({
    required String groupType,
    required bool limitsEnabled,
    GroupTypeCreateLimitInfo? info,
  }) {
    if (groupType != GroupType.Community) {
      return _i.t(
        zhHans: '普通群创建数量不限制',
        zhHant: '普通群建立數量不限制',
        en: 'No limit on how many standard groups you can create',
        ja: '通常グループの作成数に制限なし',
        ko: '일반 그룹 생성 수 제한 없음',
      );
    }
    if (!limitsEnabled || info == null) {
      return _fallbackCreateQuotaHint(groupType);
    }
    if (info.max > 0) {
      return remainingHint(
        groupType: groupType,
        remaining: info.remaining,
        max: info.max,
        used: info.used,
      );
    }
    if (info.limited && info.remaining <= 0) {
      return blockedCreateMessage(groupType, max: info.max > 0 ? info.max : null);
    }
    return _fallbackCreateQuotaHint(groupType);
  }

  static String joinQuotaHint({
    required String groupType,
    required bool limitsEnabled,
    GroupTypeCreateLimitInfo? info,
  }) {
    if (!limitsEnabled || info == null) {
      return '';
    }
    final isCommunity = groupType == GroupType.Community;
    if (info.max > 0) {
      if (info.remaining <= 0) {
        return isCommunity
            ? _i.format(
                zhHans: '每位用户最多加入 {max} 个超级大群，您已达上限',
                zhHant: '每位用戶最多加入 {max} 個超級大群，您已達上限',
                en:
                    'Each user can join up to {max} super groups. You have reached the limit',
                ja: '各ユーザーはスーパーグループに最大 {max} 個まで参加できます。上限に達しました',
                ko: '사용자당 슈퍼 그룹은 최대 {max}개까지 참가할 수 있습니다. 한도에 도달했습니다',
                vars: {'max': info.max.toString()},
              )
            : _i.format(
                zhHans: '每位用户最多加入 {max} 个普通群，您已达上限',
                zhHant: '每位用戶最多加入 {max} 個普通群，您已達上限',
                en:
                    'Each user can join up to {max} standard groups. You have reached the limit',
                ja: '各ユーザーは通常グループに最大 {max} 個まで参加できます。上限に達しました',
                ko: '사용자당 일반 그룹은 최대 {max}개까지 참가할 수 있습니다. 한도에 도달했습니다',
                vars: {'max': info.max.toString()},
              );
      }
      return isCommunity
          ? _i.format(
              zhHans: '每位用户最多加入 {max} 个超级大群，还可加入 {remaining} 个',
              zhHant: '每位用戶最多加入 {max} 個超級大群，還可加入 {remaining} 個',
              en:
                  'Each user can join up to {max} super groups. {remaining} remaining',
              ja: '各ユーザーはスーパーグループに最大 {max} 個まで参加できます。あと {remaining} 個参加可能',
              ko: '사용자당 슈퍼 그룹은 최대 {max}개까지 참가할 수 있습니다. {remaining}개 더 참가 가능',
              vars: {
                'max': info.max.toString(),
                'remaining': info.remaining.toString(),
              },
            )
          : _i.format(
              zhHans: '每位用户最多加入 {max} 个普通群，还可加入 {remaining} 个',
              zhHant: '每位用戶最多加入 {max} 個普通群，還可加入 {remaining} 個',
              en:
                  'Each user can join up to {max} standard groups. {remaining} remaining',
              ja: '各ユーザーは通常グループに最大 {max} 個まで参加できます。あと {remaining} 個参加可能',
              ko: '사용자당 일반 그룹은 최대 {max}개까지 참가할 수 있습니다. {remaining}개 더 참가 가능',
              vars: {
                'max': info.max.toString(),
                'remaining': info.remaining.toString(),
              },
            );
    }
    if (info.limited && info.remaining <= 0) {
      return blockedJoinMessage(groupType);
    }
    return '';
  }

  static String _fallbackCreateQuotaHint(String groupType) {
    if (groupType == GroupType.Community) {
      return _i.t(
        zhHans: '每个用户仅可创建有限个超级大群',
        zhHant: '每個用戶僅可建立有限個超級大群',
        en: 'Each user can create a limited number of super groups',
        ja: '各ユーザーが作成できるスーパーグループ数には上限があります',
        ko: '각 사용자가 생성할 수 있는 슈퍼 그룹 수에는 한도가 있습니다',
      );
    }
    return _i.t(
      zhHans: '普通群创建数量不限制',
      zhHant: '普通群建立數量不限制',
      en: 'No limit on how many standard groups you can create',
      ja: '通常グループの作成数に制限なし',
      ko: '일반 그룹 생성 수 제한 없음',
    );
  }

  static String selectedTypeDescription({
    required String groupType,
    required bool limitsEnabled,
    GroupTypeCreateLimitInfo? info,
    GroupTypeCreateLimitInfo? joinInfo,
  }) {
    final typeName = typeDisplayName(groupType);
    final memberHint = memberCapacityHint(groupType);
    final quotaHint = createQuotaHint(
      groupType: groupType,
      limitsEnabled: limitsEnabled,
      info: info,
    );
    final joinHint = joinQuotaHint(
      groupType: groupType,
      limitsEnabled: limitsEnabled,
      info: joinInfo,
    );
    final quotaPart = joinHint.isEmpty ? quotaHint : '$quotaHint；$joinHint';
    switch (groupType) {
      case GroupType.Community:
        return _i.format(
          zhHans: '{type}：{memberHint}，适合大规模社群运营；{quotaHint}。',
          zhHant: '{type}：{memberHint}，適合大規模社群運營；{quotaHint}。',
          en: '{type}: {memberHint}. Best for large communities. {quotaHint}.',
          ja: '{type}：{memberHint}。大規模コミュニティ向け。{quotaHint}。',
          ko: '{type}: {memberHint}. 대규모 커뮤니티에 적합합니다. {quotaHint}.',
          vars: {
            'type': typeName,
            'memberHint': memberHint,
            'quotaHint': quotaPart,
          },
        );
      case GroupType.Public:
      case GroupType.Work:
        return _i.format(
          zhHans: '{type}：{memberHint}，适合日常群聊与协作；{quotaHint}。',
          zhHant: '{type}：{memberHint}，適合日常群聊與協作；{quotaHint}。',
          en:
              '{type}: {memberHint}. Good for daily chats and teamwork. {quotaHint}.',
          ja: '{type}：{memberHint}。日常のチャットや共同作業向け。{quotaHint}。',
          ko: '{type}: {memberHint}. 일상 대화와 협업에 적합합니다. {quotaHint}.',
          vars: {
            'type': typeName,
            'memberHint': memberHint,
            'quotaHint': quotaPart,
          },
        );
      default:
        return _i.format(
          zhHans: '{type}：{memberHint}；{quotaHint}。',
          zhHant: '{type}：{memberHint}；{quotaHint}。',
          en: '{type}: {memberHint}. {quotaHint}.',
          ja: '{type}：{memberHint}。{quotaHint}。',
          ko: '{type}: {memberHint}. {quotaHint}.',
          vars: {
            'type': typeName,
            'memberHint': memberHint,
            'quotaHint': quotaPart,
          },
        );
    }
  }

  static String createGroupDeclaration() {
    return _i.t(
      zhHans: '创建群聊即表示您已阅读并同意遵守平台社区规范，对群内信息发布与管理承担责任。',
      zhHant: '建立群聊即表示您已閱讀並同意遵守平台社群規範，對群內資訊發布與管理承擔責任。',
      en:
          'By creating a group, you agree to follow the community guidelines and take responsibility for content and management within the group.',
      ja: 'グループを作成すると、コミュニティガイドラインに同意し、グループ内の情報発信と管理に責任を負うものとします。',
      ko: '그룹을 만들면 커뮤니티 가이드라인을 준수하고, 그룹 내 정보 게시 및 관리에 대한 책임에 동의하는 것으로 간주됩니다.',
    );
  }

  static String _formatMemberCount(int value) {
    if (value >= 10000 && value % 10000 == 0) {
      return '${value ~/ 10000}万';
    }
    return value.toString();
  }

  static String remainingHint({
    required String groupType,
    required int remaining,
    required int max,
    int? used,
  }) {
    final typeName = typeDisplayName(groupType);
    if (max > 0) {
      if (remaining <= 0) {
        return _i.format(
          zhHans: '每位用户最多创建 {max} 个{type}，您已达上限',
          zhHant: '每位用戶最多建立 {max} 個{type}，您已達上限',
          en:
              'Each user can create up to {max} {type}(s). You have reached the limit',
          ja: '各ユーザーは{type}を最大 {max} 個まで作成できます。上限に達しました',
          ko: '사용자당 {type}은(는) 최대 {max}개까지 생성할 수 있습니다. 한도에 도달했습니다',
          vars: {'type': typeName, 'max': max.toString()},
        );
      }
      return _i.format(
        zhHans: '每位用户最多创建 {max} 个{type}，还可创建 {remaining} 个',
        zhHant: '每位用戶最多建立 {max} 個{type}，還可建立 {remaining} 個',
        en: 'Each user can create up to {max} {type}(s). {remaining} remaining',
        ja: '各ユーザーは{type}を最大 {max} 個まで作成できます。あと {remaining} 個作成可能',
        ko: '사용자당 {type}은(는) 최대 {max}개까지 생성할 수 있습니다. {remaining}개 더 만들 수 있음',
        vars: {
          'type': typeName,
          'max': max.toString(),
          'remaining': remaining.toString(),
        },
      );
    }
    if (remaining <= 0) {
      return _i.format(
        zhHans: '{type}创建数量已达上限',
        zhHant: '{type}建立數量已達上限',
        en: 'You have reached the {type} limit',
        ja: '{type}の作成上限に達しました',
        ko: '{type} 생성 한도에 도달했습니다',
        vars: {'type': typeName},
      );
    }
    return _i.format(
      zhHans: '还可创建 {remaining} 个{type}',
      zhHant: '還可建立 {remaining} 個{type}',
      en: 'You can create {remaining} more {type}(s)',
      ja: 'あと {remaining} 個の{type}を作成できます',
      ko: '{type}을(를) {remaining}개 더 만들 수 있습니다',
      vars: {'remaining': remaining.toString(), 'type': typeName},
    );
  }

  static String? fromImResult({
    required int code,
    required String? desc,
    required String groupType,
  }) {
    final text = '${desc ?? ''} $code'.toUpperCase();
    if (text.contains('GROUP_JOIN_LIMIT_COMMUNITY')) {
      return blockedJoinMessage(GroupType.Community);
    }
    if (text.contains('GROUP_JOIN_LIMIT')) {
      return blockedJoinMessage(
        groupType == GroupType.Community ? GroupType.Community : GroupType.Public,
      );
    }
    if (text.contains('GROUP_CREATE_LIMIT_COMMUNITY') ||
        (groupType == GroupType.Community &&
            text.contains('GROUP_CREATE_LIMIT'))) {
      return blockedCreateMessage(GroupType.Community);
    }
    if (text.contains('GROUP_CREATE_LIMIT_PUBLIC') ||
        ((groupType == GroupType.Public || groupType == GroupType.Work) &&
            text.contains('GROUP_CREATE_LIMIT'))) {
      // 兼容旧 IM 文案；v2.0 普通群创建已不限制。
      return blockedCreateMessage(groupType);
    }
    return null;
  }

  static String? fromApiCode({
    required String? code,
    required String groupType,
  }) {
    final normalized = code?.trim().toUpperCase() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.contains('GROUP_JOIN_LIMIT_COMMUNITY')) {
      return blockedJoinMessage(GroupType.Community);
    }
    if (normalized == 'GROUP_JOIN_LIMIT_EXCEEDED' ||
        normalized.contains('GROUP_JOIN_LIMIT')) {
      return blockedJoinMessage(
        groupType == GroupType.Community ? GroupType.Community : GroupType.Public,
      );
    }
    if (normalized == 'GROUP_CREATE_LIMIT_COMMUNITY' ||
        normalized == 'CREATE_LIMIT_EXCEEDED' ||
        normalized.contains('GROUP_CREATE_LIMIT')) {
      return blockedCreateMessage(
        groupType == GroupType.Community ? GroupType.Community : groupType,
      );
    }
    return null;
  }

  static String? fromQuotaError(
    GroupQuotaLimitError error, {
    String? groupType,
    String? selfUserId,
  }) {
    final type = groupType ?? GroupType.Public;
    final self = selfUserId?.trim() ?? '';
    if (error.overLimitUsers.isNotEmpty) {
      GroupOverLimitUser? selfHit;
      if (self.isNotEmpty) {
        for (final u in error.overLimitUsers) {
          if (u.userId == self) {
            selfHit = u;
            break;
          }
        }
      }
      final sample = selfHit ?? error.overLimitUsers.first;
      final limitType = sample.limitType.toLowerCase();
      if (limitType == 'communitycreate' || error.isCommunityCreateLimit) {
        return blockedCreateMessage(
          GroupType.Community,
          max: sample.max > 0 ? sample.max : null,
        );
      }
      if (limitType == 'communityjoin' || error.isCommunityJoinLimit) {
        if (selfHit != null || error.overLimitUsers.length == 1 && self.isEmpty) {
          return blockedJoinMessage(
            GroupType.Community,
            max: sample.max > 0 ? sample.max : null,
          );
        }
        return _i.t(
          zhHans: '部分用户加入超级大群数量已达上限',
          zhHant: '部分用戶加入超級大群數量已達上限',
          en: 'Some users have reached the super group join limit',
          ja: '一部のユーザーがスーパーグループ参加上限に達しています',
          ko: '일부 사용자가 슈퍼 그룹 참가 한도에 도달했습니다',
        );
      }
      if (limitType == 'join' || error.isJoinLimit) {
        if (selfHit != null) {
          return blockedJoinMessage(
            GroupType.Public,
            max: sample.max > 0 ? sample.max : null,
          );
        }
        return _i.t(
          zhHans: '部分用户加入群数量已达上限',
          zhHant: '部分用戶加入群數量已達上限',
          en: 'Some users have reached the group join limit',
          ja: '一部のユーザーがグループ参加上限に達しています',
          ko: '일부 사용자가 그룹 참가 한도에 도달했습니다',
        );
      }
    }
    return fromApiCode(code: error.code, groupType: type);
  }

  /// 建群页前置拦截：优先创建满，其次加入满。
  static String blockedForCreateOwner({
    required String groupType,
    required GroupCreateLimitsResponse limits,
  }) {
    if (!limits.canCreateGroupType(groupType)) {
      final info = limits.infoForGroupType(groupType);
      return blockedCreateMessage(groupType, max: info?.max);
    }
    final joinInfo = limits.joinInfoForGroupType(groupType);
    if (joinInfo != null && joinInfo.isExhausted) {
      return blockedJoinMessage(groupType, max: joinInfo.max);
    }
    return blockedJoinMessage(groupType);
  }

  static String blockedMessage(String groupType, {int? max}) {
    return blockedCreateMessage(groupType, max: max);
  }

  static String blockedCreateMessage(String groupType, {int? max}) {
    final typeName = typeDisplayName(groupType);
    if (max != null && max > 0) {
      return _i.format(
        zhHans: '每位用户最多只能创建 {max} 个{type}，您已达上限',
        zhHant: '每位用戶最多只能建立 {max} 個{type}，您已達上限',
        en:
            'Each user can create up to {max} {type}(s) only. You have reached the limit',
        ja: '各ユーザーは{type}を最大 {max} 個まで作成できます。上限に達しました',
        ko: '사용자당 {type}은(는) 최대 {max}개까지만 생성할 수 있습니다. 한도에 도달했습니다',
        vars: {'type': typeName, 'max': max.toString()},
      );
    }
    switch (groupType) {
      case GroupType.Community:
        return _i.t(
          zhHans: '每位用户超级大群创建数量已达上限',
          zhHant: '每位用戶超級大群建立數量已達上限',
          en: 'You have reached your super group creation limit',
          ja: 'スーパーグループの作成上限に達しました',
          ko: '슈퍼 그룹 생성 한도에 도달했습니다',
        );
      case GroupType.Public:
      case GroupType.Work:
        return _i.t(
          zhHans: '每位用户普通群创建数量已达上限',
          zhHant: '每位用戶普通群建立數量已達上限',
          en: 'You have reached your standard group creation limit',
          ja: '通常グループの作成上限に達しました',
          ko: '일반 그룹 생성 한도에 도달했습니다',
        );
      default:
        return _i.t(
          zhHans: '每位用户建群数量已达上限',
          zhHant: '每位用戶建群數量已達上限',
          en: 'You have reached your group creation limit',
          ja: 'グループ作成上限に達しました',
          ko: '그룹 생성 한도에 도달했습니다',
        );
    }
  }

  static String blockedJoinMessage(String groupType, {int? max}) {
    final isCommunity = groupType == GroupType.Community;
    if (max != null && max > 0) {
      return isCommunity
          ? _i.format(
              zhHans: '每位用户最多加入 {max} 个超级大群，您已达上限',
              zhHant: '每位用戶最多加入 {max} 個超級大群，您已達上限',
              en:
                  'Each user can join up to {max} super groups. You have reached the limit',
              ja: '各ユーザーはスーパーグループに最大 {max} 個まで参加できます。上限に達しました',
              ko: '사용자당 슈퍼 그룹은 최대 {max}개까지 참가할 수 있습니다. 한도에 도달했습니다',
              vars: {'max': max.toString()},
            )
          : _i.format(
              zhHans: '每位用户最多加入 {max} 个普通群，您已达上限',
              zhHant: '每位用戶最多加入 {max} 個普通群，您已達上限',
              en:
                  'Each user can join up to {max} standard groups. You have reached the limit',
              ja: '各ユーザーは通常グループに最大 {max} 個まで参加できます。上限に達しました',
              ko: '사용자당 일반 그룹은 최대 {max}개까지 참가할 수 있습니다. 한도에 도달했습니다',
              vars: {'max': max.toString()},
            );
    }
    return isCommunity
        ? _i.t(
            zhHans: '您加入的超级大群数量已达上限',
            zhHant: '您加入的超級大群數量已達上限',
            en: 'You have reached the super group join limit',
            ja: 'スーパーグループの参加上限に達しました',
            ko: '슈퍼 그룹 참가 한도에 도달했습니다',
          )
        : _i.t(
            zhHans: '您加入的普通群数量已达上限',
            zhHant: '您加入的普通群數量已達上限',
            en: 'You have reached the standard group join limit',
            ja: '通常グループの参加上限に達しました',
            ko: '일반 그룹 참가 한도에 도달했습니다',
          );
  }
}
