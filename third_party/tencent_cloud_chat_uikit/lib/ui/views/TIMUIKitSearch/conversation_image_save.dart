import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_class.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_save_to_photos.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/permission.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_asset_utils.dart';
import 'package:universal_html/html.dart' as html;
import 'package:crypto/crypto.dart';

Future<void> saveConversationImageToGallery({
  required BuildContext context,
  required V2TimMessage message,
  required TUITheme theme,
}) async {
  try {
    String? imageUrl;
    var isLocalResource = false;
    final imageElem = message.imageElem;

    if (imageElem != null) {
      final originalImg =
          conversationImageFromList(message, V2TimImageTypesEnum.original);
      final originUrl = originalImg?.url ?? imageElem.path ?? '';
      final localUrl = imageElem.imageList?.firstOrNull?.localUrl;
      final filePath = imageElem.path;
      final isWeb = PlatformUtils().isWeb;

      if (!isWeb && filePath != null && File(filePath).existsSync()) {
        imageUrl = filePath;
        isLocalResource = true;
      } else if (localUrl != null &&
          (!isWeb && File(localUrl).existsSync())) {
        imageUrl = localUrl;
        isLocalResource = true;
      } else {
        imageUrl = originUrl;
        isLocalResource = false;
      }
    }

    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }

    await _saveConversationImageToLocal(
      context,
      message,
      imageUrl,
      isLocalResource: isLocalResource,
      theme: theme,
    );
  } catch (_) {
    TIMUIKitClass.onTIMCallback(
      TIMCallback(
        infoCode: 6660414,
        infoRecommendText: TIM_t('正在下载中'),
        type: TIMCallbackType.INFO,
      ),
    );
  }
}

Future<void> _saveConversationImageToLocal(
  BuildContext context,
  V2TimMessage message,
  String imageUrl, {
  required bool isLocalResource,
  required TUITheme theme,
}) async {
  final model = serviceLocator<TUIChatGlobalModel>();

  if (PlatformUtils().isWeb) {
    Future<void> download(String url) async {
      final http.Response r = await http.get(Uri.parse(url));
      final data = r.bodyBytes;
      final base64data = base64Encode(data);
      final a = html.AnchorElement(
        href: 'data:image/jpeg;base64,$base64data',
      );
      a.download = md5.convert(utf8.encode(url)).toString();
      a.click();
      a.remove();
    }

    await download(imageUrl);
    return;
  }

  if (PlatformUtils().isIOS) {
    if (!await Permissions.checkPermission(
      context,
      Permission.photosAddOnly.value,
      theme,
      false,
    )) {
      return;
    }
  } else if (PlatformUtils().isMobile) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt < 29) {
      if (!await Permissions.checkPermission(
        context,
        Permission.storage.value,
      )) {
        return;
      }
    }
  }

  final localPath = _resolveConversationImageLocalPath(message, model);
  if (isLocalResource && localPath.isNotEmpty) {
    final result = await _saveImageFileOrBytes(localPath, imageUrl);
    _notifyImageSaveResult(result);
    return;
  }

  if (!isLocalResource && localPath.isNotEmpty) {
    final result = await _saveImageFileOrBytes(localPath, imageUrl);
    _notifyImageSaveResult(result);
    return;
  }

  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    final result = await _downloadConversationImageAndSave(imageUrl);
    _notifyImageSaveResult(result);
    return;
  }

  final result = await _saveImageFileOrBytes(imageUrl, imageUrl);
  _notifyImageSaveResult(result);
}

String _resolveConversationImageLocalPath(
  V2TimMessage message,
  TUIChatGlobalModel model,
) {
  final path = message.imageElem?.path;
  if (path != null && path.isNotEmpty && File(path).existsSync()) {
    return path;
  }
  final localUrl = message.imageElem?.imageList?.firstOrNull?.localUrl;
  if (localUrl != null && localUrl.isNotEmpty && File(localUrl).existsSync()) {
    return localUrl;
  }
  final msgID = message.msgID;
  if (msgID != null && msgID.isNotEmpty) {
    final savedPath = model.getFileMessageLocation(msgID);
    if (savedPath.isNotEmpty && File(savedPath).existsSync()) {
      return savedPath;
    }
  }
  return '';
}

Future<dynamic> _saveImageFileOrBytes(String path, String nameSeed) async {
  final file = File(path);
  if (!file.existsSync()) return false;
  return GallerySaveToPhotos.saveFile(
    file,
    name: _conversationGalleryFileName(nameSeed),
  );
}

Future<dynamic> _downloadConversationImageAndSave(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return false;
    return _saveConversationImageBytes(bytes, url);
  } catch (_) {
    return false;
  }
}

Future<dynamic> _saveConversationImageBytes(List<int> bytes, String nameSeed) async {
  return GallerySaveToPhotos.saveBytes(
    Uint8List.fromList(bytes),
    name: _conversationGalleryFileName(nameSeed),
  );
}

String _conversationGalleryFileName(String seed) {
  final digest = md5.convert(utf8.encode(seed)).toString();
  return 'chat_img_${digest.substring(0, 12)}_${DateTime.now().millisecondsSinceEpoch}';
}

bool _isConversationImageSaveSuccess(dynamic result) {
  if (result == null) return false;
  if (result is bool) return result;
  if (result is num) {
    return result == 100 || result == 1 || result == 0;
  }
  if (result is String) {
    final value = result.trim().toLowerCase();
    if (value.isEmpty) return false;
    if (value == 'true' || value == 'success' || value == 'ok') return true;
    if (value.contains('fail') || value.contains('error')) return false;
    return true;
  }
  if (result is Map) {
    final code = result['returnCode'] ??
        result['resultCode'] ??
        result['code'] ??
        result['status'] ??
        result['errorCode'];
    if (code is num && (code == 100 || code == 1 || code == 0)) {
      return true;
    }
    if (code is String) {
      final value = code.trim().toLowerCase();
      if (value == '100' || value == '1' || value == '0' || value == 'success') {
        return true;
      }
    }

    final filePath = result['filePath'] ??
        result['path'] ??
        result['file'] ??
        result['uri'] ??
        result['url'];
    if (filePath != null && filePath.toString().trim().isNotEmpty) {
      return true;
    }

    final success = result['isSuccess'] ??
        result['success'] ??
        result['saved'] ??
        result['ok'];
    if (success is bool) return success;
    if (success is num) return success == 1 || success == 100 || success == 0;
    if (success is String) {
      final value = success.trim().toLowerCase();
      if (value == 'true' || value == '1' || value == '100' || value == 'success' || value == 'ok') {
        return true;
      }
      if (value == 'false' || value == '0' || value.contains('fail')) {
        return false;
      }
    }

    final error = result['error'] ?? result['errorMessage'] ?? result['message'];
    if (error != null && error.toString().trim().isNotEmpty) {
      return false;
    }
    return true;
  }
  return true;
}

void _notifyImageSaveResult(dynamic result) {
  final ok = _isConversationImageSaveSuccess(result);
  TIMUIKitClass.onTIMCallback(
    TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: TIM_t(ok ? '图片保存成功' : '图片保存失败'),
      infoCode: ok ? 6660406 : 6660407,
    ),
  );
}
