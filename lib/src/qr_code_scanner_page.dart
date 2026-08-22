import 'dart:async';
import 'dart:convert';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/withdraw_transfer_target_validator.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_system_ui.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/platform/clipboard_guard.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/my_profile_detail.dart';
import 'package:tencent_cloud_chat_demo/src/pages/add_friend_page.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/qr_code_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/app_gallery_picker.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_join_lookup.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/pages/join_group_application_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/qr_web_login_confirm_page.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_app_payload.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_gallery_decoder.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_web_login_payload.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

enum _QRCodeScanType { user, group, webLogin, unknown }

String _normalizeQrRawValue(String rawValue) {
  final trimmed = rawValue.trim();
  if (trimmed.isEmpty) {
    return rawValue;
  }

  // Some Android scanners return UTF-8 QR bytes as latin1 text, which makes
  // Chinese names look like mojibake. Try latin1 -> utf8 only when it produces
  // a valid app QR payload or visibly improves replacement characters.
  String? decoded;
  try {
    decoded = utf8.decode(latin1.encode(trimmed), allowMalformed: false);
  } catch (_) {
    decoded = null;
  }

  if (decoded == null || decoded.isEmpty || decoded == trimmed) {
    return trimmed;
  }

  bool isAppQr(String value) {
    return QrAppPayload.tryParse(value) != null;
  }

  if (isAppQr(decoded) && !isAppQr(trimmed)) {
    return decoded;
  }
  if (isAppQr(decoded) && _looksMojibake(trimmed)) {
    return decoded;
  }
  if (trimmed.contains('�') && !decoded.contains('�')) {
    return decoded;
  }
  return trimmed;
}

bool _looksMojibake(String value) {
  return value.contains('Ã') ||
      value.contains('Â') ||
      value.contains('æ') ||
      value.contains('è') ||
      value.contains('å') ||
      value.contains('ç') ||
      value.contains('ð');
}

class _QRCodeScanData {
  final _QRCodeScanType type;
  final String id;
  final String name;
  final String rawValue;

  const _QRCodeScanData({
    required this.type,
    required this.id,
    required this.name,
    required this.rawValue,
  });

  factory _QRCodeScanData.fromRawValue(String rawValue) {
    final normalizedRawValue = _normalizeQrRawValue(rawValue);
    final webLogin = QrWebLoginPayload.tryParse(normalizedRawValue);
    if (webLogin != null) {
      return _QRCodeScanData(
        type: _QRCodeScanType.webLogin,
        id: webLogin.sessionId,
        name: '',
        rawValue: normalizedRawValue,
      );
    }
    final appPayload = QrAppPayload.tryParse(normalizedRawValue);
    if (appPayload != null) {
      if (appPayload.type == QrAppPayloadType.user) {
        return _QRCodeScanData(
          type: _QRCodeScanType.user,
          id: ChatIdFormat.rawUserUid(appPayload.id),
          name: appPayload.name,
          rawValue: normalizedRawValue,
        );
      }
      return _QRCodeScanData(
        type: _QRCodeScanType.group,
        id: appPayload.id,
        name: appPayload.name,
        rawValue: normalizedRawValue,
      );
    }
    return _QRCodeScanData(
      type: _QRCodeScanType.unknown,
      id: normalizedRawValue,
      name: "",
      rawValue: normalizedRawValue,
    );
  }
}

class QRCodeScannerPage extends StatefulWidget {
  const QRCodeScannerPage({
    Key? key,
    this.walletAddressMode = false,
  }) : super(key: key);

  final bool walletAddressMode;

  @override
  State<QRCodeScannerPage> createState() => _QRCodeScannerPageState();
}

