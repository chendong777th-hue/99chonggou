import 'package:flutter/cupertino.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

typedef AvatarPreviewSaveHandler = Future<void> Function(
  BuildContext context, {
  required String faceUrl,
  required String showName,
  required int avatarType,
  String? fallbackAssetPath,
  String? fallbackAssetPackage,
});

/// Web：把头像 URL 转成可直接给 `<img>` / lightbox 用的地址（如带 Bearer 时拉成 data URL）。
typedef WebAvatarPreviewUrlPreparer = Future<String?> Function(String faceUrl);

class TIMUIKitConfig {
  /// Control if show online status of friends or contacts.
  /// This only works with [Ultimate Edition].
  /// [Default]: true.
  final bool isShowOnlineStatus;

  /// Controls if allows to check the disk memory after login.
  /// If the storage space is less than 1GB,
  /// an callback from `onTUIKitCallbackListener` will be invoked,
  /// type is `INFO`, while code is 6661403.
  final bool isCheckDiskStorageSpace;

  /// The asset path of the default avatar image.
  final String? defaultAvatarAssetPath;

  /// The configuration of border radius for all the avatar shows in TUIKit.
  final BorderRadius? defaultAvatarBorderRadius;

  /// You can use this function to customize the Modal that shows on desktop.
  /// Do not specified or return `false` will use our default implementation.
  final Future<bool> Function(
    TUIKitWideModalOperationKey operationKey,
    BuildContext context,
    Widget Function(VoidCallback closeFunc) child,
    TUITheme? theme,
    double? width,
    double? height,
    Offset? offset,
    String? initText,
    BorderRadius? borderRadius,
    bool? isDarkBackground,
    String? title,
    VoidCallback? onSubmit,
    Widget? submitWidget,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
  )? showDesktopModalFunc;

  /// Determines whether TUIKit should preload some messages after initialization for faster message display,
  /// with a default value of `true`, and backward-compatibility.
  final bool isPreloadMessagesAfterInit;

  /// When returns `true`, the user is hidden from contact lists, forward/share
  /// pickers, and other user-selection surfaces (not the main conversation tab).
  final bool Function(String? userId)? shouldHideUserFromPickers;

  /// Saves the avatar currently shown in full-screen preview (profile/group).
  final AvatarPreviewSaveHandler? saveAvatarPreview;

  /// Web 头像大图预览前的 URL 预处理（鉴权拉取 → data URL 等）。
  final WebAvatarPreviewUrlPreparer? prepareWebAvatarPreviewUrl;

  const TIMUIKitConfig( {
    this.defaultAvatarAssetPath,
    this.showDesktopModalFunc,
    this.isPreloadMessagesAfterInit = true,
    this.defaultAvatarBorderRadius,
    this.isCheckDiskStorageSpace = true,
    this.isShowOnlineStatus = true,
    this.shouldHideUserFromPickers,
    this.saveAvatarPreview,
    this.prepareWebAvatarPreviewUrl,
  });
}
