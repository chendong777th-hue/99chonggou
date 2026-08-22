import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/api/settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/trade_password_settings_nav.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/trade_password_pin_keypad.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/wallet_page_colors.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

/// 平台 Logo 资源路径，可按需替换为其它 assets。
const String kTradePasswordPlatformLogo = 'assets/im_new_logo.jpg';

/// 首次设置 6 位交易（支付）密码：Logo + 圆点 + 九宫格键盘。
class SetupTradePasswordPage extends StatefulWidget {
  const SetupTradePasswordPage({
    super.key,
    this.logoAsset = kTradePasswordPlatformLogo,
  });

  final String logoAsset;

  static Future<bool?> open(BuildContext context) {
    return TradePasswordSettingsNav.openSetup(context);
  }

  @override
  State<SetupTradePasswordPage> createState() => _SetupTradePasswordPageState();
}

enum _SetupStep { create, confirm }

class _SetupTradePasswordPageState extends State<SetupTradePasswordPage> {
  static const double _upperScale = 1.5;
  static const double _lowerScale = 1.2;

  _SetupStep _step = _SetupStep.create;
  String _input = '';
  String? _firstPin;
  String _error = '';
  bool _submitting = false;

  String get _stepHint {
    switch (_step) {
      case _SetupStep.create:
        return AppI18n.current.t(
          zhHans: '请输入交易密码',
          zhHant: '請輸入交易密碼',
          en: 'Enter your transaction password',
          ja: '取引パスワードを入力してください',
          ko: '거래 비밀번호를 입력해 주세요',
        );
      case _SetupStep.confirm:
        return AppI18n.current.t(
          zhHans: '请再次输入交易密码',
          zhHant: '請再次輸入交易密碼',
          en: 'Enter your transaction password again',
          ja: '取引パスワードをもう一度入力してください',
          ko: '거래 비밀번호를 다시 입력해 주세요',
        );
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void _onDigit(String digit) {
    if (_submitting || _input.length >= 6) return;
    setState(() {
      _input += digit;
      _error = '';
    });
    if (_input.length < 6) return;

    Future<void>.microtask(_onPinComplete);
  }

  void _onDelete() {
    if (_submitting || _input.isEmpty) return;
    setState(() {
      _input = _input.substring(0, _input.length - 1);
      _error = '';
    });
  }

  Future<void> _onPinComplete() async {
    if (_input.length != 6) return;
    final pin = _input;

    if (_step == _SetupStep.create) {
      setState(() {
        _firstPin = pin;
        _input = '';
        _step = _SetupStep.confirm;
        _error = '';
      });
      return;
    }

    if (_firstPin != pin) {
      setState(() {
        _input = '';
        _error = AppI18n.current.t(
          zhHans: '两次输入的密码不一致，请重新确认',
          zhHant: '兩次輸入的密碼不一致，請重新確認',
          en: 'The passwords do not match. Please try again.',
          ja: '入力したパスワードが一致しません。もう一度確認してください。',
          ko: '입력한 비밀번호가 일치하지 않습니다. 다시 확인해 주세요.',
        );
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await SettingsApi.instance.setTradePassword(payPin: pin);
      if (!mounted) return;
      _toast(AppI18n.current.t(
        zhHans: '交易密码设置成功',
        zhHant: '交易密碼設定成功',
        en: 'Transaction password set successfully.',
        ja: '取引パスワードを設定しました。',
        ko: '거래 비밀번호가 설정되었습니다.',
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _input = '';
        _error = _errorText(e);
      });
    }
  }

  void _onBack() {
    if (_step == _SetupStep.confirm && !_submitting) {
      setState(() {
        _step = _SetupStep.create;
        _input = '';
        _firstPin = null;
        _error = '';
      });
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _toast(String text) {
    ToastUtils.toast(text);
  }

  String _errorText(Object e) {
    if (e is DioError) {
      final data = e.response?.data;
      if (data is Map) {
        final code = data['code']?.toString() ?? '';
        final message = data['message']?.toString() ?? '';
        switch (code) {
          case 'INVALID_PAY_PIN':
            return AppI18n.current.t(
              zhHans: '交易密码需为 6 位数字',
              zhHant: '交易密碼需為 6 位數字',
              en: 'Your transaction password must be 6 digits.',
              ja: '取引パスワードは6桁の数字で入力してください。',
              ko: '거래 비밀번호는 6자리 숫자여야 합니다.',
            );
          default:
            if (message.isNotEmpty) {
              return DioErrorMessage.sanitizeUserText(
                message,
                fallback: AppI18n.current.t(
                  zhHans: '设置失败，请稍后重试',
                  zhHant: '設定失敗，請稍後再試',
                  en: 'Failed to set the password. Please try again later.',
                  ja: '設定に失敗しました。しばらくしてからもう一度お試しください。',
                  ko: '설정에 실패했습니다. 잠시 후 다시 시도해 주세요.',
                ),
              );
            }
        }
      }
    }
    if (e is DioError) {
      return DioErrorMessage.forApp(e);
    }
    return AppI18n.current.t(
      zhHans: '设置失败，请稍后重试',
      zhHant: '設定失敗，請稍後再試',
      en: 'Failed to set the password. Please try again later.',
      ja: '設定に失敗しました。しばらくしてからもう一度お試しください。',
      ko: '설정에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final i18n = AppI18n.of(context);
    final statusText = _submitting
        ? i18n.t(
            zhHans: '正在提交...',
            zhHant: '提交中...',
            en: 'Submitting...',
            ja: '送信中...',
            ko: '제출 중...',
          )
        : (_error.isEmpty ? '' : _error);
    final cs = WalletPageColors.of(context);
    final statusColor = _error.isEmpty ? cs.subText : cs.red;
    final u = _upperScale;
    final k = _lowerScale;

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '设置交易密码',
        zhHant: '設定交易密碼',
        en: 'Set Transaction Password',
        ja: '取引パスワードを設定',
        ko: '거래 비밀번호 설정',
      ),
      onLeadingPressed: _onBack,
      disableLeading: _submitting,
      bottom: Padding(
        padding: EdgeInsets.fromLTRB(
          (32 * k).w,
          (8 * k).h,
          (32 * k).w,
          (16 * k).h + bottomInset,
        ),
        child: TradePasswordKeyPad(
          enabled: !_submitting,
          onDigit: _onDigit,
          onDelete: _onDelete,
          scale: k,
        ),
      ),
      children: [
        SizedBox(height: (28 * u).h),
        _PlatformLogo(
          asset: widget.logoAsset,
          scale: u,
        ),
        SizedBox(height: (32 * u).h),
        Text(
          _stepHint,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (15 * u).sp,
            fontWeight: FontWeight.w400,
            color: AppColors.subText(dark: dark),
            height: 1.3,
          ),
        ),
        SizedBox(height: (48 * u).h),
        TradePasswordPinDots(
          length: _input.length,
          hasError: _error.isNotEmpty,
          dotSize: (14 * u).w,
          spacing: (20 * u).w,
        ),
        SizedBox(height: (20 * u).h),
        SizedBox(
          height: (22 * u).h,
          child: Center(
            child: Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: (13 * u).sp,
                color: statusColor,
              ),
            ),
          ),
        ),
        if (_step == _SetupStep.confirm)
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    setState(() {
                      _step = _SetupStep.create;
                      _input = '';
                      _firstPin = null;
                      _error = '';
                    });
                  },
            child: Text(
              i18n.t(
                zhHans: '重新设置密码',
                zhHant: '重新設定密碼',
                en: 'Reset Password',
                ja: 'パスワードを再設定',
                ko: '비밀번호 다시 설정',
              ),
              style: TextStyle(
                fontSize: (14 * u).sp,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
      ],
    );
  }
}

class _PlatformLogo extends StatelessWidget {
  const _PlatformLogo({
    required this.asset,
    this.scale = 1,
  });

  final String asset;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final size = (88 * scale).w;
    final radius = (20 * scale).r;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          asset,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/img/platform_99.webp',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.inputFill,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: (44 * scale).sp,
                color: cs.subText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
