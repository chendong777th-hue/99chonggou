import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_list_pick.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_selection_theme.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_country.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/env.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/setup_trade_password_page.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/security/slider_captcha.dart';
import 'package:tencent_cloud_chat_demo/src/utils/phone_binding_guard.dart';
import 'package:tencent_cloud_chat_demo/utils/phone_format.dart';

class ChangeTradePasswordPage extends StatefulWidget {
  const ChangeTradePasswordPage({super.key});

  @override
  State<ChangeTradePasswordPage> createState() =>
      _ChangeTradePasswordPageState();
}

class _ChangeTradePasswordPageState extends State<ChangeTradePasswordPage> {
  final oldTradePasswordController = TextEditingController();
  final newTradePasswordController = TextEditingController();
  final confirmTradePasswordController = TextEditingController();
  bool? payPinSet;
  bool? _phoneBound;
  bool loading = true;
  bool _guardChecking = true;
  bool sending = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool get _canSubmit {
    if (loading || sending) return false;
    final isSet = payPinSet == true;
    final oldPin = oldTradePasswordController.text.trim();
    final newPin = newTradePasswordController.text.trim();
    final confirmPin = confirmTradePasswordController.text.trim();
    return _pinError(
          newPin,
          confirmPin: confirmPin,
          oldPin: isSet ? oldPin : '',
        ) ==
        null;
  }

  @override
  void initState() {
    super.initState();
    oldTradePasswordController.addListener(_refresh);
    newTradePasswordController.addListener(_refresh);
    confirmTradePasswordController.addListener(_refresh);
    _initialize();
  }

  @override
  void dispose() {
    oldTradePasswordController.removeListener(_refresh);
    newTradePasswordController.removeListener(_refresh);
    confirmTradePasswordController.removeListener(_refresh);
    oldTradePasswordController.dispose();
    newTradePasswordController.dispose();
    confirmTradePasswordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initialize() async {
    var phoneBound = false;
    try {
      final me = await AuthApi.instance.fetchMe();
      phoneBound = PhoneBindingGuard.isBound(me);
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _phoneBound = phoneBound;
      _guardChecking = false;
    });
    await _loadState();
  }

