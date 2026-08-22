import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_lookup.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';

/// 加群入口查群失败：来源被群设置关闭。
class GroupJoinLookupDisabledException implements Exception {
  const GroupJoinLookupDisabledException(this.code);

  final String code;

  bool get isAliasDisabled => code == 'JOIN_BY_ALIAS_DISABLED';
  bool get isQrDisabled => code == 'JOIN_BY_QR_DISABLED';
}

/// 按加群来源查群：优先 REST（尊重 allowJoinByAlias / allowJoinByQrCode），再回退 IM。
class GroupJoinLookup {
  GroupJoinLookup._();

  static Future<V2TimGroupInfo?> resolve({
    required String groupKey,
    required GroupJoinSource joinSource,
  }) async {
    try {
      final fromRest = await GroupJoinApi.instance.lookupJoinTarget(
        keyword: groupKey,
        joinSource: joinSource,
      );
      if (fromRest != null) {
        return fromRest;
      }
    } on GroupJoinLookupDisabledException {
      rethrow;
    } on DioError catch (error) {
      final code = GroupJoinApi.readDioCode(error);
      if (code == 'JOIN_BY_ALIAS_DISABLED' || code == 'JOIN_BY_QR_DISABLED') {
        throw GroupJoinLookupDisabledException(code);
      }
    } catch (error) {
      if (error is GroupJoinLookupDisabledException) {
        rethrow;
      }
    }

    return GroupLookup.resolve(groupKey);
  }

  static String disabledMessage(
    AppI18n i18n,
    GroupJoinLookupDisabledException error,
  ) {
    if (error.isQrDisabled) {
      return i18n.t(
        zhHans: '该群已关闭二维码加群',
        zhHant: '該群已關閉 QR 碼加群',
        en: 'This group has disabled joining via QR code',
        ja: 'このグループはQRコードによる参加を無効にしています',
        ko: '이 그룹은 QR 코드 가입을 허용하지 않습니다',
      );
    }
    return i18n.t(
      zhHans: '该群已关闭群别名加群',
      zhHant: '該群已關閉群別名加群',
      en: 'This group has disabled joining via group alias',
      ja: 'このグループはグループ別名による参加を無効にしています',
      ko: '이 그룹은 그룹 별명 가입을 허용하지 않습니다',
    );
  }
}
