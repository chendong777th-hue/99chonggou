import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/archive_im_local_persist_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/image_types.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_file_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_file_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_face_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_face_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_text_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';

import '../api/message_archive_api.dart';

/// 归档相关兼容层。
///
/// 历史消息由腾讯 IM SDK 提供；本类只保留清空水位同步和快照消息的
/// 本地转换，避免删除历史查询后影响已有快照/清空调用契约。
class MessageArchiveHistoryService {
  MessageArchiveHistoryService._();

  /// 归档补拉诊断。完成后关闭；排查归档链路时再临时改为 true。
  static const bool traceEnabled = false;

  static void _trace(String message) {
    if (!traceEnabled) {
      return;
    }
    // ignore: avoid_print
    print(message);
  }

  static void _traceDebug(String message) {
    if (!traceEnabled) {
      return;
    }
    debugPrint(message);
  }

  /// 在 app 启动时调用一次，仅注册清空同步；历史查询已由 SDK 自己负责。
  static void register() {
    ArchiveHistoryProvider.registerClearSync(_syncClearHistory);
  }

  static Future<void> _syncClearHistory({
    required bool isGroup,
    required String conversationID,
  }) async {
    final id = _apiConversationId(
      ArchiveHistoryRequest(
        isGroup: isGroup,
        conversationID: conversationID,
        count: 1,
      ),
    );
    try {
      if (isGroup) {
        await MessageArchiveApi.instance.clearGroup(groupId: id);
      } else {
        await MessageArchiveApi.instance.clearC2c(peerUserId: id);
      }
    } catch (e) {
      _traceDebug(
        '[ArchiveClear] error conv=$id isGroup=$isGroup err=$e',
      );
    }
    // 清档可能连带丢掉服务端会话归档标记；本地已归档的重申一次，
    // 避免归档会话清空记录后掉回主消息列表。
    try {
      await ArchivedConversationSyncService.instance
          .reassertArchivedAfterHistoryClear(
        isGroup: isGroup,
        peerId: id,
      );
    } catch (e) {
      _traceDebug(
        '[ArchiveClear] reassert archived failed conv=$id err=$e',
      );
    }
  }

  /// 归档清空 API 用的会话 ID：群聊走后端短码 [ChatIdFormat.apiGroupId]，禁止拼 `@TGS#_@TGS#`。
  static String _apiConversationId(ArchiveHistoryRequest req) {
    var id = req.conversationID.trim();
    if (id.isEmpty) {
      return id;
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('group_')) {
      id = id.substring(6);
    } else if (lower.startsWith('c2c_')) {
      id = id.substring(4);
    }
    if (req.isGroup) {
      id = ChatIdFormat.apiGroupId(id);
    }
    return id;
  }

  /// H1-hide：解析历史条目发送方业务号（优先 fromUserId）。
  @visibleForTesting
  static String? resolveHistorySenderId(Map<String, dynamic> item) {
    final fromUserId =
        _asString(item['fromUserId']) ?? _asString(item['from_user_id']);
    if (fromUserId != null && fromUserId.isNotEmpty) {
      return ChatIdFormat.rawUserUid(fromUserId);
    }
    final fromAccount =
        _asString(item['fromAccount']) ?? _asString(item['from_account']);
    if (fromAccount == null || fromAccount.isEmpty) {
      return null;
    }
    return ChatIdFormat.rawUserUid(fromAccount);
  }

