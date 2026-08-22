import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

class UikitAvatarPreviewBridge {
  UikitAvatarPreviewBridge._();

  /// Web 头像预览：同域需 Bearer 时先拉成 data URL，避免 HTML `<img>` 401，
  /// 也避免 ImageScreen 读像素触发 Same-Origin 红屏。
  static Future<String?> prepareWebPreviewUrl(String faceUrl) async {
    final raw = faceUrl.trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('data:')) {
      return raw;
    }
    final resolved = UserAvatarHelper.resolveDisplayUrl(raw) ?? raw;
    if (!kIsWeb) {
      return resolved;
    }
    final headers = UserAvatarHelper.httpHeadersFor(resolved);
    if (headers == null || headers.isEmpty) {
      return resolved;
    }
    try {
      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          headers: headers,
          connectTimeout: 12000,
          receiveTimeout: 20000,
        ),
      ).get<List<int>>(resolved);
      final data = response.data;
      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300 && data != null && data.isNotEmpty) {
        final mime = _guessImageMime(
          resolved,
          response.headers.value('content-type'),
        );
        return 'data:$mime;base64,${base64Encode(data)}';
      }
    } catch (_) {}
    return resolved;
  }

  static String _guessImageMime(String url, String? contentType) {
    final ct = contentType?.split(';').first.trim().toLowerCase() ?? '';
    if (ct.startsWith('image/')) {
      return ct;
    }
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return 'image/png';
    if (lower.contains('.gif')) return 'image/gif';
    if (lower.contains('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static Future<void> savePreview(
    BuildContext context, {
    required String faceUrl,
    required String showName,
    required int avatarType,
    String? fallbackAssetPath,
    String? fallbackAssetPackage,
  }) async {
    if (kIsWeb) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '当前暂不支持保存图片',
        zhHant: '目前暫不支援儲存圖片',
        en: 'Saving images is not supported here.',
        ja: 'ここでは画像を保存できません。',
        ko: '여기서는 이미지를 저장할 수 없습니다.',
      ));
      throw StateError('unsupported');
    }

    final saved = await UserAvatarHelper.saveAvatarPreviewToGallery(
      context: context,
      faceUrl: faceUrl,
      showName: showName,
      avatarType: avatarType,
      fallbackAssetPath: fallbackAssetPath,
      fallbackAssetPackage: fallbackAssetPackage,
    );
    if (!context.mounted) {
      return;
    }
    if (saved) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '图片已保存',
        zhHant: '圖片已儲存',
        en: 'Image saved.',
        ja: '画像を保存しました。',
        ko: '이미지가 저장되었습니다.',
      ));
      return;
    }
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '保存失败',
      zhHant: '儲存失敗',
      en: 'Failed to save image.',
      ja: '保存に失敗しました。',
      ko: '저장에 실패했습니다.',
    ));
    throw StateError('save_failed');
  }
}
