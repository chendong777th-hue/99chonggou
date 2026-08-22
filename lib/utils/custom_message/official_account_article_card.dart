import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_element.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_article_message.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

class OfficialAccountArticleCard extends StatelessWidget {
  final OfficialAccountArticleMessage article;
  final TUITheme theme;

  const OfficialAccountArticleCard({
    super.key,
    required this.article,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final link = article.link?.trim() ?? '';
    final title = article.title.trim();
    final description = article.description.trim();
    final imageUrl = article.imageUrl?.trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: link.isNotEmpty
            ? () => CustomMessageElem.launchWebURL(context, link)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.center,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ColoredBox(
                        color: theme.weakDividerColor ?? const Color(0xFFE8E8E8),
                        child: Center(
                          child: LoadingAnimationWidget.threeArchedCircle(
                            color: theme.weakTextColor ?? Colors.grey,
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    color: theme.weakDividerColor ?? const Color(0xFFE8E8E8),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.weakTextColor,
                    ),
                  ),
                ),
              ),
            if (title.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(4, imageUrl.isNotEmpty ? 10 : 0, 4, 4),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: theme.weakTextColor ?? const Color(0xFF666666),
                  ),
                ),
              ),
            if (link.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                child: Text(
                  AppI18n.of(context).t(
                    zhHans: '查看详情 >>',
                    zhHant: '查看詳情 >>',
                    en: 'View details >>',
                    ja: '詳細を見る >>',
                    ko: '상세 보기 >>',
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    color: const Color(0xFF015FFF),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
