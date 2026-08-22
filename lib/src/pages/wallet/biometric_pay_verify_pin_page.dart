import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';

/// 开启面容 / 指纹支付时的全屏支付密码验证页。
class BiometricPayVerifyPinPage extends StatefulWidget {
  final String title;
  final String subtitle;

  const BiometricPayVerifyPinPage({
    super.key,
    required this.title,
    required this.subtitle,
  });

  /// 验证支付密码并尝试开启面容支付；成功返回 `true`。
  static Future<bool?> openForEnable(BuildContext context) async {
    final i18n = AppI18n.of(context);
    final bio = BiometricPayService.instance;
    final title = await bio.enableTitle(i18n);
    if (!context.mounted) return null;

    return Navigator.of(context).push<bool>(
      NavigationRoutes.cupertino(
        fullscreenDialog: true,
        builder: (_) => BiometricPayVerifyPinPage(
          title: title,
          subtitle: i18n.t(
            zhHans: '请输入支付密码，以验证身份',
            zhHant: '請輸入支付密碼，以驗證身分',
            en: 'Enter your payment password to verify your identity',
            ja: '本人確認のため、支払いパスワードを入力してください',
            ko: '본인 확인을 위해 결제 비밀번호를 입력해 주세요',
          ),
        ),
      ),
    );
  }

  @override
  State<BiometricPayVerifyPinPage> createState() =>
      _BiometricPayVerifyPinPageState();
}

class _BiometricPayVerifyPinPageState extends State<BiometricPayVerifyPinPage> {
  final _bio = BiometricPayService.instance;

  String _input = '';
  String _error = '';
  bool _submitting = false;

  Future<void> _onDigit(String digit) async {
    if (_submitting || _input.length >= 6) return;
    setState(() {
      _input += digit;
      _error = '';
    });
    HapticFeedback.selectionClick();
    if (_input.length < 6) return;

    setState(() => _submitting = true);
    final i18n = AppI18n.of(context);

    if (!await _bio.hasEnrolledBiometrics()) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _input = '';
        _error = i18n.t(
          zhHans: '请先在系统设置中录入指纹或面容',
          zhHant: '請先在系統設定中錄入指紋或面容',
          en: 'Add a fingerprint or face in system settings first.',
          ja: '先にシステム設定で指紋または顔を登録してください。',
          ko: '먼저 시스템 설정에서 지문 또는 얼굴을 등록해 주세요.',
        );
      });
      return;
    }

    final auth = await _bio.authenticate(
      i18n: i18n,
      reason: _bio.enableAuthReason(i18n),
    );
    if (!mounted) return;

    if (auth.notEnrolled) {
      setState(() {
        _submitting = false;
        _input = '';
        _error = i18n.t(
          zhHans: '请先在系统设置中录入指纹或面容',
          zhHant: '請先在系統設定中錄入指紋或面容',
          en: 'Add a fingerprint or face in system settings first.',
          ja: '先にシステム設定で指紋または顔を登録してください。',
          ko: '먼저 시스템 설정에서 지문 또는 얼굴을 등록해 주세요.',
        );
      });
      return;
    }

    if (!auth.success) {
      setState(() {
        _submitting = false;
        _input = '';
        _error = i18n.t(
          zhHans: '验证失败，请重试',
          zhHant: '驗證失敗，請重試',
          en: 'Verification failed. Please try again.',
          ja: '確認に失敗しました。もう一度お試しください。',
          ko: '인증에 실패했습니다. 다시 시도해 주세요.',
        );
      });
      return;
    }

    final userId = BiometricPayService.currentUserId();
    if (userId == null) {
      setState(() {
        _submitting = false;
        _input = '';
        _error = i18n.t(
          zhHans: '验证失败，请重试',
          zhHant: '驗證失敗，請重試',
          en: 'Verification failed. Please try again.',
          ja: '確認に失敗しました。もう一度お試しください。',
          ko: '인증에 실패했습니다. 다시 시도해 주세요.',
        );
      });
      return;
    }

    await _bio.savePayPin(userId: userId, pin: _input);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _onDelete() {
    if (_submitting || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = '';
    });
    HapticFeedback.selectionClick();
  }

  void _close() {
    if (_submitting) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.background(dark: dark);
    final text = AppColors.text(dark: dark);
    final subText = AppColors.subText(dark: dark);
    final overlay = immersiveOverlayForColors(
      statusBarBackground: bg,
      navigationBarBackground: bg,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _close,
                  icon: Icon(Icons.close_rounded, color: text, size: 26),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: text,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: subText,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 36),
                        _PinSquareCells(
                          length: _input.length,
                          hasError: _error.isNotEmpty,
                          dark: dark,
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            _error,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primaryRed,
                            ),
                          ),
                        ],
                        if (_submitting) ...[
                          const SizedBox(height: 24),
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _WechatGridKeypad(
                enabled: !_submitting,
                dark: dark,
                onDigit: _onDigit,
                onDelete: _onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinSquareCells extends StatelessWidget {
  final int length;
  final bool hasError;
  final bool dark;

  const _PinSquareCells({
    required this.length,
    required this.hasError,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    const cellSize = 44.0;
    const gap = 10.0;
    final boxColor = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F2);
    final borderColor =
        hasError ? AppColors.primaryRed : (dark ? const Color(0xFF3A3A3C) : const Color(0xFFE8E8E8));
    final dotColor = AppColors.text(dark: dark);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = length > i;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: gap / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: cellSize,
            height: cellSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: boxColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: 0.8),
            ),
            child: filled
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        );
      }),
    );
  }
}

/// 微信风格全宽网格数字键盘（细分割线、底行左空右删）。
class _WechatGridKeypad extends StatelessWidget {
  final bool enabled;
  final bool dark;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;

  const _WechatGridKeypad({
    required this.enabled,
    required this.dark,
    required this.onDigit,
    required this.onDelete,
  });

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'del'],
  ];

  @override
  Widget build(BuildContext context) {
    final line = dark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5E5);
    final keyBg = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final blankBg = dark ? const Color(0xFF2C2C2E) : const Color(0xFFF7F7F7);
    final textColor = AppColors.text(dark: dark);

    return ColoredBox(
      color: line,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < _rows.length; r++) ...[
            if (r > 0) SizedBox(height: 0.6, child: ColoredBox(color: line)),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < 3; c++) ...[
                    if (c > 0)
                      SizedBox(width: 0.6, child: ColoredBox(color: line)),
                    Expanded(
                      child: _buildKey(
                        value: _rows[r][c],
                        keyBg: keyBg,
                        blankBg: blankBg,
                        textColor: textColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKey({
    required String value,
    required Color keyBg,
    required Color blankBg,
    required Color textColor,
  }) {
    if (value.isEmpty) {
      return ColoredBox(color: blankBg, child: const SizedBox(height: 54));
    }

    final isDel = value == 'del';
    return Material(
      color: keyBg,
      child: InkWell(
        onTap: !enabled
            ? null
            : isDel
                ? onDelete
                : () => onDigit(value),
        child: SizedBox(
          height: 54,
          child: Center(
            child: isDel
                ? Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: enabled ? textColor : textColor.withValues(alpha: 0.4),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w400,
                      color: enabled ? textColor : textColor.withValues(alpha: 0.4),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
