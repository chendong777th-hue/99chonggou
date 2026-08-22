/// 99chat 动态表情（服务端）与腾讯 Face 消息约定。
class StickerConstants {
  StickerConstants._();

  /// 与内置 yz/ys/gcs 的 index 1/2/3 区分。
  static const int stickerFaceGroupIndex = 99;

  static const String stickerDataScheme = '99chat://sticker/';

  static const String virtualPackFavorites = '_virtual_favorites';
  static const String virtualPackRecent = '_virtual_recent';
  static const String userUploadPackId = 'user_upload';

  /// 服务端若以独立包返回收藏列表时的 packId（需并入爱心 Tab，勿单独占 Tab）。
  static const Set<String> serverFavoritesPackIds = {
    'favorites',
    'favorite',
    virtualPackFavorites,
  };

  /// 底部栏「添加表情」入口（微信左侧 +），非表情包 Tab。
  static const String actionAddPackId = '_action_add';

  /// 聊天表情面板不展示的内置/系统包（历史消息仍可渲染）。
  static const Set<String> hiddenPanelAssetPackIds = {'4350', '4352'};

  /// 聊天表情面板展示的内置 assets 包。
  static const Set<String> visiblePanelAssetPackIds = {'4351'};

  /// 聊天表情面板默认每行格数（小黄脸、Unicode 等）。
  static const int panelDefaultCrossAxisCount = 8;

  /// 大尺寸表情包每行格数（如 4351 ys 系列）。
  static const int panelLargeStickerCrossAxisCount = 4;

  /// 聊天表情面板内使用大尺寸网格的包 ID。
  static const Set<String> panelLargeStickerPackIds = {'4351'};

  static int panelCrossAxisCountForPack(String packId) =>
      panelLargeStickerPackIds.contains(packId)
          ? panelLargeStickerCrossAxisCount
          : panelDefaultCrossAxisCount;

  static const int recentMaxCount = 30;

  /// Face 消息 data：携带 [thumbUrl]/[originUrl] 供未收藏该表情的会话方直接渲染。
  static String dataForSticker({
    required String stickerId,
    String? thumbUrl,
    String? originUrl,
  }) {
    final id = stickerId.trim();
    var data = '$stickerDataScheme$id';
    final thumb = thumbUrl?.trim() ?? '';
    final origin = originUrl?.trim() ?? '';
    final params = <String, String>{};
    if (thumb.isNotEmpty) {
      params['thumbUrl'] = thumb;
    }
    if (origin.isNotEmpty && origin != thumb) {
      params['originUrl'] = origin;
    }
    if (params.isEmpty) {
      return data;
    }
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    return '$data?$query';
  }

  static String dataForStickerId(String stickerId) =>
      dataForSticker(stickerId: stickerId);

  /// 从 Face data 解析 stickerId（忽略 ? 后的 URL 参数）。
  static String? parseStickerIdFromData(String data) {
    final trimmed = data.trim();
    if (!trimmed.startsWith(stickerDataScheme)) {
      return null;
    }
    var rest = trimmed.substring(stickerDataScheme.length);
    final q = rest.indexOf('?');
    if (q >= 0) {
      rest = rest.substring(0, q);
    }
    final h = rest.indexOf('#');
    if (h >= 0) {
      rest = rest.substring(0, h);
    }
    rest = rest.trim();
    return rest.isEmpty ? null : rest;
  }

  /// 解析 Face data 内嵌的 thumbUrl / originUrl（发送方写入，接收方免拉 API）。
  static ({String thumbUrl, String originUrl}) parseEmbeddedUrls(String data) {
    final q = data.indexOf('?');
    if (q < 0 || q >= data.length - 1) {
      return (thumbUrl: '', originUrl: '');
    }
    final params = Uri.splitQueryString(data.substring(q + 1));
    return (
      thumbUrl: params['thumbUrl']?.trim() ?? '',
      originUrl: params['originUrl']?.trim() ?? '',
    );
  }
}
