import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:tencent_cloud_chat_demo/src/services/avatar_upload_util.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

import 'api_client.dart';

class UploadApi {
  UploadApi._();
  static final UploadApi instance = UploadApi._();

  Dio get _dio => ApiClient.instance.dio;

  String _normalizeObjectUrl(String url) {
    if (url.isEmpty) {
      return url;
    }
    final schemeIndex = url.indexOf('://');
    if (schemeIndex == -1) {
      return url.replaceAll('#', '%23');
    }
    final hostPathSeparator = url.indexOf('/', schemeIndex + 3);
    if (hostPathSeparator == -1) {
      return url;
    }
    final queryIndex = url.indexOf('?', hostPathSeparator);
    final prefix = url.substring(0, hostPathSeparator);
    final rawPath = queryIndex == -1
        ? url.substring(hostPathSeparator)
        : url.substring(hostPathSeparator, queryIndex);
    final query = queryIndex == -1 ? '' : url.substring(queryIndex);
    final encodedPath = rawPath.split('/').map((segment) {
      if (segment.isEmpty) {
        return '';
      }
      try {
        return Uri.encodeComponent(Uri.decodeComponent(segment));
      } catch (_) {
        return Uri.encodeComponent(segment);
      }
    }).join('/');
    return '$prefix$encodedPath$query';
  }

  Map<String, dynamic> _responseMap(Response<dynamic> res) {
    final body = res.data;
    if (body is Map) {
      final map = body.cast<String, dynamic>();
      final nested = map['data'];
      if (nested is Map) {
        return nested.cast<String, dynamic>();
      }
      return map;
    }
    return <String, dynamic>{};
  }

  String _firstUrl(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value != 'null') {
        return _normalizeObjectUrl(value);
      }
    }
    return '';
  }

  Future<Response<dynamic>> _postAvatarMultipart(
    String path,
    File file,
  ) async {
    final prepared = await AvatarUploadUtil.prepare(file);
    if (prepared == null) {
      throw DioError(
        requestOptions: RequestOptions(path: path),
        error: 'AVATAR_PREPARE_FAILED',
        type: DioErrorType.other,
      );
    }
    try {
      final bytes = await prepared.file.readAsBytes();
      if (bytes.isEmpty) {
        throw DioError(
          requestOptions: RequestOptions(path: path),
          error: 'AVATAR_PREPARE_FAILED',
          type: DioErrorType.other,
        );
      }
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: prepared.filename,
          contentType: MediaType.parse(prepared.mimeType),
        ),
      });
      return _dio.post(
        path,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
    } finally {
      if (prepared.deleteAfterUpload) {
        try {
          if (await prepared.file.exists()) {
            await prepared.file.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<GroupAvatarUploadResult> uploadPendingGroupAvatar({
    required File file,
  }) async {
    final res = await _postAvatarMultipart('/group/avatar/upload', file);
    return _parseGroupAvatarUploadResult(res);
  }

  /// Web / 无本地路径场景：压缩字节后上传建群待用头像。
  Future<GroupAvatarUploadResult> uploadPendingGroupAvatarBytes({
    required List<int> bytes,
    String filename = 'group_avatar.jpg',
    String mimeType = 'image/jpeg',
  }) async {
    final prepared = await AvatarUploadUtil.prepareBytes(
      bytes,
      filename: filename,
      mimeType: mimeType,
    );
    if (prepared == null || prepared.bytes.isEmpty) {
      throw DioError(
        requestOptions: RequestOptions(path: '/group/avatar/upload'),
        error: 'AVATAR_PREPARE_FAILED',
        type: DioErrorType.other,
      );
    }
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        prepared.bytes,
        filename: prepared.filename,
        contentType: MediaType.parse(prepared.mimeType),
      ),
    });
    final res = await _dio.post(
      '/group/avatar/upload',
      data: form,
    );
    return _parseGroupAvatarUploadResult(res);
  }

  Future<UserAvatarUploadResult> uploadUserAvatar({
    required File file,
  }) async {
    final res = await _postAvatarMultipart('/me/avatar', file);
    final m = _responseMap(res);
    final avatarUrl = _firstUrl(
      m,
      const [
        'thumbUrl',
        'previewUrl',
        'avatarUrl',
        'faceUrl',
        'originUrl',
        'url',
      ],
    );
    return UserAvatarUploadResult(
      avatarUrl: avatarUrl,
      originUrl: _firstUrl(m, const ['originUrl', 'avatarUrl', 'url']),
      previewUrl: _firstUrl(m, const ['previewUrl', 'avatarUrl', 'url']),
      thumbUrl:
          _firstUrl(m, const ['thumbUrl', 'avatarUrl', 'previewUrl', 'url']),
    );
  }

  Future<GroupAvatarUploadResult> uploadGroupAvatar({
    required String groupId,
    required File file,
  }) async {
    final encodedGroupId =
        Uri.encodeComponent(ChatIdFormat.apiGroupId(groupId));
    final res =
        await _postAvatarMultipart('/group/$encodedGroupId/avatar', file);
    return _parseGroupAvatarUploadResult(res);
  }

  GroupAvatarUploadResult _parseGroupAvatarUploadResult(
    Response<dynamic> res,
  ) {
    final m = _responseMap(res);
    final thumbUrl = _firstUrl(m, const ['thumbUrl']);
    final previewUrl = _firstUrl(m, const ['previewUrl']);
    final originUrl = _firstUrl(m, const ['originUrl', 'url']);
    if (thumbUrl.isEmpty) {
      throw DioError(
        requestOptions: res.requestOptions,
        response: res,
        type: DioErrorType.response,
        error: 'MISSING_THUMB_URL',
      );
    }
    return GroupAvatarUploadResult(
      originUrl: originUrl,
      previewUrl: previewUrl.isNotEmpty ? previewUrl : thumbUrl,
      thumbUrl: thumbUrl,
    );
  }
}

class UserAvatarUploadResult {
  final String avatarUrl;
  final String originUrl;
  final String previewUrl;
  final String thumbUrl;

  UserAvatarUploadResult({
    required this.avatarUrl,
    required this.originUrl,
    required this.previewUrl,
    required this.thumbUrl,
  });
}

class GroupAvatarUploadResult {
  final String originUrl;
  final String previewUrl;
  final String thumbUrl;

  GroupAvatarUploadResult({
    required this.originUrl,
    required this.previewUrl,
    required this.thumbUrl,
  });
}
