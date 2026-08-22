import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

class GroupLeaveMessage {
  GroupLeaveMessage._();

  static AppI18n get _i => AppI18n.current;

  static String failure({
    required bool dismiss,
    String? desc,
    int? code,
    DioError? error,
  }) {
    if (error != null) {
      return failureFromDio(error, dismiss: dismiss);
    }
    final text = '${desc ?? ''} ${code ?? ''}'.trim().toUpperCase();
    return _mapCode(text, dismiss: dismiss, fallback: desc?.trim());
  }

  static String failureFromDio(DioError error, {required bool dismiss}) {
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
      dismiss: dismiss,
      fallback: message.isNotEmpty ? message : MeGroupApi.readDioCode(error),
    );
  }

  static String _mapCode(
    String upper, {
    required bool dismiss,
    String? fallback,
  }) {
    if (upper.contains('OWNER_CANNOT_LEAVE') ||
        (upper.contains('OWNER') && !dismiss) ||
        upper.contains('NOT_GROUP_OWNER')) {
      return _i.t(
        zhHans: '群主请使用解散群组',
        zhHant: '群主請使用解散群組',
        en: 'Group owners must dismiss the group instead of leaving',
        ja: 'グループオーナーは退会ではなく解散してください',
        ko: '그룹장은 나가기 대신 그룹을 해산해야 합니다',
      );
    }
    if (upper.contains('NOT_GROUP_MEMBER')) {
      return _i.t(
        zhHans: '您已不是该群成员',
        zhHant: '您已不是該群成員',
        en: 'You are no longer a member of this group',
        ja: 'このグループのメンバーではありません',
        ko: '이 그룹의 멤버가 아닙니다',
      );
    }
    if (upper.contains('GROUP_NOT_FOUND') || upper.contains('GROUP_DISMISSED')) {
      return _i.t(
        zhHans: '群聊不存在或已解散',
        zhHant: '群聊不存在或已解散',
        en: 'This group does not exist or has been dismissed',
        ja: 'グループが存在しないか、すでに解散されています',
        ko: '그룹이 존재하지 않거나 이미 해산되었습니다',
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
    if (upper.contains('BRIDGE_DISABLED')) {
      return _i.t(
        zhHans: '群服务暂不可用，请稍后重试',
        zhHant: '群服務暫不可用，請稍後重試',
        en: 'Group service is unavailable. Please try again later.',
        ja: 'グループサービスを利用できません。しばらくしてから再試行してください',
        ko: '그룹 서비스를 사용할 수 없습니다. 잠시 후 다시 시도해 주세요',
      );
    }
    if (upper.contains('REQUEST_FAILED') ||
        upper.contains('NETWORK') ||
        upper.contains('TIMEOUT') ||
        upper.contains('CONNECTION')) {
      return _i.t(
        zhHans: '网络异常，请稍后重试',
        zhHant: '網路異常，請稍後重試',
        en: 'Network error. Please try again later.',
        ja: 'ネットワークエラーです。しばらくしてから再試行してください',
        ko: '네트워크 오류입니다. 잠시 후 다시 시도해 주세요',
      );
    }
    if (upper.contains('INVALID_INPUT') ||
        upper.contains('INVALID_RESPONSE') ||
        upper.contains('BAD_REQUEST')) {
      return _defaultFailure(dismiss);
    }
    final fb = fallback?.trim() ?? '';
    if (fb.isNotEmpty && RegExp(r'[\u4e00-\u9fa5]').hasMatch(fb)) {
      return fb;
    }
    return _defaultFailure(dismiss);
  }

  static String _defaultFailure(bool dismiss) {
    return dismiss
        ? _i.t(
            zhHans: '解散群聊失败，请稍后重试',
            zhHant: '解散群聊失敗，請稍後重試',
            en: 'Failed to dismiss the group. Please try again later.',
            ja: 'グループの解散に失敗しました。しばらくしてから再試行してください',
            ko: '그룹 해산에 실패했습니다. 잠시 후 다시 시도해 주세요',
          )
        : _i.t(
            zhHans: '退出群聊失败，请稍后重试',
            zhHant: '退出群聊失敗，請稍後重試',
            en: 'Failed to leave the group. Please try again later.',
            ja: 'グループの退会に失敗しました。しばらくしてから再試行してください',
            ko: '그룹 나가기에 실패했습니다. 잠시 후 다시 시도해 주세요',
          );
  }
}
