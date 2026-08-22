import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/custom_sticker_package.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_custom_face_data.dart';

/// 会话列表预览与聊天页消息气泡共用的 PNG 小表情包列表。
List<CustomEmojiFaceData> buildChatEmojiStickerList(BuildContext context) {
  final packages = Provider.of<CustomStickerPackageData>(context, listen: false)
      .customStickerPackageList;
  final fromPackages = packages
      .where((element) => element.isEmoji == true)
      .map(
        (e) => CustomEmojiFaceData(
          name: e.name,
          isEmoji: true,
          icon: e.menuItem.url ?? e.menuItem.name,
          list: e.stickerList
              .map((s) => (s.url?.isNotEmpty == true ? s.url! : s.name))
              .toList(),
        ),
      )
      .toList();
  if (fromPackages.isNotEmpty) {
    return fromPackages;
  }
  return Const.emojiList;
}
