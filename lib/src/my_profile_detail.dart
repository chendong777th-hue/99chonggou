import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:tencent_cloud_chat_demo/src/platform/permission_guard.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/desktop_modal_layout.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/change_phone_page.dart';
import 'package:tencent_cloud_chat_demo/src/api/upload_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_nickname_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/profile_signature_edit_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/about_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/contact_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/settings.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/qr_code_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_presenter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/time_ago.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_profile_widget.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_web_image_lightbox.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_screen.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';

class MyProfileDetail extends StatefulWidget {
  final V2TimUserFullInfo? userProfile;
  final TIMUIKitProfileController? controller;

  /// Web / 桌面主壳右侧嵌入：只展示资料字段，底部操作改由左侧菜单承担。
  final bool shellEmbedded;

  const MyProfileDetail({
    Key? key,
    this.userProfile,
    this.controller,
    this.shellEmbedded = false,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => MyProfileDetailState();
}

class MyProfileDetailState extends State<MyProfileDetail> {
  final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();
  late V2TimUserFullInfo? userProfile;
  late DateTime selectedDate;
  String? _phoneDisplay;
  bool _uploadingAvatar = false;
  int _profileRefreshSeq = 0;

  @override
  void initState() {
    super.initState();
    userProfile = widget.userProfile;
    if (userProfile?.birthday != null && userProfile?.birthday != 0) {
      try {
        selectedDate = DateTime.parse(userProfile!.birthday.toString());
      } catch (_) {
        selectedDate = DateTime.now();
      }
    } else {
      selectedDate = DateTime.now();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refreshUserProfile());
      _loadAccountInfo();
      unawaited(MomentsSettingsService.instance.hydrateFromLocal());
    });
  }

  Future<void> _refreshUserProfile() async {
    if (!mounted) return;
    final seq = ++_profileRefreshSeq;
    try {
      final selfVm = serviceLocator<TUISelfInfoViewModel>();
      final userId =
          userProfile?.userID?.trim() ?? selfVm.loginInfo?.userID?.trim() ?? '';
      if (userId.isEmpty) {
        return;
      }

      final localRecord = await UserProfileLocalService.instance.read(userId);
      if (localRecord != null && mounted && seq == _profileRefreshSeq) {
        setState(() {
          userProfile = localRecord.toV2TimUserFullInfo();
        });
      }

      String? backendAvatar;
      String? backendNickname;
      if (!kIsWeb) {
        try {
          final me = await AuthApi.instance.fetchMe();
          backendAvatar = me.avatarUrl?.trim();
          backendNickname = me.nickname.trim();
          await UserProfileLocalService.instance.saveMeResult(me);
        } catch (_) {}
      }

      V2TimUserFullInfo? imInfo;
      final infoRes = await TIMUIKitCore.getSDKInstance()
          .getUsersInfo(userIDList: [userId]);
      if (infoRes.code == 0 &&
          infoRes.data != null &&
          infoRes.data!.isNotEmpty) {
        imInfo = infoRes.data!.first;
        await UserProfileLocalService.instance.saveUserFullInfo(imInfo);
      }

      final localAfter = await UserProfileLocalService.instance.read(userId);

      final faceUrl = UserAvatarHelper.pickBestPreferBackend(
        imFaceUrl:
            imInfo?.faceUrl ?? localAfter?.avatarUrl ?? userProfile?.faceUrl,
        backendAvatarUrl: backendAvatar ?? localAfter?.avatarUrl,
      );
      final resolved = UserAvatarHelper.resolveDisplayUrl(faceUrl) ?? faceUrl;
      if (!mounted || seq != _profileRefreshSeq) {
        return;
      }

      setState(() {
        userProfile = localAfter?.toV2TimUserFullInfo() ??
            imInfo ??
            userProfile ??
            V2TimUserFullInfo(userID: userId);
        if (backendNickname != null && backendNickname.isNotEmpty) {
          userProfile!.nickName = backendNickname;
        } else if ((imInfo?.nickName?.trim().isNotEmpty ?? false)) {
          userProfile!.nickName = imInfo!.nickName;
        }
        if (resolved.trim().isNotEmpty) {
          userProfile!.faceUrl = resolved;
        }
        if ((imInfo?.selfSignature?.trim().isNotEmpty ?? false)) {
          userProfile!.selfSignature = imInfo!.selfSignature;
        }
        if (imInfo?.gender != null) {
          userProfile!.gender = imInfo!.gender;
        }
        if (imInfo?.birthday != null) {
          userProfile!.birthday = imInfo!.birthday;
        }
      });

      if (imInfo != null) {
        if (backendNickname != null && backendNickname.isNotEmpty) {
          imInfo.nickName = backendNickname;
        }
        if (resolved.trim().isNotEmpty) {
          imInfo.faceUrl = resolved;
        }
        selfVm.setLoginInfo(imInfo);
        Provider.of<LoginUserInfo>(context, listen: false)
            .setLoginUserInfo(imInfo);
        await UserProfileLocalService.instance.saveUserFullInfo(imInfo);
      }
    } catch (_) {}
  }

