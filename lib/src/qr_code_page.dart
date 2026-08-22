import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/qr_share_file_access.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_app_payload.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_scanner_launcher.dart';
import 'package:tencent_cloud_chat_demo/src/services/share_app_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/manager/v2_tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/contact_style_entry_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/recent_conversation_list.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/ui/components/app_search_bar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/forward_pick_pages.dart';

enum QRCodePageType { user, group }

class QRCodePage extends StatefulWidget {
  final QRCodePageType type;
  final String title;
  final String displayName;
  final String aliasLabel;
  final String aliasValue;

  /// Full group ID written into QR JSON; [aliasValue] is display-only.
  final String? qrPayloadId;
  final String faceUrl;
  final String shareText;

  /// Web / 桌面弹窗内嵌：去掉全屏 AppBar，由外层弹窗标题栏负责关闭。
  final bool embedded;

  const QRCodePage({
    Key? key,
    required this.type,
    required this.title,
    required this.displayName,
    required this.aliasLabel,
    required this.aliasValue,
    this.qrPayloadId,
    required this.faceUrl,
    required this.shareText,
    this.embedded = false,
  }) : super(key: key);

  @override
  State<QRCodePage> createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  final V2TIMManager _sdkInstance = TIMUIKitCore.getSDKInstance();
  final GlobalKey _captureKey = GlobalKey();
  static const String _brandLogoAsset = 'assets/img/99chat_logo.png';
  String? _localDisplayName;
  String? _localUserId;
  int? _localGender;
  bool _joinOptionsLoaded = false;
  bool _allowJoinByQrCode = true;
  bool _landingUrlResolved = false;
  String _landingUrl = '';

  bool get _isGroupQr => widget.type == QRCodePageType.group;

  bool get _canShowGroupQr =>
      !_isGroupQr || (_joinOptionsLoaded && _allowJoinByQrCode);

  bool get _qrPayloadReady =>
      _landingUrlResolved && (!_isGroupQr || _joinOptionsLoaded);

  @override
  void initState() {
    super.initState();
    unawaited(_loadQrLandingUrl());
    if (widget.type == QRCodePageType.user) {
      unawaited(_loadLocalUserIdentity());
    } else {
      unawaited(_loadGroupJoinOptions());
    }
  }

  Future<void> _loadQrLandingUrl() async {
    final url = await ShareAppService.instance.resolveQrLandingUrl();
    if (!mounted) {
      return;
    }
    setState(() {
      _landingUrl = url;
      _landingUrlResolved = true;
    });
  }

  Future<void> _loadGroupJoinOptions() async {
    final groupId = widget.qrPayloadId?.trim() ?? '';
    if (groupId.isEmpty) {
      if (!mounted) return;
      setState(() => _joinOptionsLoaded = true);
      return;
    }
    try {
      final options = await GroupJoinApi.instance.fetchJoinOptions(groupId);
      if (!mounted) return;
      setState(() {
        _allowJoinByQrCode = options.allowJoinByQrCode;
        _joinOptionsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allowJoinByQrCode = true;
        _joinOptionsLoaded = true;
      });
    }
  }

  Future<void> _loadLocalUserIdentity() async {
    final lookupId = ChatIdFormat.rawUserUid(
      ContactSocialCacheStore.safeLoginUserId(),
    );
    final fallbackId = lookupId.isNotEmpty
        ? lookupId
        : ChatIdFormat.rawUserUid(widget.aliasValue);
    if (fallbackId.isEmpty) {
      return;
    }
    final record = await UserProfileLocalService.instance.read(fallbackId);
    if (!mounted) {
      return;
    }
    if (record != null) {
      final nickname = record.nickname.trim();
      final userId = record.userId.trim();
      if (nickname.isNotEmpty || userId.isNotEmpty || record.gender != null) {
        setState(() {
          if (nickname.isNotEmpty) {
            _localDisplayName = nickname;
          }
          if (userId.isNotEmpty) {
            _localUserId = ChatIdFormat.display(userId);
          }
          _localGender = record.gender;
        });
      }
    }
    if (_localGender == null || _localGender == 0) {
      await _loadGenderFromSdk(fallbackId);
    }
  }

