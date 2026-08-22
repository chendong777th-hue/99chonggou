import 'package:dio/dio.dart';

import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

class StarredFriendItem {
  StarredFriendItem({
    required this.friendUserId,
    this.imUserId = '',
    this.starredAt,
  });

  /// 业务 userId（库内真相源）。
  final String friendUserId;

  /// TIM IM userId；映射开且有映射则下发；缺映射为空；映射关时可能等于业务号。
  final String imUserId;

  final DateTime? starredAt;

  factory StarredFriendItem.fromJson(Map<String, dynamic> json) =>
      StarredFriendItem(
        friendUserId: json['friendUserId']?.toString().trim() ?? '',
        imUserId: json['imUserId']?.toString().trim() ?? '',
        starredAt: MeResult.parseIsoDateTime(json['starredAt']),
      );
}

class StarredFriendMutationResult {
  StarredFriendMutationResult({
    required this.friendUserId,
    required this.starred,
    this.imUserId = '',
    this.starredAt,
  });

  final String friendUserId;
  final String imUserId;
  final bool starred;
  final DateTime? starredAt;

  factory StarredFriendMutationResult.fromJson(Map<String, dynamic> json) =>
      StarredFriendMutationResult(
        friendUserId: json['friendUserId']?.toString().trim() ?? '',
        imUserId: json['imUserId']?.toString().trim() ?? '',
        starred: json['starred'] as bool? ?? false,
        starredAt: MeResult.parseIsoDateTime(json['starredAt']),
      );
}

class StarredFriendApi {
  StarredFriendApi._();
  static final StarredFriendApi instance = StarredFriendApi._();

  Dio get _dio => ApiClient.instance.dio;

  /// 路径可收业务号或 IM 号；服务端归一为业务号落库。
  String _path(String friendUserId) =>
      '/me/starred-friends/${Uri.encodeComponent(friendUserId.trim())}';

  Map<String, dynamic> _asMap(dynamic raw) {
    final payload = unwrapApiPayload(raw);
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    return <String, dynamic>{};
  }

  /// GET /me/starred-friends — 信封 `{code,message,data:{items:[...]}}`。
  Future<List<StarredFriendItem>> list() async {
    final res = await _dio.get('/me/starred-friends');
    final list = extractApiList(res.data, listKeys: const ['items']);
    return list
        .whereType<Map>()
        .map((e) => StarredFriendItem.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.friendUserId.isNotEmpty)
        .toList();
  }

  Future<StarredFriendMutationResult> star(String friendUserId) async {
    final res = await _dio.put(_path(friendUserId));
    return StarredFriendMutationResult.fromJson(_asMap(res.data));
  }

  Future<StarredFriendMutationResult> unstar(String friendUserId) async {
    final res = await _dio.delete(_path(friendUserId));
    return StarredFriendMutationResult.fromJson(_asMap(res.data));
  }
}
