import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 公众号图文 / 链接类自定义消息（兼容 text_link、order 及控制台推送字段）。
class OfficialAccountArticleMessage {
  final String? businessID;
  final String title;
  final String description;
  final String? imageUrl;
  final String? link;

  const OfficialAccountArticleMessage({
    this.businessID,
    required this.title,
    this.description = '',
    this.imageUrl,
    this.link,
  });

  bool get hasCardContent =>
      title.isNotEmpty ||
      description.isNotEmpty ||
      (imageUrl?.isNotEmpty ?? false) ||
      (link?.isNotEmpty ?? false);

  /// 是否应以图文卡片展示（有封面图，或标题+跳转链接）。
  bool get shouldRenderAsArticleCard =>
      (imageUrl?.isNotEmpty ?? false) ||
      (title.isNotEmpty && (link?.isNotEmpty ?? false));
}

const _nestedObjectKeys = [
  'MsgContent',
  'msgContent',
  'msg_content',
  'content',
  'payload',
  'data',
  'Data',
  'body',
  'article',
  'pushContent',
  'push_content',
  'message',
  'detail',
];

const _nestedListKeys = [
  'articles',
  'itemList',
  'items',
  'news_item',
  'newsItem',
  'list',
];

Map<String, dynamic>? _decodeJsonMap(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    if (decoded is String) {
      return _decodeJsonMap(decoded);
    }
  } catch (_) {}
  return null;
}

void _collectCandidateMaps(
  List<Map<String, dynamic>> out,
  dynamic value, {
  int depth = 0,
}) {
  if (depth > 6 || value == null) {
    return;
  }

  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    out.add(map);
    for (final key in _nestedObjectKeys) {
      if (map.containsKey(key)) {
        _collectCandidateMaps(out, map[key], depth: depth + 1);
      }
    }
    for (final key in _nestedListKeys) {
      final list = map[key];
      if (list is List) {
        for (final item in list) {
          _collectCandidateMaps(out, item, depth: depth + 1);
        }
      }
    }
    return;
  }

  if (value is String) {
    final map = _decodeJsonMap(value);
    if (map != null) {
      _collectCandidateMaps(out, map, depth: depth + 1);
    }
  }
}

String? _pickString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) {
      continue;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty) {
      return text;
    }
  }
  return null;
}

String? _pickImageUrl(Map<String, dynamic> map) {
  final direct = _pickString(map, [
    'imageUrl',
    'image_url',
    'image',
    'Image',
    'cover',
    'coverUrl',
    'cover_url',
    'coverImage',
    'cover_image',
    'pic',
    'picUrl',
    'pic_url',
    'picture',
    'pictureUrl',
    'picture_url',
    'thumb',
    'thumbUrl',
    'thumb_url',
    'thumbnail',
    'thumbnail_url',
    'img',
    'imgUrl',
    'img_url',
    'imageLink',
    'image_link',
    'pushImage',
    'push_image',
    'mediaUrl',
    'media_url',
    'banner',
    'bannerUrl',
    'banner_url',
  ]);
  if (direct != null && _looksLikeHttpUrl(direct)) {
    return direct;
  }
  return _pickHttpImageUrlFromMap(map);
}

String? _pickHttpImageUrlFromMap(Map<String, dynamic> map) {
  for (final entry in map.entries) {
    final value = entry.value;
    if (value is String && _looksLikeImageUrl(value)) {
      return value.trim();
    }
    if (value is Map) {
      final nested = _pickHttpImageUrlFromMap(Map<String, dynamic>.from(value));
      if (nested != null) {
        return nested;
      }
    }
  }
  return null;
}

bool _looksLikeHttpUrl(String value) {
  final lower = value.trim().toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://');
}

bool _looksLikeImageUrl(String value) {
  if (!_looksLikeHttpUrl(value)) {
    return false;
  }
  final lower = value.toLowerCase();
  if (RegExp(r'\.(jpg|jpeg|png|gif|webp|bmp)(\?|$)').hasMatch(lower)) {
    return true;
  }
  return lower.contains('cos.') ||
      lower.contains('/image') ||
      lower.contains('console-official');
}