  /// 本地档案没有性别时向 SDK 兜底查一次（性别图标用）。
  Future<void> _loadGenderFromSdk(String userId) async {
    try {
      final res = await _sdkInstance.getUsersInfo(userIDList: [userId]);
      final gender = res.data?.firstOrNull?.gender;
      if (!mounted || gender == null) {
        return;
      }
      setState(() => _localGender = gender);
    } catch (_) {}
  }

  String get _effectiveDisplayName {
    if (widget.type != QRCodePageType.user) {
      return widget.displayName;
    }
    final local = _localDisplayName?.trim();
    if (local != null && local.isNotEmpty) {
      return local;
    }
    return widget.displayName;
  }

  String get _effectiveAliasValue {
    if (widget.type != QRCodePageType.user) {
      return widget.aliasValue;
    }
    final local = _localUserId?.trim();
    if (local != null && local.isNotEmpty) {
      return local;
    }
    return widget.aliasValue;
  }

  String _resolveQrPayloadId() {
    if (widget.type == QRCodePageType.group) {
      final full = widget.qrPayloadId?.trim() ?? '';
      if (full.isNotEmpty) {
        return full;
      }
      return ChatIdFormat.normalizeGroupId(widget.aliasValue);
    }
    return ChatIdFormat.rawUserUid(_effectiveAliasValue);
  }

  String _buildQrData() {
    return QrAppPayload.encode(
      baseUrl: _landingUrl,
      type: widget.type == QRCodePageType.user
          ? QrAppPayloadType.user
          : QrAppPayloadType.group,
      id: _resolveQrPayloadId(),
      name: _effectiveDisplayName,
    );
  }