class _QRCodeScannerPageState extends State<QRCodeScannerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final TUISelfInfoViewModel _selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  late final AnimationController _scanAnimationController;
  bool _handled = false;
  bool _loading = false;
  bool _cameraStarting = false;
  bool _cameraReady = false;
  String? _cameraError;
  int _cameraStartSeq = 0;

  @override
  void initState() {
    super.initState();
    ImmersiveSystemUi.apply();
    WidgetsBinding.instance.addObserver(this);
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCamera();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopCamera();
      return;
    }
    if (state == AppLifecycleState.resumed && !_handled && !_loading) {
      ImmersiveSystemUi.apply();
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanAnimationController.dispose();
    _scannerController.dispose();
    ImmersiveSystemUi.restore(context);
    super.dispose();
  }

  Future<void> _startCamera() async {
    if (!mounted || _cameraStarting || _cameraReady) {
      return;
    }
    final seq = ++_cameraStartSeq;
    var didTimeout = false;
    Timer? timer;
    setState(() {
      _cameraStarting = true;
      _cameraReady = false;
      _cameraError = null;
    });
    timer = Timer(const Duration(seconds: 4), () {
      didTimeout = true;
      if (!mounted || seq != _cameraStartSeq) {
        return;
      }
      setState(() {
        _cameraStarting = false;
        _cameraReady = false;
        _cameraError = AppI18n.of(context).t(
          zhHans: '相机启动较慢，请重试或从相册选择',
          zhHant: '相機啟動較慢，請重試或從相簿選擇',
          en: 'Camera is taking longer than usual. Retry or choose from album.',
          ja: 'カメラの起動が遅れています。再試行するかアルバムから選択してください。',
          ko: '카메라 시작이 지연되고 있습니다. 다시 시도하거나 앨범에서 선택하세요.',
        );
      });
    });
    try {
      await _scannerController.start();
      timer.cancel();
      if (!mounted || seq != _cameraStartSeq) {
        return;
      }
      if (didTimeout) {
        try {
          await _stopCamera();
        } catch (_) {}
        return;
      }
      setState(() {
        _cameraStarting = false;
        _cameraReady = true;
        _cameraError = null;
      });
    } catch (_) {
      timer.cancel();
      if (!mounted || seq != _cameraStartSeq) {
        return;
      }
      setState(() {
        _cameraStarting = false;
        _cameraReady = false;
        _cameraError = AppI18n.of(context).t(
          zhHans: '相机启动失败，可能正在被占用，请稍后重试',
          zhHant: '相機啟動失敗，可能正在被占用，請稍後重試',
          en: 'Camera failed to start. It may be in use. Try again later.',
          ja: 'カメラの起動に失敗しました。他の機能が使用中の可能性があります。',
          ko: '카메라 시작에 실패했습니다. 다른 기능에서 사용 중일 수 있습니다.',
        );
      });
    }
  }

  Future<void> _stopCamera() async {
    _cameraStartSeq++;
    if (mounted) {
      setState(() {
        _cameraStarting = false;
        _cameraReady = false;
      });
    }
    try {
      await _scannerController.stop();
    } catch (_) {}
  }

  Future<V2TimGroupInfo?> _fetchGroupInfo(String groupID) async {
    try {
      return await GroupJoinLookup.resolve(
        groupKey: groupID,
        joinSource: GroupJoinSource.qrCode,
      );
    } on GroupJoinLookupDisabledException catch (error) {
      if (mounted) {
        ToastUtils.toast(GroupJoinLookup.disabledMessage(
          AppI18n.of(context),
          error,
        ));
      }
      return null;
    }
  }

  Future<void> _showRawResult(String rawValue) async {
    await AppDialog.show<void>(
      barrierDismissible: true,
      closeCurrent: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final dark = theme.brightness == Brightness.dark;
        final cardColor = dark ? const Color(0xFF1F232B) : Colors.white;
        final textColor = dark ? Colors.white : const Color(0xFF1D2129);
        final subTextColor = dark
            ? Colors.white.withValues(alpha: 0.68)
            : const Color(0xFF6B7280);
        final borderColor = dark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFE5E7EB);
        final primaryColor = theme.primaryColor;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 0.6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.36 : 0.14),
                  blurRadius: 32,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      AppI18n.of(dialogContext).t(
                        zhHans: '扫码结果',
                        zhHant: '掃碼結果',
                        en: 'Scan Result',
                        ja: 'スキャン結果',
                        ko: '스캔 결과',
                      ),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.black.withValues(alpha: 0.20)
                          : const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 0.6),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        rawValue,
                        style: TextStyle(
                          color: subTextColor,
                          fontSize: 14,
                          height: 1.45,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: _ScanResultDialogButton(
                          text: AppI18n.of(dialogContext).t(
                            zhHans: '关闭',
                            zhHant: '關閉',
                            en: 'Close',
                            ja: '閉じる',
                            ko: '닫기',
                          ),
                          filled: false,
                          color: primaryColor,
                          onTap: () {
                            Navigator.of(dialogContext, rootNavigator: true)
                                .pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ScanResultDialogButton(
                          text: AppI18n.of(dialogContext).t(
                            zhHans: '复制',
                            zhHant: '複製',
                            en: 'Copy',
                            ja: 'コピー',
                            ko: '복사',
                          ),
                          filled: true,
                          color: primaryColor,
                          onTap: () async {
                            await ClipboardGuard.copy(
                              rawValue,
                              showToast: false,
                            );
                            if (!dialogContext.mounted) {
                              return;
                            }
                            Navigator.of(dialogContext, rootNavigator: true)
                                .pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUserProfile(_QRCodeScanData data) async {
    await _stopCamera();
    if (!mounted) {
      return;
    }
    final userID = ChatIdFormat.rawUserUid(data.id);
    if (userID.isEmpty) {
      setState(() {
        _handled = false;
      });
      await _startCamera();
      return;
    }

    if (ProfilePageNav.isSelfUser(userID)) {
      if (!mounted) {
        return;
      }
      await Navigator.pushReplacement(
        context,
        NavigationRoutes.cupertino(
          builder: (context) => MyProfileDetail(
            userProfile: _selfInfoViewModel.loginInfo,
            controller: TIMUIKitProfileController(),
          ),
        ),
      );
      return;
    }

    final isFriend = await ProfilePageNav.isFriendUser(userID);
    if (!mounted) {
      return;
    }

    if (isFriend) {
      await Navigator.pushReplacement(
        context,
        NavigationRoutes.cupertino(
          builder: (context) => UserProfile(
            userID: userID,
            addSource: FriendAddSource.qrCode,
          ),
        ),
      );
      return;
    }

    final users = await _friendshipServices.getUsersInfo(userIDList: [userID]);
    final friendInfo = users != null && users.isNotEmpty
        ? users.first
        : V2TimUserFullInfo(userID: userID, nickName: data.name);
    final displayName = TencentUtils.checkString(friendInfo.nickName) ??
        (data.name.trim().isNotEmpty ? data.name.trim() : userID);

    if (!mounted) {
      return;
    }
    await Navigator.pushReplacement(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => AddFriendPage(
          userID: userID,
          nickname: displayName,
          initialUserInfo: friendInfo,
          addSource: FriendAddSource.qrCode,
        ),
      ),
    );
  }

  Future<void> _openGroupTarget(_QRCodeScanData data) async {
    setState(() {
      _loading = true;
    });
    await _stopCamera();
    final groupInfo = await _fetchGroupInfo(data.id);
    if (!mounted) {
      return;
    }
    if (groupInfo == null) {
      setState(() {
        _loading = false;
        _handled = false;
      });
      await _startCamera();
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '该群聊不存在',
        zhHant: '該群聊不存在',
        en: 'Group does not exist',
        ja: 'グループが存在しません',
        ko: '그룹이 존재하지 않음',
      ));
      return;
    }
    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      context,
      NavigationRoutes.cupertino(
        builder: (context) => JoinGroupApplicationPage(
          groupInfo: groupInfo,
          joinSource: GroupJoinSource.qrCode,
        ),
      ),
    );
  }

  Future<void> _handleResult(String rawValue) async {
    if (_handled || _loading) {
      return;
    }
    final normalizedRawValue = _normalizeQrRawValue(rawValue);
    _handled = true;
    if (widget.walletAddressMode) {
      final tronAddress = _extractTronAddress(normalizedRawValue);
      if (tronAddress != null) {
        await _confirmUseWalletAddress(tronAddress);
        return;
      }
    }
    final data = _QRCodeScanData.fromRawValue(normalizedRawValue);
    switch (data.type) {
      case _QRCodeScanType.user:
        await _openUserProfile(data);
        break;
      case _QRCodeScanType.group:
        await _openGroupTarget(data);
        break;
      case _QRCodeScanType.webLogin:
        await _openWebLoginConfirm(data);
        break;
      case _QRCodeScanType.unknown:
        await _stopCamera();
        if (!mounted) {
          return;
        }
        await _showRawResult(normalizedRawValue);
        if (mounted) {
          setState(() {
            _handled = false;
            _loading = false;
          });
          await _startCamera();
        }
        break;
    }
  }

  Future<void> _openWebLoginConfirm(_QRCodeScanData data) async {
    await _stopCamera();
    if (!mounted) {
      return;
    }
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      final strings = AuthLocalizations.of(context);
      ToastUtils.toast(strings.qrWebLoginNeedAppLogin);
      if (mounted) {
        setState(() {
          _handled = false;
          _loading = false;
        });
        await _startCamera();
      }
      return;
    }
    await Navigator.of(context).pushReplacement(
      AppMaterialPageRoute(
        builder: (_) => QrWebLoginConfirmPage(sessionId: data.id),
      ),
    );
  }

  String? _extractTronAddress(String rawValue) {
    return WithdrawTransferTargetValidator.extractTronAddress(rawValue);
  }

  Future<void> _confirmUseWalletAddress(String address) async {
    await _stopCamera();
    if (!mounted) {
      return;
    }
    final useAddress = await AppDialog.confirm(
      title: AppI18n.of(context).t(
        zhHans: '识别到地址',
        zhHant: '識別到地址',
        en: 'Address Detected',
        ja: 'アドレスを検出',
        ko: '주소 감지됨',
      ),
      message: AppI18n.of(context).t(
        zhHans: '识别到 TRON 地址，是否去转账并填入收款地址？',
        zhHant: '識別到 TRON 地址，是否前往轉帳並填入收款地址？',
        en: 'TRON address detected. Go to transfer and fill payee address?',
        ja: 'TRONアドレスを検出しました。送金して受取アドレスを入力しますか？',
        ko: 'TRON 주소가 감지되었습니다. 이체로 이동해 수신 주소를 입력할까요?',
      ),
      confirmText: AppI18n.of(context).t(
        zhHans: '确认',
        zhHant: '確認',
        en: 'Confirm',
        ja: '確認',
        ko: '확인',
      ),
    );
    if (!mounted) {
      return;
    }
    if (useAddress == true) {
      Navigator.of(context).pop(address);
      return;
    }
    setState(() {
      _handled = false;
    });
    await _startCamera();
  }

  Future<void> _pickImageFromGallery() async {
    if (_loading) {
      return;
    }
    try {
      await _stopCamera();
      if (!mounted) {
        return;
      }
      final picked = await AppGalleryPicker.pickSingleImage(context);
      if (!mounted) {
        return;
      }
      final imagePath = picked?.path;
      if (imagePath == null || imagePath.isEmpty) {
        await _startCamera();
        return;
      }
      setState(() {
        _loading = true;
        _handled = false;
      });
      final rawValue = await QrGalleryDecoder.decodeFromPath(imagePath);
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      if (rawValue == null || rawValue.isEmpty) {
        await _startCamera();
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '未识别到二维码',
          zhHant: '未識別到 QR 碼',
          en: 'No QR code detected',
          ja: 'QRコードを検出できませんでした',
          ko: 'QR 코드를 인식하지 못함',
        ));
        return;
      }
      await _handleResult(rawValue);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _handled = false;
      });
      await _startCamera();
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '图片识别失败',
        zhHant: '圖片識別失敗',
        en: 'Image recognition failed',
        ja: '画像認識に失敗',
        ko: '이미지 인식 실패',
      ));
    }
  }

  Future<void> _openMyQRCode() async {
    final loginUserInfo =
        Provider.of<LoginUserInfo>(context, listen: false).loginUserInfo;
    final userID = loginUserInfo.userID ?? "";
    if (userID.isEmpty) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '当前无法获取用户信息',
        zhHant: '目前無法取得使用者資訊',
        en: 'Cannot get user info',
        ja: 'ユーザー情報を取得できません',
        ko: '사용자 정보를 가져올 수 없음',
      ));
      return;
    }
    await _stopCamera();
    if (!mounted) {
      return;
    }
    final displayName = (loginUserInfo.nickName ?? "").isNotEmpty
        ? loginUserInfo.nickName!
        : userID;
    await Navigator.push(
      context,
      AppMaterialPageRoute(
        builder: (context) => QRCodePage(
          type: QRCodePageType.user,
          title: AppI18n.of(context).t(
            zhHans: '我的二维码',
            zhHant: '我的 QR 碼',
            en: 'My QR Code',
            ja: 'マイQRコード',
            ko: '내 QR 코드',
          ),
          displayName: displayName,
          aliasLabel: AppI18n.of(context).t(
            zhHans: 'Chat ID',
            zhHant: 'Chat ID',
            en: 'Chat ID',
            ja: 'Chat ID',
            ko: 'Chat ID',
          ),
          aliasValue: userID,
          faceUrl: loginUserInfo.faceUrl ?? "",
          shareText: "${AppI18n.of(context).t(
            zhHans: '我的二维码',
            zhHant: '我的 QR 碼',
            en: 'My QR Code',
            ja: 'マイQRコード',
            ko: '내 QR 코드',
          )} $userID",
        ),
      ),
    );
    if (mounted) {
      await _startCamera();
    }
  }

  String _scannerErrorText(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return AppI18n.of(context).t(
          zhHans: '摄像头权限未开启，请在系统设置中允许访问摄像头',
          zhHant: '攝影機權限未開啟，請在系統設定中允許存取攝影機',
          en: 'Camera permission denied. Enable it in system settings.',
          ja: 'カメラの権限がありません。設定で許可してください。',
          ko: '카메라 권한이 없습니다. 시스템 설정에서 허용해 주세요.',
        );
      case MobileScannerErrorCode.unsupported:
        return AppI18n.of(context).t(
          zhHans: '当前设备不支持扫码，模拟器通常无法打开摄像头',
          zhHant: '目前裝置不支援掃碼，模擬器通常無法開啟攝影機',
          en: 'Scan not supported on this device. Emulators usually lack a camera.',
          ja: 'このデバイスではスキャンできません。エミュレーターはカメラがありません。',
          ko: '이 기기는 스캔을 지원하지 않습니다. 에뮬레이터는 카메라가 없습니다.',
        );
      case MobileScannerErrorCode.controllerUninitialized:
        return AppI18n.of(context).t(
          zhHans: '摄像头正在准备，请稍后重试',
          zhHant: '攝影機正在準備，請稍後重試',
          en: 'Camera is starting. Try again shortly.',
          ja: 'カメラを準備中です。しばらくして再試行してください。',
          ko: '카메라 준비 중입니다. 잠시 후 다시 시도해 주세요.',
        );
      default:
        return AppI18n.of(context).t(
          zhHans: '摄像头启动失败，请检查权限或切换到真机重试',
          zhHant: '攝影機啟動失敗，請檢查權限或切換到真機重試',
          en: 'Camera failed to start. Check permissions or use a real device.',
          ja: 'カメラの起動に失敗しました。権限を確認するか実機でお試しください。',
          ko: '카메라 시작 실패. 권한을 확인하거나 실제 기기에서 시도해 주세요.',
        );
    }
  }

  Widget _buildCameraStateLayer() {
    final error = _cameraError;
    return Container(
      color: Colors.black.withValues(alpha: error == null ? 0.28 : 0.54),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error == null) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 18),
              Text(
                AppI18n.of(context).t(
                  zhHans: '相机启动中...',
                  zhHant: '相機啟動中...',
                  en: 'Starting camera...',
                  ja: 'カメラを起動中...',
                  ko: '카메라 시작 중...',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ] else ...[
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: _startCamera,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: Text(AppI18n.of(context).t(
                      zhHans: '重试',
                      zhHant: '重試',
                      en: 'Retry',
                      ja: '再試行',
                      ko: '다시 시도',
                    )),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _pickImageFromGallery,
                    child: Text(AppI18n.of(context).t(
                      zhHans: '从相册选择',
                      zhHant: '從相簿選擇',
                      en: 'Choose from Album',
                      ja: 'アルバムから選択',
                      ko: '앨범에서 선택',
                    )),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannerError(MobileScannerException error) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: Colors.white,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                _scannerErrorText(error),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              if (error.errorDetails?.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  error.errorDetails!.message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () async {
                  try {
                    setState(() {
                      _handled = false;
                      _loading = false;
                    });
                    await _startCamera();
                  } catch (_) {}
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                child: Text(AppI18n.of(context).t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '다시 시도',
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(double statusBarHeight, Color primaryColor) {
    return Positioned(
      left: 0,
      right: 0,
      top: statusBarHeight,
      child: SizedBox(
        height: kToolbarHeight,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 4,
              top: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context);
                },
                child: SizedBox(
                  width: kToolbarHeight,
                  height: kToolbarHeight,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: primaryColor,
                    size: 25,
                  ),
                ),
              ),
            ),
            Text(
              AppI18n.of(context).t(
                zhHans: '扫一扫',
                zhHant: '掃一掃',
                en: 'Scan',
                ja: 'スキャン',
                ko: '스캔',
              ),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _pickImageFromGallery,
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Center(
                    child: Text(
                      AppI18n.of(context).t(
                        zhHans: '相册',
                        zhHant: '相簿',
                        en: 'Album',
                        ja: 'アルバム',
                        ko: '앨범',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashButton(double top) {
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: ValueListenableBuilder<MobileScannerState>(
        valueListenable: _scannerController,
        builder: (context, state, child) {
          final torchAvailable = state.torchState != TorchState.unavailable;
          final torchOn = state.torchState == TorchState.on;
          final color = torchAvailable
              ? Colors.white
              : Colors.white.withValues(alpha: 0.38);
          return InkWell(
            onTap: torchAvailable
                ? () {
                    _scannerController.toggleTorch();
                  }
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  color: torchOn ? const Color(0xFF3D7BFF) : color,
                  size: 34,
                ),
                const SizedBox(height: 8),
                Text(
                  torchOn
                      ? AppI18n.of(context).t(
                          zhHans: '关闭闪光灯',
                          zhHant: '關閉閃光燈',
                          en: 'Turn Off Flash',
                          ja: 'フラッシュをオフ',
                          ko: '플래시 끄기',
                        )
                      : AppI18n.of(context).t(
                          zhHans: '打开闪光灯',
                          zhHant: '開啟閃光燈',
                          en: 'Turn On Flash',
                          ja: 'フラッシュをオン',
                          ko: '플래시 켜기',
                        ),
                  style: TextStyle(
                    color: color.withValues(alpha: 0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMyQRCodeLink(double bottom) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: Center(
        child: TextButton(
          onPressed: _openMyQRCode,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2F80FF),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          ),
          child: Text(
            AppI18n.of(context).t(
              zhHans: '我的二维码',
              zhHant: '我的 QR 碼',
              en: 'My QR Code',
              ja: 'マイQRコード',
              ko: '내 QR 코드',
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final primaryColor = theme.primaryColor ?? const Color(0xFF1E90FF);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: ImmersiveSystemUi.overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final frameSide = (width * 0.72)
                .clamp(220.0, height * 0.36)
                .clamp(220.0, 420.0)
                .toDouble();
            final frameTop = height * 0.34;
            final instructionTop = height * 0.22;
            final preferredFlashTop = frameTop + frameSide + 78;
            final flashTop = preferredFlashTop > height - 170
                ? height - 170
                : preferredFlashTop;
            final myQRCodeBottom = height * 0.07;
            final scanWindow = Rect.fromLTWH(
              (width - frameSide) / 2,
              frameTop,
              frameSide,
              frameSide,
            );

            return Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  scanWindow: scanWindow,
                  errorBuilder: (context, error, child) {
                    return _buildScannerError(error);
                  },
                  placeholderBuilder: (context, child) {
                    return const ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  onDetect: (capture) {
                    if (capture.barcodes.isEmpty) {
                      return;
                    }
                    final rawValue = capture.barcodes.first.rawValue;
                    if (rawValue == null || rawValue.isEmpty) {
                      return;
                    }
                    _handleResult(rawValue);
                  },
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ScannerMaskPainter(
                      scanWindow: scanWindow,
                      color: Colors.black.withValues(alpha: 0.34),
                    ),
                    size: Size.infinite,
                  ),
                ),
                _buildTopBar(MediaQuery.of(context).padding.top, primaryColor),
                Positioned(
                  left: 26,
                  right: 26,
                  top: instructionTop,
                  child: Text(
                    AppI18n.of(context).t(
                      zhHans: '请将镜头对准二维码进行扫描',
                      zhHant: '請將鏡頭對準 QR 碼進行掃描',
                      en: 'Point the camera at a QR code',
                      ja: 'QRコードにカメラを向けてください',
                      ko: 'QR 코드에 카메라를 맞춰 주세요',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Positioned(
                  left: scanWindow.left,
                  top: scanWindow.top,
                  width: scanWindow.width,
                  height: scanWindow.height,
                  child: AnimatedBuilder(
                    animation: _scanAnimationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ScannerFramePainter(
                          color: primaryColor,
                          scanProgress: _scanAnimationController.value,
                        ),
                      );
                    },
                  ),
                ),
                _buildFlashButton(flashTop),
                _buildMyQRCodeLink(myQRCodeBottom),
                if (!_loading &&
                    (_cameraStarting || !_cameraReady || _cameraError != null))
                  _buildCameraStateLayer(),
                if (_loading)
                  const ColoredBox(
                    color: Colors.black87,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScanResultDialogButton extends StatelessWidget {
  const _ScanResultDialogButton({
    required this.text,
    required this.filled,
    required this.color,
    required this.onTap,
  });

  final String text;
  final bool filled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        filled ? Colors.white : (dark ? Colors.white : const Color(0xFF1D2129));
    final bgColor = filled
        ? color
        : (dark ? const Color(0xFF262A31) : const Color(0xFFF2F4F7));

    return SizedBox(
      height: 46,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerMaskPainter extends CustomPainter {
  final Rect scanWindow;
  final Color color;

  const _ScannerMaskPainter({
    required this.scanWindow,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    final windowPath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(scanWindow, const Radius.circular(14)));
    final maskPath =
        Path.combine(PathOperation.difference, fullPath, windowPath);
    canvas.drawPath(maskPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ScannerMaskPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow || oldDelegate.color != color;
  }
}

class _ScannerFramePainter extends CustomPainter {
  final Color color;
  final double scanProgress;

  const _ScannerFramePainter({
    required this.color,
    required this.scanProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final thinPaint = Paint()
      ..color = color.withValues(alpha: 0.88)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect.deflate(3), thinPaint);

    const minScanY = 10.0;
    final maxScanY = size.height - 10;
    final scanY = minScanY + ((maxScanY - minScanY) * scanProgress);
    final gridBottom = scanY.clamp(18.0, size.height - 10);
    final gridClip = Rect.fromLTRB(8, 8, size.width - 8, gridBottom);
    final gridPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..strokeWidth = 0.75;

    canvas.save();
    canvas.clipRect(gridClip);
    const columnCount = 24;
    for (var i = 1; i < columnCount; i++) {
      final x = size.width * i / columnCount;
      canvas.drawLine(Offset(x, 8), Offset(x, gridBottom), gridPaint);
    }
    const rowSpacing = 14.0;
    for (var y = gridBottom; y > 8; y -= rowSpacing) {
      final distanceToLine = (gridBottom - y).clamp(0.0, 84.0);
      final opacity = 0.14 + ((84.0 - distanceToLine) / 84.0 * 0.18);
      final rowPaint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = 0.75;
      canvas.drawLine(Offset(8, y), Offset(size.width - 8, y), rowPaint);
    }
    canvas.restore();

    final glowRect = Rect.fromLTWH(
      8,
      (scanY - 28).clamp(8.0, size.height - 56),
      size.width - 16,
      56,
    );
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.26),
          color.withValues(alpha: 0),
        ],
      ).createShader(glowRect);
    canvas.drawRect(glowRect, glowPaint);

    final scanLinePaint = Paint()
      ..color = color.withValues(alpha: 0.98)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(8, scanY),
      Offset(size.width - 8, scanY),
      scanLinePaint,
    );

    final cornerLength = size.width * 0.14;
    final midNotch = size.height * 0.86;
    canvas.drawLine(const Offset(0, 0), Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(const Offset(0, 0), Offset(0, cornerLength), cornerPaint);
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      cornerPaint,
    );

    canvas.drawLine(
      Offset(0, midNotch - 22),
      Offset(0, midNotch + 22),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(size.width, midNotch - 22),
      Offset(size.width, midNotch + 22),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerFramePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.scanProgress != scanProgress;
  }
}
