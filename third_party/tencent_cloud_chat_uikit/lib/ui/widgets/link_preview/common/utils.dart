import 'dart:convert';
import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/common/extensions.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitTextField/special_text/chat_id_mention_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/link_preview_entry.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/link_text_parse_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/regexp_probe.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/parsing.dart';

class _MentionSpan {
  final int start;
  final int end;

  _MentionSpan(this.start, this.end);
}

class LinkUtils {
  static const Duration _previewTimeout = Duration(seconds: 5);
  static const int _previewMaxBytes = 512 * 1024;
  static const int _previewMaxConcurrent = 2;
  static const String _previewUserAgent = 'WhatsApp/2.21.12.21 A';
  static final _LinkPreviewLimiter _previewLimiter =
      _LinkPreviewLimiter(_previewMaxConcurrent);
  static final Map<String, Future<LocalCustomDataModel?>> _previewInFlight =
      <String, Future<LocalCustomDataModel?>>{};

  static RegExp urlReg = RegExp(
      r"([hH][tT]{2}[pP]:\/\/|[hH][tT]{2}[pP][sS]:\/\/|[wW]{3}.|[wW][aA][pP].|[fF][tT][pP].|[fF][iI][lL][eE].)[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]");

  /// 消息内可点击 ID：完整社群/公开群 ID 优先，再 UID / 社群短码。
  ///
  /// 完整社群形如 `@TGS#_@TGS#cL54…`（中间含 `@`），必须整段匹配，
  /// 否则会被截成 `@TGS` / `@TGS#_`。
  static final RegExp chatIdMentionReg = RegExp(
    r'(?<![A-Za-z0-9.])@(?:'
    r'TGS#_@TGS#[A-Za-z0-9_]+'
    r'|TGS#[A-Za-z0-9_]+'
    r'|[a-z0-9_]{2,32}'
    r'|[A-Za-z0-9_]*[A-Z][A-Za-z0-9_]{0,31}'
    r')(?![A-Za-z0-9_#])',
    caseSensitive: false,
  );

  /// 群 @成员昵称：可含中文/emoji；后接空格、标点或消息结尾（发送时 trim 会去掉末尾空格）。
  static final RegExp groupAtMentionReg = RegExp(
    r'(?<![A-Za-z0-9.])@([^\s@]+)'
    r'(?=\s|$|[，,。！？!?；;：:\.）\)】\]])',
  );

  static String wrapChatIdMentionsForExtendedText(String text) {
    return LinkTextParseCache.instance.getWrappedMentions(
      text: text,
      compute: () => RegExpProbe.measure('link.wrapMentions', () {
        if (!_mayContainMentionCandidate(text)) {
          return text;
        }
        final spans = <_MentionSpan>[];
        for (final match in chatIdMentionReg.allMatches(text)) {
          spans.add(_MentionSpan(match.start, match.end));
        }
        for (final match in groupAtMentionReg.allMatches(text)) {
          final start = match.start;
          final end = match.end;
          final overlaps = spans.any((s) => start < s.end && end > s.start);
          if (!overlaps) {
            spans.add(_MentionSpan(start, end));
          }
        }
        if (spans.isEmpty) {
          return text;
        }
        spans.sort((a, b) => a.start.compareTo(b.start));
        final buffer = StringBuffer();
        var index = 0;
        for (final span in spans) {
          if (index < span.start) {
            buffer.write(text.substring(index, span.start));
          }
          final segment = text.substring(span.start, span.end);
          buffer.write(
            '${ChatIdMentionText.flag}$segment${ChatIdMentionText.flag}',
          );
          index = span.end;
        }
        if (index < text.length) {
          buffer.write(text.substring(index));
        }
        return buffer.toString();
      }),
    );
  }

  /// Get all the URL from a text message
  static List<String> getURLMatches(String textMessage) {
    return LinkTextParseCache.instance.getUrlMatches(
      text: textMessage,
      compute: () => RegExpProbe.measure('link.getURLMatches', () {
        if (!_mayContainUrlCandidate(textMessage)) {
          return const <String>[];
        }
        final matches = urlReg.allMatches(textMessage).toList();

        List<String> urlMatches = [];

        for (Match m in matches) {
          String match = m.group(0) ?? "";
          urlMatches.add(match);
        }

        return urlMatches;
      }),
    );
  }