  Future<Uint8List?> _captureQrImageBytes() async {
    try {
      final renderObject = _captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (renderObject == null) {
        return null;
      }
      final image = await renderObject.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveImage() async {
    if (kIsWeb) {
      ToastUtils.toast(TIM_t(
          "\u5f53\u524d\u6682\u4e0d\u652f\u6301\u4fdd\u5b58\u56fe\u7247"));
      return;
    }
    final bytes = await _captureQrImageBytes();
    if (bytes == null) {
      ToastUtils.toast(TIM_t("\u4fdd\u5b58\u5931\u8d25"));
      return;
    }
    final fileName = widget.type == QRCodePageType.user
        ? "user_qr_${_effectiveAliasValue}"
        : "group_qr_${widget.aliasValue}";
    final result = await ImageGallerySaverPlus.saveImage(
      bytes,
      quality: 100,
      name: fileName,
    );
    if (!mounted) {
      return;
    }
    if (result != null) {
      ToastUtils.toast(TIM_t("\u56fe\u7247\u5df2\u4fdd\u5b58"));
      return;
    }
    ToastUtils.toast(TIM_t("\u4fdd\u5b58\u5931\u8d25"));
  }

  Future<_ShareTarget?> _showShareTargetPicker(TUITheme theme) {
    return Navigator.of(context).push<_ShareTarget>(
      AppFullscreenDialogRoute(
        builder: (context) => _QRCodeSharePickerPage(theme: theme),
      ),
    );
  }

  Future<void> _shareToFriend(TUITheme theme) async {
    final target = await _showShareTargetPicker(theme);
    if (!mounted || target == null) {
      return;
    }
    if (!kIsWeb) {
      final imagePath = await _createShareImageFile();
      if (imagePath != null) {
        final createImageRes =
            await _sdkInstance.getMessageManager().createImageMessage(
                  imagePath: imagePath,
                  imageName: widget.type == QRCodePageType.user
                      ? 'my_qr_code.png'
                      : 'group_qr_code.png',
                );
        final imageMessageId = createImageRes.data?.id;
        if (createImageRes.code == 0 &&
            imageMessageId != null &&
            imageMessageId.isNotEmpty) {
          final sent = await ChatExternalMessageSender.sendCreatedMessage(
            messageInfo: createImageRes.data?.messageInfo,
            receiverUserId: target.userID,
            groupId: target.groupID,
            reason: 'qr_code_share_image_sent',
          );
          if (sent) {
            ToastUtils.toast(TIM_t("\u5df2\u5206\u4eab"));
            return;
          }
        }
      }
    }

    final createMessageRes = await _sdkInstance
        .getMessageManager()
        .createTextMessage(text: widget.shareText);
    final messageID = createMessageRes.data?.id;
    if (createMessageRes.code == 0 &&
        messageID != null &&
        messageID.isNotEmpty) {
      final sent = await ChatExternalMessageSender.sendCreatedMessage(
        messageInfo: createMessageRes.data?.messageInfo,
        receiverUserId: target.userID,
        groupId: target.groupID,
        reason: 'qr_code_share_text_fallback_sent',
      );
      if (sent) {
        ToastUtils.toast(TIM_t("\u5df2\u5206\u4eab"));
        return;
      }
    }
    ToastUtils.toast(TIM_t("\u5206\u4eab\u5931\u8d25"));
  }

  Future<String?> _createShareImageFile() async {
    final bytes = await _captureQrImageBytes();
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.type == QRCodePageType.user
          ? 'my_qr_${_effectiveAliasValue}'
          : 'group_qr_${widget.aliasValue}';
      return writeQrShareImageFile(
        dirPath: tempDir.path,
        fileName: '$safeName.png',
        bytes: bytes,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openScanner() async {
    await QRScannerLauncher.open(context);
  }

  Widget _buildIdentityAvatar(double size, _QrPagePalette palette) {
    final badgeSize = size * 0.34;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipOval(
              child: widget.type == QRCodePageType.group
                  ? Avatar(
                      faceUrl: widget.faceUrl,
                      showName: _effectiveDisplayName,
                      type: 2,
                      borderRadius: BorderRadius.zero,
                    )
                  : AppUserAvatar(
                      faceUrl: widget.faceUrl,
                      showName: _effectiveDisplayName,
                      size: size,
                      borderRadius: BorderRadius.zero,
                    ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: badgeSize,
              height: badgeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.primary,
                shape: BoxShape.circle,
                border: Border.all(color: palette.badgeBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.28),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '99',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: badgeSize * 0.42,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCenterLogo(double size) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.12),
        child: Image.asset(
          _brandLogoAsset,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSimpleQr({
    required String qrData,
    required double size,
  }) {
    return QrImageView(
      data: qrData,
      version: QrVersions.auto,
      size: size,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
  }

  Widget _buildQrFrame({
    required String qrData,
    required double qrSize,
    required double qrLogoSize,
    required _QrPagePalette palette,
  }) {
    const framePadding = 14.0;
    final frameSize = qrSize + framePadding * 2;
    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.qrFrameBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.primary
                      .withValues(alpha: palette.isDark ? 0.35 : 0.22),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary
                        .withValues(alpha: palette.isDark ? 0.2 : 0.12),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _QrCornerFramePainter(color: palette.primary),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              _buildSimpleQr(qrData: qrData, size: qrSize),
              _buildQrCenterLogo(qrLogoSize),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrandMark(double logoSize, _QrPagePalette palette) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(logoSize * 0.24),
          child: Image.asset(
            _brandLogoAsset,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '99Chat',
          maxLines: 1,
          style: TextStyle(
            color: palette.brandText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDotGrid({
    required double width,
    required double height,
    required Color color,
    Alignment alignment = Alignment.center,
  }) {
    return Align(
      alignment: alignment,
      child: CustomPaint(
        size: Size(width, height),
        painter: _DotGridPainter(color: color),
      ),
    );
  }

  Future<void> _showQrActionSheet(TUITheme theme) async {
    final action = await AppDialog.actionSheet<String>(
      title: TIM_t("\u4e8c\u7ef4\u7801"),
      cancelText: TIM_t("\u53d6\u6d88"),
      actionContentWidth: 132,
      actions: [
        AppActionSheetItem<String>(
          text: TIM_t("\u4fdd\u5b58\u56fe\u7247"),
          value: 'save',
        ),
        if (!kIsWeb)
          AppActionSheetItem<String>(
            text: TIM_t("\u626b\u4e00\u626b"),
            value: 'scan',
          ),
        AppActionSheetItem<String>(
          text: TIM_t("\u5206\u4eab\u597d\u53cb"),
          value: 'share',
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    _handleSheetAction(action, theme);
  }

  void _handleSheetAction(String value, TUITheme theme) {
    switch (value) {
      case 'save':
        _saveImage();
        break;
      case 'scan':
        _openScanner();
        break;
      case 'share':
        _shareToFriend(theme);
        break;
    }
  }

  Widget _buildQrDisabledPlaceholder({
    required double qrSize,
    required _QrPagePalette palette,
  }) {
    final i18n = AppI18n.of(context);
    const framePadding = 14.0;
    final frameSize = qrSize + framePadding * 2;
    return SizedBox(
      width: frameSize,
      height: frameSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.disabledBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: 48,
                color: palette.disabledIcon,
              ),
              const SizedBox(height: 14),
              Text(
                i18n.t(
                  zhHans: '管理员已关闭群二维码加入方式',
                  zhHant: '管理員已關閉群 QR 碼加入方式',
                  en: 'Group admins have disabled joining via QR code',
                  ja: '管理者がQRコードによる参加を無効にしています',
                  ko: '관리자가 QR 코드 가입을 비활성화했습니다',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.secondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareCard({
    required String qrData,
    required double maxWidth,
    required bool showQrCode,
    required bool loadingQrOptions,
    required _QrPagePalette palette,
  }) {
    final compact = widget.embedded;
    final cardWidth =
        maxWidth.clamp(compact ? 240.0 : 280.0, compact ? 300.0 : 360.0).toDouble();
    final avatarSize = compact ? 48.0 : 62.0;
    final qrSize = (cardWidth * (compact ? 0.52 : 0.62))
        .clamp(compact ? 148.0 : 188.0, compact ? 172.0 : 236.0)
        .toDouble();
    final qrLogoSize =
        (qrSize * 0.18).clamp(compact ? 28.0 : 34.0, compact ? 36.0 : 44.0).toDouble();
    final brandLogoSize = compact ? 22.0 : 28.0;
    // 个人码的身份图标按性别显示：男蓝、女粉、未知不显示（与资料页一致）。
    final Widget? identityIcon = widget.type == QRCodePageType.group
        ? Icon(Icons.group_rounded, color: palette.primary, size: 20)
        : switch (_localGender) {
            1 => const Icon(
                Icons.male_rounded,
                color: Color(0xFF4DA3FF),
                size: 20,
              ),
            2 => const Icon(
                Icons.female_rounded,
                color: Color(0xFFFF6B9D),
                size: 20,
              ),
            _ => null,
          };
    final hintText = widget.type == QRCodePageType.group
        ? TIM_t('扫描二维码加入群聊')
        : TIM_t('扫描二维码添加我为联系人');

    return Center(
      child: SizedBox(
        width: cardWidth,
        child: Container(
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: palette.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: palette.cardShadow,
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: 18,
                right: 18,
                child: _buildDotGrid(
                  width: 56,
                  height: 40,
                  color: palette.dotGrid,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: compact ? 64 : 88,
                child: CustomPaint(
                  painter: _CardWavePainter(color: palette.primary),
                ),
              ),
              Positioned(
                left: compact ? 14 : 18,
                bottom: compact ? 14 : 18,
                child: _buildDotGrid(
                  width: compact ? 32 : 40,
                  height: compact ? 22 : 28,
                  color: palette.dotGrid,
                ),
              ),
              Positioned(
                right: compact ? 14 : 18,
                bottom: compact ? 14 : 18,
                child: _buildDotGrid(
                  width: compact ? 32 : 40,
                  height: compact ? 22 : 28,
                  color: palette.dotGrid,
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 16 : 22,
                  compact ? 16 : 26,
                  compact ? 16 : 22,
                  compact ? 16 : 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildIdentityAvatar(avatarSize, palette),
                        SizedBox(width: compact ? 10 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      _effectiveDisplayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.name,
                                        fontSize: compact ? 16 : 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (identityIcon != null) ...[
                                    const SizedBox(width: 6),
                                    identityIcon,
                                  ],
                                ],
                              ),
                              SizedBox(height: compact ? 4 : 6),
                              Text(
                                '${widget.aliasLabel}: ${_effectiveAliasValue}',
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.secondary,
                                  fontSize: compact ? 12 : 13,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 14 : 22),
                    if (loadingQrOptions)
                      SizedBox(
                        width: qrSize + 28,
                        height: qrSize + 28,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: palette.primary,
                          ),
                        ),
                      )
                    else if (showQrCode)
                      _buildQrFrame(
                        qrData: qrData,
                        qrSize: qrSize,
                        qrLogoSize: qrLogoSize,
                        palette: palette,
                      )
                    else
                      _buildQrDisabledPlaceholder(
                        qrSize: qrSize,
                        palette: palette,
                      ),
                    if (showQrCode) ...[
                      SizedBox(height: compact ? 10 : 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.qr_code_scanner_rounded,
                            size: compact ? 14 : 16,
                            color: palette.primary.withValues(alpha: 0.85),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              hintText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.secondary,
                                fontSize: compact ? 12 : 13,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 12 : 18),
                      _buildBrandMark(brandLogoSize, palette),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActionItem({
    required IconData icon,
    required String label,
    required bool filled,
    required _QrPagePalette palette,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(28);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Ink(
            height: widget.embedded ? 44 : 52,
            decoration: BoxDecoration(
              color: filled ? palette.primary : palette.outlineButtonBg,
              borderRadius: radius,
              border: filled
                  ? null
                  : Border.all(color: palette.primary, width: 1.4),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: filled ? Colors.white : palette.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: filled ? Colors.white : palette.title,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions(_QrPagePalette palette) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.embedded ? 16 : 24,
        widget.embedded ? 4 : 8,
        widget.embedded ? 16 : 24,
        widget.embedded ? 12 : 16,
      ),
      child: Row(
        children: [
          _buildBottomActionItem(
            icon: Icons.download_rounded,
            label: TIM_t("\u4fdd\u5b58"),
            filled: true,
            palette: palette,
            onTap: _saveImage,
          ),
          if (!kIsWeb) ...[
            const SizedBox(width: 14),
            _buildBottomActionItem(
              icon: Icons.qr_code_scanner_rounded,
              label: TIM_t("\u626b\u4e00\u626b"),
              filled: false,
              palette: palette,
              onTap: _openScanner,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<DefaultThemeData>(context);
    final theme = themeModel.theme;
    final palette = _QrPagePalette.resolve(themeModel);
    final qrData = _buildQrData();
    final loadingQrOptions = !_qrPayloadReady;
    final showQrCode = _canShowGroupQr && _landingUrlResolved;

    return Scaffold(
      backgroundColor: palette.pageBgTop,
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(
                widget.title,
                style: TextStyle(
                  color: palette.title,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: palette.pageBgTop,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(color: palette.primary),
              actions: [
                if (showQrCode)
                  SizedBox(
                    width: kToolbarHeight,
                    height: kToolbarHeight,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _showQrActionSheet(theme),
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: palette.primary,
                        size: 26,
                      ),
                    ),
                  ),
              ],
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.pageBgTop, palette.pageBgBottom],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _PageWavePainter(color: palette.primary),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SafeArea(
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final card = RepaintBoundary(
                        key: _captureKey,
                        child: LayoutBuilder(
                          builder: (context, innerConstraints) {
                            final fallbackWidth =
                                MediaQuery.sizeOf(context).width - 64;
                            final maxWidth = innerConstraints.maxWidth.isFinite
                                ? innerConstraints.maxWidth
                                : fallbackWidth;
                            return _buildShareCard(
                              qrData: qrData,
                              maxWidth: maxWidth,
                              showQrCode: showQrCode,
                              loadingQrOptions: loadingQrOptions,
                              palette: palette,
                            );
                          },
                        ),
                      );
                      final padding = EdgeInsets.fromLTRB(
                        widget.embedded ? 16 : 20,
                        widget.embedded ? 8 : 12,
                        widget.embedded ? 16 : 20,
                        widget.embedded ? 4 : 12,
                      );
                      // 弹窗内优先垂直居中整卡，避免大块留白 + 再滚动。
                      if (widget.embedded) {
                        return SingleChildScrollView(
                          padding: padding,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  (constraints.maxHeight - padding.vertical)
                                      .clamp(0, double.infinity),
                            ),
                            child: Center(child: card),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        padding: padding,
                        child: Column(
                          children: [card],
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (showQrCode)
                SafeArea(
                  top: false,
                  child: _buildBottomActions(palette),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QrPagePalette {
  const _QrPagePalette({
    required this.isDark,
    required this.primary,
    required this.pageBgTop,
    required this.pageBgBottom,
    required this.cardBg,
    required this.cardBorder,
    required this.cardShadow,
    required this.title,
    required this.name,
    required this.secondary,
    required this.brandText,
    required this.dotGrid,
    required this.outlineButtonBg,
    required this.disabledBg,
    required this.disabledIcon,
    required this.qrFrameBg,
    required this.badgeBorder,
  });

  final bool isDark;
  final Color primary;
  final Color pageBgTop;
  final Color pageBgBottom;
  final Color cardBg;
  final Color cardBorder;
  final Color cardShadow;
  final Color title;
  final Color name;
  final Color secondary;
  final Color brandText;
  final Color dotGrid;
  final Color outlineButtonBg;
  final Color disabledBg;
  final Color disabledIcon;
  final Color qrFrameBg;
  final Color badgeBorder;

  factory _QrPagePalette.resolve(DefaultThemeData themeModel) {
    final isDark = themeModel.currentThemeType == ThemeType.dark;
    final primary = themeModel.theme.primaryColor ?? AppColors.primaryBlue;

    if (isDark) {
      return _QrPagePalette(
        isDark: true,
        primary: primary,
        pageBgTop: const Color(0xFF122033),
        pageBgBottom: AppColors.background(dark: true),
        cardBg: AppColors.card(dark: true),
        cardBorder: primary.withValues(alpha: 0.32),
        cardShadow: Colors.black.withValues(alpha: 0.35),
        title: AppColors.text(dark: true),
        name: AppColors.text(dark: true),
        secondary: AppColors.subText(dark: true),
        brandText: AppColors.text(dark: true),
        dotGrid: const Color(0xFF4A5568),
        outlineButtonBg: AppColors.card(dark: true),
        disabledBg: AppColors.surfaceAlt(dark: true),
        disabledIcon: AppColors.subText(dark: true),
        qrFrameBg: Colors.white,
        badgeBorder: AppColors.card(dark: true),
      );
    }

    return _QrPagePalette(
      isDark: false,
      primary: primary,
      pageBgTop: const Color(0xFFD6EBFF),
      pageBgBottom: const Color(0xFFEEF6FF),
      cardBg: Colors.white,
      cardBorder: const Color(0xFFB5D8FF),
      cardShadow: primary.withValues(alpha: 0.12),
      title: const Color(0xFF1A2332),
      name: const Color(0xFF24272B),
      secondary: const Color(0xFF9AA0A8),
      brandText: const Color(0xFF303236),
      dotGrid: const Color(0xFFD0D5DC),
      outlineButtonBg: Colors.white,
      disabledBg: const Color(0xFFF5F8FC),
      disabledIcon: const Color(0xFFBCC0C8),
      qrFrameBg: Colors.white,
      badgeBorder: Colors.white,
    );
  }
}

class _ShareTarget {
  final String userID;
  final String groupID;

  const _ShareTarget({
    this.userID = "",
    this.groupID = "",
  });

  factory _ShareTarget.fromConversation(V2TimConversation conversation) {
    final isC2C = conversation.type == 1;
    return _ShareTarget(
      userID: isC2C ? (conversation.userID ?? "") : "",
      groupID: isC2C ? "" : (conversation.groupID ?? ""),
    );
  }
}

class _QRCodeSharePickerPage extends StatefulWidget {
  final TUITheme theme;

  const _QRCodeSharePickerPage({
    required this.theme,
  });

  @override
  State<_QRCodeSharePickerPage> createState() => _QRCodeSharePickerPageState();
}

class _QRCodeSharePickerPageState extends State<_QRCodeSharePickerPage> {
  final TextEditingController _searchController = TextEditingController();
  String _keyword = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFriendPicker() async {
    final target = await Navigator.push<_ShareTarget>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ForwardSelectFriendPage(
          onTapItem: (item) async {
            final conversationID = 'c2c_${item.userID}';
            final res = await TIMUIKitCore.getSDKInstance()
                .getConversationManager()
                .getConversation(conversationID: conversationID);
            final conversation = res.data ??
                V2TimConversation(
                  conversationID: conversationID,
                  type: 1,
                  userID: item.userID,
                  showName: item.userProfile?.nickName ?? item.userID,
                  faceUrl: item.userProfile?.faceUrl,
                );
            if (!context.mounted) return;
            Navigator.pop(
              context,
              _ShareTarget.fromConversation(conversation),
            );
          },
        ),
      ),
    );
    if (!mounted || target == null) {
      return;
    }
    Navigator.pop(context, target);
  }

  Future<void> _openGroupPicker() async {
    final target = await Navigator.push<_ShareTarget>(
      context,
      AppMaterialPageRoute(
        builder: (context) => ForwardSelectGroupPage(
          onTapItem: (groupInfo, conversation) {
            Navigator.pop(
              context,
              _ShareTarget.fromConversation(conversation),
            );
          },
        ),
      ),
    );
    if (!mounted || target == null) {
      return;
    }
    Navigator.pop(context, target);
  }

  Widget _buildSearchBar(TUITheme theme) {
    return buildAppSearchBarInset(
      context: context,
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _keyword = value.trim();
        });
      },
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final backgroundColor =
        theme.weakBackgroundColor ?? theme.wideBackgroundColor ?? Colors.white;
    final appBarColor = theme.appbarBgColor ?? backgroundColor;
    final titleColor = theme.appbarTextColor ?? theme.darkTextColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarColor,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(
            Icons.close,
            color: titleColor,
          ),
        ),
        title: Text(
          TIM_t("\u9009\u62e9\u4f1a\u8bdd"),
          style: TextStyle(
            color: titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(theme),
          ContactStyleEntryItem(
            icon: contactStyleEntryIcon(
              context,
              theme,
              entryId: 'friend',
            ),
            title: TIM_t("\u9009\u62e9\u670b\u53cb"),
            onTap: _openFriendPicker,
          ),
          ContactStyleEntryItem(
            icon: contactStyleEntryIcon(
              context,
              theme,
              entryId: 'group',
            ),
            title: TIM_t("\u9009\u62e9\u7fa4\u804a"),
            onTap: _openGroupPicker,
            showDivider: false,
          ),
          Expanded(
            child: RecentForwardList(
              isMultiSelect: false,
              keyword: _keyword,
              sectionTitle: TIM_t("\u6700\u8fd1"),
              showSectionHeader: true,
              onChanged: (conversationList) {
                if (conversationList.isNotEmpty) {
                  Navigator.pop(
                    context,
                    _ShareTarget.fromConversation(conversationList.first),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QrCornerFramePainter extends CustomPainter {
  const _QrCornerFramePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const inset = 6.0;
    final length = size.shortestSide * 0.16;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;

    // Top-left
    canvas.drawLine(Offset(left, top), Offset(left + length, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left, top + length), paint);
    // Top-right
    canvas.drawLine(Offset(right, top), Offset(right - length, top), paint);
    canvas.drawLine(Offset(right, top), Offset(right, top + length), paint);
    // Bottom-left
    canvas.drawLine(Offset(left, bottom), Offset(left + length, bottom), paint);
    canvas.drawLine(Offset(left, bottom), Offset(left, bottom - length), paint);
    // Bottom-right
    canvas.drawLine(
        Offset(right, bottom), Offset(right - length, bottom), paint);
    canvas.drawLine(
        Offset(right, bottom), Offset(right, bottom - length), paint);
  }

  @override
  bool shouldRepaint(covariant _QrCornerFramePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.55);
    const spacing = 7.0;
    const radius = 1.1;
    for (var y = radius; y < size.height; y += spacing) {
      for (var x = radius; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _CardWavePainter extends CustomPainter {
  const _CardWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.09),
        ],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.12,
        size.width * 0.42,
        size.height * 0.72,
        size.width * 0.62,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.12,
        size.width * 0.9,
        size.height * 0.55,
        size.width,
        size.height * 0.28,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CardWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PageWavePainter extends CustomPainter {
  const _PageWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.16),
          color.withValues(alpha: 0.04),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.45));

    final topPath = Path()
      ..moveTo(0, size.height * 0.08)
      ..quadraticBezierTo(
        size.width * 0.28,
        size.height * 0.02,
        size.width * 0.52,
        size.height * 0.12,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.22,
        size.width,
        size.height * 0.1,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(topPath, topPaint);

    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          color.withValues(alpha: 0.14),
          color.withValues(alpha: 0.03),
          color.withValues(alpha: 0),
        ],
      ).createShader(
        Rect.fromLTWH(0, size.height * 0.55, size.width, size.height * 0.45),
      );

    final bottomPath = Path()
      ..moveTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.68,
        size.width * 0.55,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.8,
        size.height * 0.94,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(bottomPath, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _PageWavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
