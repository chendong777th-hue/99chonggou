import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/security/slider_captcha.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_credential_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/phone_binding_guard.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldPasswordController = TextEditingController();
  final smsCodeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loadingPhone = true;
  bool _guardChecking = true;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  bool? _phoneBound;
  String _boundPhone = '';
  String _boundPhoneMasked = '';

  static final RegExp _passwordPattern =
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');

  AuthLocalizations get _strings => AuthLocalizations.of(context);

  bool get _isPhoneBound => _phoneBound == true;

  bool get _confirmPasswordTouched => confirmPasswordController.text.isNotEmpty;

  bool get _confirmPasswordMismatch =>
      _confirmPasswordTouched &&
      confirmPasswordController.text != newPasswordController.text;

  bool get _canSubmit {
    if (_busy || _phoneBound == null) return false;
    if (!_passwordPattern.hasMatch(newPasswordController.text)) return false;
    if (confirmPasswordController.text != newPasswordController.text) {
      return false;
    }
    if (_isPhoneBound) {
      return _boundPhone.isNotEmpty &&
          smsCodeController.text.trim().length == 6;
    }
    return oldPasswordController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    oldPasswordController.addListener(_refresh);
    smsCodeController.addListener(_refresh);
    newPasswordController.addListener(_refresh);
    confirmPasswordController.addListener(_refresh);
    _initialize();
  }

  @override
  void dispose() {
    oldPasswordController.removeListener(_refresh);
    smsCodeController.removeListener(_refresh);
    newPasswordController.removeListener(_refresh);
    confirmPasswordController.removeListener(_refresh);
    _cooldownTimer?.cancel();
    oldPasswordController.dispose();
    smsCodeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initialize() async {
    try {
      final me = await AuthApi.instance.fetchMe();
      if (!mounted) return;
      final bound = PhoneBindingGuard.isBound(me);
      setState(() {
        _phoneBound = bound;
        _guardChecking = false;
      });
      if (bound) {
        await _loadBoundPhone(me);
      } else {
        setState(() => _loadingPhone = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phoneBound = false;
        _guardChecking = false;
        _loadingPhone = false;
      });
    }
  }

  Future<void> _loadBoundPhone([MeResult? me]) async {
    try {
      final profile = me ?? await AuthApi.instance.fetchMe();
      if (!mounted) return;
      setState(() {
        _boundPhone = profile.phone.trim();
        _boundPhoneMasked = profile.phoneMasked.trim().isEmpty
            ? profile.phone
            : profile.phoneMasked.trim();
        _loadingPhone = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPhone = false;
        _boundPhoneMasked = AppI18n.current.t(
          zhHans: '未获取',
          zhHant: '未取得',
          en: 'Unavailable',
          ja: '取得できません',
          ko: '가져올 수 없음',
        );
      });
    }
  }

  Future<void> _sendCode() async {
    if (_busy || _cooldown > 0 || _boundPhone.isEmpty) return;
    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AuthApi.instance.sendSms(phone: _boundPhone, scene: 'RESET');
      ToastUtils.toast(_strings.codeSentSuccess);
      setState(() => _cooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_cooldown > 0) {
            _cooldown--;
          }
          if (_cooldown == 0) {
            timer.cancel();
          }
        });
      });
    } on DioError catch (e) {
      ToastUtils.toast(DioErrorMessage.fromAuth(e, _strings));
    } catch (e) {
      ToastUtils.toast(DioErrorMessage.fromThrowable(e, _strings));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _passwordChangeErrorText(DioError e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString() ?? '';
      switch (code) {
        case 'BAD_OLD_PASSWORD':
          return AppI18n.current.t(
            zhHans: '旧密码错误',
            zhHant: '舊密碼錯誤',
            en: 'The current password is incorrect.',
            ja: '現在のパスワードが正しくありません。',
            ko: '현재 비밀번호가 올바르지 않습니다.',
          );
        case 'SAME_PASSWORD':
          return AppI18n.current.t(
            zhHans: '新密码不能与旧密码相同',
            zhHant: '新密碼不能與舊密碼相同',
            en: 'The new password must be different from the current one.',
            ja: '新しいパスワードは現在のパスワードと異なる必要があります。',
            ko: '새 비밀번호는 현재 비밀번호와 달라야 합니다.',
          );
        case 'PHONE_ALREADY_BOUND':
          return AppI18n.current.t(
            zhHans: '账号已绑定手机，请使用短信验证码修改密码',
            zhHant: '帳號已綁定手機，請使用簡訊驗證碼修改密碼',
            en: 'This account has a bound phone number. Please reset your password with SMS verification.',
            ja: 'このアカウントは電話番号が連携済みです。SMS認証でパスワードを変更してください。',
            ko: '이 계정은 휴대전화 번호가 등록되어 있습니다. 문자 인증으로 비밀번호를 변경해 주세요.',
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
    }
    return DioErrorMessage.fromAuth(e, _strings);
  }

  Future<void> _submit() async {
    if (_busy || _phoneBound == null) return;
    if (!_passwordPattern.hasMatch(newPasswordController.text)) {
      ToastUtils.toast(_strings.passwordRule);
      return;
    }
    if (confirmPasswordController.text != newPasswordController.text) {
      ToastUtils.toast(_strings.passwordMismatch);
      return;
    }

    setState(() => _busy = true);
    try {
      if (_isPhoneBound) {
        if (_boundPhone.isEmpty) {
          ToastUtils.toast(AppI18n.current.t(
            zhHans: '未获取到绑定手机号',
            zhHant: '未取得綁定手機號',
            en: 'No bound phone number was found.',
            ja: '連携済みの電話番号を取得できませんでした。',
            ko: '연결된 휴대전화 번호를 가져오지 못했습니다.',
          ));
          return;
        }
        if (smsCodeController.text.trim().length != 6) {
          ToastUtils.toast(_strings.smsCodeMust6);
          return;
        }
        final tokenResult = await AuthApi.instance.resetPassword(
          phone: _boundPhone,
          smsCode: smsCodeController.text.trim(),
          password: newPasswordController.text,
        );
        await ApiClient.instance.saveToken(tokenResult.token);
      } else {
        if (oldPasswordController.text.isEmpty) {
          ToastUtils.toast(AppI18n.current.t(
            zhHans: '请输入旧密码',
            zhHant: '請輸入舊密碼',
            en: 'Enter your current password.',
            ja: '現在のパスワードを入力してください。',
            ko: '현재 비밀번호를 입력해 주세요.',
          ));
          return;
        }
        final tokenResult = await AuthApi.instance.changePassword(
          oldPassword: oldPasswordController.text,
          newPassword: newPasswordController.text,
        );
        await ApiClient.instance.saveToken(tokenResult.token);
      }
      await LoginCredentialStore.instance.updateSavedPasswordIfRemembered(
        newPasswordController.text,
      );
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '登录密码修改成功',
        zhHant: '登入密碼修改成功',
        en: 'Password changed successfully.',
        ja: 'ログインパスワードを変更しました。',
        ko: '로그인 비밀번호가 변경되었습니다.',
      ));
      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } on DioError catch (e) {
      ToastUtils.toast(
        _isPhoneBound
            ? DioErrorMessage.fromAuth(e, _strings)
            : _passwordChangeErrorText(e),
      );
    } catch (e) {
      ToastUtils.toast(DioErrorMessage.fromThrowable(e, _strings));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);
    final strings = _strings;
    final isPhoneBound = _isPhoneBound;

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '修改密码',
        zhHant: '修改密碼',
        en: 'Change Password',
        ja: 'パスワードを変更',
        ko: '비밀번호 변경',
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
              isPhoneBound
                  ? i18n.t(
                      zhHans: '通过短信验证码验证身份后，设置新的登录密码。',
                      zhHant: '完成簡訊驗證後，可設定新的登入密碼。',
                      en: 'Verify your identity with an SMS code, then set a new login password.',
                      ja: 'SMS認証で本人確認を行った後、新しいログインパスワードを設定してください。',
                      ko: '문자 인증으로 본인 확인을 완료한 뒤 새 로그인 비밀번호를 설정하세요.',
                    )
                  : i18n.t(
                      zhHans: '请输入旧密码和新密码，完成登录密码修改。',
                      zhHant: '請輸入舊密碼和新密碼，完成登入密碼修改。',
                      en: 'Enter your current password and a new password to update your login password.',
                      ja: '現在のパスワードと新しいパスワードを入力して、ログインパスワードを変更してください。',
                      ko: '현재 비밀번호와 새 비밀번호를 입력해 로그인 비밀번호를 변경하세요.',
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
              if (isPhoneBound) ...[
                SettingsCell(
                  title: i18n.t(
                    zhHans: '绑定手机号',
                    zhHant: '綁定手機號',
                    en: 'Bound Phone Number',
                    ja: '連携済み電話番号',
                    ko: '연결된 휴대전화 번호',
                  ),
                  value: _boundPhoneMasked,
                  showArrow: false,
                ),
                _CodeInputRow(
                  label: strings.smsCodeLabel,
                  hint: strings.smsCodeHint,
                  controller: smsCodeController,
                  buttonText:
                      _cooldown > 0 ? '${_cooldown}s' : strings.getCode,
                  onPressed: (_busy ||
                          _cooldown > 0 ||
                          _loadingPhone ||
                          _boundPhone.isEmpty)
                      ? null
                      : _sendCode,
                ),
              ] else
                _PasswordInputRow(
                  label: i18n.t(
                    zhHans: '旧密码',
                    zhHant: '舊密碼',
                    en: 'Current Password',
                    ja: '現在のパスワード',
                    ko: '현재 비밀번호',
                  ),
                  hint: i18n.t(
                    zhHans: '请输入旧密码',
                    zhHant: '請輸入舊密碼',
                    en: 'Enter current password',
                    ja: '現在のパスワードを入力',
                    ko: '현재 비밀번호를 입력해 주세요',
                  ),
                  controller: oldPasswordController,
                  obscureText: _obscureOld,
                  onToggleObscure: () {
                    setState(() {
                      _obscureOld = !_obscureOld;
                    });
                  },
                ),
              _PasswordInputRow(
                label: strings.newPasswordLabel,
                hint: strings.passwordRule,
                controller: newPasswordController,
                obscureText: _obscureNew,
                onToggleObscure: () {
                  setState(() {
                    _obscureNew = !_obscureNew;
                  });
                },
              ),
              _PasswordInputRow(
                label: strings.confirmPasswordLabel,
                hint: strings.enterConfirmPassword,
                controller: confirmPasswordController,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _confirmPasswordMismatch
                ? Text(
                    strings.passwordMismatch,
                    style: const TextStyle(
                      color: AppTokens.danger,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  )
                : Text(
                    i18n.t(
                      zhHans: '新密码建议包含字母和数字组合。',
                      zhHant: '建議新密碼包含英文字母與數字。',
                      en: 'We recommend using a password that contains both letters and numbers.',
                      ja: '新しいパスワードには英字と数字の両方を含めることをおすすめします。',
                      ko: '새 비밀번호는 영문과 숫자를 함께 포함하는 것을 권장합니다.',
                    ),
                    style: TextStyle(
                      color: helperColor,
                      fontSize: 12,
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
                  foregroundColor:
                      _canSubmit ? Colors.white : AppColors.subText(dark: dark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _canSubmit ? _submit : null,
                child: Text(
                  _busy
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

class _CodeInputRow extends StatelessWidget {
  final String label;
  final String hint;
  final String buttonText;
  final TextEditingController controller;
  final VoidCallback? onPressed;

  const _CodeInputRow({
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

class _PasswordInputRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final bool showDivider;
  final VoidCallback onToggleObscure;

  const _PasswordInputRow({
    required this.label,
    required this.hint,
    required this.controller,
    required this.obscureText,
    required this.onToggleObscure,
    this.showDivider = true,
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