  /// Launch URL
  static Future<void> launchURL(BuildContext context, String url) async {
    try {
      await launchUrl(
        Uri.parse(url).withScheme,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TIM_t("无法打开URL"))), // Cannot launch the url
      );
    }
  }

  /// Get color
  static Color hexToColor(String hexString) {
    return Color(int.parse(hexString, radix: 16)).withAlpha(255);
  }

  /// Get the URL preview information
  static Future<List<LocalCustomDataModel>> getURLPreview(
      List<String> urlMatches) async {
    final urlPreview = <LocalCustomDataModel>[];
    final tasks = urlMatches.map(_getSafeURLPreview).toList(growable: false);
    final results = await Future.wait(tasks);
    for (final item in results) {
      if (item != null && !item.isLinkPreviewEmpty()) {
        urlPreview.add(item);
      }
    }
    return urlPreview;
  }

  static Future<LocalCustomDataModel?> _getSafeURLPreview(String rawUrl) {
    final normalizedUrl = _normalizePreviewUrl(rawUrl);
    if (normalizedUrl == null) {
      return Future.value();
    }
    final cachedFuture = _previewInFlight[normalizedUrl];
    if (cachedFuture != null) {
      return cachedFuture;
    }
    final future = _previewLimiter
        .schedule(() => _scrapeSafeURLPreview(normalizedUrl))
        .whenComplete(() => _previewInFlight.remove(normalizedUrl));
    _previewInFlight[normalizedUrl] = future;
    return future;
  }

  static String? _normalizePreviewUrl(String rawUrl) {
    var value = rawUrl.trim();
    if (value.isEmpty) {
      return null;
    }
    if (!value.toLowerCase().startsWith('http://') &&
        !value.toLowerCase().startsWith('https://')) {
      value = 'http://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return null;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }
    return uri.toString();
  }

  static Future<LocalCustomDataModel?> _scrapeSafeURLPreview(String url) {
    final task = kIsWeb
        ? _scrapeSafeURLPreviewWorker(url)
        : compute(_scrapeSafeURLPreviewWorker, url);
    return task.timeout(_previewTimeout, onTimeout: () => null);
  }

  /// save the link info to local and call updating the message on UI, only works with [onUpdateMessage]
  static Future<void> saveToLocalAndUpdate(
      V2TimMessage message,
      LocalCustomDataModel previewItem,
      ValueChanged<V2TimMessage> onUpdateMessage) async {
    if (message.msgID != null) {
      String saveInfo = LinkPreviewEntry.linkInfoToString(previewItem);
      final currentInfo = message.localCustomData;
      if (currentInfo != null && currentInfo.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(currentInfo);
        data['url'] = previewItem.url;
        data['image'] = previewItem.image;
        data['title'] = previewItem.title;
        data['description'] = previewItem.description;
        saveInfo = json.encode(data);
      }
      message.localCustomData = saveInfo;
      if (saveInfo != currentInfo) {
        final result = await TencentImSDKPlugin.v2TIMManager.v2TIMMessageManager
            .setLocalCustomData(
                msgID: message.msgID!, localCustomData: saveInfo);
        if (result.code == 0) {
          onUpdateMessage(message);
        }
      }
    }
  }
}

class _LinkPreviewLimiter {
  _LinkPreviewLimiter(this.maxConcurrent);

  final int maxConcurrent;
  final Queue<_PendingLinkPreview> _pending = Queue<_PendingLinkPreview>();
  int _running = 0;

  Future<LocalCustomDataModel?> schedule(
    Future<LocalCustomDataModel?> Function() task,
  ) {
    final pending = _PendingLinkPreview(task);
    _pending.add(pending);
    _pump();
    return pending.completer.future;
  }

  void _pump() {
    while (_running < maxConcurrent && _pending.isNotEmpty) {
      final pending = _pending.removeFirst();
      _running++;
      pending.run().then(pending.completer.complete).catchError(
        (_) {
          if (!pending.completer.isCompleted) {
            pending.completer.complete(null);
          }
        },
      ).whenComplete(() {
        _running--;
        _pump();
      });
    }
  }
}

class _PendingLinkPreview {
  _PendingLinkPreview(this.run);

  final Future<LocalCustomDataModel?> Function() run;
  final Completer<LocalCustomDataModel?> completer =
      Completer<LocalCustomDataModel?>();
}

