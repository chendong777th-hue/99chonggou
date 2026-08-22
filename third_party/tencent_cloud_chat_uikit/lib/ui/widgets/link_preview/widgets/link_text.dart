// ignore_for_file: deprecated_member_use

import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_stateless_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/chat_id_mention_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/http_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/compiler/md_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/DefaultSpecialTextSpanBuilder.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_bubble_text_color.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/link_text_parse_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/regexp_probe.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:tim_ui_kit_sticker_plugin/utils/tim_custom_face_data.dart';

typedef ImageBuilder = Widget Function(
    Uri uri, String? imageDirectory, double? width, double? height);

class LinkTextMarkdown extends TIMStatelessWidget {
  /// Callback for when link is tapped
  final void Function(String)? onLinkTap;

  /// message text
  final String messageText;

  /// text style for default words
  final TextStyle? style;

  final bool? isEnableTextSelection;

  final bool isUseQQPackage;

  final bool isUseTencentCloudChatPackage;

  final bool isUseTencentCloudChatPackageOldKeys;

  final List<CustomEmojiFaceData> customEmojiStickerList;

  const LinkTextMarkdown(
      {Key? key,
      required this.messageText,
      this.isUseQQPackage = false,
      this.isUseTencentCloudChatPackage = false,
      this.isUseTencentCloudChatPackageOldKeys = false,
      this.customEmojiStickerList = const [],
      this.isEnableTextSelection,
      this.onLinkTap,
      this.style})
      : super(key: key);

