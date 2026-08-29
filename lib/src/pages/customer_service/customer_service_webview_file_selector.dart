import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tencent_cloud_chat_demo/src/services/system_media_picker.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/editable_asset_picker.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 客服 H5 WebView 文件选择桥接（Android `<input type="file">`）。
class CustomerServiceWebViewFileSelector {
  CustomerServiceWebViewFileSelector._();

  static const int _maxMultipleImages = 9;

  /// 为 Android WebView 注册文件选择回调。
  static Future<void> attachToAndroidController({
    required AndroidWebViewController controller,
    required BuildContext context,
  }) {
    return controller.setOnShowFileSelector((params) async {
      if (!context.mounted) {
        return <String>[];
      }
      return handle(context: context, params: params);
    });
  }

  /// 处理一次 file chooser 请求，返回 WebView 需要的 URI 列表。
  static Future<List<String>> handle({
    required BuildContext context,
    required FileSelectorParams params,
  }) async {
    try {
      if (params.isCaptureEnabled) {
        return _pickFromCamera(context);
      }

      if (_acceptsImages(params)) {
        if (params.mode == FileSelectorMode.openMultiple) {
          return _pickMultipleImages(context);
        }
        return _pickSingleImage(context);
      }

      return _pickOtherFiles(params);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CUSTOMER_SERVICE file picker: $e');
      }
      return <String>[];
    }
  }

  static bool _acceptsImages(FileSelectorParams params) {
    final types = params.acceptTypes;
    if (types.isEmpty) {
      return true;
    }
    for (final raw in types) {
      final type = raw.trim().toLowerCase();
      if (type == 'image/*' || type.startsWith('image/')) {
        return true;
      }
    }
    return false;
  }

  static Future<List<String>> _pickFromCamera(BuildContext context) async {
    final allowed = await PermissionGuard.cameraForPhoto(context);
    if (!allowed || !context.mounted) {
      return <String>[];
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    final path = picked?.path;
    if (path == null || path.isEmpty) {
      return <String>[];
    }
    return <String>[Uri.file(path).toString()];
  }

  static Future<List<String>> _pickFromGallery(BuildContext context) async {
    final allowed = await PermissionGuard.photosForPick(context);
    if (!allowed || !context.mounted) {
      return <String>[];
    }
    final pickedAssets = await SystemMediaPicker.pickImages(maxAssets: 1);
    if (!context.mounted) {
      return <String>[];
    }
    final path = pickedAssets.isEmpty ? null : pickedAssets.first.path;
    if (path == null || path.isEmpty) {
      return <String>[];
    }
    return <String>[Uri.file(path).toString()];
  }

  static Future<List<String>> _pickMultipleImages(BuildContext context) async {
    final allowed = await PermissionGuard.photosForPick(context);
    if (!allowed || !context.mounted) {
      return <String>[];
    }
    final pickedAssets = await SystemMediaPicker.pickImages(maxAssets: _maxMultipleImages);
    if (!context.mounted || pickedAssets.isEmpty) {
      return <String>[];
    }

    final uris = <String>[];
    for (final asset in pickedAssets) {
      final path = asset.path;
      if (path != null && path.isNotEmpty) {
        uris.add(Uri.file(path).toString());
      }
    }
    return uris;
  }

  static Future<List<String>> _pickSingleImage(BuildContext context) async {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (dialogContext) {
        final i18n = AppI18n.of(dialogContext);
        return CupertinoActionSheet(
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: Text(i18n.t(
              zhHans: '取消',
              zhHant: '取消',
              en: 'Cancel',
              ja: 'キャンセル',
              ko: '취소',
            )),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(dialogContext, 'camera'),
              child: Text(
                i18n.t(
                  zhHans: '拍照',
                  zhHant: '拍照',
                  en: 'Take Photo',
                  ja: '写真を撮る',
                  ko: '사진 촬영',
                ),
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(dialogContext, 'gallery'),
              child: Text(
                i18n.t(
                  zhHans: '从手机相册选择',
                  zhHant: '從手機相簿選擇',
                  en: 'Choose from Gallery',
                  ja: 'ギャラリーから選択',
                  ko: '갤러리에서 선택',
                ),
                style: TextStyle(color: theme.primaryColor),
              ),
            ),
          ],
        );
      },
    );

    if (!context.mounted || result == null || result == 'cancel') {
      return <String>[];
    }
    if (result == 'camera') {
      return _pickFromCamera(context);
    }
    if (result == 'gallery') {
      return _pickFromGallery(context);
    }
    return <String>[];
  }

  static Future<List<String>> _pickOtherFiles(FileSelectorParams params) async {
    if (params.mode == FileSelectorMode.openMultiple) {
      final attachments = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (attachments == null) {
        return <String>[];
      }
      return attachments.files
          .map((file) => file.path)
          .where((path) => path != null && path.isNotEmpty)
          .map((path) => Uri.file(path!).toString())
          .toList();
    }

    final attachment = await FilePicker.platform.pickFiles();
    if (attachment == null) {
      return <String>[];
    }
    final path = attachment.files.single.path;
    if (path == null || path.isEmpty) {
      return <String>[];
    }
    return <String>[Uri.file(path).toString()];
  }
}
