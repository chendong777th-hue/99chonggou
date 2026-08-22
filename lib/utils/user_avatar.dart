import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:async' show unawaited;

import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/utils/push_identity_cache.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class UserAvatarHelper {
  UserAvatarHelper._();

  static String? resolveDisplayUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return MediaUrlResolver.resolve(trimmed) ?? trimmed;
    }
    return MediaUrlResolver.resolve(trimmed);
  }

  static Map<String, String>? httpHeadersFor(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }
    return MediaUrlResolver.authHeadersFor(url);
  }

  static bool isDefaultPlaceholder(String? url) {
    final trimmed = url?.trim() ?? '';
    if (trimmed.isEmpty) {
      return true;
    }
    final lower = trimmed.toLowerCase();
    if (lower.contains('default_c2c_head') ||
        lower.contains('default_group_head')) {
      return true;
    }
    final defaultUrl = IMDemoConfig.defaultRegisterAvatarUrl.trim().toLowerCase();
    return defaultUrl.isNotEmpty && lower == defaultUrl;
  }

  static const String defaultC2CAvatarAsset =
      'packages/tencent_cloud_chat_uikit/images/default_c2c_head.png';
  static const String appDefaultAvatarAsset = 'assets/default_avatar.png';

  /// 横幅/通知头像：无有效头像时返回 null，由 UI 展示本地占位图。
  static String? resolveBannerAvatarUrl(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty || isDefaultPlaceholder(trimmed)) {
      return null;
    }
    final resolved = resolveDisplayUrl(trimmed);
    if (resolved == null ||
        resolved.isEmpty ||
        isDefaultPlaceholder(resolved)) {
      return null;
    }
    return resolved;
  }

  /// 可用于展示的头像 URL；默认占位图或无法解析时返回空字符串。
  static String usableAvatarOrEmpty(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty || isDefaultPlaceholder(trimmed)) {
      return '';
    }
    final resolved = resolveDisplayUrl(trimmed);
    if (resolved == null ||
        resolved.isEmpty ||
        isDefaultPlaceholder(resolved)) {
      return '';
    }
    return trimmed;
  }

  /// Whether [incoming] should overwrite [current] on profile open enrich.
  ///
  /// Fill-only: write only when current is empty/default and incoming is
  /// usable. Keeps alternate CDN hosts from flashing the header avatar.
  static bool shouldReplaceProfileFaceUrl({
    required String? current,
    required String? incoming,
  }) {
    final next = usableAvatarOrEmpty(incoming);
    if (next.isEmpty) {
      return false;
    }
    final cur = usableAvatarOrEmpty(current);
    return cur.isEmpty;
  }

  static String pickBest({
    String? imFaceUrl,
    String? backendAvatarUrl,
  }) {
    final im = imFaceUrl?.trim() ?? '';
    if (im.isNotEmpty && resolveDisplayUrl(im) != null) {
      return im;
    }
    final backend = backendAvatarUrl?.trim() ?? '';
    if (backend.isNotEmpty && resolveDisplayUrl(backend) != null) {
      return backend;
    }
    return im;
  }

  /// 资料展示优先使用自建 API 头像，IM SDK 仅作兜底。
  static String pickBestPreferBackend({
    String? imFaceUrl,
    String? backendAvatarUrl,
  }) {
    final backend = backendAvatarUrl?.trim() ?? '';
    if (backend.isNotEmpty && resolveDisplayUrl(backend) != null) {
      return backend;
    }
    final im = imFaceUrl?.trim() ?? '';
    if (im.isNotEmpty && resolveDisplayUrl(im) != null) {
      return im;
    }
    return backend.isNotEmpty ? backend : im;
  }

  /// 群成员头像（同步，用于红包卡片等列表项首帧）。
  static String groupMemberFaceUrl(String? groupId, String? peerUserId) {
    final gid = groupId?.trim() ?? '';
    final uid = peerUserId?.trim() ?? '';
    if (gid.isEmpty || uid.isEmpty) {
      return '';
    }
    final candidates = <String>{
      uid,
      ChatIdFormat.rawUserUid(uid),
    };
    for (final id in candidates) {
      if (id.isEmpty) {
        continue;
      }
      final face = usableAvatarOrEmpty(
        GroupMemberStore.instance.memberOf(gid, id)?.faceUrl,
      );
      if (face.isNotEmpty) {
        return face;
      }
    }
    return '';
  }

  /// 合并「活资料 / 会话消息快照 / 群成员」候选（供单测与解析共用）。
  ///
  /// [preferLiveProfile]=true 时本地活资料优先于会话/消息快照，避免改头像后
  /// 仍被旧 conversationFaceUrl 短路。
  @visibleForTesting
  static String resolvePeerFaceUrlFromCandidates({
    required bool preferLiveProfile,
    String liveProfile = '',
    String conversationOrMessage = '',
    String groupMember = '',
  }) {
    final live = usableAvatarOrEmpty(liveProfile);
    final snap = usableAvatarOrEmpty(conversationOrMessage);
    final group = usableAvatarOrEmpty(groupMember);
    if (preferLiveProfile) {
      if (live.isNotEmpty) {
        return live;
      }
      if (snap.isNotEmpty) {
        return snap;
      }
      return group;
    }
    if (snap.isNotEmpty) {
      return snap;
    }
    if (group.isNotEmpty) {
      return group;
    }
    return live;
  }

  /// C2C 对方头像：默认快照优先；[preferLiveProfile] 时本地/网络资料优先。
  static Future<String> resolveChatPeerFaceUrl({
    required String peerUserId,
    String? messageFaceUrl,
    String? conversationFaceUrl,
    String? groupId,
    bool preferLiveProfile = false,
  }) async {
    final id = ChatIdFormat.rawUserUid(peerUserId);
    final imFace = (messageFaceUrl?.trim().isNotEmpty == true)
        ? messageFaceUrl
        : conversationFaceUrl;
    final snapshot = usableAvatarOrEmpty(imFace);
    final groupFace =
        groupMemberFaceUrl(groupId, id.isNotEmpty ? id : peerUserId);

    Future<String> fetchLiveFromNetwork() async {
      if (id.isEmpty) {
        return '';
      }
      try {
        final res =
            await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [id]);
        if (res.code == 0 && res.data != null && res.data!.isNotEmpty) {
          final info = res.data!.first;
          final fetched = usableAvatarOrEmpty(info.faceUrl);
          final nick = info.nickName?.trim() ?? '';
          if (fetched.isNotEmpty || nick.isNotEmpty) {
            await UserProfileLocalService.instance.saveUserFullInfo(
              V2TimUserFullInfo(
                userID: id,
                nickName: nick.isNotEmpty ? nick : null,
                faceUrl: fetched.isNotEmpty ? fetched : null,
              ),
            );
          }
          if (fetched.isNotEmpty) {
            return fetched;
          }
        }
      } catch (_) {}

      try {
        final remote = await UserApi.instance.tryFetchUserById(id);
        final backendAvatar = usableAvatarOrEmpty(remote?.avatarUrl);
        if (backendAvatar.isNotEmpty) {
          await UserProfileLocalService.instance.saveBackendProfile(
            userId: id,
            nickname: remote?.nickname,
            avatarUrl: backendAvatar,
          );
          return backendAvatar;
        }
      } catch (_) {}
      return '';
    }

    if (preferLiveProfile) {
      if (id.isNotEmpty) {
        final networked = await fetchLiveFromNetwork();
        if (networked.isNotEmpty) {
          return networked;
        }
        final record = await UserProfileLocalService.instance.read(id);
        final local = usableAvatarOrEmpty(record?.avatarUrl);
        if (local.isNotEmpty) {
          return local;
        }
      }
      return resolvePeerFaceUrlFromCandidates(
        preferLiveProfile: true,
        liveProfile: '',
        conversationOrMessage: snapshot,
        groupMember: groupFace,
      );
    }

    final fromHints = resolvePeerFaceUrlFromCandidates(
      preferLiveProfile: false,
      liveProfile: '',
      conversationOrMessage: snapshot,
      groupMember: groupFace,
    );
    if (fromHints.isNotEmpty) {
      return fromHints;
    }

    if (id.isEmpty) {
      return '';
    }

    final record = await UserProfileLocalService.instance.read(id);
    final backend = usableAvatarOrEmpty(record?.avatarUrl);
    if (backend.isNotEmpty) {
      return backend;
    }

    return fetchLiveFromNetwork();
  }

  /// 当前登录用户头像（聊天页自己消息应始终用最新资料，而非 message.faceUrl 快照）。
  static String currentSelfFaceUrl() {
    final selfVm = serviceLocator<TUISelfInfoViewModel>();
    final fromSelfVm = pickBest(imFaceUrl: selfVm.loginInfo?.faceUrl);
    if (fromSelfVm.isNotEmpty) {
      return fromSelfVm;
    }
    return pickBest(
      imFaceUrl: TIMUIKitCore.getInstance().loginUserInfo?.faceUrl,
    );
  }

  static Future<void> syncSelfAvatarFromBackend(String? rawAvatarUrl) async {
    final resolved = resolveDisplayUrl(rawAvatarUrl);
    if (resolved == null || resolved.isEmpty || isDefaultPlaceholder(resolved)) {
      return;
    }

    final selfVm = serviceLocator<TUISelfInfoViewModel>();
    final current = selfVm.loginInfo?.faceUrl?.trim() ?? '';
    if (current.isNotEmpty && !isDefaultPlaceholder(current)) {
      return;
    }
    if (current == resolved) {
      return;
    }
    final currentResolved = resolveDisplayUrl(current);
    if (currentResolved == resolved) {
      return;
    }

    await applySelfAvatarUpdate(rawAvatarUrl);
  }

  /// 用户主动修改头像后，强制同步到 IM 与全局 self 资料。
  static Future<V2TimUserFullInfo?> applySelfAvatarUpdate(
    String? rawAvatarUrl,
  ) async {
    final resolved = resolveDisplayUrl(rawAvatarUrl);
    if (resolved == null || resolved.isEmpty || isDefaultPlaceholder(resolved)) {
      return null;
    }

    final res = await TIMUIKitCore.getInstance().setSelfInfo(
      userFullInfo: V2TimUserFullInfo(faceUrl: resolved),
    );
    if (res.code != 0) {
      return null;
    }

    final selfVm = serviceLocator<TUISelfInfoViewModel>();
    final userId = selfVm.loginInfo?.userID?.trim() ??
        TIMUIKitCore.getInstance().loginInfo.userID?.trim();
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final infoRes =
        await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [userId]);
    if (infoRes.code != 0 ||
        infoRes.data == null ||
        infoRes.data!.isEmpty) {
      return null;
    }

    final updated = infoRes.data!.first;
    if ((updated.faceUrl ?? '').trim().isEmpty) {
      updated.faceUrl = resolved;
    }
    selfVm.setLoginInfo(updated);
    unawaited(PushIdentityCache.instance.refreshSelf());
    unawaited(
      UserProfileLocalService.instance.saveBackendProfile(
        userId: userId,
        nickname: updated.nickName,
        avatarUrl: (updated.faceUrl ?? '').trim().isNotEmpty
            ? updated.faceUrl
            : resolved,
      ),
    );
    return updated;
  }

  /// 用户主动修改昵称后，同步到 IM 与全局 self 资料。
  static Future<V2TimUserFullInfo?> applySelfNicknameUpdate(String nickname) async {
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final res = await TIMUIKitCore.getInstance().setSelfInfo(
      userFullInfo: V2TimUserFullInfo(nickName: trimmed),
    );
    if (res.code != 0) {
      return null;
    }

    final selfVm = serviceLocator<TUISelfInfoViewModel>();
    final userId = selfVm.loginInfo?.userID?.trim() ??
        TIMUIKitCore.getInstance().loginInfo.userID?.trim();
    if (userId == null || userId.isEmpty) {
      return null;
    }

    final infoRes =
        await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [userId]);
    if (infoRes.code != 0 ||
        infoRes.data == null ||
        infoRes.data!.isEmpty) {
      return null;
    }

    final updated = infoRes.data!.first;
    if ((updated.nickName ?? '').trim().isEmpty) {
      updated.nickName = trimmed;
    }
    selfVm.setLoginInfo(updated);
    unawaited(
      UserProfileLocalService.instance.saveBackendProfile(
        userId: userId,
        nickname: trimmed,
        avatarUrl: updated.faceUrl,
      ),
    );
    return updated;
  }

  static Future<void> syncSelfAvatarAfterLogin() async {
    try {
      final me = await AuthApi.instance.fetchMe();
      await syncSelfAvatarFromBackend(me.avatarUrl);
    } catch (_) {}
  }

  /// 将头像保存到系统相册。成功返回 true，失败返回 false。
  static Future<bool> saveAvatarToGallery({
    required BuildContext context,
    String? faceUrl,
    String? userId,
  }) async {
    return saveAvatarPreviewToGallery(
      context: context,
      faceUrl: faceUrl,
      showName: userId,
      avatarType: 1,
    );
  }

  /// 保存资料页全屏预览中的头像（含占位图 / 群默认 SVG）。
  static Future<bool> saveAvatarPreviewToGallery({
    required BuildContext context,
    String? faceUrl,
    String? showName,
    int avatarType = 1,
    String? fallbackAssetPath,
    String? fallbackAssetPackage,
  }) async {
    if (kIsWeb) {
      return false;
    }

    final allowed = await PermissionGuard.photosForSave(context);
    if (!allowed) {
      return false;
    }

    final bytes = await loadAvatarPreviewBytes(
      faceUrl: faceUrl,
      avatarType: avatarType,
      fallbackAssetPath: fallbackAssetPath,
      fallbackAssetPackage: fallbackAssetPackage,
    );
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final label = (showName?.trim().isNotEmpty == true ? showName!.trim() : 'avatar')
        .replaceAll(RegExp(r'[^\w\-]+'), '_');
    final name =
        'avatar_${avatarType}_${label}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: name,
      );
      return _isGallerySaveSuccess(result);
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List?> loadAvatarPreviewBytes({
    String? faceUrl,
    int avatarType = 1,
    String? fallbackAssetPath,
    String? fallbackAssetPackage,
  }) async {
    final raw = faceUrl?.trim() ?? '';
    if (raw.isNotEmpty) {
      if (raw.startsWith('assets/')) {
        if (raw.toLowerCase().endsWith('.svg')) {
          return _svgAssetToPngBytes(assetPath: raw);
        }
        return _loadBundledAssetBytes(raw, null);
      }
      final networkBytes = await _loadAvatarBytes(raw);
      if (networkBytes != null && networkBytes.isNotEmpty) {
        return networkBytes;
      }
    }

    if (fallbackAssetPath != null && fallbackAssetPath.trim().isNotEmpty) {
      if (fallbackAssetPath.toLowerCase().endsWith('.svg')) {
        return _svgAssetToPngBytes(
          assetPath: fallbackAssetPath,
          package: fallbackAssetPackage,
        );
      }
      return _loadBundledAssetBytes(
        fallbackAssetPath,
        fallbackAssetPackage,
      );
    }

    if (avatarType == 2) {
      return _svgAssetToPngBytes(
        assetPath: 'assets/default_group_avatar.svg',
      );
    }
    return _loadBundledAssetBytes(
      'images/default_c2c_head.png',
      'tencent_cloud_chat_uikit',
    );
  }

  static Future<Uint8List?> _loadBundledAssetBytes(
    String path,
    String? package,
  ) async {
    if (package != null && package.isNotEmpty) {
      try {
        final data = await rootBundle.load('packages/$package/$path');
        return data.buffer.asUint8List();
      } catch (_) {}
    }
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _svgAssetToPngBytes({
    required String assetPath,
    String? package,
    int size = 1024,
  }) async {
    try {
      final pictureInfo = await vg.loadPicture(
        SvgAssetLoader(assetPath, packageName: package),
        null,
      );
      try {
        final image = await pictureInfo.picture.toImage(size, size);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return byteData?.buffer.asUint8List();
      } finally {
        pictureInfo.picture.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _loadAvatarBytes(String? faceUrl) async {
    final raw = faceUrl?.trim() ?? '';
    if (raw.startsWith('assets/')) {
      try {
        final data = await rootBundle.load(raw);
        return data.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }

    final resolved = resolveDisplayUrl(raw);
    if (resolved != null && resolved.isNotEmpty) {
      try {
        final headers = httpHeadersFor(resolved) ?? const <String, String>{};
        final response = await Dio(
          BaseOptions(
            responseType: ResponseType.bytes,
            headers: headers,
          ),
        ).get<List<int>>(resolved);
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300 &&
            response.data != null &&
            response.data!.isNotEmpty) {
          return Uint8List.fromList(response.data!);
        }
      } catch (_) {}
    }

    try {
      final data = await rootBundle.load(
        'packages/tencent_cloud_chat_uikit/images/default_c2c_head.png',
      );
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static bool _isGallerySaveSuccess(dynamic result) {
    if (result == null) {
      return false;
    }
    if (result is bool) {
      return result;
    }
    if (result is Map) {
      final success = result['isSuccess'];
      if (success is bool) {
        return success;
      }
      final path = result['filePath'] ?? result['filepath'];
      if (path != null && path.toString().trim().isNotEmpty) {
        return true;
      }
      final code = result['returnCode'] ??
          result['resultCode'] ??
          result['code'] ??
          result['status'] ??
          result['errorCode'];
      if (code is num && (code == 100 || code == 1 || code == 0)) {
        return true;
      }
      if (code is String) {
        final value = code.trim().toLowerCase();
        return value == '100' ||
            value == '1' ||
            value == '0' ||
            value == 'success';
      }
      return false;
    }
    if (result is num) {
      return result == 100 || result == 1 || result == 0;
    }
    if (result is String) {
      final value = result.trim().toLowerCase();
      if (value.isEmpty) {
        return false;
      }
      if (value.contains('fail') || value.contains('error')) {
        return false;
      }
      return true;
    }
    return false;
  }
}
