import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/trade_password_settings_nav.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/biometric_pay_verify_pin_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 面容 / 指纹支付全屏设置页（参考微信「手机面容识别」样式）。
class BiometricPayEnablePage extends StatefulWidget {
  /// 支付成功后引导进入时可复用刚验证过的 payPin。
  final String? verifiedPayPin;

  /// 是否为支付成功后的引导页（展示「不再提示」）。
  final bool isPostPayPrompt;

  const BiometricPayEnablePage({
    super.key,
    this.verifiedPayPin,
    this.isPostPayPrompt = false,
  });

  static Future<bool?> open(
    BuildContext context, {
    String? verifiedPayPin,
    bool isPostPayPrompt = false,
  }) {
    return Navigator.of(context).push<bool>(
      NavigationRoutes.cupertino(
        builder: (_) => BiometricPayEnablePage(
          verifiedPayPin: verifiedPayPin,
          isPostPayPrompt: isPostPayPrompt,
        ),
      ),
    );
  }

  @override
  State<BiometricPayEnablePage> createState() => _BiometricPayEnablePageState();
}

class _BiometricPayEnablePageState extends State<BiometricPayEnablePage> {
  final _bio = BiometricPayService.instance;

  bool _loading = true;
  bool _enabled = false;
  bool _payPinSet = false;
  bool _busy = false;
  BiometricPayModality _modality = BiometricPayModality.fingerprint;

  static const Color _accentGreen = Color(0xFF07C160);

