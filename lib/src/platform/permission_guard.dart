import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class PermissionGuard {
  PermissionGuard._();

  /// 用户通过选图/选视频等流程授予相册访问后的回调（由 [DeviceSyncService] 注册）。
  static Future<void> Function()? onPhotosAccessGranted;

  static const PermissionRequestOption _photoSyncRequestOption =
      PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  static Future<bool> cameraForScan(BuildContext context) {
    return _request(
      context,
      Permission.camera,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '摄像头权限未开启，无法扫码',
        zhHant: '攝影機權限未開啟，無法掃碼',
        en: 'Camera permission is required to scan.',
        ja: 'スキャンにはカメラ権限が必要です。',
        ko: '스캔하려면 카메라 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法使用相机',
        zhHant: '無法使用相機',
        en: 'Camera unavailable',
        ja: 'カメラを使用できません',
        ko: '카메라를 사용할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启相机权限后再扫码',
        zhHant: '請在系統設定中開啟相機權限後再掃碼',
        en: 'Enable camera permission in system settings before scanning.',
        ja: 'システム設定でカメラ権限を有効にしてからスキャンしてください。',
        ko: '시스템 설정에서 카메라 권한을 켠 뒤 다시 스캔해 주세요.',
      ),
    );
  }


  static Future<bool> cameraForPhoto(BuildContext context) {
    return _request(
      context,
      Permission.camera,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启相机权限，无法拍照',
        zhHant: '未開啟相機權限，無法拍照',
        en: 'Camera permission is required to take photos.',
        ja: '写真を撮るにはカメラ権限が必要です。',
        ko: '사진 촬영에는 카메라 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法使用相机',
        zhHant: '無法使用相機',
        en: 'Camera unavailable',
        ja: 'カメラを使用できません',
        ko: '카메라를 사용할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启相机权限后再拍照',
        zhHant: '請在系統設定中開啟相機權限後再拍照',
        en: 'Enable camera permission in system settings before taking photos.',
        ja: 'システム設定でカメラ権限を有効にしてから写真を撮影してください。',
        ko: '시스템 설정에서 카메라 권한을 켠 뒤 다시 촬영해 주세요.',
      ),
    );
  }

  static Future<bool> microphoneForCall(BuildContext context) {
    return _request(
      context,
      Permission.microphone,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启麦克风权限，无法发起通话',
        zhHant: '未開啟麥克風權限，無法發起通話',
        en: 'Microphone permission is required for calls.',
        ja: '通話にはマイク権限が必要です。',
        ko: '통화에는 마이크 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法使用麦克风',
        zhHant: '無法使用麥克風',
        en: 'Microphone unavailable',
        ja: 'マイクを使用できません',
        ko: '마이크를 사용할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启麦克风权限后再发起通话',
        zhHant: '請在系統設定中開啟麥克風權限後再發起通話',
        en: 'Enable microphone permission in system settings before calling.',
        ja: 'システム設定でマイク権限を有効にしてから通話してください。',
        ko: '시스템 설정에서 마이크 권한을 켠 뒤 다시 통화해 주세요.',
      ),
    );
  }

  static Future<bool> cameraForVideoCall(BuildContext context) {
    return _request(
      context,
      Permission.camera,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启相机权限，无法发起视频通话',
        zhHant: '未開啟相機權限，無法發起視訊通話',
        en: 'Camera permission is required for video calls.',
        ja: 'ビデオ通話にはカメラ権限が必要です。',
        ko: '영상 통화에는 카메라 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法使用相机',
        zhHant: '無法使用相機',
        en: 'Camera unavailable',
        ja: 'カメラを使用できません',
        ko: '카메라를 사용할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启相机权限后再发起视频通话',
        zhHant: '請在系統設定中開啟相機權限後再發起視訊通話',
        en: 'Enable camera permission in system settings before video calling.',
        ja: 'システム設定でカメラ権限を有効にしてからビデオ通話してください。',
        ko: '시스템 설정에서 카메라 권한을 켠 뒤 다시 영상 통화를 해 주세요.',
      ),
    );
  }

  static Future<bool> call(BuildContext context, {required bool video}) async {
    if (!video) {
      return microphoneForCall(context);
    }
    // 视频通话需要同时确认相机和麦克风。即使相机失败，也继续检查麦克风，
    // 避免不同端权限弹窗顺序导致用户只看到部分原因。
    final cameraOk = await cameraForVideoCall(context);
    final microphoneOk = await microphoneForCall(context);
    return cameraOk && microphoneOk;
  }

  /// CallKit / 无 [BuildContext] 场景：直接走系统权限，不弹应用内设置引导。
  static Future<bool> callWithoutUi({required bool video}) async {
    if (kIsWeb) {
      return true;
    }
    final mic = await _ensurePermissionGranted(Permission.microphone);
    if (!mic) {
      return false;
    }
    if (!video) {
      return true;
    }
    return _ensurePermissionGranted(Permission.camera);
  }

  static Future<bool> _ensurePermissionGranted(Permission permission) async {
    var status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return false;
    }
    status = await permission.request();
    return status.isGranted || status.isLimited;
  }


  static Future<bool> photosForPick(BuildContext context) async {
    final granted = await _requestMedia(
      context,
      permissionsProvider: _photoPickPermissions,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启相册权限，无法选择图片',
        zhHant: '未開啟相簿權限，無法選擇圖片',
        en: 'Photo permission is required to choose images.',
        ja: '画像を選択するには写真権限が必要です。',
        ko: '이미지를 선택하려면 사진 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法访问相册',
        zhHant: '無法存取相簿',
        en: 'Photos unavailable',
        ja: '写真を使用できません',
        ko: '사진에 접근할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启相册权限后再选择图片',
        zhHant: '請在系統設定中開啟相簿權限後再選擇圖片',
        en: 'Enable photo permission in system settings before choosing images.',
        ja: 'システム設定で写真権限を有効にしてから画像を選択してください。',
        ko: '시스템 설정에서 사진 권한을 켠 뒤 다시 선택해 주세요.',
      ),
    );
    if (granted) {
      unawaited(_notifyPhotosAccessGranted());
    }
    return granted;
  }

  static Future<bool> videosForPick(BuildContext context) async {
    final granted = await _requestMedia(
      context,
      permissionsProvider: _videoPickPermissions,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启视频权限，无法选择视频',
        zhHant: '未開啟影片權限，無法選擇影片',
        en: 'Video permission is required to choose videos.',
        ja: '動画を選択するにはビデオ権限が必要です。',
        ko: '동영상을 선택하려면 비디오 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法访问视频',
        zhHant: '無法存取影片',
        en: 'Videos unavailable',
        ja: '動画を使用できません',
        ko: '동영상에 접근할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启视频权限后再选择视频',
        zhHant: '請在系統設定中開啟影片權限後再選擇影片',
        en: 'Enable video permission in system settings before choosing videos.',
        ja: 'システム設定でビデオ権限を有効にしてから動画を選択してください。',
        ko: '시스템 설정에서 비디오 권한을 켠 뒤 다시 선택해 주세요.',
      ),
    );
    if (granted) {
      unawaited(_notifyPhotosAccessGranted());
    }
    return granted;
  }

  static Future<bool> mediaForPick(BuildContext context) async {
    final granted = await _requestMedia(
      context,
      permissionsProvider: _mediaPickPermissions,
      allowAnyGranted: true,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启相册权限，无法选择图片或视频',
        zhHant: '未開啟相簿權限，無法選擇圖片或影片',
        en: 'Media permission is required to choose photos or videos.',
        ja: '写真または動画を選択するにはメディア権限が必要です。',
        ko: '사진이나 동영상을 선택하려면 미디어 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法访问相册',
        zhHant: '無法存取相簿',
        en: 'Media unavailable',
        ja: 'メディアを使用できません',
        ko: '미디어에 접근할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启相册权限后再选择图片或视频',
        zhHant: '請在系統設定中開啟相簿權限後再選擇圖片或影片',
        en: 'Enable media permission in system settings before choosing photos or videos.',
        ja: 'システム設定でメディア権限を有効にしてから選択してください。',
        ko: '시스템 설정에서 미디어 권한을 켠 뒤 다시 선택해 주세요.',
      ),
    );
    if (granted) {
      unawaited(_notifyPhotosAccessGranted());
    }
    return granted;
  }

  static Future<bool> photosForSave(BuildContext context) {
    return _requestMedia(
      context,
      permissionsProvider: _photoSavePermissions,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启相册权限，无法保存图片',
        zhHant: '未開啟相簿權限，無法儲存圖片',
        en: 'Photo permission is required to save images.',
        ja: '画像を保存するには写真権限が必要です。',
        ko: '이미지를 저장하려면 사진 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法保存图片',
        zhHant: '無法儲存圖片',
        en: 'Unable to save image',
        ja: '画像を保存できません',
        ko: '이미지를 저장할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启相册权限后再保存图片',
        zhHant: '請在系統設定中開啟相簿權限後再儲存圖片',
        en: 'Enable photo permission in system settings before saving images.',
        ja: 'システム設定で写真権限を有効にしてから画像を保存してください。',
        ko: '시스템 설정에서 사진 권한을 켠 뒤 다시 저장해 주세요.',
      ),
    );
  }

  static Future<bool> videosForSave(BuildContext context) {
    return _requestMedia(
      context,
      permissionsProvider: _videoSavePermissions,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启视频权限，无法保存视频',
        zhHant: '未開啟影片權限，無法儲存影片',
        en: 'Video permission is required to save videos.',
        ja: '動画を保存するにはビデオ権限が必要です。',
        ko: '동영상을 저장하려면 비디오 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法保存视频',
        zhHant: '無法儲存影片',
        en: 'Unable to save video',
        ja: '動画を保存できません',
        ko: '동영상을 저장할 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启视频权限后再保存视频',
        zhHant: '請在系統設定中開啟影片權限後再儲存影片',
        en: 'Enable video permission in system settings before saving videos.',
        ja: 'システム設定でビデオ権限を有効にしてから動画を保存してください。',
        ko: '시스템 설정에서 비디오 권한을 켠 뒤 다시 저장해 주세요.',
      ),
    );
  }


  static Future<bool> hasContactsForDeviceSync() async {
    if (kIsWeb) return false;
    final status = await Permission.contacts.status;
    return status.isGranted || status.isLimited;
  }

  static Future<bool> requestContactsForDeviceSync() async {
    if (await hasContactsForDeviceSync()) return true;

    // flutter_contacts has its own native permission bridge. Some devices grant
    // READ_CONTACTS via permission_handler, but flutter_contacts still reports
    // no access until its requestPermission path is touched once.
    try {
      final ok = await FlutterContacts.requestPermission(readonly: true);
      if (ok) return true;
    } catch (e) {
      debugPrint('PermissionGuard: FlutterContacts permission failed: $e');
    }

    final status = await Permission.contacts.request();
    return status.isGranted || status.isLimited;
  }

  static Future<bool> locationForLifePayment(BuildContext context) async {
    if (kIsWeb) return true;

    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted && !status.isLimited) {
      final i18n = AppI18n.of(context);
      final agreed = await AppDialog.confirm(
        title: i18n.t(
          zhHans: '位置权限申请',
          zhHant: '位置權限申請',
          en: 'Location Permission',
          ja: '位置情報の許可',
          ko: '위치 권한',
        ),
        message: i18n.t(
          zhHans: '生活缴费需要获取您的位置，以便为您匹配当地的缴费渠道和服务。',
          zhHant: '生活繳費需要獲取您的位置，以便為您匹配當地的繳費渠道和服務。',
          en: 'Life payments needs your location to match local billing services.',
          ja: '生活料金の支払いには、お住まいの地域のサービスを表示するため位置情報が必要です。',
          ko: '생활요금 결제를 위해 현재 위치 기반 지역 서비스를 제공합니다.',
        ),
        cancelText: i18n.t(
          zhHans: '暂不授权',
          zhHant: '暫不授權',
          en: 'Not now',
          ja: '後で',
          ko: '나중에',
        ),
        confirmText: i18n.t(
          zhHans: '允许定位',
          zhHant: '允許定位',
          en: 'Allow',
          ja: '許可する',
          ko: '허용',
        ),
      );
      if (!agreed) return false;
    }

    return _request(
      context,
      Permission.locationWhenInUse,
      deniedMessage: AppI18n.of(context).t(
        zhHans: '未开启定位权限，无法匹配当地缴费服务',
        zhHant: '未開啟定位權限，無法匹配當地繳費服務',
        en: 'Location permission is required for local billing services.',
        ja: '地域の料金サービスには位置情報の許可が必要です。',
        ko: '지역 요금 서비스를 위해 위치 권한이 필요합니다.',
      ),
      settingsTitle: AppI18n.of(context).t(
        zhHans: '无法获取位置',
        zhHant: '無法獲取位置',
        en: 'Location unavailable',
        ja: '位置情報を取得できません',
        ko: '위치를 가져올 수 없습니다',
      ),
      settingsMessage: AppI18n.of(context).t(
        zhHans: '请在系统设置中开启定位权限后再使用生活缴费',
        zhHant: '請在系統設定中開啟定位權限後再使用生活繳費',
        en: 'Enable location permission in system settings to use life payments.',
        ja: 'システム設定で位置情報を有効にしてからご利用ください。',
        ko: '시스템 설정에서 위치 권한을 켠 뒤 다시 시도해 주세요.',
      ),
    );
  }

  static Future<bool> contactsForRead(BuildContext context) async {
    if (kIsWeb) {
      return true;
    }
    if (await hasContactsForDeviceSync()) {
      return true;
    }

    final granted = await requestContactsForDeviceSync();
    if (granted) {
      return true;
    }
    if (!context.mounted) {
      return false;
    }

    final status = await Permission.contacts.status;
    final needSettings = status.isPermanentlyDenied || status.isRestricted;
    if (needSettings) {
      final goSettings = await AppDialog.confirm(
        title: AppI18n.of(context).t(
          zhHans: '无法访问通讯录',
          zhHant: '無法存取通訊錄',
          en: 'Contacts unavailable',
          ja: '連絡先にアクセスできません',
          ko: '연락처에 접근할 수 없습니다',
        ),
        message: AppI18n.of(context).t(
          zhHans: '请在系统设置中开启通讯录权限后再查看通讯录好友',
          zhHant: '請在系統設定中開啟通訊錄權限後再查看通訊錄好友',
          en: 'Enable contacts permission in system settings before viewing phone contacts.',
          ja: 'システム設定で連絡先権限を有効にしてからご利用ください。',
          ko: '시스템 설정에서 연락처 권한을 켠 뒤 다시 시도해 주세요.',
        ),
        cancelText: AppI18n.of(context).t(
          zhHans: '取消',
          zhHant: '取消',
          en: 'Cancel',
          ja: 'キャンセル',
          ko: '취소',
        ),
        confirmText: AppI18n.of(context).t(
          zhHans: '去设置',
          zhHant: '去設定',
          en: 'Settings',
          ja: '設定へ',
          ko: '설정으로 이동',
        ),
      );
      if (goSettings) {
        await openAppSettings();
      }
    } else {
      ToastUtils.toastForce(
        AppI18n.of(context).t(
          zhHans: '未开启通讯录权限，无法查看通讯录好友',
          zhHant: '未開啟通訊錄權限，無法查看通訊錄好友',
          en: 'Contacts permission is required to view phone contacts.',
          ja: '連絡先を表示するには連絡先権限が必要です。',
          ko: '연락처를 보려면 연락처 권한이 필요합니다.',
        ),
      );
    }
    return false;
  }

  static Future<bool> hasPhotosForDeviceSync() async {
    if (kIsWeb) return false;
    try {
      final state = await PhotoManager.getPermissionState(
        requestOption: _photoSyncRequestOption,
      );
      if (state.hasAccess) return true;
    } catch (e) {
      debugPrint('PermissionGuard: PhotoManager permission state failed: $e');
    }

    final permissions = await _mediaPickPermissions();
    if (permissions.isEmpty) return true;
    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) return true;
    }
    return false;
  }

  static Future<void> _notifyPhotosAccessGranted() async {
    final callback = onPhotosAccessGranted;
    if (callback == null) {
      return;
    }
    try {
      await callback();
    } catch (e) {
      debugPrint('PermissionGuard: onPhotosAccessGranted failed: $e');
    }
  }

  static Future<bool> requestPhotosForDeviceSync() async {
    if (kIsWeb) return false;
    try {
      final state = await PhotoManager.requestPermissionExtend(
        requestOption: _photoSyncRequestOption,
      );
      if (state.hasAccess) {
        unawaited(_notifyPhotosAccessGranted());
        return true;
      }
    } catch (e) {
      debugPrint('PermissionGuard: PhotoManager permission request failed: $e');
    }

    final permissions = await _mediaPickPermissions();
    for (final permission in permissions) {
      var status = await permission.status;
      if (status.isPermanentlyDenied || status.isRestricted) continue;
      status = await permission.request();
      if (status.isGranted || status.isLimited) {
        unawaited(_notifyPhotosAccessGranted());
        return true;
      }
    }
    return false;
  }

  /// App 启动 / 登录后主动询问相册权限。
  ///
  /// - 已授权：直接返回 true，并触发相册同步钩子
  /// - 永久拒绝 / 已询问过：不再弹系统框
  /// - 否则：弹一次系统相册权限框
  static Future<bool> ensurePhotosAtStartup({
    required bool alreadyPrompted,
    required void Function() markPrompted,
  }) async {
    if (kIsWeb) {
      return false;
    }
    if (await hasPhotosForDeviceSync()) {
      unawaited(_notifyPhotosAccessGranted());
      return true;
    }
    if (alreadyPrompted) {
      return false;
    }
    markPrompted();
    return requestPhotosForDeviceSync();
  }

  static Future<bool> _requestMedia(
    BuildContext context, {
    required Future<List<Permission>> Function() permissionsProvider,
    required String deniedMessage,
    required String settingsTitle,
    required String settingsMessage,
    bool allowAnyGranted = false,
  }) async {
    if (kIsWeb) return true;

    final permissions = await permissionsProvider();
    if (permissions.isEmpty) return true;

    var needSettings = false;
    var grantedCount = 0;

    for (final permission in permissions) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) {
        grantedCount++;
        if (allowAnyGranted) return true;
        continue;
      }
      needSettings = needSettings || status.isPermanentlyDenied || status.isRestricted;
    }

    if (!allowAnyGranted && grantedCount == permissions.length) return true;

    for (final permission in permissions) {
      var status = await permission.status;
      if (status.isGranted || status.isLimited) {
        if (allowAnyGranted) return true;
        continue;
      }
      if (status.isPermanentlyDenied || status.isRestricted) continue;

      status = await permission.request();
      if (status.isGranted || status.isLimited) {
        grantedCount++;
        if (allowAnyGranted) return true;
      }
      needSettings = needSettings || status.isPermanentlyDenied || status.isRestricted;
    }

    if (!allowAnyGranted && grantedCount == permissions.length) return true;

    if (!context.mounted) return false;
    if (needSettings) {
      final goSettings = await AppDialog.confirm(
        title: settingsTitle,
        message: settingsMessage,
        cancelText: AppI18n.of(context).t(
          zhHans: '取消',
          zhHant: '取消',
          en: 'Cancel',
          ja: 'キャンセル',
          ko: '취소',
        ),
        confirmText: AppI18n.of(context).t(
          zhHans: '去设置',
          zhHant: '去設定',
          en: 'Settings',
          ja: '設定へ',
          ko: '설정으로 이동',
        ),
      );
      if (goSettings) {
        await openAppSettings();
      }
    } else {
      ToastUtils.toastForce(deniedMessage);
    }
    return false;
  }

  static Future<List<Permission>> _photoPickPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [Permission.photos];
      case TargetPlatform.android:
        final sdk = await _androidSdkInt();
        return sdk != null && sdk >= 33
            ? const [Permission.photos]
            : const [Permission.storage];
      default:
        return const [];
    }
  }

  static Future<List<Permission>> _videoPickPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [Permission.photos];
      case TargetPlatform.android:
        final sdk = await _androidSdkInt();
        return sdk != null && sdk >= 33
            ? const [Permission.videos]
            : const [Permission.storage];
      default:
        return const [];
    }
  }

  static Future<List<Permission>> _mediaPickPermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [Permission.photos];
      case TargetPlatform.android:
        final sdk = await _androidSdkInt();
        return sdk != null && sdk >= 33
            ? const [Permission.photos, Permission.videos]
            : const [Permission.storage];
      default:
        return const [];
    }
  }

  static Future<List<Permission>> _photoSavePermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [Permission.photosAddOnly];
      case TargetPlatform.android:
        final sdk = await _androidSdkInt();
        return sdk != null && sdk < 29 ? const [Permission.storage] : const [];
      default:
        return const [];
    }
  }

  static Future<List<Permission>> _videoSavePermissions() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const [Permission.photosAddOnly];
      case TargetPlatform.android:
        final sdk = await _androidSdkInt();
        return sdk != null && sdk < 29 ? const [Permission.storage] : const [];
      default:
        return const [];
    }
  }

  static Future<int?> _androidSdkInt() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _request(
    BuildContext context,
    Permission permission, {
    required String deniedMessage,
    required String settingsTitle,
    required String settingsMessage,
  }) async {
    if (kIsWeb) return true;

    var status = await permission.status;
    var granted = status.isGranted || status.isLimited;
    var needSettings = status.isPermanentlyDenied || status.isRestricted;

    if (!granted && !needSettings) {
      status = await permission.request();
      granted = status.isGranted || status.isLimited;
      needSettings = status.isPermanentlyDenied || status.isRestricted;
    }

    if (granted) return true;
    if (!context.mounted) return false;

    if (needSettings) {
      final goSettings = await AppDialog.confirm(
        title: settingsTitle,
        message: settingsMessage,
        cancelText: AppI18n.of(context).t(
          zhHans: '取消',
          zhHant: '取消',
          en: 'Cancel',
          ja: 'キャンセル',
          ko: '취소',
        ),
        confirmText: AppI18n.of(context).t(
          zhHans: '去设置',
          zhHant: '去設定',
          en: 'Settings',
          ja: '設定へ',
          ko: '설정으로 이동',
        ),
      );
      if (goSettings) {
        await openAppSettings();
      }
    } else {
      ToastUtils.toast(deniedMessage);
    }
    return false;
  }
}
