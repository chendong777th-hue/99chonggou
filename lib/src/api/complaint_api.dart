import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';

import 'api_client.dart';

/// 投诉原因，与后端 `reason` 枚举一致。
enum ComplaintReason {
  spam('spam'),
  harassment('harassment'),
  fraud('fraud'),
  pornography('pornography'),
  violence('violence'),
  illegal('illegal'),
  other('other');

  const ComplaintReason(this.value);

  final String value;
}

class ComplaintScreenshot {
  const ComplaintScreenshot({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}

class ComplaintSubmitResult {
  const ComplaintSubmitResult({
    required this.id,
    required this.chatType,
    required this.reportedUserId,
    required this.reason,
    required this.status,
    required this.screenshotUrls,
    this.groupId,
    this.content,
    this.msgKey,
    this.msgSeq,
    this.createdAt,
  });

  final int id;
  final String chatType;
  final String reportedUserId;
  final String? groupId;
  final String reason;
  final String? content;
  final String? msgKey;
  final int? msgSeq;
  final List<String> screenshotUrls;
  final String status;
  final DateTime? createdAt;

  factory ComplaintSubmitResult.fromJson(Map<String, dynamic> json) {
    final urls = json['screenshotUrls'];
    return ComplaintSubmitResult(
      id: json['id'] as int? ?? 0,
      chatType: json['chatType']?.toString() ?? '',
      reportedUserId: json['reportedUserId']?.toString() ?? '',
      groupId: json['groupId']?.toString(),
      reason: json['reason']?.toString() ?? '',
      content: json['content']?.toString(),
      msgKey: json['msgKey']?.toString(),
      msgSeq: json['msgSeq'] is int
          ? json['msgSeq'] as int
          : int.tryParse(json['msgSeq']?.toString() ?? ''),
      screenshotUrls: urls is List
          ? urls.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      status: json['status']?.toString() ?? '',
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}

/// 单聊 / 群聊投诉：`POST /me/complaints/c2c|group`。
///
/// - 无截图：`application/json`
/// - 有截图：`multipart/form-data`，字段名 `screenshots`（可多张）
class ComplaintApi {
  ComplaintApi._();

  static final ComplaintApi instance = ComplaintApi._();

  static const int maxScreenshots = 5;

  Dio get _dio => ApiClient.instance.dio;

  Future<ComplaintSubmitResult> submitC2c({
    required String reportedUserId,
    required ComplaintReason reason,
    String? content,
    String? msgKey,
    int? msgSeq,
    String? clientVersion,
    List<ComplaintScreenshot> screenshots = const [],
  }) {
    return _submit(
      path: '/me/complaints/c2c',
      fields: {
        'reportedUserId': reportedUserId.trim(),
        'reason': reason.value,
        if (content != null && content.trim().isNotEmpty)
          'content': content.trim(),
        if (msgKey != null && msgKey.trim().isNotEmpty) 'msgKey': msgKey.trim(),
        if (msgSeq != null) 'msgSeq': msgSeq,
      },
      clientVersion: clientVersion,
      screenshots: screenshots,
    );
  }

  Future<ComplaintSubmitResult> submitGroup({
    required String groupId,
    required String reportedUserId,
    required ComplaintReason reason,
    String? content,
    String? msgKey,
    int? msgSeq,
    String? clientVersion,
    List<ComplaintScreenshot> screenshots = const [],
  }) {
    return _submit(
      path: '/me/complaints/group',
      fields: {
        'groupId': groupId.trim(),
        'reportedUserId': reportedUserId.trim(),
        'reason': reason.value,
        if (content != null && content.trim().isNotEmpty)
          'content': content.trim(),
        if (msgKey != null && msgKey.trim().isNotEmpty) 'msgKey': msgKey.trim(),
        if (msgSeq != null) 'msgSeq': msgSeq,
      },
      clientVersion: clientVersion,
      screenshots: screenshots,
    );
  }

  Future<String> _resolveClientVersion(String? clientVersion) async {
    if (clientVersion != null && clientVersion.trim().isNotEmpty) {
      return clientVersion.trim();
    }
    return AppVersion.getClientVersion();
  }

  Future<ComplaintSubmitResult> _submit({
    required String path,
    required Map<String, dynamic> fields,
    String? clientVersion,
    List<ComplaintScreenshot> screenshots = const [],
  }) async {
    final version = await _resolveClientVersion(clientVersion);
    final Response res;
    if (screenshots.isEmpty) {
      // 无截图走 JSON，与文档方式 A 一致。
      res = await _dio.post(
        path,
        data: {
          ...fields,
          'clientVersion': version,
        },
      );
    } else {
      // 有截图走 multipart；msgSeq 以字符串传递更稳妥。
      final formMap = <String, dynamic>{
        for (final entry in fields.entries)
          entry.key: entry.value is int ? '${entry.value}' : entry.value,
        'clientVersion': version,
      };
      final form = FormData.fromMap(formMap);
      for (final shot in screenshots.take(maxScreenshots)) {
        form.files.add(
          MapEntry(
            'screenshots',
            MultipartFile.fromBytes(
              shot.bytes,
              filename: _ensureImageFilename(shot.filename),
            ),
          ),
        );
      }
      res = await _dio.post(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
    }

    final payload = unwrapApiPayload(res.data);
    final map = payload is Map<String, dynamic>
        ? payload
        : payload is Map
            ? Map<String, dynamic>.from(payload)
            : <String, dynamic>{};
    return ComplaintSubmitResult.fromJson(map);
  }

  /// 兜底：octet-stream 时靠后缀识别格式。
  String _ensureImageFilename(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      return 'screenshot.jpg';
    }
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp')) {
      return name;
    }
    return '$name.jpg';
  }
}
