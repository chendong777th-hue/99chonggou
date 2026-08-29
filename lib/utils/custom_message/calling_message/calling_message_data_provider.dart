//通话协议类型
import 'dart:convert';

import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_bubble_dedupe_key.dart';
import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_signaling_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_signaling_info.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_bubble_direction.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_message_visual.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_parse_cache.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

enum CallProtocolType {
  unknown,
  send,
  accept,
  reject,
  cancel,
  hangup,
  timeout,
  lineBusy,
  switchToAudio,
  switchToAudioConfirm
}

//通话媒体类型
enum CallStreamMediaType { unknown, audio, video }

//通话参与者样式
enum CallParticipantType {
  unknown,
  c2c,
  group,
}

//通话人员角色
enum CallParticipantRole { unknown, caller, callee }

enum CallMessageDirection { incoming, outcoming }

class CallingMessageDataProvider {
  Map? _jsonData;
  V2TimSignalingInfo? _signalingInfo;
  V2TimMessage? _innerMessage;

  CallProtocolType _protocolType = CallProtocolType.unknown;
  CallStreamMediaType _streamMediaType = CallStreamMediaType.unknown;
  CallParticipantType _participantType = CallParticipantType.unknown;
  CallParticipantRole _participantRole = CallParticipantRole.unknown;
  CallMessageDirection _direction = CallMessageDirection.outcoming;
  bool _excludeFromHistory = false;
  String _callerId = '';
  String _operatorId = '';
  String _content = '';
  bool _isCallingSignal = false;
  bool _usedCanonicalCallResult = false;
  bool? _canonicalIsOutgoing;

  CallProtocolType get protocolType => _protocolType;
  // 媒体类型
  CallStreamMediaType get streamMediaType => _streamMediaType;
  // 通话类型
  CallParticipantType get participantType => _participantType;
  // 用户角色
  CallParticipantRole get participantRole => _participantRole;
  // 上屏信息的方向信息
  CallMessageDirection get direction => _direction;
  // 是否需要上屏
  bool get excludeFromHistory => _excludeFromHistory;
  // 主角ID
  String get callerId => _callerId;
  String get operatorId => _operatorId;
  // 上屏内容
  String get content => _content;
  // 是否Call信令
  bool get isCallingSignal => _isCallingSignal;

  CallMessageOutcome get outcome => CallMessageVisual.outcomeFor(
        protocolType: _protocolType,
        participantRole: _participantRole,
      );

  bool get _isFinalState {
    switch (_protocolType) {
      case CallProtocolType.hangup:
      case CallProtocolType.cancel:
      case CallProtocolType.reject:
      case CallProtocolType.timeout:
      case CallProtocolType.lineBusy:
        return true;
      default:
        return false;
    }
  }

  /// 是否应在聊天记录中展示。只排除发起、接听、切换摄像头等中间态，
  /// 拒绝、取消、未接听、忙线、挂断这类最终态必须保留。
  ///
  /// 注意：`hangup` 即使 `call_end==0`（秒挂 / 未写入时长）也要展示，
  /// 否则 LiveKit 本地气泡与 IM hangup 会被整行 shrink，表现为「打了没气泡」。
  bool get shouldDisplayInHistory {
    if (!_isCallingSignal) {
      return false;
    }
    if (_participantType == CallParticipantType.c2c) {
      // LiveKit bubbles are a single callId lifecycle. Keep ringing and
      // answered signals visible so the row can progress to its terminal
      // state when the canonical store is updated.
      return _protocolType != CallProtocolType.switchToAudio &&
          _protocolType != CallProtocolType.switchToAudioConfirm &&
          _protocolType != CallProtocolType.unknown;
    }
    switch (_protocolType) {
      case CallProtocolType.send:
      case CallProtocolType.accept:
      case CallProtocolType.switchToAudio:
      case CallProtocolType.switchToAudioConfirm:
      case CallProtocolType.unknown:
        return false;
      default:
        return true;
    }
  }

  CallingMessageDataProvider(V2TimMessage message) {
    _initInter(message);

    //这里的顺序不能乱
    _setIsCallingSignal();
    _setProtocolType();
    _applyCanonicalCallResultIfPresent();
    _setStreamMediaType();
    _setParticipantType();
    _setCallerId();
    _setOperatorId();
    _setParticipantRole();
    _setDirection();
    _setExcludeFromHistory();
    _setContent();
  }

  Map<String, dynamic>? _decodeCallMap(
    String raw, {
    required String parserVersion,
  }) {
    final message = _innerMessage;
    if (message == null || raw.trim().isEmpty) return null;
    return CustomMessageParseCache.instance.decodeMap(
      message: message,
      payload: raw,
      parserVersion: parserVersion,
    );
  }

  String getUserID() => callPeerID;

  String get conversationID {
    final groupID = _firstNotEmpty([
      _signalingInfo?.groupID,
      _innerMessage?.groupID,
      _jsonData?['groupID']?.toString(),
    ]);
    if (groupID.isNotEmpty) {
      return 'group_$groupID';
    }
    final peerID = callPeerID;
    return peerID.isEmpty ? '' : 'c2c_$peerID';
  }

  String get inviteID => _firstNotEmpty([
        _signalingInfo?.inviteID,
        _jsonData?['inviteID']?.toString(),
        _jsonData?['inviteId']?.toString(),
        _jsonData?['callId']?.toString(),
        _jsonData?['callID']?.toString(),
      ]);

  /// Hangup / connected duration in seconds (from already-parsed JSON).
  int get hangupDurationSec => _hangupDurationSec();

  /// Room id from already-parsed call JSON (empty when absent).
  String get callRoomId => _extractRoomId();

  String get callStableKey {
    final duration = _hangupDurationSec();
    if (duration > 0 && _participantType == CallParticipantType.c2c) {
      final conv = conversationID.trim();
      if (conv.isNotEmpty) {
        return CallBubbleDedupeKey.c2cHangup(
          conversationId: conv,
          durationSec: duration,
          roomId: _extractRoomId(),
        );
      }
    }
    final roomId = _extractRoomId();
    if (duration > 0 && roomId.isNotEmpty) {
      return 'call-room:$roomId:$duration';
    }
    final id = inviteID.trim();
    if (id.isNotEmpty) {
      return 'call:$id';
    }
    return callNearDuplicateKey;
  }

  int _hangupDurationSec() {
    final callEnd = _jsonData?['call_end'] ?? _jsonData?['callEnd'];
    if (callEnd is num && callEnd > 0) {
      return callEnd.round();
    }
    final data = _jsonData?['data'];
    if (data is Map) {
      final nested = data['call_end'] ?? data['callEnd'];
      if (nested is num && nested > 0) {
        return nested.round();
      }
    } else if (data is String && data.trim().startsWith('{')) {
      try {
        final decoded = _decodeCallMap(
          data,
          parserVersion: 'call-nested-v1',
        );
        if (decoded != null) {
          final nested = decoded['call_end'] ?? decoded['callEnd'];
          if (nested is num && nested > 0) {
            return nested.round();
          }
        }
      } catch (_) {}
    }
    return 0;
  }

