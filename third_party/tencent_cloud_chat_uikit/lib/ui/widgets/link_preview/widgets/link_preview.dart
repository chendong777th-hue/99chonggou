import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_stateless_widget.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/models/link_preview_content.dart';

class LinkPreviewWidget extends TIMStatelessWidget {
  final LocalCustomDataModel linkPreview;

  /// 所在消息气泡背景色，用于适配深浅气泡上的预览卡片对比度。
  final Color? bubbleBackgroundColor;

  const LinkPreviewWidget({
    Key? key,
    required this.linkPreview,
    this.bubbleBackgroundColor,
  }) : super(key: key);

  @override
  Widget timBuild(BuildContext context) {
    if (linkPreview.isLinkPreviewEmpty()) {
      return Container();
    }
    final theme = Provider.of<TUIThemeViewModel>(context, listen: false).theme;
    final bubbleColor = bubbleBackgroundColor ??
        theme.chatMessageItemFromOthersBgColor ??
        const Color(0xFFEDEDED);
    final titleColor = MessageBubbleTextColor.linkPreviewTitle(
      theme: theme,
      backgroundColor: bubbleColor,
    );
    final descriptionColor = MessageBubbleTextColor.linkPreviewDescription(
      theme: theme,
      backgroundColor: bubbleColor,
    );
    final cardBg = MessageBubbleTextColor.linkPreviewCardBackground(bubbleColor);
    final cardBorder = MessageBubbleTextColor.linkPreviewCardBorder(bubbleColor);

    return GestureDetector(
      onTap: () {
        if (linkPreview.url != null) {
          LinkUtils.launchURL(context, linkPreview.url!);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 8, right: 8),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: cardBorder),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (linkPreview.title != null && linkPreview.title!.isNotEmpty)
              Text(
                linkPreview.title!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.0,
                  color: titleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (linkPreview.image != null && linkPreview.image!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      height: 40,
                      width: 40,
                      child: Image.network(linkPreview.image!),
                    ),
                  ),
                if (linkPreview.description != null &&
                    linkPreview.description!.isNotEmpty)
                  Expanded(
                    child: Text(
                      linkPreview.description!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: descriptionColor,
                      ),
                    ),
                  ),
                if ((linkPreview.description == null ||
                        linkPreview.description!.isEmpty) &&
                    linkPreview.title != null &&
                    linkPreview.title!.isNotEmpty)
                  Expanded(
                    child: Text(
                      linkPreview.title!,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: descriptionColor,
                      ),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