Future<LocalCustomDataModel?> _scrapeSafeURLPreviewWorker(String url) async {
  final client = http.Client();
  try {
    final uri = Uri.parse(url);
    final request = http.Request('GET', uri)
      ..followRedirects = true
      ..headers.addAll(<String, String>{
        'User-Agent': LinkUtils._previewUserAgent,
        'Accept': 'text/html,application/xhtml+xml,image/*;q=0.8,*/*;q=0.5',
      });
    final response =
        await client.send(request).timeout(LinkUtils._previewTimeout);
    if (response.statusCode < 200 || response.statusCode >= 400) {
      return null;
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final contentLength = response.contentLength;
    if (contentLength != null && contentLength > LinkUtils._previewMaxBytes) {
      return null;
    }
    if (_isPreviewImage(contentType)) {
      return LocalCustomDataModel(
        url: url,
        title: _titleFromUrl(url),
        image: url,
        description: uri.host,
      );
    }
    if (contentType.isNotEmpty && !_isPreviewHtml(contentType)) {
      return null;
    }

    final bytes = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk
        in response.stream.timeout(LinkUtils._previewTimeout)) {
      totalBytes += chunk.length;
      if (totalBytes > LinkUtils._previewMaxBytes) {
        return null;
      }
      bytes.add(chunk);
    }

    final document = parseHtmlDocument(
      utf8.decode(bytes.takeBytes(), allowMalformed: true),
    );
    final title = _cleanPreviewText(
      _firstMetaContent(document, const <List<String>>[
            <String>['meta[property="og:title"]', 'content'],
            <String>['meta[name="twitter:title"]', 'content'],
          ]) ??
          document.title,
      maxLength: 120,
    );
    final description = _cleanPreviewText(
      _firstMetaContent(document, const <List<String>>[
        <String>['meta[property="og:description"]', 'content'],
        <String>['meta[name="twitter:description"]', 'content'],
        <String>['meta[name="description"]', 'content'],
      ]),
      maxLength: 240,
    );
    final image = _absolutePreviewUrl(
      url,
      _firstMetaContent(document, const <List<String>>[
        <String>['meta[property="og:image"]', 'content'],
        <String>['meta[property="og:image:secure_url"]', 'content'],
        <String>['meta[name="twitter:image"]', 'content'],
        <String>['meta[name="twitter:image:src"]', 'content'],
      ]),
    );

    return LocalCustomDataModel(
      url: url,
      title: title,
      image: image,
      description: description,
    );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

bool _isPreviewHtml(String contentType) {
  return contentType.contains('text/html') ||
      contentType.contains('application/xhtml+xml');
}

bool _isPreviewImage(String contentType) {
  return contentType.startsWith('image/');
}

String? _firstMetaContent(
  html.HtmlDocument document,
  List<List<String>> selectors,
) {
  for (final selector in selectors) {
    final value =
        document.querySelector(selector[0])?.getAttribute(selector[1]);
    final cleaned = _cleanPreviewText(value);
    if (cleaned != null && cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return null;
}

String? _absolutePreviewUrl(String baseUrl, String? value) {
  final cleaned = _cleanPreviewText(value);
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(cleaned);
  if (uri != null && uri.hasScheme) {
    return uri.toString();
  }
  return Uri.tryParse(baseUrl)?.resolve(cleaned).toString();
}

String? _cleanPreviewText(String? value, {int maxLength = 200}) {
  final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned == null || cleaned.isEmpty) {
    return null;
  }
  if (cleaned.length <= maxLength) {
    return cleaned;
  }
  return cleaned.substring(0, maxLength);
}

String _titleFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final segment =
      uri?.pathSegments.isNotEmpty == true ? uri!.pathSegments.last : uri?.host;
  return Uri.decodeComponent(segment ?? url);
}

/// Cheap mention gate: no `@` means mention regexes cannot match.
bool _mayContainMentionCandidate(String text) => text.contains('@');

/// Cheap URL gate aligned with [LinkUtils.urlReg] prefixes
/// (`http` / `https` / `www.` / `wap.` / `ftp.` / `file.`), ASCII case-insensitive,
/// without allocating via `toLowerCase`.
bool _mayContainUrlCandidate(String text) {
  // Shortest plausible urlReg hit is around `www.ab` / `ftp.ab` (6 chars).
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
      // ASCII a-z / A-Z fold only.
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