  Future<void> _loadAccountInfo() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString(Const.SMS_LOGIN_PHONE);
        if (!mounted) return;
        if (cached != null && cached.isNotEmpty) {
          setState(() => _phoneDisplay = _formatPhoneForDisplay(cached));
        }
        return;
      }
      final me = await AuthApi.instance.fetchMe();
      if (!mounted) return;
      final rawPhone = me.phone.contains('*') ? me.phoneMasked : me.phone;
      setState(() {
        _phoneDisplay = _formatPhoneForDisplay(rawPhone);
      });
    } on DioError {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(Const.SMS_LOGIN_PHONE);
      if (!mounted) return;
      if (cached != null && cached.isNotEmpty) {
        setState(() => _phoneDisplay = _formatPhoneForDisplay(cached));
      }
    } catch (_) {}
  }

  static String _formatPhoneForDisplay(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 13 && digits.startsWith('86')) {
      return digits.substring(digits.length - 11);
    }
    if (digits.length == 11) return digits;
    return phone;
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AccountSessionService.instance.clearForLogout(
      reason: 'profile_detail_logout',
    );
    if (context.mounted) {
      InitStep.directToLogin(context);
    }
  }

  Future<void> showGenderChoseSheet(
      BuildContext context, TUITheme theme) async {
    final i18n = AppI18n.of(context);
    final current = userProfile?.gender;
    final selected = await AppDialog.actionSheet<int>(
      title: i18n.t(
        zhHans: '性别',
        zhHant: '性別',
        en: 'Gender',
        ja: '性別',
        ko: '성별',
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
            zhHans: '男',
            zhHant: '男',
            en: 'Male',
            ja: '男性',
            ko: '남성',
          ),
          value: 1,
          enabled: current != 1,
        ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '女',
            zhHant: '女',
            en: 'Female',
            ja: '女性',
            ko: '여성',
          ),
          value: 2,
          enabled: current != 2,
        ),
      ],
    );
    if (selected == null || !mounted) return;
    final res = await widget.controller?.updateGender(selected);
    if (res?.code == 0 && mounted) {
      setState(() => userProfile?.gender = selected);
      _syncLoginUserInfo();
    }
  }

  String _formatBirthdayDisplay(int? birthday) {
    if (birthday == null || birthday == 0) {
      return AppI18n.of(context).t(
        zhHans: '未填写',
        zhHant: '未填寫',
        en: 'Not filled',
        ja: '未入力',
        ko: '미입력',
      );
    }
    try {
      final date = DateTime.parse(birthday.toString());
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return AppI18n.of(context).t(
        zhHans: '未填写',
        zhHant: '未填寫',
        en: 'Not filled',
        ja: '未入力',
        ko: '미입력',
      );
    }
  }

  DateTime _clampBirthdayDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min = DateTime(1900);
    if (date.isBefore(min)) return min;
    if (date.isAfter(today)) return today;
    return date;
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final sheetBackground = theme.conversationItemBgColor ??
        theme.weakBackgroundColor ??
        Colors.white;
    final titleColor = theme.darkTextColor ?? Colors.black;
    final actionColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);

    DateTime tempDate = _clampBirthdayDate(selectedDate);
    final maxDate = DateTime.now();
    final minDate = DateTime(1900);

    final pickedDate = await showAdaptiveModalSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      desktopMaxWidth: 420,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: sheetBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: Text(
                              AppI18n.of(context).t(
                                zhHans: '取消',
                                zhHant: '取消',
                                en: 'Cancel',
                                ja: 'キャンセル',
                                ko: '취소',
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                color: titleColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              AppI18n.of(context).t(
                                zhHans: '选择生日',
                                zhHant: '選擇生日',
                                en: 'Select Birthday',
                                ja: '誕生日を選択',
                                ko: '생일 선택',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext, tempDate),
                            child: Text(
                              AppI18n.of(context).t(
                                zhHans: '确定',
                                zhHant: '確定',
                                en: 'OK',
                                ja: 'OK',
                                ko: '확인',
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: actionColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 0.5, color: dividerColor),
                    SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: tempDate,
                        minimumDate: minDate,
                        maximumDate: maxDate,
                        onDateTimeChanged: (date) {
                          setModalState(() {
                            tempDate = _clampBirthdayDate(date);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (pickedDate == null) {
      return;
    }
    final normalized = _clampBirthdayDate(pickedDate);
    if (normalized == selectedDate &&
        userProfile?.birthday != null &&
        userProfile!.birthday != 0) {
      return;
    }
    final birthdayString = normalized.year.toString() +
        TimeAgo.getMonth(normalized) +
        TimeAgo.getDay(normalized);
    final result =
        await widget.controller?.updateBirthday(int.parse(birthdayString));
    if (result?.code == 0) {
      setState(() {
        selectedDate = normalized;
        userProfile?.birthday = int.parse(birthdayString);
      });
      _syncLoginUserInfo();
    }
  }

  String handleGender(int gender) {
    switch (gender) {
      case 0:
        return AppI18n.of(context).t(
          zhHans: '未设置',
          zhHant: '未設定',
          en: 'Not set',
          ja: '未設定',
          ko: '설정 안 됨',
        );
      case 1:
        return AppI18n.of(context).t(
          zhHans: '男',
          zhHant: '男',
          en: 'Male',
          ja: '男性',
          ko: '남성',
        );
      case 2:
        return AppI18n.of(context).t(
          zhHans: '女',
          zhHant: '女',
          en: 'Female',
          ja: '女性',
          ko: '여성',
        );
      default:
        return "";
    }
  }

  String _avatarUploadErrorMessage(DioError e) {
    if (e.error == 'AVATAR_PREPARE_FAILED') {
      return AppI18n.of(context).t(
        zhHans: '图片处理失败，请换一张 JPG/PNG 后重试',
        zhHant: '圖片處理失敗，請換一張 JPG/PNG 後重試',
        en: 'Image processing failed. Try another JPG/PNG.',
        ja: '画像処理に失敗しました。別のJPG/PNGをお試しください。',
        ko: '이미지 처리 실패. 다른 JPG/PNG를 사용해 주세요.',
      );
    }
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString() ?? '';
      switch (code) {
        case 'UNSUPPORTED_TYPE':
          return AppI18n.of(context).t(
            zhHans: '仅支持 JPG、PNG、WEBP 图片',
            zhHant: '僅支援 JPG、PNG、WEBP 圖片',
            en: 'Only JPG, PNG, and WEBP are supported',
            ja: 'JPG、PNG、WEBPのみ対応',
            ko: 'JPG, PNG, WEBP만 지원',
          );
        case 'INVALID_IMAGE':
          return AppI18n.of(context).t(
            zhHans: '图片文件无效',
            zhHant: '圖片檔案無效',
            en: 'Invalid image file',
            ja: '無効な画像ファイル',
            ko: '유효하지 않은 이미지',
          );
        case 'EMPTY_FILE':
          return AppI18n.of(context).t(
            zhHans: '图片文件为空',
            zhHant: '圖片檔案為空',
            en: 'Image file is empty',
            ja: '画像ファイルが空です',
            ko: '이미지 파일이 비어 있음',
          );
        case 'FILE_TOO_LARGE':
          return AppI18n.of(context).t(
            zhHans: '图片不能超过 10MB',
            zhHant: '圖片不能超過 10MB',
            en: 'Image must be under 10MB',
            ja: '画像は10MB以下にしてください',
            ko: '이미지는 10MB 이하여야 합니다',
          );
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return DioErrorMessage.sanitizeUserText(
          message,
          fallback: AppI18n.of(context).t(
            zhHans: '上传失败',
            zhHant: '上傳失敗',
            en: 'Upload failed',
            ja: 'アップロード失敗',
            ko: '업로드 실패',
          ),
        );
      }
    }
    return DioErrorMessage.forApp(e);
  }

  Future<void> _uploadAvatar(String imagePath) async {
    if (_uploadingAvatar) return;
    setState(() => _uploadingAvatar = true);
    try {
      final result = await UploadApi.instance.uploadUserAvatar(
        file: File(imagePath),
      );
      final resolved = UserAvatarHelper.resolveDisplayUrl(result.avatarUrl) ??
          result.avatarUrl;
      if (!mounted) return;
      setState(() => userProfile?.faceUrl = resolved);
      final updated = await UserAvatarHelper.applySelfAvatarUpdate(resolved);
      if (updated != null && mounted) {
        setState(() => userProfile = updated);
        Provider.of<LoginUserInfo>(context, listen: false)
            .setLoginUserInfo(updated);
      }
      if (mounted) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '修改成功',
          zhHant: '修改成功',
          en: 'Updated',
          ja: '更新しました',
          ko: '수정 완료',
        ));
      }
    } on DioError catch (e) {
      ToastUtils.toast(_avatarUploadErrorMessage(e));
    } catch (e) {
      ToastUtils.toast(DioErrorMessage.forApp(e));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    final picked = await AppGalleryPicker.pickSingleImage(context);
    if (!mounted) return;
    final imagePath = picked?.path;
    if (imagePath == null || imagePath.isEmpty) return;
    await _uploadAvatar(imagePath);
  }

  Future<void> _pickAvatarFromCamera() async {
    final allowed = await PermissionGuard.cameraForPhoto(context);
    if (!allowed || !mounted) return;
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    final imagePath = picked?.path;
    if (imagePath == null || imagePath.isEmpty || !mounted) {
      return;
    }
    await _uploadAvatar(imagePath);
  }

  String _avatarDisplayName() {
    return TencentUtils.isTextNotEmpty(userProfile?.nickName)
        ? userProfile!.nickName!
        : '';
  }

  /// 优先资料页 faceUrl，再回退当前登录用户最新头像。
  String? _resolveAvatarPreviewNetworkUrl() {
    for (final raw in <String?>[
      userProfile?.faceUrl,
      UserAvatarHelper.currentSelfFaceUrl(),
    ]) {
      final trimmed = raw?.trim() ?? '';
      if (trimmed.isEmpty || trimmed.startsWith('assets/')) {
        continue;
      }
      if (UserAvatarHelper.isDefaultPlaceholder(trimmed)) {
        continue;
      }
      final resolved = UserAvatarHelper.resolveDisplayUrl(trimmed);
      if (resolved != null && resolved.isNotEmpty) {
        return resolved;
      }
    }
    return null;
  }

  /// Web lightbox 走 HTML `<img>`，同域需 Bearer 时先拉成 data URL。
  Future<String?> _prepareAvatarPreviewUrlForLightbox() async {
    final url = _resolveAvatarPreviewNetworkUrl();
    if (url == null) {
      return null;
    }
    if (!kIsWeb) {
      return url;
    }
    final headers = UserAvatarHelper.httpHeadersFor(url);
    if (headers == null || headers.isEmpty) {
      return url;
    }
    try {
      final response = await Dio(
        BaseOptions(
          responseType: ResponseType.bytes,
          headers: headers,
          connectTimeout: 12000,
          receiveTimeout: 20000,
        ),
      ).get<List<int>>(url);
      final data = response.data;
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300 &&
          data != null &&
          data.isNotEmpty) {
        final mime =
            _guessImageMime(url, response.headers.value('content-type'));
        return 'data:$mime;base64,${base64Encode(data)}';
      }
    } catch (_) {}
    return url;
  }

  String _guessImageMime(String url, String? contentType) {
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

  ImageProvider _avatarPreviewProvider() {
    final raw = userProfile?.faceUrl?.trim() ?? '';
    if (raw.startsWith('assets/')) {
      return Image.asset(raw).image;
    }
    final resolved = _resolveAvatarPreviewNetworkUrl();
    if (resolved != null && resolved.isNotEmpty) {
      final headers = UserAvatarHelper.httpHeadersFor(resolved);
      return CachedNetworkImageProvider(
        resolved,
        headers: headers,
      );
    }
    return Avatar(
      faceUrl: '',
      showName: _avatarDisplayName(),
    ).getImageProvider();
  }

  String _avatarPreviewHeroTag() {
    final raw = userProfile?.faceUrl?.trim() ?? '';
    if (raw.startsWith('assets/')) {
      return raw;
    }
    final resolved = _resolveAvatarPreviewNetworkUrl();
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
    final userId = userProfile?.userID?.trim() ?? '';
    return userId.isNotEmpty ? 'profile_avatar_$userId' : 'profile_avatar_self';
  }

  Future<void> _openAvatarPreview() async {
    final isWideDesktop = kIsWeb ||
        DesktopModalLayout.isDesktop(context) ||
        PlatformUtils().isDesktop;

    // Web / 桌面：与聊天图片预览同路（lightbox / showMedia），不用手机版 ImageScreen。
    if (isWideDesktop) {
      final networkUrl = await _prepareAvatarPreviewUrlForLightbox();
      if (!mounted) {
        return;
      }
      if (networkUrl == null || networkUrl.isEmpty) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '暂无头像可预览',
          zhHant: '暫無頭像可預覽',
          en: 'No avatar to preview.',
          ja: 'プレビューできる画像がありません。',
          ko: '미리볼 아바타가 없습니다.',
        ));
        return;
      }

      if (kIsWeb) {
        final openUrl = networkUrl.startsWith('data:')
            ? (_resolveAvatarPreviewNetworkUrl() ?? networkUrl)
            : networkUrl;
        await ChatWebImageLightbox.show(
          context: context,
          imageUrl: networkUrl,
          onDownload: () {
            unawaited(_downloadAvatar());
          },
          onOpenExternal: () {
            final uri = Uri.tryParse(openUrl);
            if (uri == null) {
              return;
            }
            unawaited(
              launchUrl(uri, mode: LaunchMode.externalApplication),
            );
          },
        );
        return;
      }

      TUIKitWidePopup.showMedia(
        context: context,
        mediaURL: networkUrl,
        onClickOrigin: () {
          final uri = Uri.tryParse(networkUrl);
          if (uri == null) {
            return;
          }
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
        },
      );
      return;
    }

    pushMediaPreview(
      context: context,
      enableGestureBack: false,
      child: ImageScreen(
        imageProvider: _avatarPreviewProvider(),
        heroTag: _avatarPreviewHeroTag(),
        downloadFn: _downloadAvatar,
        downloadOnly: true,
        fitTallImagesToScreenWidth: false,
      ),
    );
  }

  Future<void> _downloadAvatar() async {
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

    final saved = await UserAvatarHelper.saveAvatarToGallery(
      context: context,
      faceUrl: userProfile?.faceUrl,
      userId: userProfile?.userID,
    );
    if (!mounted) {
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

  Future<void> _showAvatarSourceSheet(BuildContext context) async {
    if (_uploadingAvatar) return;
    final i18n = AppI18n.of(context);
    final isDesktop = kIsWeb || DesktopModalLayout.isDesktop(context);

    final result = await AppDialog.actionSheet<String>(
      title: i18n.t(
        zhHans: '更换头像',
        zhHant: '更換頭像',
        en: 'Change Avatar',
        ja: 'プロフィール画像を変更',
        ko: '프로필 사진 변경',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: [
        if (!isDesktop)
          AppActionSheetItem(
            text: i18n.t(
              zhHans: '拍照',
              zhHant: '拍照',
              en: 'Take Photo',
              ja: '写真を撮る',
              ko: '사진 촬영',
            ),
            value: 'camera',
          ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: isDesktop ? '从本地选择' : '从手机相册选择',
            zhHant: isDesktop ? '從本機選擇' : '從手機相簿選擇',
            en: isDesktop ? 'Choose from Files' : 'Choose from Gallery',
            ja: isDesktop ? 'ファイルから選択' : 'ギャラリーから選択',
            ko: isDesktop ? '파일에서 선택' : '갤러리에서 선택',
          ),
          value: 'gallery',
        ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '查看头像',
            zhHant: '查看頭像',
            en: 'View Avatar',
            ja: 'プロフィール画像を表示',
            ko: '프로필 사진 보기',
          ),
          value: 'view',
        ),
      ],
    );
    if (!mounted) return;
    if (result == 'view') {
      await _openAvatarPreview();
    } else if (result == 'camera') {
      await _pickAvatarFromCamera();
    } else if (result == 'gallery') {
      await _pickAvatarFromGallery();
    }
  }

  Future<void> _copyChatId() async {
    final id = ChatIdFormat.display(userProfile?.userID);
    if (id.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '未填写',
        zhHant: '未填寫',
        en: 'Not filled',
        ja: '未入力',
        ko: '미입력',
      ));
      return;
    }
    await ClipboardGuard.copy(id);
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '用户ID已复制',
      zhHant: '使用者 ID 已複製',
      en: 'User ID copied',
      ja: 'ユーザーIDをコピーしました',
      ko: '사용자 ID 복사됨',
    ));
  }

  Future<void> _openChangePhonePage(BuildContext context) async {
    if (DesktopModalLayout.isDesktop(context)) {
      final size = DesktopModalLayout.compact(context);
      final isBind = _phoneDisplay == null || _phoneDisplay!.isEmpty;
      await TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.custom,
        context: context,
        title: AppI18n.of(context).t(
          zhHans: isBind ? '绑定手机号' : '修改手机号',
          zhHant: isBind ? '綁定手機號' : '修改手機號',
          en: isBind ? 'Link Phone Number' : 'Change Phone Number',
          ja: isBind ? '電話番号を登録' : '電話番号を変更',
          ko: isBind ? '휴대전화 번호 등록' : '휴대전화 번호 변경',
        ),
        width: size.width,
        height: size.height,
        isDarkBackground: false,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: (closeFunc) => Navigator(
          onGenerateRoute: (settings) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const ChangePhonePage(embedded: true),
            );
          },
        ),
      );
      if (mounted) {
        unawaited(_loadAccountInfo());
      }
      return;
    }
    await Navigator.push(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => const ChangePhonePage(),
      ),
    );
    if (mounted) {
      unawaited(_loadAccountInfo());
    }
  }

  void _syncLoginUserInfo() {
    if (userProfile == null || !mounted) {
      return;
    }
    Provider.of<LoginUserInfo>(context, listen: false)
        .setLoginUserInfo(userProfile!);
  }

  Future<void> _openNicknameEditPage(BuildContext context) async {
    final result = await ProfileNicknameEditPage.push(
      context,
      initialNickname: userProfile?.nickName ?? '',
    );
    if (result == null || !mounted) {
      return;
    }

    _profileRefreshSeq++;
    final updated = await UserAvatarHelper.applySelfNicknameUpdate(result);
    if (!mounted) {
      return;
    }

    setState(() {
      if (updated != null) {
        userProfile = updated;
      } else {
        final userId = userProfile?.userID?.trim() ??
            serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ??
            '';
        userProfile ??= V2TimUserFullInfo(userID: userId);
        userProfile!.nickName = result;
      }
    });

    if (userProfile != null) {
      Provider.of<LoginUserInfo>(context, listen: false)
          .setLoginUserInfo(userProfile!);
    }

    final userId = userProfile?.userID?.trim() ?? '';
    if (userId.isNotEmpty) {
      widget.controller?.loadData(userId);
    }
  }

  Future<void> _openSignatureEditPage(BuildContext context) async {
    if (widget.controller == null) {
      return;
    }
    final result = await ProfileSignatureEditPage.pushWithProfileController(
      context,
      controller: widget.controller!,
      initialSignature: userProfile?.selfSignature ?? '',
      maxLength: 30,
    );
    if (result != null && mounted) {
      setState(() => userProfile?.selfSignature = result);
      _syncLoginUserInfo();
    }
  }

  void _openQrCodePage(BuildContext context) {
    final displayName = TencentUtils.isTextNotEmpty(userProfile?.nickName)
        ? userProfile!.nickName!
        : AppI18n.of(context).t(
            zhHans: '未填写昵称',
            zhHant: '未填寫暱稱',
            en: 'No nickname',
            ja: 'ニックネーム未設定',
            ko: '닉네임 없음',
          );
    final title = AppI18n.of(context).t(
      zhHans: '我的二维码',
      zhHant: '我的 QR 碼',
      en: 'My QR Code',
      ja: 'マイQRコード',
      ko: '내 QR 코드',
    );
    final page = QRCodePage(
      type: QRCodePageType.user,
      title: title,
      displayName: displayName,
      aliasLabel: AppI18n.of(context).t(
        zhHans: '99号ID',
        zhHant: '99號ID',
        en: '99 ID',
        ja: '99 ID',
        ko: '99 ID',
      ),
      aliasValue: ChatIdFormat.display(userProfile?.userID),
      faceUrl: userProfile?.faceUrl ?? "",
      shareText: "$title ${ChatIdFormat.display(userProfile?.userID)}",
      embedded: kIsWeb || DesktopModalLayout.isDesktop(context),
    );

    if (kIsWeb || DesktopModalLayout.isDesktop(context)) {
      final size = DesktopModalLayout.qrCode(context);
      unawaited(TUIKitWidePopup.showPopupWindow(
        operationKey: TUIKitWideModalOperationKey.custom,
        context: context,
        title: title,
        width: size.width,
        height: size.height,
        isDarkBackground: false,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: (_) => page,
      ));
      return;
    }

    Navigator.push(
      context,
      AppMaterialPageRoute(builder: (context) => page),
    );
  }

  void _openMyMoments() {
    final userId = ChatIdFormat.rawUserUid(userProfile?.userID ?? '');
    if (userId.isEmpty) {
      return;
    }
    unawaited(MomentsSettingsService.instance.hydrateFromLocal());
    final displayName = TencentUtils.isTextNotEmpty(userProfile?.nickName)
        ? userProfile!.nickName!.trim()
        : userId;
    Navigator.push(
      context,
      AppMaterialPageRoute(
        builder: (_) => MomentsPage(
          authorId: userId,
          profileName: displayName,
          profileAvatarUrl: userProfile?.faceUrl?.trim(),
          showCoverHeader: true,
        ),
      ),
    );
  }

  Widget _buildProfileRow({
    required Color dividerColor,
    required Color labelColor,
    required Color valueColor,
    required Color arrowColor,
    required String label,
    String? value,
    Widget? trailing,
    bool showDivider = true,
    VoidCallback? onTap,
    void Function(TapDownDetails details)? onTapDown,
    double minHeight = 56,
    bool signatureLayout = false,
  }) {
    final valueWidget = trailing ??
        (value != null
            ? Text(
                value,
                maxLines: signatureLayout ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 16, color: valueColor),
              )
            : null);

    Widget content;
    if (signatureLayout) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 17,
                    color: labelColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (valueWidget != null) ...[
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: valueWidget),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 22, color: arrowColor),
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              color: labelColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (valueWidget != null) ...[
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: valueWidget,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(Icons.chevron_right, size: 22, color: arrowColor),
              ],
            ),
          ),
        ],
      );
    }

    final row = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: dividerColor, width: 0.5))
            : null,
      ),
      alignment: Alignment.center,
      child: content,
    );

    if (onTapDown != null) {
      return Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTapDown: onTapDown,
          behavior: HitTestBehavior.opaque,
          child: row,
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: row,
      ),
    );
  }

  ({Color pageBackground, Color listBackground}) _mobileSurfaceColors(
      TUITheme theme) {
    final appBarBase =
        theme.appbarBgColor ?? theme.wideBackgroundColor ?? Colors.white;
    final isDarkBackground =
        ThemeData.estimateBrightnessForColor(appBarBase) == Brightness.dark;
    return (
      pageBackground: isDarkBackground
          ? (theme.weakBackgroundColor ?? const Color(0xFF0F0F0F))
          : const Color(0xFFF1F1F1),
      listBackground: theme.conversationItemBgColor ?? Colors.white,
    );
  }

  Widget _buildDesktopShellBody(TUITheme theme) {
    final pageBg = theme.wideBackgroundColor ?? Colors.white;
    final nickName = TencentUtils.isTextNotEmpty(userProfile?.nickName)
        ? userProfile!.nickName!
        : AppI18n.of(context).t(
            zhHans: '未填写',
            zhHant: '未填寫',
            en: 'Not filled',
            ja: '未入力',
            ko: '미입력',
          );
    final signature = TencentUtils.isTextNotEmpty(userProfile?.selfSignature)
        ? userProfile!.selfSignature!
        : AppI18n.of(context).t(
            zhHans: '未填写',
            zhHant: '未填寫',
            en: 'Not filled',
            ja: '未入力',
            ko: '미입력',
          );
    final phoneText = _phoneDisplay?.isNotEmpty == true
        ? _phoneDisplay!
        : AppI18n.of(context).t(
            zhHans: '未绑定',
            zhHant: '未綁定',
            en: 'Not linked',
            ja: '未連携',
            ko: '연결 안 됨',
          );

    final valueColor = theme.darkTextColor ?? const Color(0xFF111827);
    final emptyColor = theme.weakTextColor ?? const Color(0xFF9CA3AF);
    final labelColor = theme.weakTextColor ?? const Color(0xFF7F7F7F);

    Widget desktopRow({
      required String label,
      required String value,
      Widget? trailing,
      VoidCallback? onTap,
      bool isEmpty = false,
    }) {
      final display = value.trim().isEmpty
          ? AppI18n.of(context).t(
              zhHans: '未填写',
              zhHant: '未填寫',
              en: 'Not filled',
              ja: '未入力',
              ko: '미입력',
            )
          : value;
      final showEmptyStyle = isEmpty || value.trim().isEmpty;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: labelColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing ??
                        Text(
                          display,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            color: showEmptyStyle ? emptyColor : valueColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: pageBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
        children: [
          TIMUIKitProfileUserInfoCard(
            onClickAvatar:
                _uploadingAvatar ? null : () => _showAvatarSourceSheet(context),
            userInfo: userProfile,
          ),
          TIMUIKitProfileWidget.operationDivider(
            color: theme.weakDividerColor,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '名字',
              zhHant: '名字',
              en: 'Name',
              ja: '名前',
              ko: '이름',
            ),
            value: nickName,
            isEmpty: !TencentUtils.isTextNotEmpty(userProfile?.nickName),
            onTap: () => _openNicknameEditPage(context),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '性别',
              zhHant: '性別',
              en: 'Gender',
              ja: '性別',
              ko: '성별',
            ),
            value: handleGender(userProfile?.gender ?? 0),
            onTap: () => showGenderChoseSheet(context, theme),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '生日',
              zhHant: '生日',
              en: 'Birthday',
              ja: '誕生日',
              ko: '생일',
            ),
            value: _formatBirthdayDisplay(userProfile?.birthday),
            isEmpty:
                userProfile?.birthday == null || userProfile?.birthday == 0,
            onTap: () => _selectDate(context),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '手机号',
              zhHant: '手機號',
              en: 'Phone',
              ja: '電話番号',
              ko: '전화번호',
            ),
            value: phoneText,
            isEmpty: _phoneDisplay == null || _phoneDisplay!.isEmpty,
            onTap: () => _openChangePhonePage(context),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '99号ID',
              zhHant: '99號ID',
              en: '99 ID',
              ja: '99 ID',
              ko: '99 ID',
            ),
            value: ChatIdFormat.display(userProfile?.userID),
            onTap: _copyChatId,
          ),
          TIMUIKitProfileWidget.operationDivider(
            color: theme.weakDividerColor,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '我的二维码',
              zhHant: '我的 QR 碼',
              en: 'My QR Code',
              ja: 'マイQRコード',
              ko: '내 QR 코드',
            ),
            value: AppI18n.of(context).t(
              zhHans: '点击查看',
              zhHant: '點擊查看',
              en: 'View',
              ja: '表示',
              ko: '보기',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppI18n.of(context).t(
                    zhHans: '点击查看',
                    zhHant: '點擊查看',
                    en: 'View',
                    ja: '表示',
                    ko: '보기',
                  ),
                  style: TextStyle(fontSize: 14, color: emptyColor),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 20,
                  color: emptyColor,
                ),
              ],
            ),
            onTap: () => _openQrCodePage(context),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '朋友圈',
              zhHant: '朋友圈',
              en: 'Moments',
              ja: 'モーメンツ',
              ko: '모멘트',
            ),
            value: AppI18n.of(context).t(
              zhHans: '查看我的动态',
              zhHant: '查看我的動態',
              en: 'View my posts',
              ja: '自分の投稿を見る',
              ko: '내 게시물 보기',
            ),
            onTap: _openMyMoments,
          ),
          TIMUIKitProfileWidget.operationDivider(
            color: theme.weakDividerColor,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 16),
          ),
          desktopRow(
            label: AppI18n.of(context).t(
              zhHans: '个性签名',
              zhHant: '個性簽名',
              en: 'Bio',
              ja: '自己紹介',
              ko: '상태 메시지',
            ),
            value: signature,
            isEmpty: !TencentUtils.isTextNotEmpty(userProfile?.selfSignature),
            onTap: () => _openSignatureEditPage(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBody(TUITheme theme) {
    final surfaces = _mobileSurfaceColors(theme);
    final labelColor = theme.darkTextColor ?? const Color(0xFF191919);
    final valueColor = theme.weakTextColor ?? const Color(0xFF999999);
    final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    final arrowColor = theme.weakTextColor ?? const Color(0xFFBDBDBD);

    final nickName = TencentUtils.isTextNotEmpty(userProfile?.nickName)
        ? userProfile!.nickName!
        : AppI18n.of(context).t(
            zhHans: '未填写',
            zhHant: '未填寫',
            en: 'Not filled',
            ja: '未入力',
            ko: '미입력',
          );
    final signature = TencentUtils.isTextNotEmpty(userProfile?.selfSignature)
        ? userProfile!.selfSignature!
        : AppI18n.of(context).t(
            zhHans: '未填写',
            zhHant: '未填寫',
            en: 'Not filled',
            ja: '未入力',
            ko: '미입력',
          );
    final phoneText = _phoneDisplay?.isNotEmpty == true
        ? _phoneDisplay!
        : AppI18n.of(context).t(
            zhHans: '未绑定',
            zhHant: '未綁定',
            en: 'Not linked',
            ja: '未連携',
            ko: '연결 안 됨',
          );

    final rows = <Widget>[
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '头像',
          zhHant: '頭像',
          en: 'Avatar',
          ja: 'プロフィール画像',
          ko: '프로필 사진',
        ),
        trailing: _uploadingAvatar
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : AppUserAvatar(
                faceUrl: userProfile?.faceUrl ?? '',
                showName: userProfile?.nickName ?? '',
                size: 48,
                borderRadius: BorderRadius.circular(24),
              ),
        onTap: _uploadingAvatar ? null : () => _showAvatarSourceSheet(context),
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '名字',
          zhHant: '名字',
          en: 'Name',
          ja: '名前',
          ko: '이름',
        ),
        value: nickName,
        onTap: () => _openNicknameEditPage(context),
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '性别',
          zhHant: '性別',
          en: 'Gender',
          ja: '性別',
          ko: '성별',
        ),
        value: handleGender(userProfile?.gender ?? 0),
        onTap: () => showGenderChoseSheet(context, theme),
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '生日',
          zhHant: '生日',
          en: 'Birthday',
          ja: '誕生日',
          ko: '생일',
        ),
        value: _formatBirthdayDisplay(userProfile?.birthday),
        onTap: () => _selectDate(context),
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '手机号',
          zhHant: '手機號',
          en: 'Phone',
          ja: '電話番号',
          ko: '전화번호',
        ),
        value: phoneText,
        onTap: () => _openChangePhonePage(context),
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '99号ID',
          zhHant: '99號ID',
          en: '99 ID',
          ja: '99 ID',
          ko: '99 ID',
        ),
        value: ChatIdFormat.display(userProfile?.userID),
        onTap: _copyChatId,
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '我的二维码',
          zhHant: '我的 QR 碼',
          en: 'My QR Code',
          ja: 'マイQRコード',
          ko: '내 QR 코드',
        ),
        trailing: Icon(Icons.qr_code_2_rounded, size: 22, color: valueColor),
        onTap: () => _openQrCodePage(context),
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '朋友圈',
          zhHant: '朋友圈',
          en: 'Moments',
          ja: 'モーメンツ',
          ko: '모멘트',
        ),
        value: AppI18n.of(context).t(
          zhHans: '查看我的动态',
          zhHant: '查看我的動態',
          en: 'View my posts',
          ja: '自分の投稿を見る',
          ko: '내 게시물 보기',
        ),
        onTap: _openMyMoments,
      ),
      _buildProfileRow(
        dividerColor: dividerColor,
        labelColor: labelColor,
        valueColor: valueColor,
        arrowColor: arrowColor,
        label: AppI18n.of(context).t(
          zhHans: '个性签名',
          zhHant: '個性簽名',
          en: 'Bio',
          ja: '自己紹介',
          ko: '상태 메시지',
        ),
        value: signature,
        showDivider: false,
        minHeight: 72,
        signatureLayout: true,
        onTap: () => _openSignatureEditPage(context),
      ),
    ];

    final listCard = Container(
      color: surfaces.listBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );

    return ColoredBox(
      color: surfaces.pageBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          listCard,
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildWideScreenBody(
    TUITheme theme,
    bool isWideScreen, {
    bool showActions = true,
  }) {
    final fields = <Widget>[
      TIMUIKitProfileUserInfoCard(
        onClickAvatar:
            _uploadingAvatar ? null : () => _showAvatarSourceSheet(context),
        userInfo: userProfile,
      ),
      TIMUIKitProfileWidget.operationDivider(
        color: theme.weakDividerColor,
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 20),
      ),
      InkWell(
        onTap: () => _openNicknameEditPage(context),
        child: TIMUIKitOperationItem(
          isEmpty: !TencentUtils.isTextNotEmpty(userProfile?.nickName),
          operationName: AppI18n.of(context).t(
            zhHans: '昵称',
            zhHant: '暱稱',
            en: 'Nickname',
            ja: 'ニックネーム',
            ko: '닉네임',
          ),
          operationRightWidget: Text(
            TencentUtils.isTextNotEmpty(userProfile?.nickName)
                ? userProfile!.nickName!
                : AppI18n.of(context).t(
                    zhHans: '未填写',
                    zhHant: '未填寫',
                    en: 'Not filled',
                    ja: '未入力',
                    ko: '미입력',
                  ),
          ),
        ),
      ),
      TIMUIKitProfileWidget.userAccountBar(userProfile?.userID ?? "", false),
      TIMUIKitProfileWidget.operationDivider(
        color: theme.weakDividerColor,
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 20),
      ),
      InkWell(
        onTap: () => _openSignatureEditPage(context),
        child: TIMUIKitOperationItem(
          isEmpty: !TencentUtils.isTextNotEmpty(userProfile?.selfSignature),
          operationName: AppI18n.of(context).t(
            zhHans: '个性签名',
            zhHant: '個性簽名',
            en: 'Bio',
            ja: '自己紹介',
            ko: '상태 메시지',
          ),
          operationRightWidget: Text(
            TencentUtils.isTextNotEmpty(userProfile?.selfSignature)
                ? userProfile!.selfSignature!
                : AppI18n.of(context).t(
                    zhHans: '未填写',
                    zhHant: '未填寫',
                    en: 'Not filled',
                    ja: '未入力',
                    ko: '미입력',
                  ),
          ),
        ),
      ),
      InkWell(
        onTapDown: (details) {
          TUIKitWidePopup.showPopupWindow(
            isDarkBackground: false,
            operationKey: TUIKitWideModalOperationKey.secondaryClickUserAvatar,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            context: context,
            offset:
                Offset(details.globalPosition.dx, details.globalPosition.dy),
            child: (closeFunc) => TUIKitColumnMenu(
              data: [
                ColumnMenuItem(
                  label: AppI18n.of(context).t(
                    zhHans: '男',
                    zhHant: '男',
                    en: 'Male',
                    ja: '男性',
                    ko: '남성',
                  ),
                  onClick: () async {
                    final res = await widget.controller?.updateGender(1);
                    if (res?.code == 0) {
                      setState(() => userProfile?.gender = 1);
                    }
                    closeFunc();
                  },
                ),
                ColumnMenuItem(
                  label: AppI18n.of(context).t(
                    zhHans: '女',
                    zhHant: '女',
                    en: 'Female',
                    ja: '女性',
                    ko: '여성',
                  ),
                  onClick: () async {
                    final res = await widget.controller?.updateGender(2);
                    if (res?.code == 0) {
                      setState(() => userProfile?.gender = 2);
                    }
                    closeFunc();
                  },
                ),
              ],
            ),
          );
        },
        child: TIMUIKitProfileWidget.genderBarWithArrow(
          context,
          userProfile?.gender ?? 0,
          false,
        ),
      ),
      InkWell(
        onTap: () => _selectDate(context),
        child: TIMUIKitProfileWidget.birthdayBar(
          userProfile?.birthday ?? 0,
          false,
        ),
      ),
    ];

    if (!showActions) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: fields,
          ),
        ),
      );
    }

    return Column(
      children: [
        ...fields,
        Expanded(child: Container()),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () => _handleLogout(context),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(Icons.logout, color: theme.cautionColor, size: 15),
                    const SizedBox(width: 8),
                    Text(
                      AppI18n.of(context).t(
                        zhHans: '退出登录',
                        zhHant: '登出',
                        en: 'Log Out',
                        ja: 'ログアウト',
                        ko: '로그아웃',
                      ),
                      style: TextStyle(color: theme.cautionColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: () {
                TUIKitWidePopup.showPopupWindow(
                  operationKey: TUIKitWideModalOperationKey.settings,
                  context: context,
                  theme: theme,
                  title: AppI18n.of(context).t(
                    zhHans: '设置',
                    zhHant: '設定',
                    en: 'Settings',
                    ja: '設定',
                    ko: '설정',
                  ),
                  width: MediaQuery.of(context).size.width * 0.7,
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: (closeFunc) => Settings(closeFunc: closeFunc),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Icon(Icons.settings, color: theme.darkTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      AppI18n.of(context).t(
                        zhHans: '设置',
                        zhHant: '設定',
                        en: 'Settings',
                        ja: '設定',
                        ko: '설정',
                      ),
                      style: TextStyle(color: theme.darkTextColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 40),
            OutlinedButton(
              onPressed: () {
                TUIKitWidePopup.showPopupWindow(
                  operationKey: TUIKitWideModalOperationKey.contactUs,
                  context: context,
                  theme: theme,
                  title: AppI18n.of(context).t(
                    zhHans: '联系我们',
                    zhHant: '聯繫我們',
                    en: 'Contact Us',
                    ja: 'お問い合わせ',
                    ko: '문의하기',
                  ),
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: (closeFunc) => ContactUs(closeFunc: closeFunc),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Icon(Icons.mail_outline,
                        color: theme.darkTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      AppI18n.of(context).t(
                        zhHans: '联系我们',
                        zhHant: '聯繫我們',
                        en: 'Contact Us',
                        ja: 'お問い合わせ',
                        ko: '문의하기',
                      ),
                      style: TextStyle(color: theme.darkTextColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 40),
            OutlinedButton(
              onPressed: () {
                TUIKitWidePopup.showPopupWindow(
                  operationKey: TUIKitWideModalOperationKey.aboutUs,
                  context: context,
                  theme: theme,
                  title: AppI18n.of(context).t(
                    zhHans: '关于我们',
                    zhHant: '關於我們',
                    en: 'About Us',
                    ja: 'このアプリについて',
                    ko: '앱 정보',
                  ),
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: (closeFunc) => AboutUs(closeFunc: closeFunc),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: theme.darkTextColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      AppI18n.of(context).t(
                        zhHans: '关于',
                        zhHant: '關於',
                        en: 'About',
                        ja: 'について',
                        ko: '정보',
                      ),
                      style: TextStyle(color: theme.darkTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isWideScreen = widget.shellEmbedded ||
        TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
    final mobileSurfaces = isWideScreen ? null : _mobileSurfaceColors(theme);
    final pageBackgroundColor = isWideScreen
        ? theme.wideBackgroundColor ?? Colors.white
        : mobileSurfaces!.pageBackground;
    final appBarBackgroundColor = theme.appbarBgColor ?? Colors.white;
    final appBarTextColor =
        theme.appbarTextColor ?? theme.darkTextColor ?? Colors.black;
    final appBarIconColor = theme.primaryColor ?? const Color(0xFF1E90FF);

    if (widget.shellEmbedded) {
      return _buildDesktopShellBody(theme);
    }

    return Scaffold(
      backgroundColor: pageBackgroundColor,
      appBar: isWideScreen
          ? null
          : AppBar(
              backgroundColor: appBarBackgroundColor,
              surfaceTintColor: Colors.transparent,
              leading: BackButton(color: appBarIconColor),
              iconTheme: IconThemeData(color: appBarIconColor),
              shadowColor: theme.weakDividerColor,
              elevation: 0.5,
              centerTitle: true,
              title: Text(
                AppI18n.of(context).t(
                  zhHans: '个人资料',
                  zhHant: '個人資料',
                  en: 'Profile',
                  ja: 'プロフィール',
                  ko: '프로필',
                ),
                style: TextStyle(
                  fontSize: IMDemoConfig.appBarTitleFontSize,
                  color: appBarTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: isWideScreen
          ? Container(
              color: pageBackgroundColor,
              child: _buildWideScreenBody(theme, isWideScreen),
            )
          : _buildMobileBody(theme),
    );
  }
}
