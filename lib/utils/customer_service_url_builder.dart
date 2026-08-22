import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 在线客服 H5 链接拼接（访客信息 + 固定业务参数）。
class CustomerServiceUrlBuilder {
  CustomerServiceUrlBuilder._();

  static const String defaultBusinessId = '2';
  static const String defaultGroupId = '1';
  static const String defaultSpecial = '2';
  static const String guestAvatarUrl =
      'https://99chat.oss-cn-hongkong.aliyuncs.com/moren/default_c2c_head.png';

  static CustomerServiceVisitor guestVisitor() {
    return const CustomerServiceVisitor(
      id: '',
      name: '',
      avatar: guestAvatarUrl,
    );
  }

  static Uri? parseLoadableUri(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.host.trim().isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    return uri;
  }

  /// 在后台返回的 base URL 上拼接访客与业务参数。
  static String build({
    required String baseUrl,
    required String visiterId,
    required String visiterName,
    required String avatar,
    String businessId = defaultBusinessId,
    String groupId = defaultGroupId,
    String special = defaultSpecial,
    String product = '',
  }) {
    final uri = Uri.parse(baseUrl.trim());
    final merged = Map<String, String>.from(uri.queryParameters);
    merged['visiter_id'] = visiterId;
    merged['visiter_name'] = visiterName;
    merged['avatar'] = avatar;
    merged['business_id'] = businessId;
    merged['groupid'] = groupId;
    merged['special'] = special;
    merged['product'] = product;
    return uri.replace(queryParameters: merged).toString();
  }

  static Future<CustomerServiceVisitor> resolveVisitor({bool guest = false}) async {
    if (guest) {
      return guestVisitor();
    }

    var userId = '';
    var nickname = '';
    var avatarRaw = '';

    try {
      final me = await AuthApi.instance.fetchMe();
      userId = me.userId.trim();
      nickname = me.nickname.trim();
      avatarRaw = me.avatarUrl?.trim() ?? '';
    } catch (_) {}

    if (userId.isEmpty) {
      try {
        final res = await TIMUIKitCore.getSDKInstance().getLoginUser();
        userId = res.data?.trim() ?? '';
      } catch (_) {}
    }

    if (userId.isNotEmpty) {
      try {
        final infoRes = await TIMUIKitCore.getSDKInstance()
            .getUsersInfo(userIDList: [userId]);
        final info = infoRes.data?.isNotEmpty == true
            ? infoRes.data!.first
            : null;
        if (nickname.isEmpty) {
          nickname = info?.nickName?.trim() ?? '';
        }
        avatarRaw = UserAvatarHelper.pickBest(
          imFaceUrl: info?.faceUrl,
          backendAvatarUrl: avatarRaw,
        );
      } catch (_) {}
    }

    if (avatarRaw.isEmpty) {
      avatarRaw = UserAvatarHelper.currentSelfFaceUrl();
    }

    final avatar =
        UserAvatarHelper.resolveDisplayUrl(avatarRaw) ?? avatarRaw.trim();

    if (nickname.isEmpty) {
      nickname = userId;
    }

    return CustomerServiceVisitor(
      id: userId,
      name: nickname,
      avatar: avatar,
    );
  }
}

class CustomerServiceVisitor {
  const CustomerServiceVisitor({
    required this.id,
    required this.name,
    required this.avatar,
  });

  final String id;
  final String name;
  final String avatar;
}