  /// 将 HistoryItem 转为 [V2TimMessage]（有真 `msgId` 时 UI/落库身份用腾讯 id）。
  static V2TimMessage? convertItem(
    Map<String, dynamic> item,
    ArchiveHistoryRequest req,
  ) {
    final msgKey = _asString(item['msgKey']);
    if (msgKey == null || msgKey.isEmpty) {
      return null;
    }
    final cloudMsgId = _asString(item['msgId']) ?? _asString(item['msg_id']);
    final fromRaw = resolveHistorySenderId(item) ?? '';
    final msgTimeMs = _asInt(item['msgTimeMs']) ?? 0;
    final msgSeq = _asInt(item['msgSeq']);
    final status = _asInt(item['status']) ?? 1;
    final previewText = _asString(item['previewText']) ?? '';
    final body = item['msgBody'];
    final elems = body is List ? body : const <dynamic>[];
    final Map<String, dynamic> first = (elems.isNotEmpty && elems.first is Map)
        ? Map<String, dynamic>.from(elems.first as Map)
        : <String, dynamic>{};
    final msgType = _asString(first['MsgType']);
    final Map<String, dynamic> content = first['MsgContent'] is Map
        ? Map<String, dynamic>.from(first['MsgContent'] as Map)
        : <String, dynamic>{};

    final msg = V2TimMessage(
      elemType: MessageElemType.V2TIM_ELEM_TYPE_NONE,
    );
    final useCloudId = cloudMsgId != null &&
        cloudMsgId.isNotEmpty &&
        ArchiveImLocalPersistService.isTrustedCloudMsgId(cloudMsgId);
    msg.msgID = useCloudId ? cloudMsgId : msgKey;
    msg.timestamp = (msgTimeMs / 1000).round();
    final loginUserId = req.loginUserID?.trim() ?? '';
    final loginRaw = ChatIdFormat.rawUserUid(loginUserId);
    msg.sender = fromRaw;
    msg.isSelf =
        fromRaw.isNotEmpty && loginRaw.isNotEmpty && fromRaw == loginRaw;
    msg.groupID = req.isGroup ? req.conversationID : null;
    msg.userID = req.isGroup ? null : req.conversationID;
    msg.seq = msgSeq?.toString();
    // C2C 归档 msgKey 常见形如 seq_random_ts，写入 random 供跨源 wire identity。
    final msgRandom = _asInt(item['msgRandom']) ?? _asInt(item['random']);
    if (msgRandom != null && msgRandom > 0) {
      msg.random = msgRandom;
    } else if (!req.isGroup) {
      final keyParts = msgKey.split('_');
      if (keyParts.length == 3) {
        final parsedRandom = int.tryParse(keyParts[1]) ?? 0;
        if (parsedRandom > 0) {
          msg.random = parsedRandom;
        }
      }
    }
    msg.isRead = true;
    msg.isPeerRead = true;
    // status: 0=撤回，其余=正常。撤回消息保留但标记为已撤回态。
    msg.status = status == 0
        ? MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED
        : MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    // 标记归档来源：聊天气泡据此跳过 SDK downloadMessage。
    msg.localCustomData = jsonEncode(<String, Object?>{
      'archiveHistory': true,
      'archiveMsgKey': msgKey,
    });

    _applyElem(msg, msgType, content, previewText);
    return msg;
  }

