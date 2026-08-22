import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_recent_store.dart';

class StickerSendHelper {
  StickerSendHelper._();

  static bool isDynamicStickerData(String data) {
    return StickerRepository.instance.isDynamicFaceData(data);
  }

  static void sendViaPanelCallback(
    void Function(int index, String data) sendFaceMessage, {
    required String stickerId,
    required String thumbUrl,
    String? originUrl,
  }) {
    final id = stickerId.trim();
    if (id.isEmpty) {
      return;
    }
    StickerRepository.instance.putCache(
      StickerItem(
        stickerId: id,
        thumbUrl: thumbUrl,
        originUrl: originUrl ?? thumbUrl,
      ),
    );
    StickerRecentStore.add(id);
    sendFaceMessage(
      StickerConstants.stickerFaceGroupIndex,
      StickerConstants.dataForSticker(
        stickerId: id,
        thumbUrl: thumbUrl,
        originUrl: originUrl,
      ),
    );
  }
}
