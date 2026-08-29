// ignore_for_file: avoid_print

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_list_pick.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_selection_theme.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_country.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/env.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/auth_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_credential_store.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/phone_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/security/slider_captcha.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  String _countryCode = AppEnv.defaultCountryCode;
  String _phoneCountryIso = AppEnv.defaultPhoneCountry;
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _busy = false;
  bool _obscure = true;
  bool _confirmObscure = true;
  String _displayVersion = IMDemoConfig.appVersion;

  static final RegExp _passwordPattern =
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$');

  AuthLocalizations get _strings => AuthLocalizations.of(context);

  bool get _isPhoneValid => PhoneFormat.isValidNationalNumber(
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
        nationalNumber: _phoneCtrl.text.trim(),
      );
  bool get _isSmsCodeComplete => _smsCtrl.text.trim().length == 6;
  bool get _canSubmit =>
      !_busy &&
      _isPhoneValid &&
      _isSmsCodeComplete &&
      _passwordPattern.hasMatch(_passwordCtrl.text) &&
      _confirmCtrl.text == _passwordCtrl.text;

  @override
  void initState() {
    super.initState();
    for (final c in [_phoneCtrl, _smsCtrl, _passwordCtrl, _confirmCtrl]) {
      c.addListener(_onInput);
    }
    AppVersion.getDisplayVersion().then((value) {
      if (!mounted) return;
      setState(() {
        _displayVersion = value;
      });
    });
  }

  void _onInput() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_phoneCtrl, _smsCtrl, _passwordCtrl, _confirmCtrl]) {
      c.removeListener(_onInput);
    }
    _cooldownTimer?.cancel();
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _e164Phone => PhoneFormat.e164(
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
        nationalNumber: _phoneCtrl.text.trim(),
      );

  String get _phoneInvalidText =>
      PhoneFormat.nationalNumberError(
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
        nationalNumber: _phoneCtrl.text.trim(),
      ) ??
      '请输入正确的手机号';

  Future<void> _sendCode() async {
    final strings = _strings;
    if (_cooldown > 0 || _busy) return;
    if (_phoneCtrl.text.trim().isEmpty)
      return ToastUtils.toast(strings.enterPhone);
    if (!_isPhoneValid) return ToastUtils.toast(_phoneInvalidText);
    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AuthApi.instance.sendSms(
        phone: _e164Phone,
        scene: 'RESET',
        phoneCountry: _phoneCountryIso,
      );
      ToastUtils.toast(strings.codeSentSuccess);
      setState(() => _cooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          if (_cooldown > 0) _cooldown--;
          if (_cooldown == 0) t.cancel();
        });
      });
    } on DioError catch (e) {
      ToastUtils.toast(_dioMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final strings = _strings;
    if (_busy) return;
    if (!_isPhoneValid) return ToastUtils.toast(_phoneInvalidText);
    if (!_isSmsCodeComplete) return ToastUtils.toast(strings.smsCodeMust6);
    if (!_passwordPattern.hasMatch(_passwordCtrl.text)) {
      return ToastUtils.toast(strings.passwordRule);
    }
    if (_confirmCtrl.text != _passwordCtrl.text) {
      return ToastUtils.toast(strings.passwordMismatch);
    }
    setState(() => _busy = true);
    try {
      final tr = await AuthApi.instance.resetPassword(
        phone: _e164Phone,
        smsCode: _smsCtrl.text.trim(),
        password: _passwordCtrl.text,
        phoneCountry: _phoneCountryIso,
      );
      // Reset-password returns a new authenticated session. Cross the same
      // account boundary as the normal login flow before installing it, so a
      // previous UIKit/native session cannot leak into the new account.
      await AuthSessionService.instance.beginLogin();
      await AuthSessionService.instance.applyTokenResult(tr);
      await LoginCredentialStore.instance.updateSavedPasswordIfRemembered(
        _passwordCtrl.text,
      );

      final sig =
          await AuthSessionService.instance.bootstrapAuthenticatedSession();
      final generation = SessionIdentityService.instance.generation;
      final imCode = await AuthBootstrapService.instance.loginImStack(
        sig,
        forceLogin: true,
        expectedSessionGeneration: generation,
      );
      if (imCode != 0) {
        ToastUtils.toast(strings.resetPasswordButImFailed);
        return;
      }
      if (!mounted) return;
      InitStep.directToHomePage(context);
    } on DioError catch (e) {
      ToastUtils.toast(_dioMsg(e));
    } catch (e) {
      ToastUtils.toast(DioErrorMessage.fromThrowable(e, _strings));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dioMsg(DioError e) => DioErrorMessage.fromAuth(e, _strings);

  String _mapCode(String code) {
    final strings = _strings;
    switch (code) {
      case 'USER_NOT_FOUND':
        return strings.unregisteredPhone;
      case 'INVALID_PHONE':
        return strings.invalidPhone;
      case 'SMS_CODE_INVALID':
        return strings.smsCodeInvalid;
      case 'ACCOUNT_DISABLED':
        return strings.accountDisabled;
      case 'RATE_LIMITED':
        return strings.rateLimited;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return AuthLightScope(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: authImmersiveOverlayStyle,
        child: Scaffold(
          backgroundColor: AppTokens.brand600,
          extendBodyBehindAppBar: true,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: AuthEntryScaffold(
              greeting: strings.hello,
              accent: strings.findPassword,
              onBack: () => Navigator.maybePop(context),
              headerAction: const AuthCustomerServiceButton(),
              footer: _buildVersionText(),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildForm(),
              ),
            ),
          ),
          resizeToAvoidBottomInset: false,
        ),
      ),
    );
  }

  Widget _buildVersionText() {
    return Center(
      child: Text(
        'Version $_displayVersion',
        style: AppTokens.caption.copyWith(
          fontSize: 13,
          color: AppTokens.ink400,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildForm() {
    final strings = _strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthFieldLabel(strings.phoneLabel),
        AuthCompoundField(
          controller: _phoneCtrl,
          hint: strings.enterPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 15,
          onChanged: (_) => _onInput(),
          leading: _countryPicker(),
          leadingWidth: 102,
        ),
        const SizedBox(height: 22),
        AuthCompoundField(
          controller: _smsCtrl,
          hint: strings.smsCodeHint,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          onChanged: (_) => _onInput(),
          trailing: _sendCodeAction(),
          trailingWidth: 122,
        ),
        const SizedBox(height: 22),
        AuthTextField(
          controller: _passwordCtrl,
          hint: strings.enterPasswordRule,
          obscureText: _obscure,
          onChanged: (_) => _onInput(),
          suffix: GestureDetector(
            onTap: () => setState(() => _obscure = !_obscure),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppTokens.ink300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        AuthTextField(
          controller: _confirmCtrl,
          hint: strings.enterPasswordAgain,
          obscureText: _confirmObscure,
          onChanged: (_) => _onInput(),
          suffix: GestureDetector(
            onTap: () => setState(() => _confirmObscure = !_confirmObscure),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                _confirmObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppTokens.ink300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          text: strings.resetPasswordButton,
          loading: _busy,
          pill: true,
          onPressed: _canSubmit ? _resetPassword : null,
        ),
      ],
    );
  }

  Widget _countryPicker() {
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
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  countryCode?.dialCode ?? _countryCode,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.brand500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: AppTokens.ink400,
                ),
              ],
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
            if (code?.dialCode != null) {
              setState(() {
                _countryCode = code!.dialCode!;
                _phoneCountryIso = code.code?.trim().isNotEmpty == true
                    ? code.code!.toUpperCase()
                    : PhoneFormat.isoCountryFromDialCode(_countryCode);
              });
            }
          },
        ),
      ),
    );
  }

  Widget _sendCodeAction() {
    final strings = _strings;
    final enabled = _cooldown == 0 && !_busy;
    return GestureDetector(
      onTap: enabled ? _sendCode : null,
      child: Container(
        alignment: Alignment.center,
        child: Text(
          _cooldown > 0 ? '${_cooldown}s' : strings.getCode,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTokens.brand500 : AppTokens.ink300,
          ),
        ),
      ),
    );
  }
}
