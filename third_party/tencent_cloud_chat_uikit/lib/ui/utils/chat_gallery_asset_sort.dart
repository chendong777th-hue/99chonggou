import 'package:photo_manager/photo_manager.dart';

/// Telegram 风格：按「最近入库/修改」排序，而非仅拍摄时间。
class ChatGalleryAssetSort {
  ChatGalleryAssetSort._();

  /// 取 create / modify 中较新者，近似「最近保存/编辑」。
  static int recentActivityEpochSecond(AssetEntity asset) {
    final create = asset.createDateSecond ?? 0;
    final modified = asset.modifiedDateSecond ?? 0;
    return create > modified ? create : modified;
  }

  static int compareByRecentActivityDesc(AssetEntity a, AssetEntity b) {
    final delta = recentActivityEpochSecond(b) - recentActivityEpochSecond(a);
    if (delta != 0) {
      return delta;
    }
    return b.id.compareTo(a.id);
  }
}
