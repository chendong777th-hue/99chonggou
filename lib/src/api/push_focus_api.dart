import 'package:dio/dio.dart';

import 'api_client.dart';

/// P3：上报当前正在查看的会话，服务端据此跳过该会话 Push。
class PushFocusApi {
  PushFocusApi._();

  static final PushFocusApi instance = PushFocusApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<void> putFocus({
    required String chatType,
    required String peerOrGroupId,
  }) async {
    final type = chatType.trim().toLowerCase();
    final id = peerOrGroupId.trim();
    if (id.isEmpty) {
      return;
    }
    final Map<String, dynamic> body;
    if (type == 'group') {
      body = <String, dynamic>{
        'chatType': 'group',
        'groupId': id,
      };
    } else {
      body = <String, dynamic>{
        'chatType': 'c2c',
        'peerId': id,
      };
    }
    await _dio.put('/me/push-focus', data: body);
  }

  Future<void> deleteFocus() async {
    await _dio.delete('/me/push-focus');
  }
}