  bool get _usesFace => _bio.usesFaceUi(_modality);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var enabled = false;
    var payPinSet = false;
    var modality = BiometricPayModality.fingerprint;
    try {
      enabled = await _bio.isEnabled();
      final me = await WalletApi.instance.getMe();
      payPinSet = me.payPinSet;
      modality = await _bio.currentModality();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _loading = false;
      _enabled = enabled;
      _payPinSet = payPinSet;
      _modality = modality;
    });
  }

  /// 未录入生物识别时引导去系统设置；已录入返回 true。
  Future<bool> _ensureEnrolled(AppI18n i18n) async {
    if (await _bio.hasEnrolledBiometrics()) return true;
    if (!mounted) return false;

    final goSettings = await AppDialog.confirm(
      title: i18n.t(
        zhHans: '未设置生物识别',
        zhHant: '未設定生物辨識',
        en: 'Biometric not set up',
        ja: '生体認証が未設定です',
        ko: '생체 인증이 설정되지 않음',
      ),
      message: i18n.t(
        zhHans: '请先在系统「设置 → 安全」中录入指纹或面容，再返回开启快捷支付。',
        zhHant: '請先在系統「設定 → 安全性」中錄入指紋或面容，再返回開啟快捷支付。',
        en:
            'Add a fingerprint or face in Settings > Security, then return to enable quick pay.',
        ja: '設定 > セキュリティで指紋または顔を登録してから、クイック支払いを有効にしてください。',
        ko: '설정 > 보안에서 지문 또는 얼굴을 등록한 뒤 빠른 결제를 켜 주세요.',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      confirmText: i18n.t(
        zhHans: '去设置',
        zhHant: '去設定',
        en: 'Go to Settings',
        ja: '設定を開く',
        ko: '설정으로',
      ),
    );
    if (goSettings) {
      await _bio.openSystemSettings();
    }
    return false;
  }

  Future<void> _onActionRowTap() async {
    if (_busy || _loading) return;
    final i18n = AppI18n.of(context);

    if (!_payPinSet) {
      ToastUtils.toast(
        i18n.t(
          zhHans: '请先设置支付密码',
          zhHant: '請先設定支付密碼',
          en: 'Please set a payment password first.',
          ja: '先に支払いパスワードを設定してください。',
          ko: '먼저 결제 비밀번호를 설정해 주세요.',
        ),
      );
      await TradePasswordSettingsNav.openSetup(context);
      await _load();
      return;
    }

    if (_enabled) {
      final label = await _bio.paymentLabel(i18n);
      if (!mounted) return;
      final confirm = await AppDialog.confirm(
        title: i18n.t(
          zhHans: '关闭$label',
          zhHant: '關閉$label',
          en: 'Disable $label',
          ja: '$labelを無効にする',
          ko: '$label 해제',
        ),
        message: i18n.t(
          zhHans: '关闭后，支付时需重新输入 6 位支付密码。',
          zhHant: '關閉後，支付時需重新輸入 6 位支付密碼。',
          en: 'You will need to enter your 6-digit payment password again.',
          ja: '無効にすると、支払い時に6桁の支払いパスワードを再入力する必要があります。',
          ko: '해제하면 결제 시 6자리 결제 비밀번호를 다시 입력해야 합니다.',
        ),
        cancelText: i18n.t(
          zhHans: '取消',
          zhHant: '取消',
          en: 'Cancel',
          ja: 'キャンセル',
          ko: '취소',
        ),
        confirmText: i18n.t(
          zhHans: '关闭',
          zhHant: '關閉',
          en: 'Disable',
          ja: '無効にする',
          ko: '해제',
        ),
        destructive: true,
      );
      if (!confirm || !mounted) return;
      setState(() => _busy = true);
      try {
        await _bio.disableAndClear();
        if (!mounted) return;
        setState(() => _enabled = false);
        ToastUtils.toast(await _bio.disabledToast(i18n));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (!await _ensureEnrolled(i18n)) return;

    setState(() => _busy = true);
    try {
      final ok = await _enablePay(i18n);
      if (!mounted) return;
      if (ok) {
        final modality = await _bio.currentModality();
        final toast = await _bio.enabledToast(i18n);
        if (!mounted) return;
        setState(() {
          _enabled = true;
          _modality = modality;
        });
        ToastUtils.toast(toast);
        if (widget.isPostPayPrompt) {
          Navigator.of(context).pop(true);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _enablePay(AppI18n i18n) async {
    final cached = widget.verifiedPayPin?.trim();
    if (cached != null && cached.length == 6) {
      return _bio.enableWithVerifiedPin(pin: cached, i18n: i18n);
    }

    final ok = await BiometricPayVerifyPinPage.openForEnable(context);
    return ok == true;
  }

  Future<void> _neverAskAgain() async {
    await _bio.setPromptNever(true);
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.background(dark: dark);
    final text = AppColors.text(dark: dark);
    final subText = AppColors.subText(dark: dark);
    final line = AppColors.line(dark: dark);
    final overlay = immersiveOverlayForColors(
      statusBarBackground: bg,
      navigationBarBackground: bg,
    );

    final pageTitle = switch (_modality) {
      BiometricPayModality.face => i18n.t(
          zhHans: '手机面容识别',
          zhHant: '手機面容識別',
          en: 'Face ID for Payments',
          ja: 'Face ID 支払い',
          ko: 'Face ID 결제',
        ),
      BiometricPayModality.faceAndFingerprint => i18n.t(
          zhHans: '手机面容/指纹识别',
          zhHant: '手機面容/指紋識別',
          en: 'Biometrics for Payments',
          ja: '生体認証支払い',
          ko: '생체 인증 결제',
        ),
      BiometricPayModality.biometric => i18n.t(
          zhHans: '手机生物识别',
          zhHant: '手機生物辨識',
          en: 'Biometrics for Payments',
          ja: '生体認証支払い',
          ko: '생체 인증 결제',
        ),
      BiometricPayModality.fingerprint => i18n.t(
          zhHans: '手机指纹识别',
          zhHant: '手機指紋識別',
          en: 'Fingerprint for Payments',
          ja: '指紋支払い',
          ko: '지문 결제',
        ),
    };

    final description = switch (_modality) {
      BiometricPayModality.face => i18n.t(
          zhHans: '开启后，支付时可验证面容，快速完成付款。',
          zhHant: '開啟後，支付時可驗證面容，快速完成付款。',
          en: 'Once enabled, verify with Face ID to pay faster.',
          ja: '有効にすると、支払い時に Face ID で素早く確認できます。',
          ko: '사용하면 결제 시 Face ID로 빠르게 확인할 수 있습니다.',
        ),
      BiometricPayModality.faceAndFingerprint => i18n.t(
          zhHans: '开启后，支付时可验证面容或指纹，快速完成付款。',
          zhHant: '開啟後，支付時可驗證面容或指紋，快速完成付款。',
          en: 'Once enabled, verify with face or fingerprint to pay faster.',
          ja: '有効にすると、支払い時に顔または指紋ですばやく確認できます。',
          ko: '사용하면 결제 시 얼굴 또는 지문으로 빠르게 확인할 수 있습니다.',
        ),
      BiometricPayModality.biometric => i18n.t(
          zhHans: '开启后，支付时可验证生物识别，快速完成付款。',
          zhHant: '開啟後，支付時可驗證生物辨識，快速完成付款。',
          en: 'Once enabled, verify with biometrics to pay faster.',
          ja: '有効にすると、支払い時に生体認証ですばやく確認できます。',
          ko: '사용하면 결제 시 생체 인증으로 빠르게 확인할 수 있습니다.',
        ),
      BiometricPayModality.fingerprint => i18n.t(
          zhHans: '开启后，支付时可验证指纹，快速完成付款。',
          zhHant: '開啟後，支付時可驗證指紋，快速完成付款。',
          en: 'Once enabled, verify with fingerprint to pay faster.',
          ja: '有効にすると、支払い時に指紋ですばやく確認できます。',
          ko: '사용하면 결제 시 지문으로 빠르게 확인할 수 있습니다.',
        ),
    };

    final actionLabel = switch (_modality) {
      BiometricPayModality.face => i18n.t(
          zhHans: '开启手机面容识别',
          zhHant: '開啟手機面容識別',
          en: 'Enable Face ID for payments',
          ja: 'Face ID 支払いを有効にする',
          ko: 'Face ID 결제 사용',
        ),
      BiometricPayModality.faceAndFingerprint => i18n.t(
          zhHans: '开启手机面容/指纹识别',
          zhHant: '開啟手機面容/指紋識別',
          en: 'Enable biometrics for payments',
          ja: '生体認証支払いを有効にする',
          ko: '생체 인증 결제 사용',
        ),
      BiometricPayModality.biometric => i18n.t(
          zhHans: '开启手机生物识别',
          zhHant: '開啟手機生物辨識',
          en: 'Enable biometrics for payments',
          ja: '生体認証支払いを有効にする',
          ko: '생체 인증 결제 사용',
        ),
      BiometricPayModality.fingerprint => i18n.t(
          zhHans: '开启手机指纹识别',
          zhHant: '開啟手機指紋識別',
          en: 'Enable fingerprint for payments',
          ja: '指紋支払いを有効にする',
          ko: '지문 결제 사용',
        ),
    };

    final statusText = _enabled
        ? i18n.t(
            zhHans: '已开启',
            zhHant: '已開啟',
            en: 'Enabled',
            ja: '有効',
            ko: '사용 중',
          )
        : i18n.t(
            zhHans: '未开启',
            zhHant: '未開啟',
            en: 'Disabled',
            ja: '無効',
            ko: '미사용',
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: bg,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: overlay,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: text,
            onPressed: () => Navigator.of(context).pop(_enabled),
          ),
        ),
        body: _loading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  const SizedBox(height: 36),
                  _BiometricHeroIcon(
                    usesFace: _usesFace,
                    color: _accentGreen,
                  ),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      pageTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: text,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: subText,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Material(
                    color: AppColors.card(dark: dark),
                    child: InkWell(
                      onTap: _busy ? null : _onActionRowTap,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: line, width: 0.6),
                            bottom: BorderSide(color: line, width: 0.6),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                actionLabel,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: text,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            if (_busy)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CupertinoActivityIndicator(
                                  color: subText,
                                ),
                              )
                            else ...[
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _enabled ? _accentGreen : subText,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: subText.withValues(alpha: 0.55),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (widget.isPostPayPrompt) ...[
                    const Spacer(),
                    SafeArea(
                      top: false,
                      child: TextButton(
                        onPressed: _neverAskAgain,
                        child: Text(
                          i18n.t(
                            zhHans: '不再提示',
                            zhHant: '不再提示',
                            en: 'Don\'t ask again',
                            ja: '今後表示しない',
                            ko: '다시 묻지 않기',
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: subText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

class _BiometricHeroIcon extends StatelessWidget {
  final bool usesFace;
  final Color color;

  const _BiometricHeroIcon({
    required this.usesFace,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (usesFace) {
      return SizedBox(
        width: 112,
        height: 112,
        child: CustomPaint(
          painter: _FaceIdBracketPainter(color: color),
        ),
      );
    }

    return Icon(
      Icons.fingerprint_rounded,
      size: 88,
      color: color,
    );
  }
}

/// 微信风格 Face ID 四角括号图标。
class _FaceIdBracketPainter extends CustomPainter {
  final Color color;

  _FaceIdBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bracket = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;

    final len = w * 0.22;
    final inset = w * 0.12;

    void corner(Offset origin, {required bool top, required bool left}) {
      final dx = left ? 1.0 : -1.0;
      final dy = top ? 1.0 : -1.0;
      final p = origin;
      canvas.drawLine(p, p + Offset(dx * len, 0), bracket);
      canvas.drawLine(p, p + Offset(0, dy * len), bracket);
    }

    corner(Offset(inset, inset), top: true, left: true);
    corner(Offset(w - inset, inset), top: true, left: false);
    corner(Offset(inset, h - inset), top: false, left: true);
    corner(Offset(w - inset, h - inset), top: false, left: false);

    final face = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = w / 2;
    final cy = h / 2;
    canvas.drawCircle(Offset(cx - w * 0.11, cy - h * 0.04), w * 0.028, face);
    canvas.drawCircle(Offset(cx + w * 0.11, cy - h * 0.04), w * 0.028, face);

    final smile = Path();
    smile.moveTo(cx - w * 0.14, cy + h * 0.08);
    smile.quadraticBezierTo(
      cx,
      cy + h * 0.18,
      cx + w * 0.14,
      cy + h * 0.08,
    );
    canvas.drawPath(
      smile,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _FaceIdBracketPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