  static void _applyElem(
    V2TimMessage msg,
    String? msgType,
    Map<String, dynamic> content,
    String previewText,
  ) {
    switch (msgType) {
      case 'TIMTextElem':
        final elem = V2TimTextElem(text: _asString(content['Text']) ?? '');
        msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
        msg.textElem = elem;
        msg.elemList = <dynamic>[elem];
        return;
      case 'TIMCustomElem':
        final elem = V2TimCustomElem(
          data: _asString(content['Data']),
          desc: _asString(content['Desc']),
          extension: _asString(content['Ext']),
        );
        msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
        msg.customElem = elem;
        msg.elemList = <dynamic>[elem];
        return;
      case 'TIMImageElem':
        final elem = _buildImageElem(content);
        if (elem != null) {
          msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
          msg.imageElem = elem;
          msg.elemList = <dynamic>[elem];
          return;
        }
        break;
      case 'TIMVideoFileElem':
        final elem = _buildVideoElem(content);
        if (elem != null) {
          msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
          msg.videoElem = elem;
          msg.elemList = <dynamic>[elem];
          return;
        }
        break;
      case 'TIMFaceElem':
        final elem = _buildFaceElem(content);
        if (elem != null) {
          msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_FACE;
          msg.faceElem = elem;
          msg.elemList = <dynamic>[elem];
          return;
        }
        break;
      case 'TIMSoundElem':
        final elem = _buildSoundElem(content);
        if (elem != null) {
          msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_SOUND;
          msg.soundElem = elem;
          msg.elemList = <dynamic>[elem];
          return;
        }
        break;
      case 'TIMFileElem':
        final elem = _buildFileElem(content);
        if (elem != null) {
          msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_FILE;
          msg.fileElem = elem;
          msg.elemList = <dynamic>[elem];
          return;
        }
        break;
    }
    // 其余类型暂用摘要文本兜底，保证不崩、可读。
    _traceDebug(
      '[ArchiveElem] fallback msgType=$msgType preview="$previewText" '
      'contentKeys=${content.keys.toList()}',
    );
    final fallback = V2TimTextElem(
      text: previewText.isNotEmpty ? previewText : '[消息]',
    );
    msg.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
    msg.textElem = fallback;
    msg.elemList = <dynamic>[fallback];
  }

  static V2TimImageElem? _buildImageElem(Map<String, dynamic> content) {
    final infoArray = content['ImageInfoArray'] ??
        content['imageInfoArray'] ??
        content['ImageInfoList'];
    if (infoArray is! List || infoArray.isEmpty) {
      _traceDebug(
          '[ArchiveImg] no ImageInfoArray keys=${content.keys.toList()}');
      return null;
    }
    final images = <V2TimImage>[];
    final urlDebug = <String>[];
    for (final raw in infoArray) {
      if (raw is! Map) continue;
      final info = Map<String, dynamic>.from(raw);
      final tencentType = _asInt(info['Type'] ?? info['type']) ?? 1;
      final url = _asString(info['URL'] ?? info['Url'] ?? info['url']);
      urlDebug
          .add('t$tencentType=${url == null || url.isEmpty ? "EMPTY" : url}');
      images.add(V2TimImage(
        type: _mapImageType(tencentType),
        uuid: _asString(content['UUID'] ?? content['uuid']),
        url: url,
        size: _asInt(info['Size'] ?? info['size']),
        width: _asInt(info['Width'] ?? info['width']),
        height: _asInt(info['Height'] ?? info['height']),
      ));
    }
    _trace(
      '[ArchiveImg] extracted msgKeyHint=${_asString(content['UUID']) ?? ""} '
      '${urlDebug.join(" | ")}',
    );
    if (images.isEmpty) {
      return null;
    }
    return V2TimImageElem(path: '', imageList: images);
  }

  static V2TimVideoElem? _buildVideoElem(Map<String, dynamic> content) {
    final videoUrl = _pick(content, ['VideoUrl', 'VideoURL', 'videoUrl']);
    final thumbUrl = _pick(content, ['ThumbUrl', 'ThumbURL', 'thumbUrl']);
    _traceDebug(
      '[ArchiveVideo] videoUrl=${videoUrl ?? "EMPTY"} thumbUrl=${thumbUrl ?? "EMPTY"} '
      'keys=${content.keys.toList()}',
    );
    // 至少要有视频 URL 或封面 URL 才有意义，否则交回文本兜底。
    if ((videoUrl == null || videoUrl.isEmpty) &&
        (thumbUrl == null || thumbUrl.isEmpty)) {
      return null;
    }
    return V2TimVideoElem(
      videoPath: '',
      UUID: _pick(content, ['VideoUUID', 'videoUUID']),
      videoSize: _asInt(_pickRaw(content, ['VideoSize', 'videoSize'])),
      duration: _asInt(_pickRaw(content, ['VideoSecond', 'videoSecond'])),
      videoType: _pick(content, ['VideoFormat', 'videoFormat']),
      videoUrl: videoUrl,
      snapshotPath: '',
      snapshotUUID: _pick(content, ['ThumbUUID', 'thumbUUID']),
      snapshotSize: _asInt(_pickRaw(content, ['ThumbSize', 'thumbSize'])),
      snapshotWidth: _asInt(_pickRaw(content, ['ThumbWidth', 'thumbWidth'])),
      snapshotHeight: _asInt(_pickRaw(content, ['ThumbHeight', 'thumbHeight'])),
      snapshotUrl: thumbUrl,
    );
  }

