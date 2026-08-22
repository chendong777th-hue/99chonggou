import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

enum _CoverPickSource { camera, gallery }

class MomentsCoverPicker {
  MomentsCoverPicker._();

  static Future<String?> pickAndSave(BuildContext context) async {
    final i18n = AppI18n.of(context);
    final selected = await AppDialog.actionSheet<_CoverPickSource>(
      title: i18n.t(
        zhHans: '更换封面',
        zhHant: '更換封面',
        en: 'Change Cover',
        ja: 'カバーを変更',
        ko: '커버 변경',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: [
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '拍照',
            zhHant: '拍照',
            en: 'Take Photo',
            ja: '写真を撮る',
            ko: '사진 촬영',
          ),
          value: _CoverPickSource.camera,
        ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '从手机相册选择',
            zhHant: '從手機相簿選擇',
            en: 'Choose from Gallery',
            ja: 'ギャラリーから選択',
            ko: '갤러리에서 선택',
          ),
          value: _CoverPickSource.gallery,
        ),
      ],
    );
    if (selected == null) return null;
    if (!context.mounted) return null;

    final path = switch (selected) {
      _CoverPickSource.camera => await _pickFromCamera(context),
      _CoverPickSource.gallery => await _pickFromGallery(context),
    };
    if (path == null || path.isEmpty) return null;

    return MomentsSettingsService.instance.uploadAndSaveCover(path);
  }

  static Future<String?> _pickFromGallery(BuildContext context) async {
    final picked = await AppGalleryPicker.pickSingleImage(context);
    return picked?.path;
  }

  static Future<String?> _pickFromCamera(BuildContext context) async {
    final allowed = await PermissionGuard.cameraForPhoto(context);
    if (!allowed || !context.mounted) return null;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    return picked?.path;
  }
}
