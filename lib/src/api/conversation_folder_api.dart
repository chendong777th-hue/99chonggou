import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

int? _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

bool _readBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1';
}

class ConversationFolderMemberRef {
  const ConversationFolderMemberRef({
    required this.chatType,
    required this.peerId,
    this.updatedAt,
  });

  final String chatType;
  final String peerId;
  final int? updatedAt;

  factory ConversationFolderMemberRef.fromJson(Map<String, dynamic> json) {
    return ConversationFolderMemberRef(
      chatType: json['chatType']?.toString().trim().toLowerCase() ?? '',
      peerId: json['peerId']?.toString().trim() ?? '',
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson({bool? inFolder}) {
    return <String, dynamic>{
      'chatType': chatType,
      'peerId': peerId,
      if (inFolder != null) 'inFolder': inFolder,
    };
  }
}

class ConversationFolderDto {
  const ConversationFolderDto({
    required this.folderId,
    required this.name,
    required this.scope,
    required this.sortOrder,
    required this.members,
    this.updatedAt,
    this.createdAt,
  });

  final String folderId;
  final String name;
  final String scope;
  final int sortOrder;
  final List<ConversationFolderMemberRef> members;
  final int? updatedAt;
  final int? createdAt;

  factory ConversationFolderDto.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members = <ConversationFolderMemberRef>[];
    if (rawMembers is List) {
      for (final entry in rawMembers) {
        if (entry is! Map) {
          continue;
        }
        final member = ConversationFolderMemberRef.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (member.chatType != 'c2c' && member.chatType != 'group') {
          continue;
        }
        if (member.peerId.isEmpty) {
          continue;
        }
        members.add(member);
      }
    }
    return ConversationFolderDto(
      folderId: (json['folderId'] ?? json['folder_id'])?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      scope: json['scope']?.toString().trim().toLowerCase() ?? '',
      sortOrder: _asInt(json['sortOrder'] ?? json['sort_order']) ?? 0,
      members: members,
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
      createdAt: _asInt(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toReplaceJson() {
    return <String, dynamic>{
      'folderId': folderId,
      'name': name,
      'scope': scope,
      'sortOrder': sortOrder,
      'members': members
          .map((m) => m.toJson())
          .toList(growable: false),
    };
  }
}

class ConversationFolderPage {
  const ConversationFolderPage({
    required this.folders,
    this.serverTime,
  });

  final List<ConversationFolderDto> folders;
  final int? serverTime;

  static const ConversationFolderPage empty = ConversationFolderPage(
    folders: <ConversationFolderDto>[],
  );
}

class ConversationFolderMutationResult {
  const ConversationFolderMutationResult({
    required this.ok,
    this.folder,
    this.folderId,
    this.count,
    this.updatedAt,
  });

  final bool ok;
  final ConversationFolderDto? folder;
  final String? folderId;
  final int? count;
  final int? updatedAt;

  factory ConversationFolderMutationResult.fromJson(Map<String, dynamic> json) {
    ConversationFolderDto? folder;
    final rawFolder = json['folder'];
    if (rawFolder is Map) {
      folder = ConversationFolderDto.fromJson(
        Map<String, dynamic>.from(rawFolder),
      );
    } else if ((json['folderId'] ?? json['folder_id']) != null &&
        json['name'] != null) {
      folder = ConversationFolderDto.fromJson(json);
    }
    return ConversationFolderMutationResult(
      ok: json.containsKey('ok') ? _readBool(json['ok']) : true,
      folder: folder,
      folderId: (json['folderId'] ?? json['folder_id'])?.toString().trim(),
      count: _asInt(json['count']),
      updatedAt: _asInt(json['updatedAt'] ?? json['updated_at']),
    );
  }
}

/// 会话自定义分组多端同步 API。
class ConversationFolderApi {
  ConversationFolderApi._();

  static final ConversationFolderApi instance = ConversationFolderApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<ConversationFolderPage> fetch({String? scope}) async {
    final normalizedScope = scope?.trim().toLowerCase();
    final res = await _dio.get(
      '/me/conversation-folders',
      queryParameters: <String, dynamic>{
        if (normalizedScope == 'c2c' || normalizedScope == 'group')
          'scope': normalizedScope,
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is! Map) {
      return ConversationFolderPage.empty;
    }
    final map = Map<String, dynamic>.from(payload);
    final rawFolders = map['folders'] ?? map['items'];
    final folders = <ConversationFolderDto>[];
    if (rawFolders is List) {
      for (final entry in rawFolders) {
        if (entry is! Map) {
          continue;
        }
        final folder = ConversationFolderDto.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (folder.folderId.isEmpty ||
            folder.name.isEmpty ||
            !_isValidFolderScope(folder.scope)) {
          continue;
        }
        folders.add(folder);
      }
    }
    folders.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) {
        return byOrder;
      }
      return a.name.compareTo(b.name);
    });
    return ConversationFolderPage(
      folders: folders,
      serverTime: _asInt(map['serverTime'] ?? map['server_time']),
    );
  }

  Future<ConversationFolderMutationResult> upsertFolder({
    String? folderId,
    required String name,
    required String scope,
    int? sortOrder,
  }) async {
    final trimmedName = name.trim();
    final normalizedScope = scope.trim().toLowerCase();
    if (trimmedName.isEmpty) {
      throw ArgumentError('name is required');
    }
    if (!_isValidFolderScope(normalizedScope)) {
      throw ArgumentError('scope must be all, c2c, or group');
    }
    final res = await _dio.put(
      '/me/conversation-folders',
      data: <String, dynamic>{
        if (folderId != null && folderId.trim().isNotEmpty)
          'folderId': folderId.trim(),
        'name': trimmedName,
        'scope': normalizedScope,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return ConversationFolderMutationResult.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return ConversationFolderMutationResult(
      ok: true,
      folderId: folderId?.trim(),
    );
  }

  Future<void> deleteFolder(String folderId) async {
    final id = folderId.trim();
    if (id.isEmpty) {
      return;
    }
    await _dio.delete('/me/conversation-folders/$id');
  }

  Future<ConversationFolderMutationResult> updateMembers({
    required String folderId,
    required List<ConversationFolderMemberRef> members,
    required bool inFolder,
  }) async {
    final id = folderId.trim();
    if (id.isEmpty) {
      throw ArgumentError('folderId is required');
    }
    if (members.isEmpty) {
      return ConversationFolderMutationResult(ok: true, folderId: id, count: 0);
    }
    final res = await _dio.put(
      '/me/conversation-folders/$id/members',
      data: <String, dynamic>{
        'items': members
            .map((m) => m.toJson(inFolder: inFolder))
            .toList(growable: false),
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return ConversationFolderMutationResult.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return ConversationFolderMutationResult(
      ok: true,
      folderId: id,
      count: members.length,
    );
  }

  Future<ConversationFolderMutationResult> replaceAll(
    List<ConversationFolderDto> folders,
  ) async {
    final res = await _dio.put(
      '/me/conversation-folders/replace',
      data: <String, dynamic>{
        'folders': folders
            .map((f) => f.toReplaceJson())
            .toList(growable: false),
      },
    );
    final payload = unwrapApiPayload(res.data);
    if (payload is Map) {
      return ConversationFolderMutationResult.fromJson(
        Map<String, dynamic>.from(payload),
      );
    }
    return ConversationFolderMutationResult(
      ok: true,
      count: folders.length,
    );
  }
}

bool _isValidFolderScope(String scope) {
  // 空 scope 视为合法（历史数据）；客户端 Store 会归一成 all。
  return scope.isEmpty ||
      scope == 'all' ||
      scope == 'c2c' ||
      scope == 'group';
}