OfficialAccountArticleMessage? _buildFromCandidateMaps(
  List<Map<String, dynamic>> candidates, {
  String? titleFallback,
  String? descriptionFallback,
}) {
  if (candidates.isEmpty &&
      (titleFallback == null || titleFallback.isEmpty) &&
      (descriptionFallback == null || descriptionFallback.isEmpty)) {
    return null;
  }

  String? businessID;
  String? title;
  String? description;
  String? imageUrl;
  String? link;
  String? legacyText;

  for (final map in candidates) {
    businessID ??= _pickString(map, ['businessID', 'businessId', 'type']);
    title ??= _pickString(map, [
      'title',
      'Title',
      'name',
      'headline',
      'subject',
      'pushContent',
      'push_content',
      'msgContent',
      'textContent',
      'message',
    ]);
    description ??= _pickString(map, [
      'description',
      'desc',
      'summary',
      'digest',
      'content',
      'abstract',
      'intro',
      'subTitle',
      'subtitle',
    ]);
    imageUrl ??= _pickImageUrl(map);
    link ??= _pickString(map, [
      'link',
      'url',
      'jumpUrl',
      'jump_url',
      'href',
      'detailUrl',
      'detail_url',
      'webUrl',
      'web_url',
      'targetUrl',
      'pageUrl',
    ]);
    legacyText ??= _pickString(map, ['text', 'Text']);
  }

  title ??= legacyText?.trim();
  title ??= titleFallback?.trim();
  description ??= descriptionFallback?.trim();

  if ((title == null || title.isEmpty) && (legacyText?.isNotEmpty ?? false)) {
    final lines = legacyText!
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      title = lines.first;
      if (lines.length > 1 && (description == null || description.isEmpty)) {
        description = lines.sublist(1).join('\n');
      }
    }
  }

  link ??= '';
  if ((title == null || title.isEmpty) &&
      (description == null || description.isEmpty) &&
      (imageUrl == null || imageUrl.isEmpty) &&
      link.isEmpty) {
    return null;
  }

  return OfficialAccountArticleMessage(
    businessID: businessID,
    title: title ?? '',
    description: description ?? '',
    imageUrl: imageUrl,
    link: link.isNotEmpty ? link : null,
  );
}

List<Map<String, dynamic>> _mapsFromCustomElem(V2TimCustomElem customElem) {
  final candidates = <Map<String, dynamic>>[];
  _collectCandidateMaps(candidates, customElem.data);
  _collectCandidateMaps(candidates, customElem.extension);
  _collectCandidateMaps(candidates, customElem.desc);
  return candidates;
}

OfficialAccountArticleMessage? parseOfficialAccountArticleMessage(
  V2TimCustomElem? customElem,
) {
  if (customElem == null) {
    return null;
  }

  final candidates = _mapsFromCustomElem(customElem);
  final rawData = customElem.data?.trim() ?? '';
  final desc = customElem.desc?.trim() ?? '';

  if (candidates.isEmpty) {
    if (rawData.startsWith('http')) {
      return OfficialAccountArticleMessage(
        title: desc,
        link: rawData,
      );
    }
    if (rawData.isNotEmpty || desc.isNotEmpty) {
      return OfficialAccountArticleMessage(
        title: rawData.isNotEmpty ? rawData : desc,
        description: rawData.isNotEmpty ? desc : '',
      );
    }
    return null;
  }

  return _buildFromCandidateMaps(
    candidates,
    titleFallback: _decodeJsonMap(rawData) == null && rawData.isNotEmpty ? rawData : null,
    descriptionFallback: _decodeJsonMap(desc) == null ? desc : null,
  );
}

OfficialAccountArticleMessage? parseOfficialAccountArticleFromMessage(
  V2TimMessage message,
) {
  OfficialAccountArticleMessage? article =
      parseOfficialAccountArticleMessage(message.customElem);

  final extraCandidates = <Map<String, dynamic>>[];
  _collectCandidateMaps(extraCandidates, message.cloudCustomData);
  final fromCloud = _buildFromCandidateMaps(extraCandidates);
  article = _mergeArticles(article, fromCloud);

  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
    final text = message.textElem?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      final textArticle = OfficialAccountArticleMessage(
        title: text,
        imageUrl: article?.imageUrl,
        link: article?.link,
        description: article?.description ?? '',
        businessID: article?.businessID,
      );
      article = _mergeArticles(article, textArticle);
    }
  }

  return article;
}

OfficialAccountArticleMessage? _mergeArticles(
  OfficialAccountArticleMessage? base,
  OfficialAccountArticleMessage? extra,
) {
  if (extra == null) {
    return base;
  }
  if (base == null) {
    return extra;
  }
  return OfficialAccountArticleMessage(
    businessID: base.businessID ?? extra.businessID,
    title: base.title.isNotEmpty ? base.title : extra.title,
    description: base.description.isNotEmpty ? base.description : extra.description,
    imageUrl: (base.imageUrl?.isNotEmpty ?? false) ? base.imageUrl : extra.imageUrl,
    link: (base.link?.isNotEmpty ?? false) ? base.link : extra.link,
  );
}