  @override
  Widget timBuild(BuildContext context) {
    final onLightBubble = MessageBubbleTextColor.bodyStyleOnLightBubble(style);
    final linkColor =
        onLightBubble ? Colors.white : const Color(0xFF1E90FF);
    return MarkdownBody(
      data: mdTextCompiler(messageText,
          isUseTencentCloudChatPackage: isUseTencentCloudChatPackage,
          customEmojiStickerList: customEmojiStickerList),
      selectable: isEnableTextSelection ?? false,
      styleSheet: MarkdownStyleSheet.fromTheme(ThemeData(
              textTheme: TextTheme(
                  bodyMedium: style ?? const TextStyle(fontSize: 16.0))))
          .copyWith(
        a: TextStyle(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      extensionSet: md.ExtensionSet.gitHubWeb,
      onTapLink: (
        String link,
        String? href,
        String title,
      ) {
        if (onLinkTap != null) {
          onLinkTap!(href ?? "");
        } else {
          LinkUtils.launchURL(context, href ?? "");
        }
      },
    );
  }
}

class _LinkTextSegment {
  final int start;
  final int end;
  final bool isUrl;

  const _LinkTextSegment({
    required this.start,
    required this.end,
    required this.isUrl,
  });
}

class LinkText extends TIMStatelessWidget {
  /// Callback for when link is tapped
  final void Function(String)? onLinkTap;

  /// Callback for when `@userId` / `@groupId` is tapped (id without `@`).
  final void Function(String id)? onTapChatIdMention;

  /// message text
  final String messageText;

  /// text style for default words
  final TextStyle? style;

  final bool isUseQQPackage;

  final bool isUseTencentCloudChatPackage;

  final bool isUseTencentCloudChatPackageOldKeys;

  final List<CustomEmojiFaceData> customEmojiStickerList;

  final bool? isEnableTextSelection;

  const LinkText(
      {Key? key,
      required this.messageText,
      this.onLinkTap,
      this.onTapChatIdMention,
      this.isEnableTextSelection,
      this.style,
      this.isUseQQPackage = false,
      this.isUseTencentCloudChatPackage = false,
      this.isUseTencentCloudChatPackageOldKeys = false,
      this.customEmojiStickerList = const []})
      : super(key: key);

  List<_LinkTextSegment> _collectSegments(String text) {
    return RegExpProbe.measure('link.LinkText.scan', () {
      final segments = <_LinkTextSegment>[];
      final mayUrl = _mayContainUrlCandidate(text);
      final mayMention =
          onTapChatIdMention != null && _mayContainMentionCandidate(text);
      if (!mayUrl && !mayMention) {
        return segments;
      }
      if (mayUrl) {
        for (final match in LinkUtils.urlReg.allMatches(text)) {
          segments.add(_LinkTextSegment(
            start: match.start,
            end: match.end,
            isUrl: true,
          ));
        }
      }
      if (mayMention) {
        final mentionMatches = [
          ...LinkUtils.chatIdMentionReg.allMatches(text),
          ...LinkUtils.groupAtMentionReg.allMatches(text),
        ]..sort((a, b) => a.start.compareTo(b.start));
        for (final match in mentionMatches) {
          final overlapsUrl = segments.any(
            (segment) => match.start < segment.end && match.end > segment.start,
          );
          final overlapsMention = segments.any(
            (segment) =>
                !segment.isUrl &&
                match.start < segment.end &&
                match.end > segment.start,
          );
          if (!overlapsUrl && !overlapsMention) {
            segments.add(_LinkTextSegment(
              start: match.start,
              end: match.end,
              isUrl: false,
            ));
          }
        }
      }
      segments.sort((a, b) => a.start.compareTo(b.start));
      return segments;
    });
  }

  /// Cheap mention gate: no `@` means mention regexes cannot match.
  bool _mayContainMentionCandidate(String text) => text.contains('@');

  /// Cheap URL gate aligned with [LinkUtils.urlReg] prefixes
  /// (`http` / `https` / `www.` / `wap.` / `ftp.` / `file.`), ASCII case-insensitive,
  /// without allocating via `toLowerCase`.
  bool _mayContainUrlCandidate(String text) {
    if (text.length < 5) {
      return false;
    }
    return _containsAsciiIgnoreCase(text, 'http') ||
        _containsAsciiIgnoreCase(text, 'www.') ||
        _containsAsciiIgnoreCase(text, 'wap.') ||
        _containsAsciiIgnoreCase(text, 'ftp.') ||
        _containsAsciiIgnoreCase(text, 'file.');
  }

  bool _containsAsciiIgnoreCase(String haystack, String needle) {
    final nLen = needle.length;
    if (nLen == 0 || haystack.length < nLen) {
      return false;
    }
    final end = haystack.length - nLen;
    for (var i = 0; i <= end; i++) {
      var matched = true;
      for (var j = 0; j < nLen; j++) {
        final hc = haystack.codeUnitAt(i + j);
        final nc = needle.codeUnitAt(j);
        if (hc == nc) {
          continue;
        }
        final hFold = (hc >= 65 && hc <= 90) ? hc + 32 : hc;
        final nFold = (nc >= 65 && nc <= 90) ? nc + 32 : nc;
        if (hFold != nFold) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return true;
      }
    }
    return false;
  }

  String _getContentSpan(String text, BuildContext context) {
    final webZeroWidthPrefix = PlatformUtils().isWeb;
    return LinkTextParseCache.instance.getFlaggedContent(
      text: text,
      scanMentions: onTapChatIdMention != null,
      webZeroWidthPrefix: webZeroWidthPrefix,
      compute: () {
        String contentData = webZeroWidthPrefix ? '\u200B' : "";
        final segments = _collectSegments(text);
        var index = 0;

        for (final segment in segments) {
          if (index < segment.start) {
            contentData += text.substring(index, segment.start);
          }
          final segmentText = text.substring(segment.start, segment.end);
          if (segment.isUrl) {
            contentData += HttpText.flag + segmentText + HttpText.flag;
          } else {
            contentData +=
                ChatIdMentionText.flag + segmentText + ChatIdMentionText.flag;
          }
          index = segment.end;
        }
        if (index < text.length) {
          contentData += text.substring(index);
        }

        return contentData;
      },
    );
  }

  @override
  Widget timBuild(BuildContext context) {
    return ExtendedText(_getContentSpan(messageText, context), softWrap: true,
        onSpecialTextTap: (dynamic parameter) {
      final raw = parameter.toString();
      if (raw.startsWith(HttpText.flag)) {
        final url = raw.replaceAll(HttpText.flag, '');
        if (onLinkTap != null) {
          onLinkTap!(url);
        } else {
          LinkUtils.launchURL(context, url);
        }
        return;
      }
      if (raw.startsWith(ChatIdMentionText.flag) && onTapChatIdMention != null) {
        final mention = raw.replaceAll(ChatIdMentionText.flag, '');
        onTapChatIdMention!(ChatIdMentionText.parseRawId(mention));
      }
    },
        style: style ?? const TextStyle(fontSize: 16.0),
        specialTextSpanBuilder: DefaultSpecialTextSpanBuilder(
          isUseQQPackage: isUseQQPackage,
          isUseTencentCloudChatPackage: isUseTencentCloudChatPackage,
          isUseTencentCloudChatPackageOldKeys: isUseTencentCloudChatPackageOldKeys,
          customEmojiStickerList: customEmojiStickerList,
          showAtBackground: true,
          checkChatIdMention: onTapChatIdMention != null,
          onTapChatIdMention: onTapChatIdMention,
        ));
  }
}