  static V2TimFaceElem? _buildFaceElem(Map<String, dynamic> content) {
    final index = _asInt(_pickRaw(content, ['Index', 'index']));
    final data = _pick(content, ['Data', 'data']);
    _traceDebug('[ArchiveFace] index=$index data=${data ?? "EMPTY"}');
    if (index == null && (data == null || data.isEmpty)) {
      return null;
    }
    return V2TimFaceElem(index: index, data: data);
  }

  static V2TimSoundElem? _buildSoundElem(Map<String, dynamic> content) {
    final url = _pick(content, ['Url', 'URL', 'url']);
    final uuid = _pick(content, ['UUID', 'uuid']);
    final size = _asInt(_pickRaw(content, ['Size', 'size']));
    final second =
        _asInt(_pickRaw(content, ['Second', 'second', 'Duration', 'duration']));
    _traceDebug(
      '[ArchiveSound] url=${url ?? "EMPTY"} uuid=${uuid ?? "EMPTY"} '
      'size=$size second=$second keys=${content.keys.toList()}',
    );
    if ((url == null || url.isEmpty) && (uuid == null || uuid.isEmpty)) {
      return null;
    }
    return V2TimSoundElem(
      path: '',
      UUID: uuid,
      dataSize: size,
      duration: second,
      url: url,
    );
  }

  static V2TimFileElem? _buildFileElem(Map<String, dynamic> content) {
    final url = _pick(content, ['Url', 'URL', 'url']);
    final uuid = _pick(content, ['UUID', 'uuid']);
    final fileName =
        _pick(content, ['FileName', 'fileName', 'Filename', 'filename']);
    final fileSize =
        _asInt(_pickRaw(content, ['FileSize', 'fileSize', 'Size', 'size']));
    _traceDebug(
      '[ArchiveFile] url=${url ?? "EMPTY"} uuid=${uuid ?? "EMPTY"} '
      'fileName=${fileName ?? "EMPTY"} fileSize=$fileSize keys=${content.keys.toList()}',
    );
    if ((url == null || url.isEmpty) &&
        (uuid == null || uuid.isEmpty) &&
        (fileName == null || fileName.isEmpty)) {
      return null;
    }
    final resolvedName = (fileName != null && fileName.isNotEmpty)
        ? fileName
        : (url != null && url.isNotEmpty
            ? Uri.tryParse(url)?.pathSegments.last
            : null);
    return V2TimFileElem(
      path: '',
      fileName: resolvedName,
      UUID: uuid,
      url: url,
      fileSize: fileSize,
    );
  }

  static String? _pick(Map<String, dynamic> map, List<String> keys) {
    return _asString(_pickRaw(map, keys));
  }

  static dynamic _pickRaw(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      if (map.containsKey(k) && map[k] != null) {
        return map[k];
      }
    }
    return null;
  }

  /// 腾讯 REST：1=原图 2=大图 3=缩略图 → SDK：0/2/1。
  static int _mapImageType(int tencentType) {
    switch (tencentType) {
      case 2:
        return V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_LARGE;
      case 3:
        return V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_THUMB;
      case 1:
      default:
        return V2TIM_IMAGE_TYPE.V2TIM_IMAGE_TYPE_ORIGIN;
    }
  }

  static String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