  bool _hasPositiveCallEnd() => _hangupDurationSec() > 0;

  String _extractRoomId() {
    for (final key in const ['room_id', 'roomId', 'intRoomId']) {
      final value = _jsonData?[key];
      if (value is num && value > 0) {
        return value.round().toString();
      }
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != '0' && text != 'null') {
        return text;
      }
    }
    final data = _jsonData?['data'];
    if (data is Map) {
      for (final key in const ['room_id', 'roomId', 'intRoomId']) {
        final value = data[key];
        if (value is num && value > 0) {
          return value.round().toString();
        }
      }
    }
    return '';
  }

  String get callNearDuplicateKey {
    if (_hasPositiveCallEnd() && _participantType == CallParticipantType.c2c) {
      final conv = conversationID.trim();
      if (conv.isNotEmpty) {
        return CallBubbleDedupeKey.c2cHangup(
          conversationId: conv,
          durationSec: _hangupDurationSec(),
          roomId: _extractRoomId(),
        );
      }
    }
    final ts = (_innerMessage?.timestamp ?? 0);
    final bucket = ts <= 0 ? 0 : ts ~/ 30;
    final conv = conversationID;
    return [
      'call-near',
      conv,
      _protocolType.toString().split('.').last,
      _streamMediaType.toString().split('.').last,
      bucket.toString(),
    ].join(':');
  }

  String get inviterID => _signalingInfo?.inviter ?? '';

  List<String> get inviteeList => (_signalingInfo?.inviteeList ?? const [])
      .map((e) => e?.toString().trim() ?? '')
      .where((e) => e.isNotEmpty)
      .toList();

  String get callPeerID {
    final loginUserId = _safeCurrentLoginUserId();
    final candidates = <String?>[
      _innerMessage?.userID,
      _innerMessage?.sender,
      _signalingInfo?.inviter,
      ...inviteeList,
      _callerId,
    ];
    for (final item in candidates) {
      final value = item?.trim() ?? '';
      if (value.isNotEmpty && value != loginUserId) {
        return value;
      }
    }
    return '';
  }

  static bool looksLikeCallMessage(V2TimMessage message) {
    final raw = message.customElem?.data?.trim() ?? '';
    if (raw.isEmpty) return false;
    return raw.contains('av_call') ||
        raw.contains('rtc_call') ||
        raw.contains('lk_call') ||
        raw.contains('inviteID') ||
        raw.contains('callId');
  }

  static String fallbackText() {
    return AppI18n.current.t(
      zhHans: '通话记录',
      zhHant: '通話記錄',
      en: 'Call record',
      ja: '通話記録',
      ko: '통화 기록',
    );
  }

  static CallMessageDirection? directionForMessage(V2TimMessage message) {
    try {
      final provider = CallingMessageDataProvider(message);
      if (provider.isCallingSignal &&
          provider.shouldDisplayInHistory &&
          provider.participantType == CallParticipantType.c2c) {
        return provider.direction;
      }
    } catch (_) {}
    return null;
  }

  static String _safeCurrentLoginUserId() {
    try {
      return CallUserId.normalizeCallUserId(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }

  void _initInter(V2TimMessage message) {
    _innerMessage = message;
    Map<String, dynamic>? outerMap;
    try {
      final raw = _innerMessage?.customElem?.data?.trim();
      if (raw == null || raw.isEmpty) {
        return;
      }
      final decoded = _decodeCallMap(
        raw,
        parserVersion: 'call-outer-v1',
      );
      if (decoded == null) {
        return;
      }
      final signalingInfoData = Utils.formatJson(decoded);
      outerMap = Map<String, dynamic>.from(signalingInfoData);
      if (_looksLikeCallJson(signalingInfoData)) {
        _jsonData = Map<String, dynamic>.from(signalingInfoData);
      }
      try {
        transferDataToSignalingInfo(signalingInfoData);
      } catch (_) {
        // lk_call uses string businessID; legacy int field must not abort parsing.
      }
    } catch (err) {
      return;
    }
    if (outerMap == null) {
      return;
    }

    try {
      final signalingData = _signalingInfo?.data?.trim() ?? '';
      if (signalingData.isNotEmpty) {
        final decoded = _decodeCallMap(
          signalingData,
          parserVersion: 'call-signaling-v1',
        );
        if (decoded != null) {
          final nested = Utils.formatJson(decoded);
          // Keep outer businessID/action/actionType when nested payload omits them
          // (common for LiveKit lk_call wrappers). Losing `action` here used to
          // leave protocol=unknown → conversation list showed「未知通话」.
          nested['businessID'] ??= outerMap['businessID'];
          nested['actionType'] ??= outerMap['actionType'];
          nested['action'] ??= outerMap['action'];
          nested['event'] ??= outerMap['event'];
          nested['mediaType'] ??=
              outerMap['mediaType'] ?? outerMap['media_type'];
          nested['call_end'] ??= outerMap['call_end'] ??
              outerMap['durationSec'] ??
              outerMap['duration'];
          nested['inviteID'] ??= outerMap['inviteID'] ??
              outerMap['inviteId'] ??
              outerMap['callId'];
          nested['callId'] ??= outerMap['callId'] ??
              outerMap['inviteID'] ??
              outerMap['inviteId'];
          nested['inviter'] ??= outerMap['inviter'] ?? outerMap['callerId'];
          nested['callerId'] ??= outerMap['callerId'] ?? outerMap['inviter'];
          nested['calleeId'] ??= outerMap['calleeId'];
          nested['groupID'] ??= outerMap['groupID'];
          _jsonData = nested;
        }
      } else {
        _jsonData ??= _extractNestedCallJson();
      }
    } catch (err) {
      _jsonData ??= _extractNestedCallJson();
    }
    // TIM 外层只有 inviteID/callId、缺 businessID 时仍要解析，否则 looksLikeCall
    // 为 true 但 isCallingSignal=false，挂载层会把整条通话消息滤掉。
    _jsonData ??= outerMap;
    if (_jsonData != null && looksLikeCallMessage(message)) {
      _promoteNestedCallFields(Map<String, dynamic>.from(_jsonData!));
    }
    _normalizeLiveKitCallFields();
  }

  /// Promote action/duration/callId from nested `data` JSON string into top-level.
  void _promoteNestedCallFields(Map<String, dynamic> data) {
    final nestedRaw = data['data'];
    Map<String, dynamic>? nestedMap;
    if (nestedRaw is Map) {
      nestedMap = Map<String, dynamic>.from(nestedRaw);
    } else if (nestedRaw is String && nestedRaw.trim().startsWith('{')) {
      try {
        nestedMap = _decodeCallMap(
          nestedRaw,
          parserVersion: 'call-nested-v1',
        );
      } catch (_) {}
    }
    if (nestedMap == null) {
      return;
    }
    data['action'] ??= nestedMap['action'] ?? nestedMap['event'];
    data['event'] ??= nestedMap['event'] ?? nestedMap['action'];
    data['callId'] ??= nestedMap['callId'] ?? nestedMap['inviteId'];
    data['inviteID'] ??=
        nestedMap['inviteID'] ?? nestedMap['inviteId'] ?? nestedMap['callId'];
    data['callerId'] ??= nestedMap['callerId'] ?? nestedMap['inviter'];
    data['calleeId'] ??= nestedMap['calleeId'];
    data['call_end'] ??= nestedMap['call_end'] ??
        nestedMap['durationSec'] ??
        nestedMap['duration'];
    data['mediaType'] ??= nestedMap['mediaType'] ?? nestedMap['media_type'];
    data['businessID'] ??= nestedMap['businessID'];
    data['actionType'] ??= nestedMap['actionType'];
  }

  /// Normalize LiveKit / TIM call payloads into TUICallKit-shaped fields.
  void _normalizeLiveKitCallFields() {
    final data = _jsonData;
    if (data == null) return;
    final businessId =
        data['businessID']?.toString().trim().toLowerCase() ?? '';
    final raw = _innerMessage?.customElem?.data?.toLowerCase() ?? '';
    final isLk = businessId == 'lk_call' || raw.contains('lk_call');
    var action =
        (data['action'] ?? data['event'] ?? '').toString().trim().toLowerCase();
    if (!isLk && action.isEmpty) {
      return;
    }
    if (isLk) {
      data['businessID'] = 'lk_call';
    }

    final callId = _firstNotEmpty([
      data['callId']?.toString(),
      data['inviteId']?.toString(),
      data['inviteID']?.toString(),
      _signalingInfo?.inviteID,
    ]);
    if (callId.isNotEmpty) {
      data['callId'] = callId;
      data['inviteID'] = callId;
    }

    // Promote nested Data.callerId / Data.calleeId (server history shape).
    final nested = data['data'];
    Map<String, dynamic>? nestedMap;
    if (nested is Map) {
      nestedMap = Map<String, dynamic>.from(nested);
    } else if (nested is String && nested.trim().startsWith('{')) {
      try {
        nestedMap = _decodeCallMap(
          nested,
          parserVersion: 'call-nested-v1',
        );
      } catch (_) {}
    }
    if (nestedMap != null) {
      final caller = _firstNotEmpty([
        data['callerId']?.toString(),
        data['callerID']?.toString(),
        nestedMap['callerId']?.toString(),
        nestedMap['callerID']?.toString(),
      ]);
      final callee = _firstNotEmpty([
        data['calleeId']?.toString(),
        data['calleeID']?.toString(),
        nestedMap['calleeId']?.toString(),
        nestedMap['calleeID']?.toString(),
      ]);
      if (caller.isNotEmpty) {
        data['callerId'] = caller;
        nestedMap['callerId'] = caller;
        nestedMap['inviter'] ??= caller;
      }
      if (callee.isNotEmpty) {
        data['calleeId'] = callee;
        nestedMap['calleeId'] = callee;
      }
      data['action'] ??= nestedMap['action'] ?? nestedMap['event'];
      data['event'] ??= nestedMap['event'] ?? nestedMap['action'];
      data['mediaType'] ??= nestedMap['mediaType'] ?? nestedMap['media_type'];
      data['data'] = nestedMap;
    }

    final durationRaw = data['duration'] ??
        data['durationSec'] ??
        data['totalTime'] ??
        data['call_end'];
    final durationSec = durationRaw is num
        ? durationRaw.round()
        : int.tryParse(durationRaw?.toString() ?? '') ?? 0;
    if (durationSec > 0) {
      data['call_end'] = durationSec;
    }

    final mediaType = (data['mediaType'] ?? data['media_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (mediaType == 'video') {
      data['call_type'] = 2;
    } else if (mediaType == 'audio' || mediaType.isEmpty) {
      data['call_type'] ??= 1;
    }

    action =
        (data['action'] ?? data['event'] ?? '').toString().trim().toLowerCase();
    // Nested TIM wrappers may only keep actionType; synthesize action so
    // _setProtocolType can resolve invite/cancel/hangup instead of unknown.
    if (action.isEmpty) {
      final actionType = int.tryParse(
            (data['actionType'] ?? _signalingInfo?.actionType ?? '').toString(),
          ) ??
          0;
      switch (actionType) {
        case 1:
          final cmd = (nestedMap?['cmd'] ?? data['cmd'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          action = cmd == 'hangup' ? 'hangup' : 'invite';
          break;
        case 2:
          action = 'cancel';
          break;
        case 3:
          action = 'accept';
          break;
        case 4:
          action = data['line_busy'] != null ? 'busy' : 'reject';
          break;
        case 5:
          action = 'timeout';
          break;
      }
      if (action.isNotEmpty) {
        data['action'] = action;
      }
    }
    if (action.isEmpty) return;

    // Synthesize TRTC-style actionType / cmd so existing protocol mapping works.
    switch (action) {
      case 'invite':
        data['actionType'] = 1;
        final nested = data['data'];
        final cmd = mediaType == 'video' ? 'videoCall' : 'audioCall';
        if (nested is Map) {
          nested['cmd'] ??= cmd;
          nested['businessID'] ??= isLk ? 'lk_call' : 'av_call';
        } else {
          data['data'] = <String, dynamic>{
            'cmd': cmd,
            'businessID': isLk ? 'lk_call' : 'av_call',
            'inviter': data['callerId'] ?? data['inviter'],
            'callerId': data['callerId'] ?? data['inviter'],
          };
        }
        break;
      case 'accept':
        data['actionType'] = 3;
        break;
      case 'cancel':
        data['actionType'] = 2;
        break;
      case 'reject':
        data['actionType'] = 4;
        break;
      case 'busy':
      case 'line_busy':
      case 'linebusy':
        data['actionType'] = 4;
        data['line_busy'] = 1;
        break;
      case 'timeout':
      case 'no_response':
      case 'noresponse':
        data['actionType'] = 5;
        break;
      case 'hangup':
      case 'end':
        data['actionType'] = 1;
        final nested = data['data'];
        if (nested is Map) {
          nested['cmd'] = 'hangup';
        } else {
          data['data'] = <String, dynamic>{
            'cmd': 'hangup',
            'businessID': isLk ? 'lk_call' : 'av_call',
          };
        }
        break;
    }

    final signaling = _signalingInfo;
    if (signaling != null) {
      final parsedAction =
          int.tryParse(data['actionType']?.toString() ?? '') ?? 0;
      final actionType =
          parsedAction != 0 ? parsedAction : (signaling.actionType ?? 0);
      final invitees = signaling.inviteeList;
      transferDataToSignalingInfo(<String, dynamic>{
        'inviteID': callId,
        'groupID': data['groupID'] ?? signaling.groupID,
        'inviter': data['callerId'] ?? data['inviter'] ?? signaling.inviter,
        'inviteeList': (invitees != null && invitees.isNotEmpty)
            ? invitees
            : <dynamic>[
                if ((data['calleeId'] ?? '').toString().trim().isNotEmpty)
                  data['calleeId'].toString().trim(),
              ],
        'data': data['data'] is String
            ? data['data']
            : jsonEncode(data['data'] ?? data),
        'timeout': signaling.timeout ?? 30,
        'actionType': actionType,
        'businessID': data['businessID'],
      });
    }
  }

  static bool _looksLikeCallJson(Map json) {
    final businessID = json['businessID']?.toString();
    if (businessID == 'av_call' ||
        businessID == 'rtc_call' ||
        businessID == 'lk_call') {
      return true;
    }
    for (final key in const ['inviteID', 'inviteId', 'callId', 'callID']) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return true;
      }
    }
    final action = (json['action'] ?? json['event'] ?? '').toString().trim();
    if (action.isNotEmpty &&
        const {
          'invite',
          'hangup',
          'reject',
          'cancel',
          'accept',
          'timeout',
          'busy'
        }.contains(action.toLowerCase())) {
      return true;
    }
    final data = json['data'];
    if (data is Map) {
      final nestedBusinessID = data['businessID']?.toString();
      final cmd = data['cmd']?.toString();
      return nestedBusinessID == 'av_call' ||
          nestedBusinessID == 'rtc_call' ||
          nestedBusinessID == 'lk_call' ||
          cmd == 'audioCall' ||
          cmd == 'videoCall';
    }
    final raw = data?.toString() ?? '';
    return raw.contains('av_call') ||
        raw.contains('rtc_call') ||
        raw.contains('lk_call') ||
        raw.contains('audioCall') ||
        raw.contains('videoCall');
  }

  Map<String, dynamic>? _extractNestedCallJson() {
    final raw = _innerMessage?.customElem?.data;
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = _decodeCallMap(
        raw,
        parserVersion: 'call-outer-v1',
      );
      if (decoded == null) {
        return null;
      }
      final map = Utils.formatJson(decoded);
      final data = map['data'];
      if (data is Map) {
        return Utils.formatJson(data);
      }
      if (_looksLikeCallJson(map)) {
        return map;
      }
    } catch (_) {}
    return null;
  }

  transferDataToSignalingInfo(Map json) {
    json = Utils.formatJson(json);
    String inviteID = (json['inviteID'] ??
            json['inviteId'] ??
            json['callId'] ??
            json['callID'] ??
            '')
        .toString();
    String? groupID = json['groupID']?.toString();
    String inviter =
        (json['inviter'] ?? json['callerId'] ?? json['callerID'] ?? '')
            .toString();
    List<dynamic> inviteeList = json['inviteeList'] ??
        <dynamic>[
          if ((json['calleeId'] ?? json['calleeID'] ?? '')
              .toString()
              .trim()
              .isNotEmpty)
            (json['calleeId'] ?? json['calleeID']).toString().trim(),
        ];
    final rawData = json['data'];
    String? data;
    if (rawData is String) {
      data = rawData;
    } else if (rawData != null) {
      data = jsonEncode(rawData);
    }
    int? timeout = json['timeout'] is int
        ? json['timeout'] as int
        : int.tryParse(json['timeout']?.toString() ?? '');
    int actionType = json['actionType'] is int
        ? json['actionType'] as int
        : int.tryParse(json['actionType']?.toString() ?? '') ?? 0;
    // 下方三个参数ios不会返回

    int? businessIDInt;
    final businessIDRaw = json['businessID'];
    if (businessIDRaw is int) {
      businessIDInt = businessIDRaw;
    } else if (businessIDRaw is String) {
      businessIDInt = int.tryParse(businessIDRaw);
    }
    bool? isOnlineUserOnly;
    OfflinePushInfo? offlinePushInfo;
    if (json['onlineUserOnly'] != null) {
      isOnlineUserOnly = json['onlineUserOnly'];
    }
    if (json['offlinePushInfo'] != null) {
      offlinePushInfo = OfflinePushInfo.fromJson(json['offlinePushInfo']);
    }

    _signalingInfo = V2TimSignalingInfo(
      inviteID: inviteID,
      groupID: groupID,
      inviter: inviter,
      inviteeList: inviteeList,
      data: data,
      timeout: timeout,
      actionType: actionType,
      businessID: businessIDInt,
      isOnlineUserOnly: isOnlineUserOnly,
      offlinePushInfo: offlinePushInfo,
    );
  }

  _setIsCallingSignal() {
    if (_innerMessage == null) {
      _isCallingSignal = false;
      return;
    }
    if (_jsonData == null) {
      _isCallingSignal = looksLikeCallMessage(_innerMessage!);
      return;
    }

    final businessID =
        _jsonData!['businessID']?.toString().trim().toLowerCase();
    final cmd = _callCmd();
    final action = (_jsonData!['action'] ?? '').toString().trim().toLowerCase();
    final raw = _innerMessage?.customElem?.data?.toLowerCase() ?? '';
    if (businessID == 'av_call' ||
        businessID == 'rtc_call' ||
        businessID == 'lk_call' ||
        raw.contains('lk_call') ||
        raw.contains('av_call') ||
        raw.contains('rtc_call')) {
      _isCallingSignal = true;
    } else if (cmd == 'audioCall' ||
        cmd == 'videoCall' ||
        cmd == 'hangup' ||
        cmd == 'switchToAudio' ||
        action == 'invite' ||
        action == 'hangup' ||
        action == 'reject' ||
        action == 'cancel') {
      _isCallingSignal = true;
    } else if (_innerMessage != null && looksLikeCallMessage(_innerMessage!)) {
      _isCallingSignal = true;
    } else {
      _isCallingSignal = false;
    }
  }

  String? _callCmd() {
    final direct = _jsonData?['cmd']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final data = _jsonData?['data'];
    if (data is Map) {
      return data['cmd']?.toString();
    }
    if (data is String && data.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded['cmd']?.toString();
        }
      } catch (_) {}
    }
    return null;
  }

  CallProtocolType? _inferProtocolFromJsonData() {
    if (_jsonData == null) {
      return null;
    }
    final action = (_jsonData!['action'] ?? _jsonData!['event'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    switch (action) {
      case 'invite':
        return CallProtocolType.send;
      case 'accept':
        return CallProtocolType.accept;
      case 'cancel':
        return CallProtocolType.cancel;
      case 'reject':
        return CallProtocolType.reject;
      case 'busy':
      case 'line_busy':
      case 'linebusy':
        return CallProtocolType.lineBusy;
      case 'timeout':
      case 'no_response':
      case 'noresponse':
        return CallProtocolType.timeout;
      case 'hangup':
      case 'end':
        return CallProtocolType.hangup;
    }
    final cmd = _callCmd()?.trim().toLowerCase();
    if (cmd == 'hangup' || _hasPositiveCallEnd()) {
      return CallProtocolType.hangup;
    }
    if (cmd == 'audioCall' || cmd == 'videoCall') {
      return CallProtocolType.send;
    }
    final actionType = int.tryParse(
          (_jsonData!['actionType'] ?? '').toString(),
        ) ??
        0;
    switch (actionType) {
      case 1:
        return cmd == 'hangup' || _hasPositiveCallEnd()
            ? CallProtocolType.hangup
            : CallProtocolType.send;
      case 2:
        return CallProtocolType.cancel;
      case 3:
        return CallProtocolType.accept;
      case 4:
        return _jsonData!['line_busy'] != null
            ? CallProtocolType.lineBusy
            : CallProtocolType.reject;
      case 5:
        return CallProtocolType.timeout;
    }
    return null;
  }

  _setProtocolType() {
    if (_innerMessage == null || _jsonData == null) {
      _protocolType = CallProtocolType.unknown;
      return;
    }

    final inferredEarly = _inferProtocolFromJsonData();
    if (inferredEarly != null) {
      _protocolType = inferredEarly;
      return;
    }

    // LiveKit action string (may remain even after normalize).
    final action = (_jsonData!['action'] ?? _jsonData!['event'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final businessId =
        _jsonData!['businessID']?.toString().trim().toLowerCase() ?? '';
    final rawContainsLk =
        _innerMessage?.customElem?.data?.toLowerCase().contains('lk_call') ??
            false;
    if (action.isNotEmpty &&
        (businessId == 'av_call' || businessId == 'lk_call' || rawContainsLk)) {
      switch (action) {
        case 'invite':
          _protocolType = CallProtocolType.send;
          return;
        case 'accept':
          _protocolType = CallProtocolType.accept;
          return;
        case 'cancel':
          _protocolType = CallProtocolType.cancel;
          return;
        case 'reject':
          _protocolType = CallProtocolType.reject;
          return;
        case 'busy':
        case 'line_busy':
        case 'linebusy':
          _protocolType = CallProtocolType.lineBusy;
          return;
        case 'timeout':
        case 'no_response':
        case 'noresponse':
          _protocolType = CallProtocolType.timeout;
          return;
        case 'hangup':
        case 'end':
          _protocolType = CallProtocolType.hangup;
          return;
      }
    }

    if (_signalingInfo == null) {
      _protocolType = _inferProtocolFromJsonData() ?? CallProtocolType.unknown;
      return;
    }

    switch (_signalingInfo!.actionType) {
      case 1:
        final cmd = _callCmd();
        if (cmd != null) {
          if (cmd == 'switchToAudio') {
            _protocolType = CallProtocolType.switchToAudio;
          } else if (cmd == 'hangup') {
            _protocolType = CallProtocolType.hangup;
          } else if (cmd == 'videoCall') {
            _protocolType = CallProtocolType.send;
          } else if (cmd == 'audioCall') {
            _protocolType = CallProtocolType.send;
          } else {
            _protocolType = CallProtocolType.unknown;
          }
        } else {
          if (_hasPositiveCallEnd()) {
            _protocolType = CallProtocolType.hangup;
          } else {
            _protocolType = CallProtocolType.send;
          }
        }
        break;
      case 2:
        _protocolType = CallProtocolType.cancel;
        break;
      case 3:
        final cmd = _callCmd();
        if (cmd != null) {
          if (cmd == 'switchToAudio') {
            _protocolType = CallProtocolType.switchToAudioConfirm;
          } else {
            _protocolType = CallProtocolType.accept;
          }
        } else {
          _protocolType = CallProtocolType.accept;
        }
        break;
      case 4:
        if (_jsonData!['line_busy'] != null) {
          _protocolType = CallProtocolType.lineBusy;
        } else {
          _protocolType = CallProtocolType.reject;
        }
        break;
      case 5:
        _protocolType = CallProtocolType.timeout;
        break;
      default:
        final cmd = _callCmd();
        if (cmd == 'audioCall' || cmd == 'videoCall') {
          _protocolType = CallProtocolType.send;
        } else if (cmd == 'hangup' || _hasPositiveCallEnd()) {
          _protocolType = CallProtocolType.hangup;
        } else if (cmd == 'switchToAudio') {
          _protocolType = CallProtocolType.switchToAudio;
        } else {
          _protocolType = CallProtocolType.unknown;
        }
        break;
    }
  }

  void _applyCanonicalCallResultIfPresent() {
    final id = inviteID.trim();
    if (id.isEmpty) {
      return;
    }
    final record = CallResultRepository.instance.get(id);
    if (record == null) {
      // Missing cache: chat open path will GET /calls/{callId} asynchronously.
      return;
    }
    _usedCanonicalCallResult = true;
    _canonicalIsOutgoing = record.isOutgoing;
    if (record.callerUserId.isNotEmpty) {
      _callerId = record.callerUserId;
    }
    if (record.operatorUserId.isNotEmpty) {
      _operatorId = record.operatorUserId;
    }
    if (record.protocolType != CallProtocolType.unknown) {
      _protocolType = record.protocolType;
    }
    if (_jsonData != null) {
      if (record.durationSec > 0) {
        _jsonData!['call_end'] = record.durationSec;
      }
      if (record.mediaType == 'video') {
        _jsonData!['call_type'] = 2;
      } else if (record.mediaType == 'audio') {
        _jsonData!['call_type'] = 1;
      }
    }
  }

  _setStreamMediaType() {
    _streamMediaType = CallStreamMediaType.unknown;

    final callType = _jsonData?['call_type'];
    if (callType != null) {
      if (callType == 1 || callType.toString() == '1' || callType == 'audio') {
        _streamMediaType = CallStreamMediaType.audio;
      } else if (callType == 2 ||
          callType.toString() == '2' ||
          callType == 'video') {
        _streamMediaType = CallStreamMediaType.video;
      }
    }
    final mediaType =
        (_jsonData?['mediaType'] ?? _jsonData?['media_type'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
    if (_streamMediaType == CallStreamMediaType.unknown) {
      if (mediaType == 'video') {
        _streamMediaType = CallStreamMediaType.video;
      } else if (mediaType == 'audio') {
        _streamMediaType = CallStreamMediaType.audio;
      }
    }

    if (_protocolType == CallProtocolType.unknown) {
      return;
    }

    if (_protocolType == CallProtocolType.send) {
      final cmd = _callCmd();
      if (cmd == 'audioCall') {
        _streamMediaType = CallStreamMediaType.audio;
      } else if (cmd == 'videoCall') {
        _streamMediaType = CallStreamMediaType.video;
      }
    } else if (_protocolType == CallProtocolType.switchToAudio ||
        _protocolType == CallProtocolType.switchToAudioConfirm) {
      _streamMediaType = CallStreamMediaType.video;
    }
  }

  _setParticipantType() {
    final groupID =
        (_signalingInfo?.groupID ?? _jsonData?['groupID']?.toString() ?? '')
            .trim();
    if (_protocolType == CallProtocolType.unknown && !_isCallingSignal) {
      _participantType = CallParticipantType.unknown;
      return;
    }

    if (groupID.isNotEmpty) {
      _participantType = CallParticipantType.group;
    } else {
      _participantType = CallParticipantType.c2c;
    }
  }

  _setCallerId() async {
    if (_protocolType == CallProtocolType.unknown) {
      return;
    }
    if (_usedCanonicalCallResult && _callerId.isNotEmpty) {
      _callerId = CallUserId.normalizeCallUserId(_callerId);
      return;
    }

    final data = _jsonData!['data'];
    if (data is Map) {
      _callerId = _firstNotEmpty([
        data['callerId']?.toString(),
        data['callerID']?.toString(),
        data['inviter']?.toString(),
      ]);
    }

    if (_callerId.isEmpty) {
      _callerId = _firstNotEmpty([
        _jsonData?['callerId']?.toString(),
        _jsonData?['callerID']?.toString(),
        _jsonData?['inviter']?.toString(),
        _signalingInfo?.inviter,
      ]);
    }

    if (_callerId.isEmpty) {
      _callerId = _callerIdFromLocalCustomData();
    }

    if (_callerId.isEmpty) {
      _callerId = _callerIdFromDirectionHint();
    }

    if (_callerId.isEmpty) {
      final sender = _innerMessage?.sender?.trim() ?? '';
      final userId = _innerMessage?.userID?.trim() ?? '';
      final loginUserId = _safeCurrentLoginUserId();
      final isFromSelf = _innerMessage?.isSelf ?? false;
      final peerId = _firstNotEmpty([
        userId != loginUserId ? userId : null,
        sender != loginUserId ? sender : null,
        ...inviteeList.where((id) => id != loginUserId),
      ]);

      // 拒绝/忙线消息通常由“被叫方”发出，通话记录仍应归属发起方。
      if (_protocolType == CallProtocolType.reject ||
          _protocolType == CallProtocolType.lineBusy) {
        if (isFromSelf && peerId.isNotEmpty) {
          _callerId = peerId;
        } else if (!isFromSelf && loginUserId.isNotEmpty) {
          _callerId = loginUserId;
        }
      }

      if (_callerId.isEmpty && _protocolType == CallProtocolType.hangup) {
        final inviter = (_signalingInfo?.inviter ?? '').trim();
        if (inviter.isNotEmpty) {
          _callerId = inviter;
        } else if (isFromSelf && peerId.isNotEmpty) {
          final direction = _callDirectionFromLocalCustomData();
          if (direction == CallBubbleDirection.callDirectionIncoming) {
            _callerId = peerId;
          } else if (direction == CallBubbleDirection.callDirectionOutgoing &&
              loginUserId.isNotEmpty) {
            _callerId = loginUserId;
          }
        }
      }

      // 取消/超时一般由发起方产生；缺少 caller 字段时按消息发送方兜底。
      if (_callerId.isEmpty &&
          (_protocolType == CallProtocolType.cancel ||
              _protocolType == CallProtocolType.timeout)) {
        if (isFromSelf && loginUserId.isNotEmpty) {
          _callerId = loginUserId;
        } else if (sender.isNotEmpty) {
          _callerId = sender;
        } else if (peerId.isNotEmpty) {
          _callerId = peerId;
        }
      }

      if (_callerId.isEmpty) {
        if (sender.isNotEmpty && !isFromSelf) {
          _callerId = sender;
        } else if (isFromSelf &&
            loginUserId.isNotEmpty &&
            _protocolType != CallProtocolType.hangup) {
          _callerId = loginUserId;
        } else if (peerId.isNotEmpty) {
          _callerId = peerId;
        } else if (isFromSelf && loginUserId.isNotEmpty) {
          _callerId = loginUserId;
        }
      }
    }
    _callerId = CallUserId.normalizeCallUserId(_callerId);
  }

  String _callerIdFromDirectionHint() {
    final direction = _callDirectionFromLocalCustomData();
    if (direction == null) {
      return '';
    }
    final loginUserId = _safeCurrentLoginUserId();
    final peerId = callPeerID.trim();
    return CallBubbleDirection.resolveCallerIdFromDirectionHint(
          callDirection: direction,
          loginUserId: loginUserId,
          peerUserId: peerId,
        ) ??
        '';
  }

  String? _callDirectionFromLocalCustomData() {
    final raw = _innerMessage?.localCustomData?.trim() ?? '';
    if (raw.isEmpty || !raw.startsWith('{')) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final direction = decoded['callDirection']?.toString().trim() ?? '';
      if (direction == CallBubbleDirection.callDirectionIncoming ||
          direction == CallBubbleDirection.callDirectionOutgoing) {
        return direction;
      }
    } catch (_) {}
    return null;
  }

  String _callerIdFromLocalCustomData() {
    final raw = _innerMessage?.localCustomData?.trim() ?? '';
    if (raw.isEmpty || !raw.startsWith('{')) {
      return '';
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return '';
      }
      return _firstNotEmpty([
        decoded['callerUserId']?.toString(),
        decoded['callerId']?.toString(),
        decoded['callerID']?.toString(),
        decoded['inviter']?.toString(),
      ]);
    } catch (_) {
      return '';
    }
  }

  _setOperatorId() {
    if (_protocolType == CallProtocolType.unknown) {
      return;
    }
    if (_usedCanonicalCallResult && _operatorId.isNotEmpty) {
      _operatorId = CallUserId.normalizeCallUserId(_operatorId);
      return;
    }

    final data = _jsonData?['data'];
    if (data is Map) {
      _operatorId = _firstNotEmpty([
        data['operatorId']?.toString(),
        data['operatorUserId']?.toString(),
        data['endedByUserId']?.toString(),
        data['rejecterId']?.toString(),
        data['cancelerId']?.toString(),
        data['hangupUserId']?.toString(),
      ]);
    }

    if (_operatorId.isEmpty) {
      _operatorId = _firstNotEmpty([
        _jsonData?['operatorId']?.toString(),
        _jsonData?['operatorUserId']?.toString(),
        _jsonData?['endedByUserId']?.toString(),
        _jsonData?['rejecterId']?.toString(),
        _jsonData?['cancelerId']?.toString(),
        _jsonData?['hangupUserId']?.toString(),
      ]);
    }

    if (_operatorId.isEmpty) {
      _operatorId = _operatorIdFromLocalCustomData();
    }

    if (_operatorId.isEmpty) {
      final sender = _innerMessage?.sender?.trim() ?? '';
      final loginUserId = _safeCurrentLoginUserId();
      final peerId = callPeerID.trim();

      if (_protocolType == CallProtocolType.reject ||
          _protocolType == CallProtocolType.lineBusy) {
        // 拒绝消息的操作者是拒绝方。历史消息无 operator 字段时，
        // sender 通常就是拒绝方；仍缺失时再按 caller/self 关系兜底。
        if (sender.isNotEmpty) {
          _operatorId = sender;
        } else if (_callerId.trim().isNotEmpty && loginUserId.isNotEmpty) {
          _operatorId = CallUserId.isSameCallUserId(_callerId, loginUserId)
              ? peerId
              : loginUserId;
        }
      } else if (_protocolType == CallProtocolType.cancel) {
        _operatorId = _callerId.trim().isNotEmpty ? _callerId.trim() : sender;
      } else if (_protocolType == CallProtocolType.hangup) {
        _operatorId = sender.isNotEmpty ? sender : loginUserId;
      }
    }
    _operatorId = CallUserId.normalizeCallUserId(_operatorId);
  }

  String _operatorIdFromLocalCustomData() {
    final raw = _innerMessage?.localCustomData?.trim() ?? '';
    if (raw.isEmpty || !raw.startsWith('{')) {
      return '';
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return '';
      }
      return _firstNotEmpty([
        decoded['operatorUserId']?.toString(),
        decoded['operatorId']?.toString(),
        decoded['endedByUserId']?.toString(),
        decoded['rejecterId']?.toString(),
      ]);
    } catch (_) {
      return '';
    }
  }

  _setParticipantRole() {
    final loginUserId = _safeCurrentLoginUserId();

    if (CallUserId.isSameCallUserId(_callerId, loginUserId)) {
      _participantRole = CallParticipantRole.caller;
    } else {
      _participantRole = CallParticipantRole.callee;
    }
  }

  _setDirection() {
    // Display side: call-record direction / local marker only.
    // Never use callerId==me (that confuses "who initiated" with bubble side).
    if (_usedCanonicalCallResult && _canonicalIsOutgoing != null) {
      _direction = _canonicalIsOutgoing!
          ? CallMessageDirection.outcoming
          : CallMessageDirection.incoming;
      return;
    }
    final marker = _callDirectionFromLocalCustomData();
    if (marker == CallBubbleDirection.callDirectionOutgoing) {
      _direction = CallMessageDirection.outcoming;
      return;
    }
    if (marker == CallBubbleDirection.callDirectionIncoming) {
      _direction = CallMessageDirection.incoming;
      return;
    }
    // Last resort: IM isSelf only.
    final fallbackIsSelf = _innerMessage?.isSelf;
    if (fallbackIsSelf == true) {
      _direction = CallMessageDirection.outcoming;
    } else {
      _direction = CallMessageDirection.incoming;
    }
  }

  _setExcludeFromHistory() {
    _excludeFromHistory = _protocolType != CallProtocolType.unknown &&
        (_innerMessage?.isExcludedFromLastMessage ?? false) &&
        (_innerMessage?.isExcludedFromUnreadCount ?? false);
  }

  _setContent() {
    final i18n = AppI18n.current;
    bool isCaller = _participantRole == CallParticipantRole.caller;
    final showName = _getShowName();

    if (_participantType == CallParticipantType.c2c) {
      if (_protocolType == CallProtocolType.reject) {
        final loginUserId = _safeCurrentLoginUserId();
        final rejectedByMe = CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: _protocolType,
          callerId: _callerId,
          operatorId: _operatorId,
          loginUserId: loginUserId,
          fallbackIsSelf: _innerMessage?.isSelf,
        );
        _content = rejectedByMe
            ? i18n.t(
                zhHans: '已拒绝',
                zhHant: '已拒絕',
                en: 'Declined',
                ja: '拒否しました',
                ko: '거절함',
              )
            : i18n.t(
                zhHans: '对方已拒绝',
                zhHant: '對方已拒絕',
                en: 'Declined by other party',
                ja: '相手が拒否しました',
                ko: '상대방이 거절했습니다',
              );
      } else if (_protocolType == CallProtocolType.cancel) {
        final loginUserId = _safeCurrentLoginUserId();
        final cancelledByMe =
            CallBubbleDirection.resolveC2CTerminalActionBySelf(
          protocolType: _protocolType,
          callerId: _callerId,
          operatorId: _operatorId,
          loginUserId: loginUserId,
          fallbackIsSelf: _innerMessage?.isSelf,
        );
        _content = cancelledByMe
            ? i18n.t(
                zhHans: '已取消',
                zhHant: '已取消',
                en: 'Cancelled',
                ja: 'キャンセルしました',
                ko: '취소함',
              )
            : i18n.t(
                zhHans: '对方已取消',
                zhHant: '對方已取消',
                en: 'Cancelled by other party',
                ja: '相手がキャンセルしました',
                ko: '상대방이 취소했습니다',
              );
      } else if (_protocolType == CallProtocolType.hangup) {
        final callEnd = _jsonData?['call_end'];
        final time =
            callEnd != null ? _getShowTime(_safeInt(callEnd)) : '00:00';
        _content =
            '${i18n.t(zhHans: '通话时长', zhHant: '通話時長', en: 'Call duration', ja: '通話時間', ko: '통화 시간')}：$time';
      } else if (_protocolType == CallProtocolType.timeout) {
        _content = isCaller
            ? i18n.t(
                zhHans: '对方无应答',
                zhHant: '對方無應答',
                en: 'No answer',
                ja: '応答なし',
                ko: '응답 없음',
              )
            : i18n.t(
                zhHans: '未接听',
                zhHant: '未接聽',
                en: 'Missed call',
                ja: '不在着信',
                ko: '부재중 전화',
              );
      } else if (_protocolType == CallProtocolType.lineBusy) {
        _content = isCaller
            ? i18n.t(
                zhHans: '对方忙线中',
                zhHant: '對方忙線中',
                en: 'Line busy',
                ja: '話し中',
                ko: '통화 중',
              )
            : i18n.t(
                zhHans: '忙线未接',
                zhHant: '忙線未接',
                en: 'Line busy, missed',
                ja: '話し中で不在',
                ko: '통화 중 부재',
              );
      } else if (_protocolType == CallProtocolType.send) {
        _content = i18n.t(
          zhHans: '发起通话',
          zhHant: '發起通話',
          en: 'Call started',
          ja: '通話を開始',
          ko: '통화 시작',
        );
      } else if (_protocolType == CallProtocolType.accept) {
        _content = i18n.t(
          zhHans: '接听通话',
          zhHant: '接聽通話',
          en: 'Call answered',
          ja: '通話に応答',
          ko: '통화 수락',
        );
      } else if (_protocolType == CallProtocolType.switchToAudio) {
        _content = i18n.t(
          zhHans: '视频转语音',
          zhHant: '視訊轉語音',
          en: 'Switched to voice',
          ja: 'ビデオから音声へ切替',
          ko: '영상에서 음성으로 전환',
        );
      } else if (_protocolType == CallProtocolType.switchToAudioConfirm) {
        _content = i18n.t(
          zhHans: '确认转语音',
          zhHant: '確認轉語音',
          en: 'Confirmed switch to voice',
          ja: '音声への切替を確認',
          ko: '음성 전환 확인',
        );
      } else {
        _content = _mediaCallFallbackLabel();
      }
    } else if (_participantType == CallParticipantType.group) {
      if (_protocolType == CallProtocolType.send) {
        _content = showName +
            i18n.t(
              zhHans: '发起了群通话',
              zhHant: '發起了群通話',
              en: ' started a group call',
              ja: 'がグループ通話を開始しました',
              ko: '님이 그룹 통화를 시작했습니다',
            );
      } else if (_protocolType == CallProtocolType.cancel) {
        _content = i18n.t(
          zhHans: '通话已取消',
          zhHant: '通話已取消',
          en: 'Call cancelled',
          ja: '通話がキャンセルされました',
          ko: '통화가 취소됨',
        );
      } else if (_protocolType == CallProtocolType.hangup) {
        _content = i18n.t(
          zhHans: '通话结束',
          zhHant: '通話結束',
          en: 'Call ended',
          ja: '通話終了',
          ko: '통화 종료',
        );
      } else if (_protocolType == CallProtocolType.timeout ||
          _protocolType == CallProtocolType.lineBusy) {
        String inviteeNames = '';
        for (String invitee in _signalingInfo!.inviteeList) {
          inviteeNames = inviteeNames + invitee + '、';
        }
        _content = inviteeNames.substring(0, inviteeNames.length - 1) +
            i18n.t(
              zhHans: '未接听',
              zhHant: '未接聽',
              en: ' missed',
              ja: 'が応答しませんでした',
              ko: ' 미응답',
            );
      } else if (_protocolType == CallProtocolType.reject) {
        _content = showName +
            i18n.t(
              zhHans: '拒绝群通话',
              zhHant: '拒絕群通話',
              en: ' declined group call',
              ja: 'がグループ通話を拒否しました',
              ko: '님이 그룹 통화를 거절했습니다',
            );
      } else if (_protocolType == CallProtocolType.accept) {
        _content = showName +
            i18n.t(
              zhHans: '接听',
              zhHant: '接聽',
              en: ' answered',
              ja: 'が応答しました',
              ko: '님이 수락함',
            );
      } else if (_protocolType == CallProtocolType.switchToAudio) {
        _content = showName +
            i18n.t(
              zhHans: '视频转语音',
              zhHant: '視訊轉語音',
              en: ' switched to voice',
              ja: 'がビデオから音声へ切替',
              ko: '님이 영상에서 음성으로 전환',
            );
      } else if (_protocolType == CallProtocolType.switchToAudioConfirm) {
        _content = showName +
            i18n.t(
              zhHans: '同意视频转语音',
              zhHant: '同意視訊轉語音',
              en: ' agreed to switch to voice',
              ja: 'が音声への切替に同意',
              ko: '님이 음성 전환에 동의',
            );
      } else {
        _content = _mediaCallFallbackLabel();
      }
    } else {
      _content = _mediaCallFallbackLabel();
    }
  }

  String _mediaCallFallbackLabel() {
    final i18n = AppI18n.current;
    if (_streamMediaType == CallStreamMediaType.video ||
        _jsonData?['call_type']?.toString() == '2' ||
        (_jsonData?['mediaType']?.toString().toLowerCase() == 'video')) {
      return i18n.t(
        zhHans: '[视频通话]',
        zhHant: '[視訊通話]',
        en: '[Video call]',
        ja: '[ビデオ通話]',
        ko: '[영상 통화]',
      );
    }
    if (_streamMediaType == CallStreamMediaType.audio ||
        _jsonData?['call_type']?.toString() == '1' ||
        (_jsonData?['mediaType']?.toString().toLowerCase() == 'audio') ||
        _isCallingSignal) {
      return i18n.t(
        zhHans: '[语音通话]',
        zhHant: '[語音通話]',
        en: '[Voice call]',
        ja: '[音声通話]',
        ko: '[음성 통화]',
      );
    }
    return fallbackText();
  }

  _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  int _safeInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  _getShowTime(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final secondsShow = safeSeconds % 60;
    final minutesTotal = safeSeconds ~/ 60;
    final minutesShow = minutesTotal % 60;
    final hoursShow = minutesTotal ~/ 60;
    if (hoursShow > 0) {
      return "${_twoDigits(hoursShow)}:${_twoDigits(minutesShow)}:${_twoDigits(secondsShow)}";
    }
    return "${_twoDigits(minutesShow)}:${_twoDigits(secondsShow)}";
  }

  String _firstNotEmpty(List<String?> values) {
    for (final item in values) {
      final text = item?.trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static String _normalizeC2CPeerID(String? value) {
    return CallUserId.normalizeCallUserId(value ?? '');
  }

  _getShowName() {
    final userID = _firstNotEmpty([
      _callerId,
      _innerMessage?.sender,
      _innerMessage?.userID,
    ]);
    final groupID = _firstNotEmpty([
      _signalingInfo?.groupID,
      _innerMessage?.groupID,
      _jsonData?['groupID']?.toString(),
    ]);

    if (groupID.isNotEmpty && userID.isNotEmpty) {
      final member = GroupMemberStore.instance.memberOf(groupID, userID);
      final name = _firstNotEmpty([
        member?.nameCard,
        member?.friendRemark,
        member?.nickName,
      ]);
      if (name.isNotEmpty) {
        return name;
      }
    }

    final peerID =
        _normalizeC2CPeerID(callPeerID.isNotEmpty ? callPeerID : userID);
    if (peerID.isNotEmpty &&
        (_participantType == CallParticipantType.c2c || groupID.isEmpty)) {
      final name = DisplayNameStore.instance.c2c(peerID);
      if (name != null && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    return _firstNotEmpty([
      _innerMessage?.nameCard,
      _innerMessage?.friendRemark,
      _innerMessage?.nickName,
      _innerMessage?.sender,
      _innerMessage?.userID,
    ]);
  }
}
