import 'dart:js_util';

import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_face_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_file_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_location_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_merger_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_sdk/web/enum/message_type.dart';
import 'package:tencent_cloud_chat_sdk/web/manager/im_sdk_plugin_js.dart';
import 'package:tencent_cloud_chat_sdk/web/manager/v2_tim_message_manager.dart';
import 'package:tencent_cloud_chat_sdk/web/utils/utils.dart';

class WebHistoryLoader {
  static Future<List<V2TimMessage>?> loadList({
    required HistoryMsgGetTypeEnum getType,
    String? userID,
    String? groupID,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    List<int>? messageTypeList,
  }) async {
    final res = await loadWithComplete(
      getType: getType,
      userID: userID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq,
      count: count,
      lastMsgID: lastMsgID,
      messageTypeList: messageTypeList,
    );
    return res?.messageList;
  }

  /// Web has no native local DB; LOCAL_* is treated as CLOUD_*.
  static HistoryMsgGetTypeEnum _normalizeGetType(HistoryMsgGetTypeEnum getType) {
    switch (getType) {
      case HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG:
        return HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG;
      case HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG:
        return HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG;
      default:
        return getType;
    }
  }

  static Future<dynamic> _waitForTim({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    var tim = V2TIMManagerWeb.timWeb ?? V2TIMMessageManager.timeweb;
    if (tim != null) {
      return tim;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      tim = V2TIMManagerWeb.timWeb ?? V2TIMMessageManager.timeweb;
      if (tim != null) {
        return tim;
      }
    }
    return V2TIMManagerWeb.timWeb ?? V2TIMMessageManager.timeweb;
  }

  static Future<V2TimMessageListResult?> loadWithComplete({
    required HistoryMsgGetTypeEnum getType,
    String? userID,
    String? groupID,
    int lastMsgSeq = 0,
    required int count,
    String? lastMsgID,
    List<int>? messageTypeList,
  }) async {
    final normalizedType = _normalizeGetType(getType);
    final target = _conversationTarget(userID: userID, groupID: groupID);
    if (target == null) {
      return V2TimMessageListResult(isFinished: true, messageList: []);
    }

    final timeweb = await _waitForTim();
    if (timeweb == null) {
      return null;
    }

    final params = <String, dynamic>{
      'conversationID': target,
      'count': count,
      'nextReqMessageID': lastMsgID,
      'direction': _isNewer(normalizedType) ? 1 : 0,
    };
    if (lastMsgSeq > 0) {
      params['sequence'] = lastMsgSeq;
    }

    final res = await wrappedPromiseToFuture(
      timeweb.getMessageListHopping(mapToJSObj(params)),
    );
    final code = _readInt(res, 'code') ?? _readInt(res, 'errorCode') ?? -1;
    if (code != 0) {
      return V2TimMessageListResult(isFinished: false, messageList: []);
    }

    final data = _toMap(_readAny(res, 'data'));
    final rawList = _toList(data['messageList']);
    // 缺失 isCompleted 时保守认为还有更早，避免 Web 过早停止上拉/归档。
    final isCompleted = _readBoolFromMap(data, 'isCompleted') ?? false;

    final messages = <V2TimMessage>[];
    final Iterable<dynamic> source = rawList.reversed.skipWhile((item) {
      final map = _toMap(item);
      return _readBoolFromMap(map, 'isDeleted') ?? false;
    });

    for (final raw in source) {
      try {
        final msg = _convertMessage(raw);
        if (msg != null) {
          final elem = msg.elemType;
          if (messageTypeList == null ||
              messageTypeList.isEmpty ||
              messageTypeList.contains(elem)) {
            messages.add(msg);
          }
        }
      } catch (_) {
        // A single malformed web message must not block the whole history page.
      }
    }

    return V2TimMessageListResult(
      isFinished: isCompleted,
      messageList:
          _isNewer(normalizedType) ? messages.reversed.toList() : messages,
    );
  }

  static String? _conversationTarget({String? userID, String? groupID}) {
    final group = (groupID ?? '').trim();
    final user = (userID ?? '').trim();
    if (group.isNotEmpty && user.isNotEmpty) {
      return null;
    }
    if (group.isNotEmpty) {
      return 'GROUP$group';
    }
    if (user.isNotEmpty) {
      return 'C2C$user';
    }
    return null;
  }

  static bool _isNewer(HistoryMsgGetTypeEnum getType) {
    return getType == HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG ||
        getType == HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG;
  }

  static V2TimMessage? _convertMessage(dynamic raw) {
    final message = _toMap(raw);
    if (message.isEmpty || (_readBoolFromMap(message, 'isDeleted') ?? false)) {
      return null;
    }

    final type = _readStringFromMap(message, 'type');
    final elemType = _convertElemType(type);
    final payload = _toMap(message['payload']);
    final conversationType = _readStringFromMap(message, 'conversationType');
    final conversationID = _readStringFromMap(message, 'conversationID');

    final msg = V2TimMessage(
      msgID: _readStringFromMap(message, 'ID') ?? '',
      timestamp: _readIntFromMap(message, 'time'),
      progress: 100,
      sender: _readStringFromMap(message, 'from') ??
          _readStringFromMap(message, 'fromAccount') ??
          '',
      nickName: _readStringFromMap(message, 'nick') ?? '',
      friendRemark: '',
      faceUrl: _readStringFromMap(message, 'avatar') ?? '',
      nameCard: _readStringFromMap(message, 'nameCard') ?? '',
      groupID: conversationType == 'GROUP' ? _readStringFromMap(message, 'to') : null,
      userID: conversationType == 'C2C' ? _stripC2C(conversationID) : null,
      status: _convertStatus(message),
      elemType: elemType,
      localCustomData: '',
      localCustomInt: 0,
      cloudCustomData: _readStringFromMap(message, 'cloudCustomData') ?? '',
      isSelf: _readStringFromMap(message, 'flow') == 'out',
      isRead: _readBoolFromMap(message, 'isRead') ?? false,
      isPeerRead: _readBoolFromMap(message, 'isPeerRead') ?? false,
      priority: _convertPriority(_readStringFromMap(message, 'priority')),
      groupAtUserList: _toStringList(message['atUserList']),
      seq: _readStringFromMap(message, 'sequence') ?? '',
      random: _readIntFromMap(message, 'random'),
      isExcludedFromUnreadCount:
          _readBoolFromMap(message, 'isExcludedFromUnreadCount') ?? false,
      isExcludedFromLastMessage:
          _readBoolFromMap(message, 'isExcludedFromLastMessage') ?? false,
      isSupportMessageExtension:
          _readBoolFromMap(message, 'isSupportMessageExtension') ?? false,
      // Keep web payload for revoke / modify / reaction on all elem types.
      messageFromWeb: _safeStringify(raw),
      needReadReceipt: _readBoolFromMap(message, 'needReadReceipt') ?? false,
    );

    switch (elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        msg.textElem = V2TimTextElem(text: _readStringFromMap(payload, 'text') ?? '');
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        msg.customElem = V2TimCustomElem(
          data: _readStringFromMap(payload, 'data') ?? '',
          desc: _readStringFromMap(payload, 'description') ??
              _readStringFromMap(payload, 'discription') ??
              '',
          extension: _readStringFromMap(payload, 'extension') ?? '',
        );
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        msg.imageElem = _convertImageElem(payload);
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        msg.soundElem = V2TimSoundElem(
          localUrl: _readStringFromMap(payload, 'url'),
          url: _readStringFromMap(payload, 'remoteAudioUrl') ??
              _readStringFromMap(payload, 'audioUrl') ??
              _readStringFromMap(payload, 'url'),
          dataSize: _readIntFromMap(payload, 'size'),
          duration: _readIntFromMap(payload, 'second'),
          UUID: _readStringFromMap(payload, 'uuid'),
        );
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        msg.videoElem = V2TimVideoElem(
          videoPath: _readStringFromMap(payload, 'videoUrl'),
          duration: _readIntFromMap(payload, 'videoSecond'),
          UUID: _readStringFromMap(payload, 'videoUUID'),
          snapshotPath: _readStringFromMap(payload, 'thumbUrl'),
          snapshotUUID: _readStringFromMap(payload, 'thumbUUID'),
          snapshotSize: _readIntFromMap(payload, 'thumbSize'),
          snapshotWidth: _readIntFromMap(payload, 'thumbWidth'),
          snapshotHeight: _readIntFromMap(payload, 'thumbHeight'),
          snapshotUrl: _readStringFromMap(payload, 'thumbUrl'),
          videoUrl: _readStringFromMap(payload, 'remoteVideoUrl') ??
              _readStringFromMap(payload, 'videoUrl'),
          videoSize: _readIntFromMap(payload, 'videoSize'),
        );
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        msg.fileElem = V2TimFileElem(
          path: _readStringFromMap(payload, 'fileUrl'),
          fileName: _readStringFromMap(payload, 'fileName') ?? '',
          UUID: _readStringFromMap(payload, 'uuid'),
          fileSize: _readIntFromMap(payload, 'fileSize'),
        );
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        msg.locationElem = V2TimLocationElem(
          desc: _readStringFromMap(payload, 'description') ?? '',
          longitude: _readDoubleFromMap(payload, 'longitude') ?? 0,
          latitude: _readDoubleFromMap(payload, 'latitude') ?? 0,
        );
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        msg.faceElem = V2TimFaceElem(
          index: _readIntFromMap(payload, 'index'),
          data: _readStringFromMap(payload, 'data') ?? '',
        );
        break;
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        msg.mergerElem = V2TimMergerElem(
          title: _readStringFromMap(payload, 'title') ?? '',
          abstractList: _toStringList(payload['abstractList']),
          isLayersOverLimit: _readBoolFromMap(payload, 'layersOverLimit') ?? false,
        );
        break;
      default:
        break;
    }

    return msg;
  }

  static V2TimImageElem? _convertImageElem(Map<String, dynamic> payload) {
    final imageInfoArray = _toList(payload['imageInfoArray']);
    if (imageInfoArray.isEmpty) {
      final url = _readStringFromMap(payload, 'imageUrl') ?? _readStringFromMap(payload, 'url');
      if (url == null || url.isEmpty) {
        return null;
      }
      return V2TimImageElem(
        path: url,
        imageList: [
          V2TimImage(
            type: 1,
            uuid: _readStringFromMap(payload, 'uuid'),
            url: url,
          )
        ],
      );
    }

    final uuid = _readStringFromMap(payload, 'uuid');
    final images = <V2TimImage>[];
    String? path;
    for (final rawImage in imageInfoArray) {
      final image = _toMap(rawImage);
      final url = _readStringFromMap(image, 'imageUrl') ?? _readStringFromMap(image, 'url');
      path ??= url;
      images.add(V2TimImage(
        type: _readIntFromMap(image, 'type') ?? 1,
        uuid: uuid,
        height: _readIntFromMap(image, 'height'),
        width: _readIntFromMap(image, 'width'),
        size: _readIntFromMap(image, 'size'),
        url: url,
      ));
    }
    return V2TimImageElem(path: path, imageList: images);
  }

  static int _convertElemType(String? type) {
    if (type == null || type.isEmpty) {
      return MessageElemType.V2TIM_ELEM_TYPE_NONE;
    }
    try {
      return MsgType.convertMsgType(type);
    } catch (_) {
      switch (type) {
        case 'TIMTextElem':
          return MessageElemType.V2TIM_ELEM_TYPE_TEXT;
        case 'TIMCustomElem':
          return MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
        case 'TIMImageElem':
          return MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
        case 'TIMSoundElem':
        case 'TIMAudioElem':
          return MessageElemType.V2TIM_ELEM_TYPE_SOUND;
        case 'TIMVideoFileElem':
          return MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
        case 'TIMFileElem':
          return MessageElemType.V2TIM_ELEM_TYPE_FILE;
        case 'TIMFaceElem':
          return MessageElemType.V2TIM_ELEM_TYPE_FACE;
        case 'TIMLocationElem':
          return MessageElemType.V2TIM_ELEM_TYPE_LOCATION;
        case 'TIMRelayElem':
          return MessageElemType.V2TIM_ELEM_TYPE_MERGER;
      }
    }
    return MessageElemType.V2TIM_ELEM_TYPE_NONE;
  }

  static int _convertStatus(Map<String, dynamic> message) {
    if (_readBoolFromMap(message, 'isDeleted') ?? false) {
      return MessageStatus.V2TIM_MSG_STATUS_HAS_DELETED;
    }
    if (_readBoolFromMap(message, 'isRevoked') ?? false) {
      return MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED;
    }
    final status = _readStringFromMap(message, 'status');
    if (status == 'success') {
      return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
    }
    if (status == 'fail') {
      return MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    }
    if (status == 'unSend') {
      return MessageStatus.V2TIM_MSG_STATUS_SENDING;
    }
    return MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC;
  }

  static int _convertPriority(String? priority) {
    switch (priority) {
      case 'High':
        return 1;
      case 'Normal':
        return 2;
      case 'Low':
        return 3;
      default:
        return 0;
    }
  }

  static Map<String, dynamic> _toMap(dynamic value) {
    if (value == null) {
      return <String, dynamic>{};
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    try {
      return Map<String, dynamic>.from(jsToMap(value));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static List<dynamic> _toList(dynamic value) {
    if (value == null) {
      return <dynamic>[];
    }
    if (value is List) {
      return List<dynamic>.from(value);
    }
    try {
      return List<dynamic>.from(value as Iterable);
    } catch (_) {
      return <dynamic>[];
    }
  }

  static List<String> _toStringList(dynamic value) {
    return _toList(value).map((item) => item.toString()).toList();
  }

  static dynamic _readAny(Object source, String key) {
    try {
      return getProperty<dynamic>(source, key);
    } catch (_) {
      if (source is Map) {
        return source[key];
      }
    }
    return null;
  }

  static int? _readInt(Object source, String key) {
    final value = _readAny(source, key);
    return _asInt(value);
  }

  static int? _readIntFromMap(Map<String, dynamic> map, String key) {
    return _asInt(map[key]);
  }

  static double? _readDoubleFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _readStringFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) {
      return null;
    }
    return value.toString();
  }

  static bool? _readBoolFromMap(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return null;
  }

  static String? _stripC2C(String? conversationID) {
    if (conversationID == null || conversationID.isEmpty) {
      return null;
    }
    return conversationID.startsWith('C2C')
        ? conversationID.substring(3)
        : conversationID;
  }

  static String _safeStringify(dynamic raw) {
    try {
      return stringify(raw);
    } catch (_) {
      return '';
    }
  }
}
