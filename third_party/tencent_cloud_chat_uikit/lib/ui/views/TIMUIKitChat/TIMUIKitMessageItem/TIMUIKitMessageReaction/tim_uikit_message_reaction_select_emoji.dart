import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/TIMUIKitMessageReaction/message_reaction_emoji.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_emoji_panel.dart'
    as emoji;
import 'package:tencent_cloud_chat_uikit/ui/widgets/emoji.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/extended_wrap/extended_wrap.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

enum SelectEmojiPanelPosition { up, down }

class TIMUIKitMessageReactionEmojiSelectPanel extends StatefulWidget {
  final ValueChanged<int> onSelect;
  final bool isShowMoreSticker;
  final ValueChanged<bool> onClickShowMore;

  const TIMUIKitMessageReactionEmojiSelectPanel(
      {Key? key,
      required this.onSelect,
      required this.isShowMoreSticker,
      required this.onClickShowMore})
      : super(key: key);

  @override
  State<StatefulWidget> createState() =>
      TIMUIKitMessageReactionEmojiSelectPanelState();
}

class TIMUIKitMessageReactionEmojiSelectPanelState
    extends TIMUIKitState<TIMUIKitMessageReactionEmojiSelectPanel> {
  static const int _compactEmojiCount = 7;

  Widget _buildEmojiButton(Map<String, Object> data) {
    final item = Emoji.fromJson(data);
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.black12,
      borderRadius: BorderRadius.circular(20),
      onTap: () => widget.onSelect(item.unicode),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: emoji.EmojiItem(
          name: item.name,
          unicode: item.unicode,
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: () => widget.onClickShowMore(true),
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(left: 2),
        decoration: const BoxDecoration(
          color: Color(0xFFE8F4FC),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF3A9FE6),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildCompactReactionRow(List<Map<String, Object>> emojiData) {
    final preview = emojiData.take(_compactEmojiCount).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...preview.map(_buildEmojiButton),
          _buildExpandButton(),
        ],
      ),
    );
  }

  Widget _buildExpandedPanel(List<Map<String, Object>> emojiData) {
    return ExtendedWrap(
      maxLines: 5,
      spacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 16,
      children: [
        GestureDetector(
          onTap: () => widget.onClickShowMore(false),
          child: const SizedBox(
            height: 34,
            child: Icon(
              Icons.cancel_outlined,
              color: Color(0xFF444444),
              size: 26,
            ),
          ),
        ),
        ...emojiData.map(_buildEmojiButton),
      ],
    );
  }

  Widget _buildSimplePanel(TUITheme theme) {
    final List<Map<String, Object>> emojiData = messageReactionEmojiData;
    final isDesktopScreen =
        TUIKitScreenUtils.getFormFactor() == DeviceType.Desktop;

    if (isDesktopScreen) {
      return Material(
        color: Colors.white,
        child: ExtendedWrap(
          maxLines: widget.isShowMoreSticker ? 5 : 1,
          spacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 24,
          children: [
            ...emojiData.map(_buildEmojiButton),
          ],
        ),
      );
    }

    if (widget.isShowMoreSticker) {
      return _buildExpandedPanel(emojiData);
    }

    return _buildCompactReactionRow(emojiData);
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final TUITheme theme = value.theme;

    return _buildSimplePanel(theme);
  }
}
