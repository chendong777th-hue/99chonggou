import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 持久化消息媒体的可渲染元数据。
///
/// SDK 本地历史里的图片/视频经常只有 uuid/尺寸，没有可直接展示的 URL。
/// 本服务把已经补齐过的 imageList / videoUrl / snapshotUrl 按消息写入本地，
/// 下一次历史消息进入 UI 前先 hydrate，避免首帧先出气泡再二次刷新图片。
class MessageMediaMetadataStore {
  MessageMediaMetadataStore._();

  static final MessageMediaMetadataStore instance =
      MessageMediaMetadataStore._();

  static const _dbName = 'message_media_metadata_v1.db';
  static const _table = 'message_media_metadata';

  Database? _db;
  Future<Database>? _dbOpenInFlight;
  bool _factoryReady = false;

  /// owner -> messageKey -> metadata
  final Map<String, Map<String, _MediaMetadataRecord>> _memoryByOwner =
      <String, Map<String, _MediaMetadataRecord>>{};

  bool get _useMemoryOnly => kIsWeb;

  @visibleForTesting
  String? debugOwnerUserId;

  Future<void> _ensureDatabaseFactory() async {
    if (_factoryReady) {
      return;
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _factoryReady = true;
  }

  Future<Database> _openDb() async {
    final existing = SqfliteLifecycleGuard.beforeOpen(_db);
    if (existing != null) {
      return existing;
    }
    final opening = _dbOpenInFlight;
    if (opening != null) {
      return opening;
    }
    final task = _openDbOnce();
    _dbOpenInFlight = task;
    try {
      return await task;
    } finally {
      if (identical(_dbOpenInFlight, task)) {
        _dbOpenInFlight = null;
      }
    }
  }

  Future<Database> _openDbOnce() async {
    await _ensureDatabaseFactory();
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await _createTable(db);
      },
    );
    if (!SqfliteLifecycleGuard.instance.canOpenDatabase) {
      await SqfliteLifecycleGuard.closeDatabase(db);
      throw const SqfliteClosedForBackground();
    }
    _db = db;
    return db;
  }

  Future<void> closeIfOpen() async {
    final opening = _dbOpenInFlight;
    if (opening != null) {
      try {
        await opening.timeout(const Duration(milliseconds: 400));
      } catch (_) {}
    }
    final db = _db;
    _db = null;
    await SqfliteLifecycleGuard.closeDatabase(db);
  }

  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        owner_user_id TEXT NOT NULL,
        message_key TEXT NOT NULL,
        conversation_id TEXT NOT NULL DEFAULT '',
        elem_type INTEGER NOT NULL DEFAULT 0,
        image_elem_json TEXT,
        video_elem_json TEXT,
        updated_at INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (owner_user_id, message_key)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_msg_media_owner_conv ON $_table(owner_user_id, conversation_id)',
    );
  }

  String currentOwnerUserId() {
    final fromContact =
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    if (fromContact.isNotEmpty) {
      return fromContact;
    }
    try {
      return ChatIdFormat.rawUserUid(
        TIMUIKitCore.getInstance().loginInfo.userID,
      );
    } catch (_) {
      return '';
    }
  }

  String _resolveOwner(String? ownerUserId) {
    final explicit = ChatIdFormat.rawUserUid(ownerUserId);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    final debug = debugOwnerUserId?.trim() ?? '';
    if (debug.isNotEmpty) {
      return debug;
    }
    return currentOwnerUserId();
  }

  Map<String, _MediaMetadataRecord> _memoryForOwner(String owner) {
    return _memoryByOwner.putIfAbsent(
      owner,
      () => <String, _MediaMetadataRecord>{},
    );
  }

  Future<void> hydrateMessages(
    Iterable<V2TimMessage?> messages, {
    String? ownerUserId,
  }) async {
    final list = messages.whereType<V2TimMessage>().toList(growable: false);
    if (list.isEmpty) {
      return;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return;
    }

    final keyed = <String, V2TimMessage>{};
    for (final message in list) {
      if (!_isMediaMessage(message)) {
        continue;
      }
      final key = messageStorageKey(message);
      if (key == null || key.isEmpty) {
        continue;
      }
      keyed[key] = message;
    }
    if (keyed.isEmpty) {
      return;
    }

    final records = await _loadRecords(owner: owner, keys: keyed.keys);
    if (records.isEmpty) {
      return;
    }
    records.forEach((key, record) {
      final message = keyed[key];
      if (message == null) {
        return;
      }
      _applyRecord(message, record);
    });
  }

  Future<void> persistFromMessages(
    Iterable<V2TimMessage?> messages, {
    String? ownerUserId,
  }) async {
    final records = <_MediaMetadataRecord>[];
    for (final message in messages.whereType<V2TimMessage>()) {
      final record = _recordFromMessage(
        message,
        ownerUserId: ownerUserId,
      );
      if (record != null) {
        records.add(record);
      }
    }
    if (records.isEmpty) {
      return;
    }
    await _upsertRecords(records);
  }

  Future<void> upsertFromMessage(
    V2TimMessage? message, {
    String? ownerUserId,
  }) async {
    if (message == null) {
      return;
    }
    final record = _recordFromMessage(message, ownerUserId: ownerUserId);
    if (record == null) {
      return;
    }
    await _upsertRecords(<_MediaMetadataRecord>[record]);
  }

  _MediaMetadataRecord? _recordFromMessage(
    V2TimMessage message, {
    String? ownerUserId,
  }) {
    if (!_isMediaMessage(message)) {
      return null;
    }
    final owner = _resolveOwner(ownerUserId);
    if (owner.isEmpty) {
      return null;
    }
    final key = messageStorageKey(message);
    if (key == null || key.isEmpty) {
      return null;
    }

    final imageJson = _encodeImageElem(message.imageElem);
    final videoJson = _encodeVideoElem(message.videoElem);
    if (imageJson == null && videoJson == null) {
      return null;
    }

    return _MediaMetadataRecord(
      owner: owner,
      messageKey: key,
      conversationId: _conversationIdForMessage(message),
      elemType: message.elemType,
      imageElemJson: imageJson,
      videoElemJson: videoJson,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _upsertRecords(List<_MediaMetadataRecord> records) async {
    for (final record in records) {
      _memoryForOwner(record.owner)[record.messageKey] = record;
    }
    if (_useMemoryOnly || !SqfliteLifecycleGuard.instance.writesAllowed) {
      return;
    }

    try {
      final db = await _openDb();
      final batch = db.batch();
      for (final record in records) {
        batch.insert(
          _table,
          record.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  Future<Map<String, _MediaMetadataRecord>> _loadRecords({
    required String owner,
    required Iterable<String> keys,
  }) async {
    final memory = _memoryForOwner(owner);
    final out = <String, _MediaMetadataRecord>{};
    final missing = <String>[];
    for (final key in keys) {
      final cached = memory[key];
      if (cached != null) {
        out[key] = cached;
      } else {
        missing.add(key);
      }
    }
    if (missing.isEmpty || _useMemoryOnly) {
      return out;
    }

    try {
      final db = await _openDb();
      const chunkSize = 80;
      for (var start = 0; start < missing.length; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, missing.length);
        final chunk = missing.sublist(start, end);
        final placeholders = List.filled(chunk.length, '?').join(',');
        final rows = await db.query(
          _table,
          where: 'owner_user_id = ? AND message_key IN ($placeholders)',
          whereArgs: <Object?>[owner, ...chunk],
        );
        for (final row in rows) {
          final record = _MediaMetadataRecord.fromRow(row);
          if (record == null) {
            continue;
          }
          memory[record.messageKey] = record;
          out[record.messageKey] = record;
        }
      }
    } catch (_) {}
    return out;
  }

  bool _applyRecord(V2TimMessage message, _MediaMetadataRecord record) {
    var changed = false;
    final imageElem = _decodeImageElem(record.imageElemJson);
    if (imageElem != null) {
      changed = _mergeImageElemIntoMessage(message, imageElem) || changed;
    }
    final videoElem = _decodeVideoElem(record.videoElemJson);
    if (videoElem != null) {
      changed = _mergeVideoElemIntoMessage(message, videoElem) || changed;
    }
    return changed;
  }

  static String? messageStorageKey(V2TimMessage? message) {
    if (message == null) {
      return null;
    }
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty && !msgID.startsWith(V2TimMessage.createIDPrefix)) {
      return 'msg:$msgID';
    }
    final id = message.id?.trim() ?? '';
    if (id.isNotEmpty) {
      return 'id:$id';
    }
    final conversationId = _conversationIdForMessage(message);
    final seq = message.seq?.toString().trim() ?? '';
    final random = message.random?.toString() ?? '';
    final timestamp = message.timestamp?.toString() ?? '';
    final sender = message.sender?.trim() ?? '';
    if (conversationId.isEmpty ||
        (seq.isEmpty && random.isEmpty && timestamp.isEmpty)) {
      return null;
    }
    return 'synthetic:$conversationId:$seq:$random:$timestamp:$sender:${message.elemType}';
  }

  static bool _isMediaMessage(V2TimMessage message) {
    return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO ||
        message.imageElem != null ||
        message.videoElem != null;
  }

  static String _conversationIdForMessage(V2TimMessage message) {
    final userID = message.userID?.trim() ?? '';
    if (userID.isNotEmpty) {
      return userID;
    }
    final groupID = message.groupID?.trim() ?? '';
    if (groupID.isNotEmpty) {
      return ChatIdFormat.canonicalGroupStorageId(groupID);
    }
    try {
      final raw = message.messageConvID?.toString().trim() ?? '';
      if (raw.isEmpty) {
        return '';
      }
      return message.messageConvType == 2
          ? ChatIdFormat.canonicalGroupStorageId(raw)
          : raw;
    } catch (_) {
      return '';
    }
  }

  static String? _encodeImageElem(V2TimImageElem? elem) {
    if (elem == null || !_hasUsefulImageSource(elem)) {
      return null;
    }
    final payload = <String, Object?>{
      'path': elem.path,
      'imageList': [
        for (final image in elem.imageList ?? const [])
          if (image != null)
            <String, Object?>{
              'uuid': image.uuid,
              'type': image.type,
              'size': image.size,
              'width': image.width,
              'height': image.height,
              'url': image.url,
              'localUrl': image.localUrl,
            },
      ],
    };
    return jsonEncode(payload);
  }

  static String? _encodeVideoElem(V2TimVideoElem? elem) {
    if (elem == null || !_hasUsefulVideoSource(elem)) {
      return null;
    }
    final payload = <String, Object?>{
      'videoPath': elem.videoPath,
      'UUID': elem.UUID,
      'videoSize': elem.videoSize,
      'duration': elem.duration,
      'videoType': elem.videoType,
      'snapshotPath': elem.snapshotPath,
      'snapshotUUID': elem.snapshotUUID,
      'snapshotSize': elem.snapshotSize,
      'snapshotWidth': elem.snapshotWidth,
      'snapshotHeight': elem.snapshotHeight,
      'videoUrl': elem.videoUrl,
      'snapshotUrl': elem.snapshotUrl,
      'localVideoUrl': elem.localVideoUrl,
      'localSnapshotUrl': elem.localSnapshotUrl,
    };
    return jsonEncode(payload);
  }

  static V2TimImageElem? _decodeImageElem(String? raw) {
    final map = _decodeMap(raw);
    if (map == null) {
      return null;
    }
    final images = <V2TimImage?>[];
    final imageList = map['imageList'];
    if (imageList is List) {
      for (final item in imageList) {
        if (item is! Map) {
          continue;
        }
        final imageMap = Map<String, dynamic>.from(item);
        images.add(
          V2TimImage(
            uuid: _asString(imageMap['uuid'] ?? imageMap['UUID']),
            type: _asInt(imageMap['type']) ?? 0,
            size: _asInt(imageMap['size']),
            width: _asInt(imageMap['width']),
            height: _asInt(imageMap['height']),
            url: _asString(imageMap['url']),
            localUrl: _asString(imageMap['localUrl']),
          ),
        );
      }
    }
    final elem = V2TimImageElem(
      path: _asString(map['path']),
      imageList: images,
    );
    return _hasUsefulImageSource(elem) ? elem : null;
  }

  static V2TimVideoElem? _decodeVideoElem(String? raw) {
    final map = _decodeMap(raw);
    if (map == null) {
      return null;
    }
    final elem = V2TimVideoElem(
      videoPath: _asString(map['videoPath']),
      UUID: _asString(map['UUID']),
      videoSize: _asInt(map['videoSize']),
      duration: _asInt(map['duration']),
      videoType: _asString(map['videoType']),
      snapshotPath: _asString(map['snapshotPath']),
      snapshotUUID: _asString(map['snapshotUUID']),
      snapshotSize: _asInt(map['snapshotSize']),
      snapshotWidth: _asInt(map['snapshotWidth']),
      snapshotHeight: _asInt(map['snapshotHeight']),
      videoUrl: _asString(map['videoUrl']),
      snapshotUrl: _asString(map['snapshotUrl']),
      localVideoUrl: _asString(map['localVideoUrl']),
      localSnapshotUrl: _asString(map['localSnapshotUrl']),
    );
    return _hasUsefulVideoSource(elem) ? elem : null;
  }

  static Map<String, dynamic>? _decodeMap(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static bool _mergeImageElemIntoMessage(
    V2TimMessage message,
    V2TimImageElem incoming,
  ) {
    final current = message.imageElem;
    if (current == null) {
      message.imageElem = incoming;
      if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_NONE) {
        message.elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
      }
      return true;
    }

    var changed = false;
    final incomingPath = _nonEmpty(incoming.path);
    if (_nonEmpty(current.path) == null && incomingPath != null) {
      current.path = incomingPath;
      changed = true;
    }

    final currentList = current.imageList;
    final incomingList = incoming.imageList;
    if (incomingList == null || incomingList.isEmpty) {
      return changed;
    }
    if (currentList == null || currentList.isEmpty) {
      current.imageList = List<V2TimImage?>.from(incomingList);
      return true;
    }

    for (final donor in incomingList) {
      if (donor == null) {
        continue;
      }
      final existing = currentList.firstWhere(
        (image) => image?.type == donor.type,
        orElse: () => null,
      );
      if (existing == null) {
        currentList.add(donor);
        changed = true;
        continue;
      }
      changed = _fillImage(existing, donor) || changed;
    }
    return changed;
  }

  static bool _fillImage(V2TimImage target, V2TimImage donor) {
    var changed = false;
    if (_nonEmpty(target.uuid) == null && _nonEmpty(donor.uuid) != null) {
      target.uuid = donor.uuid;
      changed = true;
    }
    if ((target.size ?? 0) <= 0 && (donor.size ?? 0) > 0) {
      target.size = donor.size;
      changed = true;
    }
    if ((target.width ?? 0) <= 0 && (donor.width ?? 0) > 0) {
      target.width = donor.width;
      changed = true;
    }
    if ((target.height ?? 0) <= 0 && (donor.height ?? 0) > 0) {
      target.height = donor.height;
      changed = true;
    }
    if (_nonEmpty(target.url) == null && _nonEmpty(donor.url) != null) {
      target.url = donor.url;
      changed = true;
    }
    if (_nonEmpty(target.localUrl) == null &&
        _nonEmpty(donor.localUrl) != null) {
      target.localUrl = donor.localUrl;
      changed = true;
    }
    return changed;
  }

  static bool _mergeVideoElemIntoMessage(
    V2TimMessage message,
    V2TimVideoElem incoming,
  ) {
    final current = message.videoElem;
    if (current == null) {
      message.videoElem = incoming;
      if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_NONE) {
        message.elemType = MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
      }
      return true;
    }

    var changed = false;
    changed = _fillString(
          get: () => current.videoPath,
          set: (value) => current.videoPath = value,
          donor: incoming.videoPath,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.UUID,
          set: (value) => current.UUID = value,
          donor: incoming.UUID,
        ) ||
        changed;
    changed = _fillInt(
          get: () => current.videoSize,
          set: (value) => current.videoSize = value,
          donor: incoming.videoSize,
        ) ||
        changed;
    changed = _fillInt(
          get: () => current.duration,
          set: (value) => current.duration = value,
          donor: incoming.duration,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.videoType,
          set: (value) => current.videoType = value,
          donor: incoming.videoType,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.snapshotPath,
          set: (value) => current.snapshotPath = value,
          donor: incoming.snapshotPath,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.snapshotUUID,
          set: (value) => current.snapshotUUID = value,
          donor: incoming.snapshotUUID,
        ) ||
        changed;
    changed = _fillInt(
          get: () => current.snapshotSize,
          set: (value) => current.snapshotSize = value,
          donor: incoming.snapshotSize,
        ) ||
        changed;
    changed = _fillInt(
          get: () => current.snapshotWidth,
          set: (value) => current.snapshotWidth = value,
          donor: incoming.snapshotWidth,
        ) ||
        changed;
    changed = _fillInt(
          get: () => current.snapshotHeight,
          set: (value) => current.snapshotHeight = value,
          donor: incoming.snapshotHeight,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.videoUrl,
          set: (value) => current.videoUrl = value,
          donor: incoming.videoUrl,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.snapshotUrl,
          set: (value) => current.snapshotUrl = value,
          donor: incoming.snapshotUrl,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.localVideoUrl,
          set: (value) => current.localVideoUrl = value,
          donor: incoming.localVideoUrl,
        ) ||
        changed;
    changed = _fillString(
          get: () => current.localSnapshotUrl,
          set: (value) => current.localSnapshotUrl = value,
          donor: incoming.localSnapshotUrl,
        ) ||
        changed;
    return changed;
  }

  static bool _fillString({
    required String? Function() get,
    required void Function(String value) set,
    required String? donor,
  }) {
    final next = _nonEmpty(donor);
    if (_nonEmpty(get()) != null || next == null) {
      return false;
    }
    set(next);
    return true;
  }

  static bool _fillInt({
    required int? Function() get,
    required void Function(int value) set,
    required int? donor,
  }) {
    final next = donor ?? 0;
    if ((get() ?? 0) > 0 || next <= 0) {
      return false;
    }
    set(next);
    return true;
  }

  static bool _hasUsefulImageSource(V2TimImageElem elem) {
    if (_nonEmpty(elem.path) != null) {
      return true;
    }
    for (final image in elem.imageList ?? const []) {
      if (image == null) {
        continue;
      }
      if (_nonEmpty(image.url) != null || _nonEmpty(image.localUrl) != null) {
        return true;
      }
    }
    return false;
  }

  static bool _hasUsefulVideoSource(V2TimVideoElem elem) {
    return _nonEmpty(elem.videoUrl) != null ||
        _nonEmpty(elem.snapshotUrl) != null ||
        _nonEmpty(elem.localVideoUrl) != null ||
        _nonEmpty(elem.localSnapshotUrl) != null ||
        _nonEmpty(elem.videoPath) != null ||
        _nonEmpty(elem.snapshotPath) != null;
  }

  static String? _nonEmpty(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _asString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return;
    }
    _memoryByOwner.remove(owner);
    if (_useMemoryOnly) {
      return;
    }
    try {
      final db = await _openDb();
      await db.delete(_table, where: 'owner_user_id = ?', whereArgs: [owner]);
    } catch (_) {}
  }

  @visibleForTesting
  Future<void> closeDatabaseForTest() => closeIfOpen();

  @visibleForTesting
  void debugClearMemoryForOwner(String owner) {
    _memoryByOwner.remove(owner);
  }
}

class _MediaMetadataRecord {
  const _MediaMetadataRecord({
    required this.owner,
    required this.messageKey,
    required this.conversationId,
    required this.elemType,
    required this.imageElemJson,
    required this.videoElemJson,
    required this.updatedAt,
  });

  final String owner;
  final String messageKey;
  final String conversationId;
  final int elemType;
  final String? imageElemJson;
  final String? videoElemJson;
  final int updatedAt;

  Map<String, Object?> toRow() {
    return <String, Object?>{
      'owner_user_id': owner,
      'message_key': messageKey,
      'conversation_id': conversationId,
      'elem_type': elemType,
      'image_elem_json': imageElemJson,
      'video_elem_json': videoElemJson,
      'updated_at': updatedAt,
    };
  }

  static _MediaMetadataRecord? fromRow(Map<String, Object?> row) {
    final owner = row['owner_user_id']?.toString().trim() ?? '';
    final messageKey = row['message_key']?.toString().trim() ?? '';
    if (owner.isEmpty || messageKey.isEmpty) {
      return null;
    }
    return _MediaMetadataRecord(
      owner: owner,
      messageKey: messageKey,
      conversationId: row['conversation_id']?.toString() ?? '',
      elemType: row['elem_type'] as int? ?? 0,
      imageElemJson: row['image_elem_json']?.toString(),
      videoElemJson: row['video_elem_json']?.toString(),
      updatedAt: row['updated_at'] as int? ?? 0,
    );
  }
}