  Future<void> _loadState() async {
    try {
      final me = await WalletApi.instance.getMe();
      if (!mounted) return;
      if (!me.payPinSet && mounted) {
        Navigator.pushReplacement(
          context,
          NavigationRoutes.cupertino(
            builder: (_) => const SetupTradePasswordPage(),
          ),
        );
        return;
      }
      setState(() {
        payPinSet = me.payPinSet;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        payPinSet = true;
        loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (sending || loading) return;
    final isSet = payPinSet == true;
    final oldPin = oldTradePasswordController.text.trim();
    final newPin = newTradePasswordController.text.trim();
    final confirmPin = confirmTradePasswordController.text.trim();
    final err = _pinError(
      newPin,
      confirmPin: confirmPin,
      oldPin: isSet ? oldPin : '',
    );
    if (err != null) {
      _toast(err);
      return;
    }

    setState(() => sending = true);
    try {
      if (isSet) {
        await SettingsApi.instance.changeTradePassword(
          oldPassword: oldPin,
          newPassword: newPin,
        );
      } else {
        await SettingsApi.instance.setTradePassword(payPin: newPin);
      }
      if (!mounted) return;
      await BiometricPayService.instance.disableAndClear();
      _toast(AppI18n.current.t(
        zhHans: isSet ? '修改成功' : '设置成功',
        zhHant: isSet ? '修改成功' : '設定成功',
        en: isSet ? 'Updated successfully.' : 'Set successfully.',
        ja: isSet ? '変更しました。' : '設定しました。',
        ko: isSet ? '변경되었습니다.' : '설정되었습니다.',
      ));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _openReset() async {
    await Navigator.of(context).push(
      AppMaterialPageRoute(builder: (_) => const ResetTradePasswordPage()),
    );
  }

  String? _pinError(
    String pin, {
    required String confirmPin,
    String oldPin = '',
  }) {
    final re = RegExp(r'^\d{6}$');
    if (oldPin.isNotEmpty && !re.hasMatch(oldPin)) {
      return AppI18n.current.t(
        zhHans: '请输入 6 位原支付密码',
        zhHant: '請輸入 6 位原支付密碼',
        en: 'Enter your current 6-digit payment password.',
        ja: '現在の6桁の支払いパスワードを入力してください。',
        ko: '현재 6자리 결제 비밀번호를 입력해 주세요.',
      );
    }
    if (!re.hasMatch(pin)) {
      return AppI18n.current.t(
        zhHans: '请输入 6 位新支付密码',
        zhHant: '請輸入 6 位新支付密碼',
        en: 'Enter a new 6-digit payment password.',
        ja: '新しい6桁の支払いパスワードを入力してください。',
        ko: '새 6자리 결제 비밀번호를 입력해 주세요.',
      );
    }
    if (pin != confirmPin) {
      return AppI18n.current.t(
        zhHans: '两次输入的支付密码不一致',
        zhHant: '兩次輸入的支付密碼不一致',
        en: 'The two payment passwords do not match.',
        ja: '入力した支払いパスワードが一致しません。',
        ko: '입력한 결제 비밀번호가 서로 일치하지 않습니다.',
      );
    }
    return null;
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
          case 'PAY_PIN_INVALID':
            return AppI18n.current.t(
              zhHans: '支付密码错误',
              zhHant: '支付密碼錯誤',
              en: 'Incorrect payment password.',
              ja: '支払いパスワードが正しくありません。',
              ko: '결제 비밀번호가 올바르지 않습니다.',
            );
          case 'PAY_PIN_LOCKED':
            return AppI18n.current.t(
              zhHans: '支付密码已锁定',
              zhHant: '支付密碼已鎖定',
              en: 'Your payment password has been locked.',
              ja: '支払いパスワードはロックされています。',
              ko: '결제 비밀번호가 잠겼습니다.',
            );
          case 'SMS_CODE_INVALID':
            return AppI18n.current.t(
              zhHans: '验证码错误或已过期',
              zhHant: '驗證碼錯誤或已過期',
              en: 'The verification code is invalid or has expired.',
              ja: '認証コードが正しくないか、有効期限が切れています。',
              ko: '인증 코드가 올바르지 않거나 만료되었습니다.',
            );
          case 'INVALID_PAY_PIN':
            return AppI18n.current.t(
              zhHans: '支付密码需为 6 位数字',
              zhHant: '支付密碼需為 6 位數字',
              en: 'Your payment password must be 6 digits.',
              ja: '支払いパスワードは6桁の数字で入力してください。',
              ko: '결제 비밀번호는 6자리 숫자여야 합니다.',
            );
        }
        if (message.isNotEmpty) {
          return DioErrorMessage.sanitizeUserText(
            message,
            fallback: AppI18n.current.t(
              zhHans: '操作失败，请稍后重试',
              zhHant: '操作失敗，請稍後再試',
              en: 'The operation failed. Please try again later.',
              ja: '操作に失敗しました。しばらくしてからもう一度お試しください。',
              ko: '작업에 실패했습니다. 잠시 후 다시 시도해 주세요.',
            ),
          );
        }
      }
    }
    return AppI18n.current.t(
      zhHans: '操作失败，请稍后重试',
      zhHant: '操作失敗，請稍後再試',
      en: 'The operation failed. Please try again later.',
      ja: '操作に失敗しました。しばらくしてからもう一度お試しください。',
      ko: '작업에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSet = payPinSet == true;
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: isSet ? '修改支付密码' : '设置支付密码',
        zhHant: isSet ? '修改支付密碼' : '設定支付密碼',
        en: isSet ? 'Change Payment Password' : 'Set Payment Password',
        ja: isSet ? '支払いパスワードを変更' : '支払いパスワードを設定',
        ko: isSet ? '결제 비밀번호 변경' : '결제 비밀번호 설정',
      ),
      children: [
        if (_guardChecking)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              isSet
                  ? i18n.t(
                      zhHans: '请输入当前支付密码，并设置新的 6 位数字支付密码。',
                      zhHant: '請輸入目前支付密碼，並設定新的 6 位數字支付密碼。',
                      en: 'Enter your current payment password, then set a new 6-digit one.',
                      ja: '現在の支払いパスワードを入力し、新しい6桁の支払いパスワードを設定してください。',
                      ko: '현재 결제 비밀번호를 입력한 뒤 새 6자리 결제 비밀번호를 설정해 주세요.',
                    )
                  : i18n.t(
                      zhHans: '请设置 6 位数字支付密码，用于转账、红包等资金操作。',
                      zhHant: '請設定 6 位數字支付密碼，用於轉帳、紅包等資金操作。',
                      en: 'Set a 6-digit payment password for transfers, red packets, and other wallet actions.',
                      ja: '送金、紅包、その他の資金操作に使用する6桁の支払いパスワードを設定してください。',
                      ko: '송금, 레드패킷 등 자금 관련 기능에 사용할 6자리 결제 비밀번호를 설정해 주세요.',
                    ),
              style: TextStyle(
                color: helperColor,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          if (loading)
            const _SettingsLoadingBox()
          else ...[
            SettingsGroup(
              margin: EdgeInsets.zero,
              children: [
                if (isSet)
                  _PinInputCell(
                    label: i18n.t(
                      zhHans: '原密码',
                      zhHant: '原密碼',
                      en: 'Current Password',
                      ja: '現在のパスワード',
                      ko: '현재 비밀번호',
                    ),
                    hint: i18n.t(
                      zhHans: '请输入 6 位支付密码',
                      zhHant: '請輸入 6 位支付密碼',
                      en: 'Enter your 6-digit payment password',
                      ja: '6桁の支払いパスワードを入力',
                      ko: '6자리 결제 비밀번호를 입력해 주세요',
                    ),
                    controller: oldTradePasswordController,
                    obscureText: _obscureOld,
                    onToggleObscure: () {
                      setState(() {
                        _obscureOld = !_obscureOld;
                      });
                    },
                  ),
                _PinInputCell(
                  label: i18n.t(
                    zhHans: '新密码',
                    zhHant: '新密碼',
                    en: 'New Password',
                    ja: '新しいパスワード',
                    ko: '새 비밀번호',
                  ),
                  hint: i18n.t(
                    zhHans: '请输入新的 6 位支付密码',
                    zhHant: '請輸入新的 6 位支付密碼',
                    en: 'Enter a new 6-digit payment password',
                    ja: '新しい6桁の支払いパスワードを入力',
                    ko: '새 6자리 결제 비밀번호를 입력해 주세요',
                  ),
                  controller: newTradePasswordController,
                  obscureText: _obscureNew,
                  onToggleObscure: () {
                    setState(() {
                      _obscureNew = !_obscureNew;
                    });
                  },
                ),
                _PinInputCell(
                  label: i18n.t(
                    zhHans: '确认密码',
                    zhHant: '確認密碼',
                    en: 'Confirm Password',
                    ja: 'パスワードを確認',
                    ko: '비밀번호 확인',
                  ),
                  hint: i18n.t(
                    zhHans: '请再次输入支付密码',
                    zhHant: '請再次輸入支付密碼',
                    en: 'Enter the payment password again',
                    ja: '支払いパスワードをもう一度入力',
                    ko: '결제 비밀번호를 다시 입력해 주세요',
                  ),
                  controller: confirmTradePasswordController,
                  obscureText: _obscureConfirm,
                  showDivider: false,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                ),
              ],
            ),
            if (isSet && _phoneBound == true)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: GestureDetector(
                  onTap: _openReset,
                  child: Text(
                    i18n.t(
                      zhHans: '忘记支付密码？通过短信验证码重置',
                      zhHant: '忘記支付密碼？透過簡訊驗證碼重設',
                      en: 'Forgot your payment password? Reset it with an SMS code.',
                      ja: '支払いパスワードを忘れた場合は、SMS認証コードで再設定できます。',
                      ko: '결제 비밀번호를 잊으셨나요? 문자 인증 코드로 재설정할 수 있습니다.',
                    ),
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
            else if (isSet && _phoneBound == false)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  i18n.t(
                    zhHans: '未绑定手机时无法通过短信重置支付密码，请联系管理后台处理。',
                    zhHant: '未綁定手機時無法透過簡訊重設支付密碼，請聯繫管理後台處理。',
                    en: 'SMS reset is unavailable without a bound phone number. Please contact support.',
                    ja: '電話番号未連携の場合、SMS再設定は利用できません。管理者にお問い合わせください。',
                    ko: '휴대전화 번호가 등록되지 않은 경우 문자 재설정을 사용할 수 없습니다. 관리자에게 문의해 주세요.',
                  ),
                  style: TextStyle(
                    color: helperColor,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _canSubmit
                        ? AppColors.primaryBlue
                        : AppColors.line(dark: dark),
                    foregroundColor: _canSubmit
                        ? Colors.white
                        : AppColors.subText(dark: dark),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _canSubmit ? _submit : null,
                  child: Text(
                    sending
                        ? i18n.t(
                            zhHans: '提交中...',
                            zhHant: '提交中...',
                            en: 'Submitting...',
                            ja: '送信中...',
                            ko: '제출 중...',
                          )
                        : i18n.t(
                            zhHans: isSet ? '完成' : '设置',
                            zhHant: isSet ? '完成' : '設定',
                            en: isSet ? 'Done' : 'Set',
                            ja: isSet ? '完了' : '設定',
                            ko: isSet ? '완료' : '설정',
                          ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            if (isSet) const SizedBox(height: 4),
          ],
        ],
      ],
    );
  }
}

class _SettingsLoadingBox extends StatelessWidget {
  const _SettingsLoadingBox();

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    return SettingsGroup(
      children: [
        Container(
          height: 92,
          alignment: Alignment.center,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.primaryBlue,
              backgroundColor: AppColors.line(dark: dark),
            ),
          ),
        ),
      ],
    );
  }
}

class ResetTradePasswordPage extends StatefulWidget {
  const ResetTradePasswordPage({super.key});

  @override
  State<ResetTradePasswordPage> createState() => _ResetTradePasswordPageState();
}

class _ResetTradePasswordPageState extends State<ResetTradePasswordPage> {
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();
  bool sendingCode = false;
  bool submitting = false;
  bool _guardChecking = true;
  int codeCooldown = 0;
  Timer? codeCooldownTimer;
  String _countryCode = AppEnv.defaultCountryCode;
  String _phoneCountryIso = AppEnv.defaultPhoneCountry;

  bool get _isPhoneValid => PhoneFormat.isValidNationalNumber(
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
        nationalNumber: phoneController.text.trim(),
      );

  String get _e164Phone => PhoneFormat.e164(
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
        nationalNumber: phoneController.text.trim(),
      );

  @override
  void initState() {
    super.initState();
    _ensurePhoneBound();
  }

  Future<void> _ensurePhoneBound() async {
    final bound = await PhoneBindingGuard.ensureBound(context);
    if (!mounted) {
      return;
    }
    if (!bound) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _guardChecking = false);
  }

  @override
  void dispose() {
    codeCooldownTimer?.cancel();
    phoneController.dispose();
    codeController.dispose();
    pinController.dispose();
    confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (sendingCode || codeCooldown > 0) return;
    if (phoneController.text.trim().isEmpty) {
      _toast(AppI18n.current.t(
        zhHans: '请输入绑定手机号',
        zhHant: '請輸入綁定手機號',
        en: 'Enter your bound phone number.',
        ja: '連携済みの電話番号を入力してください。',
        ko: '연결된 휴대전화 번호를 입력해 주세요.',
      ));
      return;
    }
    if (!_isPhoneValid) {
      _toast(AppI18n.current.t(
        zhHans: '手机号格式不正确',
        zhHant: '手機號格式不正確',
        en: 'The phone number format is invalid.',
        ja: '電話番号の形式が正しくありません。',
        ko: '휴대전화 번호 형식이 올바르지 않습니다.',
      ));
      return;
    }

    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;

    setState(() => sendingCode = true);
    try {
      await AuthApi.instance.sendSms(
        phone: _e164Phone,
        scene: 'PAY_PIN_RESET',
        phoneCountry: _phoneCountryIso,
      );
      if (!mounted) return;
      _startCodeCooldown();
      _toast(AppI18n.current.t(
        zhHans: '验证码已发送',
        zhHant: '驗證碼已發送',
        en: 'Verification code sent.',
        ja: '認証コードを送信しました。',
        ko: '인증 코드가 전송되었습니다.',
      ));
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => sendingCode = false);
    }
  }

  void _startCodeCooldown() {
    codeCooldownTimer?.cancel();
    setState(() => codeCooldown = 60);
    codeCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (codeCooldown > 0) {
          codeCooldown--;
        }
        if (codeCooldown == 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submit() async {
    if (submitting) return;
    final code = codeController.text.trim();
    final pin = pinController.text.trim();
    final confirm = confirmPinController.text.trim();

    if (code.length != 6) {
      _toast(AppI18n.current.t(
        zhHans: '请输入 6 位验证码',
        zhHant: '請輸入 6 位驗證碼',
        en: 'Enter the 6-digit verification code.',
        ja: '6桁の認証コードを入力してください。',
        ko: '6자리 인증 코드를 입력해 주세요.',
      ));
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      _toast(AppI18n.current.t(
        zhHans: '请输入 6 位新支付密码',
        zhHant: '請輸入 6 位新支付密碼',
        en: 'Enter a new 6-digit payment password.',
        ja: '新しい6桁の支払いパスワードを入力してください。',
        ko: '새 6자리 결제 비밀번호를 입력해 주세요.',
      ));
      return;
    }
    if (pin != confirm) {
      _toast(AppI18n.current.t(
        zhHans: '两次输入的支付密码不一致',
        zhHant: '兩次輸入的支付密碼不一致',
        en: 'The two payment passwords do not match.',
        ja: '入力した支払いパスワードが一致しません。',
        ko: '입력한 결제 비밀번호가 서로 일치하지 않습니다.',
      ));
      return;
    }

    setState(() => submitting = true);
    try {
      await SettingsApi.instance.resetTradePassword(
        smsCode: code,
        payPin: pin,
      );
      if (!mounted) return;
      await BiometricPayService.instance.disableAndClear();
      _toast(AppI18n.current.t(
        zhHans: '重置成功',
        zhHant: '重設成功',
        en: 'Reset successfully.',
        ja: '再設定しました。',
        ko: '재설정되었습니다.',
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
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
          case 'SMS_CODE_INVALID':
            return AppI18n.current.t(
              zhHans: '验证码错误或已过期',
              zhHant: '驗證碼錯誤或已過期',
              en: 'The verification code is invalid or has expired.',
              ja: '認証コードが正しくないか、有効期限が切れています。',
              ko: '인증 코드가 올바르지 않거나 만료되었습니다.',
            );
          case 'INVALID_PAY_PIN':
            return AppI18n.current.t(
              zhHans: '支付密码需为 6 位数字',
              zhHant: '支付密碼需為 6 位數字',
              en: 'Your payment password must be 6 digits.',
              ja: '支払いパスワードは6桁の数字で入力してください。',
              ko: '결제 비밀번호는 6자리 숫자여야 합니다.',
            );
          case 'ACCOUNT_DISABLED':
            return AppI18n.current.t(
              zhHans: '账号已禁用',
              zhHant: '帳號已停用',
              en: 'This account has been disabled.',
              ja: 'このアカウントは無効になっています。',
              ko: '이 계정은 비활성화되었습니다.',
            );
        }
        if (message.isNotEmpty) {
          return DioErrorMessage.sanitizeUserText(
            message,
            fallback: AppI18n.current.t(
              zhHans: '操作失败，请稍后重试',
              zhHant: '操作失敗，請稍後再試',
              en: 'The operation failed. Please try again later.',
              ja: '操作に失敗しました。しばらくしてからもう一度お試しください。',
              ko: '작업에 실패했습니다. 잠시 후 다시 시도해 주세요.',
            ),
          );
        }
      }
    }
    return AppI18n.current.t(
      zhHans: '操作失败，请稍后重试',
      zhHant: '操作失敗，請稍後再試',
      en: 'The operation failed. Please try again later.',
      ja: '操作に失敗しました。しばらくしてからもう一度お試しください。',
      ko: '작업에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  Widget _phoneCountryPicker() {
    final dark = settingsIsDark(context);
    return SizedBox(
      height: 52,
      child: TextButtonTheme(
        data: TextButtonThemeData(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        child: CountryListPick(
          initialSelection: _countryCode,
          pickerBuilder: (context, countryCode) {
            final dialCode = countryCode?.dialCode ?? _countryCode;
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dialCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.subText(dark: dark),
                  ),
                ],
              ),
            );
          },
          theme: CountryTheme(
            isShowFlag: false,
            isShowTitle: false,
            isShowCode: true,
            isDownIcon: true,
            showEnglishName: false,
          ),
          onChanged: (CountryCode? code) {
            if (code?.dialCode == null) return;
            setState(() {
              _countryCode = code!.dialCode!;
              _phoneCountryIso = code.code?.trim().isNotEmpty == true
                  ? code.code!.toUpperCase()
                  : PhoneFormat.isoCountryFromDialCode(_countryCode);
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '重置支付密码',
        zhHant: '重設支付密碼',
        en: 'Reset Payment Password',
        ja: '支払いパスワードを再設定',
        ko: '결제 비밀번호 재설정',
      ),
      children: [
        if (_guardChecking)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              i18n.t(
                zhHans: '验证绑定手机号后，重新设置新的 6 位数字支付密码。',
                zhHant: '驗證綁定手機號後，重新設定新的 6 位數字支付密碼。',
                en: 'Verify your bound phone number, then set a new 6-digit payment password.',
                ja: '連携済みの電話番号を確認した後、新しい6桁の支払いパスワードを設定してください。',
                ko: '연결된 휴대전화 번호를 인증한 뒤 새 6자리 결제 비밀번호를 설정하세요.',
              ),
              style: TextStyle(
                color: helperColor,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          SettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              SettingsInputCell(
                label: i18n.t(
                  zhHans: '绑定手机',
                  zhHant: '綁定手機',
                  en: 'Bound Phone',
                  ja: '連携済み電話番号',
                  ko: '연결된 휴대전화',
                ),
                hint: i18n.t(
                  zhHans: '请输入绑定手机号',
                  zhHant: '請輸入綁定手機號',
                  en: 'Enter bound phone number',
                  ja: '連携済みの電話番号を入力',
                  ko: '연결된 휴대전화 번호를 입력해 주세요',
                ),
                keyboardType: TextInputType.phone,
                controller: phoneController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                leading: _phoneCountryPicker(),
                leadingWidth: 96,
              ),
              _ResetCodeInputRow(
                label: i18n.t(
                  zhHans: '验证码',
                  zhHant: '驗證碼',
                  en: 'Code',
                  ja: '認証コード',
                  ko: '인증 코드',
                ),
                hint: i18n.t(
                  zhHans: '请输入验证码',
                  zhHant: '請輸入驗證碼',
                  en: 'Enter verification code',
                  ja: '認証コードを入力',
                  ko: '인증 코드를 입력해 주세요',
                ),
                controller: codeController,
                buttonText: codeCooldown > 0
                    ? '${codeCooldown}s'
                    : sendingCode
                        ? i18n.t(
                            zhHans: '发送中...',
                            zhHant: '發送中...',
                            en: 'Sending...',
                            ja: '送信中...',
                            ko: '전송 중...',
                          )
                        : i18n.t(
                            zhHans: '获取验证码',
                            zhHant: '獲取驗證碼',
                            en: 'Get Code',
                            ja: 'コードを取得',
                            ko: '인증코드 받기',
                          ),
                onPressed: sendingCode || codeCooldown > 0 ? null : _sendCode,
              ),
              _PinInputCell(
                label: i18n.t(
                  zhHans: '新密码',
                  zhHant: '新密碼',
                  en: 'New Password',
                  ja: '新しいパスワード',
                  ko: '새 비밀번호',
                ),
                hint: i18n.t(
                  zhHans: '请输入新的 6 位支付密码',
                  zhHant: '請輸入新的 6 位支付密碼',
                  en: 'Enter a new 6-digit payment password',
                  ja: '新しい6桁の支払いパスワードを入力',
                  ko: '새 6자리 결제 비밀번호를 입력해 주세요',
                ),
                controller: pinController,
              ),
              _PinInputCell(
                label: i18n.t(
                  zhHans: '确认密码',
                  zhHant: '確認密碼',
                  en: 'Confirm Password',
                  ja: 'パスワードを確認',
                  ko: '비밀번호 확인',
                ),
                hint: i18n.t(
                  zhHans: '请再次输入支付密码',
                  zhHant: '請再次輸入支付密碼',
                  en: 'Enter the payment password again',
                  ja: '支払いパスワードをもう一度入力',
                  ko: '결제 비밀번호를 다시 입력해 주세요',
                ),
                controller: confirmPinController,
                showDivider: false,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _submit,
                child: Text(
                  submitting
                      ? i18n.t(
                          zhHans: '提交中...',
                          zhHant: '提交中...',
                          en: 'Submitting...',
                          ja: '送信中...',
                          ko: '제출 중...',
                        )
                      : i18n.t(
                          zhHans: '完成',
                          zhHant: '完成',
                          en: 'Done',
                          ja: '完了',
                          ko: '완료',
                        ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PinInputCell extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final bool showDivider;
  final VoidCallback? onToggleObscure;

  const _PinInputCell({
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = true,
    this.showDivider = true,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: AppColors.line(dark: dark),
                  width: 0.7,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              cursorColor: AppColors.primaryBlue,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                filled: false,
                isCollapsed: true,
                hintStyle: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 16,
                ),
              ),
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
          if (onToggleObscure != null)
            IconButton(
              onPressed: onToggleObscure,
              splashRadius: 18,
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.subText(dark: dark),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResetCodeInputRow extends StatelessWidget {
  final String label;
  final String hint;
  final String buttonText;
  final TextEditingController controller;
  final VoidCallback? onPressed;

  const _ResetCodeInputRow({
    required this.label,
    required this.hint,
    required this.buttonText,
    required this.controller,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.line(dark: dark),
            width: 0.7,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              cursorColor: AppColors.primaryBlue,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                filled: false,
                isCollapsed: true,
              ),
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: Text(
              buttonText,
              style: TextStyle(
                fontSize: 15,
                color: onPressed == null
                    ? AppColors.subText(dark: dark)
                    : AppColors.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
