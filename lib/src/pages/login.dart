// ignore_for_file: avoid_print

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_list_pick.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/country_selection_theme.dart';
import 'package:tencent_cloud_chat_demo/country_list_pick-1.0.1+5/lib/support/code_country.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/auth_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/env.dart';
import 'package:tencent_cloud_chat_demo/src/pages/forgot_password.dart';
import 'package:tencent_cloud_chat_demo/src/pages/privacy/user_agreement_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/language_switch_sheet.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/node_switch_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_credential_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/utils/launch_system_ui.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/ui/auth_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/phone_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tencent_cloud_chat_demo/src/security/slider_captcha.dart';

class LoginPage extends StatelessWidget {
  final Future<void> Function()? initIMSDK;
  final int initialTab;
  const LoginPage({Key? key, this.initIMSDK, this.initialTab = 0})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AuthLightScope(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: authImmersiveOverlayStyle,
        child: Scaffold(
          backgroundColor: AppTokens.brand600,
          extendBodyBehindAppBar: true,
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _LoginBody(initIMSDK: initIMSDK, initialTab: initialTab),
          ),
          // 登录页内部自己处理键盘安全区，避免 Android 键盘顶起固定头部后出现黄黑溢出条。
          resizeToAvoidBottomInset: false,
        ),
      ),
    );
  }
}

class _LoginBody extends StatefulWidget {
  final Future<void> Function()? initIMSDK;
  final int initialTab;
  const _LoginBody({Key? key, this.initIMSDK, this.initialTab = 0})
      : super(key: key);
  @override
  State<_LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<_LoginBody> {
  bool _busy = false;
  bool _isSmsMode = false;

  /// Web only: mutually exclusive with password/SMS forms.
  bool _isQrMode = false;
  int _activeTab = 0;
  PageController? _pageController;

  String _countryCode = AppEnv.defaultCountryCode;
  String _phoneCountryIso = AppEnv.defaultPhoneCountry;
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  int _cooldown = 0;
  Timer? _cooldownTimer;

  Timer? _qrPollTimer;
  String? _qrSessionId;
  String? _qrPayload;
  String _qrStatus =
      'idle'; // idle|loading|pending|scanned|cancelled|expired|error
  String? _qrErrorMessage;
  DateTime? _qrExpiresAt;
  int _qrRequestGeneration = 0;

  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _loginPhoneFocusNode = FocusNode();
  final _loginSmsFocusNode = FocusNode();
  final _accountFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _registerPhoneFocusNode = FocusNode();
  final _registerSmsFocusNode = FocusNode();
  final _nicknameFocusNode = FocusNode();
  final _registerPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _obscure = true;
  bool _rememberPassword = true;
  final List<VoidCallback> _focusScrollDisposers = [];
  final _nicknameCtrl = TextEditingController();
  final _registerPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _registerObscure = true;
  bool _confirmRegisterObscure = true;
  Timer? _registerNicknameCheckTimer;
  int _registerNicknameCheckSeq = 0;
  String _lastRegisterNicknameInput = '';
  bool _registerNicknameChecking = false;
  bool? _registerNicknameAvailable;
  String? _registerNicknameError;
  String? _registerNicknameHint;
  String _displayVersion = IMDemoConfig.appVersion;
  Future<void>? _initImSdkTask;

  AuthLocalizations get _strings => AuthLocalizations.of(context);

  /// 仅 Web 客户端展示/使用「扫码登录」；iOS/Android 等移动端永不进入该模式。
  bool get _supportsWebQrLogin => kIsWeb;

  bool get _registerPasswordHasMinLength =>
      _registerPasswordCtrl.text.length >= 8;
  bool get _registerPasswordHasLetter =>
      RegExp(r'[A-Za-z]').hasMatch(_registerPasswordCtrl.text);
  bool get _registerPasswordHasDigit =>
      RegExp(r'\d').hasMatch(_registerPasswordCtrl.text);
  bool get _registerPasswordOk =>
      _registerPasswordHasMinLength &&
      _registerPasswordHasLetter &&
      _registerPasswordHasDigit;
  bool get _confirmPasswordTouched => _confirmPasswordCtrl.text.isNotEmpty;
  bool get _confirmPasswordOk =>
      _confirmPasswordCtrl.text.isNotEmpty &&
      _confirmPasswordCtrl.text == _registerPasswordCtrl.text;

  String _normalizeAccount(String raw) {
    return raw.replaceFirst(RegExp(r'^@+'), '');
  }

  bool get _isPhoneValid => PhoneFormat.isValidNationalNumber(
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
        nationalNumber: _phoneCtrl.text.trim(),
      );
  bool get _isSmsCodeComplete => _smsCtrl.text.trim().length == 6;
  bool get _canSubmitSms => !_busy && _isPhoneValid && _isSmsCodeComplete;
  bool get _canSubmitPassword =>
      !_busy &&
      _normalizeAccount(_accountCtrl.text).trim().isNotEmpty &&
      _passwordCtrl.text.length >= 8;
  bool get _canSubmitRegister =>
      !_busy &&
      _isPhoneValid &&
      _isSmsCodeComplete &&
      _isRegisterNicknameReady &&
      _registerPasswordOk &&
      _confirmPasswordOk;

  bool get _isRegisterNicknameReady {
    final nickname = _nicknameCtrl.text.trim();
    return nickname.length >= 2 &&
        _registerNicknameAvailable == true &&
        !_registerNicknameChecking &&
        (_registerNicknameError == null || _registerNicknameError!.isEmpty);
  }

  @override
  void initState() {
    super.initState();
    AuthSessionService.instance.enterAuthFlow();
    _activeTab = widget.initialTab;
    // 仅 Web 登录 Tab 默认扫码；移动端保持账密/短信。
    if (_supportsWebQrLogin && widget.initialTab == 0) {
      _isQrMode = true;
    } else {
      _isQrMode = false;
    }
    _pageController = PageController(initialPage: widget.initialTab);
    for (final controller in [
      _phoneCtrl,
      _smsCtrl,
      _passwordCtrl,
      _registerPasswordCtrl,
      _confirmPasswordCtrl,
    ]) {
      controller.addListener(_handleInputChanged);
    }
    _nicknameCtrl.addListener(_handleNicknameChanged);
    _accountCtrl.addListener(_handleInputChanged);
    if (widget.initIMSDK != null && !AuthBootstrapService.imSdkInitialized) {
      _initImSdkTask = widget.initIMSDK!();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<LocalSetting>(context, listen: false).connectStatus =
          ConnectStatus.success;
      // 进入登录/注册页不自动弹键盘，等用户主动点输入框。
      if (_supportsWebQrLogin && _isQrMode) {
        unawaited(_startQrLoginSession());
      }
    });
    _bindFocusScrollListeners();
    _loadSavedCredentials();
    AppVersion.getDisplayVersion().then((value) {
      if (!mounted) return;
      setState(() {
        _displayVersion = value;
      });
    });
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  void _bindFocusScrollListeners() {
    for (final node in [
      _loginPhoneFocusNode,
      _loginSmsFocusNode,
      _accountFocusNode,
      _passwordFocusNode,
      _registerPhoneFocusNode,
      _registerSmsFocusNode,
      _nicknameFocusNode,
      _registerPasswordFocusNode,
      _confirmPasswordFocusNode,
    ]) {
      void listener() {
        if (node.hasFocus) {
          _scrollFieldIntoView(node);
        }
      }

      node.addListener(listener);
      _focusScrollDisposers.add(() => node.removeListener(listener));
    }
  }

  void _requestPrimaryFieldFocus() {
    if (_supportsWebQrLogin && _isQrMode && _activeTab == 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_supportsWebQrLogin && _isQrMode && _activeTab == 0) {
        return;
      }
      final target = _activeTab == 1
          ? _registerPhoneFocusNode
          : (_isSmsMode ? _loginPhoneFocusNode : _accountFocusNode);
      _focusField(target);
    });
  }

  /// Web：登录 Tab 默认扫码；离开登录 Tab 停轮询。移动端强制关闭扫码态。
  void _syncWebLoginTabMode(int tabIndex) {
    if (!_supportsWebQrLogin) {
      _stopQrLoginPolling();
      _isQrMode = false;
      return;
    }
    if (tabIndex != 0) {
      _stopQrLoginPolling();
      _isQrMode = false;
      return;
    }
    _isSmsMode = false;
    _isQrMode = true;
  }

  void _afterWebLoginTabModeSynced(int tabIndex) {
    if (_supportsWebQrLogin && tabIndex == 0 && _isQrMode) {
      unawaited(_startQrLoginSession());
    }
    // 切换登录/注册 Tab 时也不自动抢焦点弹键盘。
  }

  void _focusField(FocusNode node) {
    if (!node.canRequestFocus) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus) {
        return;
      }
      FocusScope.of(context).requestFocus(node);
      _scrollFieldIntoView(node);
    });
  }

  void _scrollFieldIntoView(FocusNode node, {bool retry = true}) {
    void ensure() {
      if (!mounted || !node.hasFocus) {
        return;
      }
      final fieldContext = node.context;
      if (fieldContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.35,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ensure();
      if (retry) {
        Future<void>.delayed(const Duration(milliseconds: 320), () {
          if (mounted && node.hasFocus) {
            ensure();
          }
        });
      }
    });
  }

  void _finishField({VoidCallback? submit}) {
    FocusScope.of(context).unfocus();
    submit?.call();
  }

  void _handleNicknameChanged() {
    _maybeScheduleRegisterNicknameCheck();
    if (mounted) setState(() {});
  }

  void _maybeScheduleRegisterNicknameCheck({bool immediate = false}) {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname == _lastRegisterNicknameInput && !immediate) {
      return;
    }
    _lastRegisterNicknameInput = nickname;
    _registerNicknameCheckTimer?.cancel();

    if (nickname.isEmpty) {
      _registerNicknameCheckSeq++;
      if (mounted) {
        setState(() {
          _registerNicknameChecking = false;
          _registerNicknameAvailable = null;
          _registerNicknameError = null;
          _registerNicknameHint = null;
        });
      }
      return;
    }

    if (nickname.length < 2) {
      _registerNicknameCheckSeq++;
      if (mounted) {
        setState(() {
          _registerNicknameChecking = false;
          _registerNicknameAvailable = false;
          _registerNicknameError = _strings.nicknameMin2;
          _registerNicknameHint = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _registerNicknameChecking = true;
        _registerNicknameAvailable = null;
        _registerNicknameError = null;
        _registerNicknameHint = '校验中...';
      });
    }

    final seq = ++_registerNicknameCheckSeq;
    final delay = immediate ? Duration.zero : const Duration(milliseconds: 300);
    _registerNicknameCheckTimer = Timer(delay, () {
      _checkRegisterNickname(seq, nickname);
    });
  }

  Future<void> _checkRegisterNickname(int seq, String nickname) async {
    try {
      final result = await UserApi.instance.checkNicknameForRegister(nickname);
      if (!mounted || seq != _registerNicknameCheckSeq) return;
      final reasonMessage = UserApiErrorMessage.fromNicknameCheck(
        reason: result.reason,
        nextChangeableAt: result.nextChangeableAt,
      );
      setState(() {
        _registerNicknameChecking = false;
        _registerNicknameHint = null;
        _registerNicknameAvailable = result.available;
        _registerNicknameError = result.available
            ? null
            : (reasonMessage.isNotEmpty ? reasonMessage : '用户名已存在');
      });
    } on DioError catch (e) {
      if (!mounted || seq != _registerNicknameCheckSeq) return;
      final message = _isRegisterNicknameCheckAuthNoise(
              UserApiErrorMessage.fromNicknameCheckRequest(e))
          ? '用户名校验暂不可用'
          : UserApiErrorMessage.fromNicknameCheckRequest(e);
      setState(() {
        _registerNicknameChecking = false;
        _registerNicknameHint = null;
        _registerNicknameAvailable = false;
        _registerNicknameError = message;
      });
    } catch (_) {
      if (!mounted || seq != _registerNicknameCheckSeq) return;
      setState(() {
        _registerNicknameChecking = false;
        _registerNicknameHint = null;
        _registerNicknameAvailable = false;
        _registerNicknameError = '用户名校验失败，请稍后再试';
      });
    }
  }

  bool _isRegisterNicknameCheckAuthNoise(String message) {
    final text = message.trim().toLowerCase();
    return text.contains('验证已过期') ||
        text.contains('登录已失效') ||
        text.contains('重新登录') ||
        text.contains('invalid or expired token') ||
        ((text.contains('invalid') || text.contains('expired')) &&
            text.contains('token'));
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await LoginCredentialStore.instance.load();
    if (!mounted) return;
    if (saved.account != null && saved.account!.isNotEmpty) {
      _accountCtrl.text = saved.account!;
    }
    if (saved.phone != null && saved.phone!.isNotEmpty) {
      _phoneCtrl.text = saved.phone!;
    }
    if (saved.countryCode != null && saved.countryCode!.isNotEmpty) {
      _countryCode = saved.countryCode!;
    }
    if (saved.countryIso != null && saved.countryIso!.isNotEmpty) {
      _phoneCountryIso = saved.countryIso!.toUpperCase();
    } else if (saved.countryCode != null && saved.countryCode!.isNotEmpty) {
      _phoneCountryIso = PhoneFormat.isoCountryFromDialCode(_countryCode);
    }
    _rememberPassword = saved.rememberPassword;
    if (saved.password != null && saved.password!.isNotEmpty) {
      _passwordCtrl.text = saved.password!;
    }
    setState(() {});
  }

  @override
  void dispose() {
    AuthSessionService.instance.leaveAuthFlow();
    for (final controller in [
      _phoneCtrl,
      _smsCtrl,
      _accountCtrl,
      _passwordCtrl,
      _registerPasswordCtrl,
      _confirmPasswordCtrl,
    ]) {
      controller.removeListener(_handleInputChanged);
    }
    _nicknameCtrl.removeListener(_handleNicknameChanged);
    _cooldownTimer?.cancel();
    _qrPollTimer?.cancel();
    _registerNicknameCheckTimer?.cancel();
    for (final dispose in _focusScrollDisposers) {
      dispose();
    }
    _focusScrollDisposers.clear();
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    _registerPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _loginPhoneFocusNode.dispose();
    _loginSmsFocusNode.dispose();
    _accountFocusNode.dispose();
    _passwordFocusNode.dispose();
    _registerPhoneFocusNode.dispose();
    _registerSmsFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _registerPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _pageController?.dispose();
    super.dispose();
  }

  PageController get _safePageController {
    return _pageController ??= PageController(initialPage: _activeTab);
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

  Future<void> _sendLoginCode() async {
    final strings = _strings;
    if (_cooldown > 0 || _busy) return;
    if (_phoneCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterPhone);
    }
    if (!_isPhoneValid) {
      return ToastUtils.toast(_phoneInvalidText);
    }
    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AuthApi.instance.sendSms(
        phone: _e164Phone,
        scene: 'LOGIN',
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

  Future<void> _smsLogin() async {
    final strings = _strings;
    if (_busy) return;
    if (_phoneCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterPhone);
    }
    if (!_isPhoneValid) {
      return ToastUtils.toast(_phoneInvalidText);
    }
    if (_smsCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterSmsCode);
    }
    if (!_isSmsCodeComplete) {
      return ToastUtils.toast(strings.smsCodeMust6);
    }
    setState(() => _busy = true);
    try {
      await LoginCoordinator.instance.loginWithSmsCode(
        context: context,
        phoneE164: _e164Phone,
        phone: _phoneCtrl.text.trim(),
        smsCode: _smsCtrl.text.trim(),
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
      );
    } on LoginCoordinatorException catch (e) {
      ToastUtils.toast(
        DioErrorMessage.sanitizeUserText(
          e.message,
          fallback: _strings.requestFailed,
        ),
      );
    } catch (e) {
      final message = DioErrorMessage.fromThrowable(e, _strings);
      ToastUtils.toast(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _passwordLogin() async {
    final strings = _strings;
    final rawAccount = _accountCtrl.text.trim();
    final account = _normalizeAccount(rawAccount).trim();
    if (_busy) return;
    if (account.isEmpty) {
      return ToastUtils.toast(strings.enterAccount);
    }
    if (_passwordCtrl.text.length < 8) {
      return ToastUtils.toast(strings.passwordMin8);
    }
    setState(() => _busy = true);
    try {
      final result = await LoginCoordinator.instance.loginWithPassword(
        context: context,
        rawAccount: rawAccount,
        account: account,
        password: _passwordCtrl.text,
        rememberPassword: _rememberPassword,
        phoneCountryIso: _phoneCountryIso,
        countryCode: _countryCode,
        phoneInput: _phoneCtrl.text.trim(),
      );
      if (!result.requiresDeviceChallenge) {
        return;
      }
      if (!mounted) return;
      final ok = await Navigator.push<bool>(
        context,
        AppMaterialPageRoute(
          builder: (_) => DeviceChallengePage(
            challengeId: result.challengeId!,
            phone: result.phone!,
            phoneMasked: result.phoneMasked ?? '',
          ),
        ),
      );
      if (ok == true) {
        await LoginCoordinator.instance
            .completePasswordLoginAfterDeviceChallenge(
          context: context,
          rawAccount: rawAccount,
          password: _passwordCtrl.text,
          rememberPassword: _rememberPassword,
          phoneCountryIso: _phoneCountryIso,
          countryCode: _countryCode,
          phoneInput: _phoneCtrl.text.trim(),
        );
      }
    } on LoginCoordinatorException catch (e) {
      ToastUtils.toast(
        DioErrorMessage.sanitizeUserText(
          e.message,
          fallback: _strings.requestFailed,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('password login error: $e');
      }
      ToastUtils.toast(DioErrorMessage.fromThrowable(e, _strings));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final strings = _strings;
    if (_busy) return;
    if (_phoneCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterPhone);
    }
    if (!_isPhoneValid) {
      return ToastUtils.toast(_phoneInvalidText);
    }
    if (_smsCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterSmsCode);
    }
    if (!_isSmsCodeComplete) {
      return ToastUtils.toast(strings.smsCodeMust6);
    }
    if (_nicknameCtrl.text.trim().length < 2) {
      setState(() {
        _registerNicknameAvailable = false;
        _registerNicknameError = strings.nicknameMin2;
        _registerNicknameHint = null;
      });
      return;
    }
    if (_registerNicknameChecking || _registerNicknameAvailable != true) {
      setState(() {
        _registerNicknameHint =
            _registerNicknameChecking ? _registerNicknameHint : null;
        _registerNicknameError ??= '请先输入可用用户名';
      });
      return;
    }
    if (!_registerPasswordOk) {
      return ToastUtils.toast(strings.passwordRule);
    }
    if (_confirmPasswordCtrl.text.isEmpty) {
      return ToastUtils.toast(strings.enterConfirmPassword);
    }
    if (_confirmPasswordCtrl.text != _registerPasswordCtrl.text) {
      return ToastUtils.toast(strings.passwordMismatch);
    }
    setState(() => _busy = true);
    try {
      await LoginCoordinator.instance.registerAccount(
        context: context,
        phoneE164: _e164Phone,
        phone: _phoneCtrl.text.trim(),
        smsCode: _smsCtrl.text.trim(),
        nickname: _nicknameCtrl.text.trim(),
        password: _registerPasswordCtrl.text,
        countryCode: _countryCode,
        countryIso: _phoneCountryIso,
      );
    } on LoginCoordinatorException catch (e) {
      ToastUtils.toast(
        DioErrorMessage.sanitizeUserText(
          e.message,
          fallback: _strings.requestFailed,
        ),
      );
    } catch (e) {
      final message = DioErrorMessage.fromThrowable(e, _strings);
      ToastUtils.toast(message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _dioMsg(DioError e) => DioErrorMessage.fromAuth(e, _strings);

  Future<bool> _ensureImSdkReadyForSubmit() async {
    try {
      await _initImSdkTask;
    } catch (_) {}
    final ready = await AuthBootstrapService.instance.ensureImSdkInitialized();
    if (!ready && mounted) {
      ToastUtils.toast('聊天服务初始化失败，请稍后重试');
    }
    return ready;
  }

  void _onTabSelected(int i) {
    if (_activeTab == i) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _activeTab = i;
      _syncWebLoginTabMode(i);
    });
    if (_safePageController.hasClients) {
      _safePageController.animateToPage(
        i,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
    _afterWebLoginTabModeSynced(i);
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AuthEntryScaffold(
      greeting: strings.hello,
      accent: strings.welcomeUse(IMDemoConfig.appName),
      tabs: [strings.loginTab, strings.registerTab],
      activeTab: _activeTab,
      onTabSelected: _onTabSelected,
      headerAction: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthCustomerServiceButton(),
          const SizedBox(width: 10),
          _buildNodeSwitchButton(),
          const SizedBox(width: 10),
          _buildLanguageSwitchButton(),
        ],
      ),
      footer: _buildVersionText(),
      contentPadding: EdgeInsets.fromLTRB(
        0,
        keyboardVisible ? 12 : 34,
        0,
        24,
      ),
      child: PageView(
        controller: _safePageController,
        onPageChanged: (index) {
          if (_activeTab != index) {
            FocusScope.of(context).unfocus();
            setState(() {
              _activeTab = index;
              _syncWebLoginTabMode(index);
            });
            _afterWebLoginTabModeSynced(index);
          }
        },
        children: [
          _buildFormPage(
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _supportsWebQrLogin && _isQrMode
                  ? _buildQrLoginForm()
                  : (_isSmsMode ? _buildSmsForm() : _buildPasswordForm()),
            ),
          ),
          _buildFormPage(_buildRegisterForm()),
        ],
      ),
    );
  }

  double get _authFieldGap => kIsWeb ? 16 : 22;

  double get _countryLeadingWidth => kIsWeb ? 118 : 102;

  Widget _buildFormPage(Widget child) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        bottom: bottomInset > 0 ? bottomInset + 120 : (kIsWeb ? 56 : 24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: child,
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

  Widget _buildHeaderIconButton({
    required String label,
    required VoidCallback onTap,
    required Widget icon,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: icon,
        ),
      ),
    );
  }

  Widget _buildNodeSwitchButton() {
    return _buildHeaderIconButton(
      label: '节点切换',
      onTap: () {
        Navigator.of(context).push(
          NavigationRoutes.cupertino(
            builder: (_) => const NodeSwitchPage(),
          ),
        );
      },
      icon: const Icon(
        Icons.dns_rounded,
        size: 22,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLanguageSwitchButton() {
    return _buildHeaderIconButton(
      label: '切换语言',
      onTap: () {
        final localSetting = Provider.of<LocalSetting>(context, listen: false);
        LanguageSwitchSheet.show(context, localSetting);
      },
      icon: Image.asset(
        'assets/img/language_switch.png',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.language_rounded,
          size: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  void _stopQrLoginPolling() {
    _qrRequestGeneration++;
    _qrPollTimer?.cancel();
    _qrPollTimer = null;
  }

  Future<void> _startQrLoginSession() async {
    if (!_supportsWebQrLogin || !mounted) {
      return;
    }
    final strings = _strings;
    _stopQrLoginPolling();
    final requestGeneration = _qrRequestGeneration;
    setState(() {
      _qrStatus = 'loading';
      _qrErrorMessage = null;
      _qrSessionId = null;
      _qrPayload = null;
      _qrExpiresAt = null;
    });
    try {
      final session = await AuthApi.instance.createQrLoginSession();
      if (!mounted || !_isQrMode || requestGeneration != _qrRequestGeneration) {
        return;
      }
      setState(() {
        _qrSessionId = session.sessionId;
        _qrPayload = session.qrPayload;
        _qrStatus = 'pending';
        _qrExpiresAt = DateTime.now().add(Duration(seconds: session.expiresIn));
      });
      _qrPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(
          _pollQrLoginSession(requestGeneration: requestGeneration),
        );
      });
    } on DioError catch (e) {
      if (!mounted) {
        return;
      }
      final unavailable = e.response?.statusCode == 404;
      setState(() {
        _qrStatus = 'error';
        _qrErrorMessage = unavailable
            ? strings.qrLoginUnavailable
            : DioErrorMessage.fromAuth(e, strings);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _qrStatus = 'error';
        _qrErrorMessage = strings.qrLoginUnavailable;
      });
    }
  }

  Future<void> _pollQrLoginSession({required int requestGeneration}) async {
    final sessionId = _qrSessionId?.trim() ?? '';
    if (!mounted ||
        !_isQrMode ||
        requestGeneration != _qrRequestGeneration ||
        sessionId.isEmpty) {
      return;
    }
    final expiresAt = _qrExpiresAt;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt)) {
      _stopQrLoginPolling();
      setState(() => _qrStatus = 'expired');
      return;
    }
    try {
      final poll = await AuthApi.instance.pollQrLoginSession(sessionId);
      if (!mounted ||
          !_isQrMode ||
          requestGeneration != _qrRequestGeneration ||
          sessionId != _qrSessionId?.trim()) {
        return;
      }
      if (poll.isConfirmed) {
        _stopQrLoginPolling();
        final token = poll.tokenResult;
        if (token == null) {
          setState(() {
            _qrStatus = 'error';
            _qrErrorMessage = _strings.requestFailed;
          });
          return;
        }
        setState(() => _busy = true);
        try {
          await LoginCoordinator.instance.loginWithQrTokenResult(
            context: context,
            tokenResult: token,
          );
        } catch (e) {
          if (!mounted) {
            return;
          }
          setState(() {
            _busy = false;
            _qrStatus = 'error';
            _qrErrorMessage = e.toString();
          });
        }
        return;
      }
      if (poll.isCancelled) {
        _stopQrLoginPolling();
        setState(() => _qrStatus = 'cancelled');
        return;
      }
      if (poll.isExpired) {
        _stopQrLoginPolling();
        setState(() => _qrStatus = 'expired');
        return;
      }
      setState(() {
        _qrStatus = poll.isScanned ? 'scanned' : 'pending';
      });
    } on DioError catch (e) {
      if (!mounted) {
        return;
      }
      if (e.response?.statusCode == 404) {
        _stopQrLoginPolling();
        setState(() {
          _qrStatus = 'error';
          _qrErrorMessage = _strings.qrLoginUnavailable;
        });
      }
    } catch (_) {
      // 轮询短暂失败时保持等待，不打断扫码。
    }
  }

  Widget _buildQrLoginForm() {
    final strings = _strings;
    final payload = _qrPayload?.trim() ?? '';
    String statusText;
    switch (_qrStatus) {
      case 'scanned':
        statusText = strings.qrLoginScannedConfirmOnPhone;
        break;
      case 'expired':
        statusText = strings.qrLoginExpired;
        break;
      case 'cancelled':
        statusText = strings.qrLoginCancelled;
        break;
      case 'error':
        statusText = _qrErrorMessage ?? strings.qrLoginUnavailable;
        break;
      case 'loading':
        statusText = strings.loggingIn;
        break;
      default:
        statusText = strings.qrLoginWaitingScan;
        break;
    }
    return Column(
      key: const ValueKey('qr'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          strings.qrLoginTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTokens.ink900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          strings.qrLoginHint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppTokens.ink500,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 220,
          height: 220,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTokens.ink100),
          ),
          child: _qrStatus == 'loading'
              ? const CircularProgressIndicator()
              : (payload.isEmpty
                  ? Icon(
                      Icons.qr_code_2_rounded,
                      size: 72,
                      color: AppTokens.ink300,
                    )
                  : QrImageView(
                      data: payload,
                      size: 200,
                      backgroundColor: Colors.white,
                    )),
        ),
        const SizedBox(height: 16),
        Text(
          statusText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppTokens.ink500,
          ),
        ),
        const SizedBox(height: 20),
        if (_qrStatus == 'expired' ||
            _qrStatus == 'cancelled' ||
            _qrStatus == 'error')
          AuthPrimaryButton(
            text: strings.qrLoginRefresh,
            pill: true,
            onPressed: _busy ? null : () => unawaited(_startQrLoginSession()),
          ),
        const SizedBox(height: 18),
        _actionRow(
          leftIcon: Icons.arrow_back_rounded,
          leftLabel: strings.switchToPasswordLogin,
          leftAction: () {
            _stopQrLoginPolling();
            setState(() {
              _isQrMode = false;
              _isSmsMode = false;
            });
            _requestPrimaryFieldFocus();
          },
          rightIcon: Icons.sms_outlined,
          rightLabel: strings.switchToSmsLogin,
          rightAction: () {
            _stopQrLoginPolling();
            setState(() {
              _isQrMode = false;
              _isSmsMode = true;
            });
            _requestPrimaryFieldFocus();
          },
        ),
      ],
    );
  }

  void _enterWebQrLoginMode() {
    if (!_supportsWebQrLogin) {
      return;
    }
    setState(() {
      _isSmsMode = false;
      _isQrMode = true;
    });
    unawaited(_startQrLoginSession());
  }

  Widget _buildWebQrCornerEntry() {
    if (!_supportsWebQrLogin) {
      return const SizedBox.shrink();
    }
    final label = _strings.switchToQrLogin;
    return Positioned(
      top: 0,
      right: 0,
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _busy ? null : _enterWebQrLoginMode,
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 24,
                  color: AppTokens.ink400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmsForm() {
    final strings = _strings;
    return Stack(
      key: const ValueKey('sms'),
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kIsWeb) const SizedBox(height: 8),
            AuthFieldLabel(strings.phoneLabel),
            AuthCompoundField(
              controller: _phoneCtrl,
              focusNode: _loginPhoneFocusNode,
              hint: strings.enterPhone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 15,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _focusField(_loginSmsFocusNode),
              onChanged: (_) => _handleInputChanged(),
              leading: _countryPicker(),
              leadingWidth: _countryLeadingWidth,
            ),
            const SizedBox(height: 22),
            AuthCompoundField(
              controller: _smsCtrl,
              focusNode: _loginSmsFocusNode,
              hint: strings.smsCodeHint,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _finishField(
                submit: _canSubmitSms ? _smsLogin : null,
              ),
              onChanged: (_) => _handleInputChanged(),
              trailing: _sendCodeAction(_cooldown, _busy, _sendLoginCode),
              trailingWidth: 122,
            ),
            const SizedBox(height: 18),
            _actionRow(
              leftIcon: Icons.arrow_back_rounded,
              leftLabel: strings.switchToPasswordLogin,
              leftAction: () {
                setState(() => _isSmsMode = false);
                _requestPrimaryFieldFocus();
              },
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              text: strings.loginButton,
              loadingText: strings.loggingIn,
              loading: _busy,
              pill: true,
              onPressed: _canSubmitSms ? _smsLogin : null,
            ),
          ],
        ),
        if (_supportsWebQrLogin) _buildWebQrCornerEntry(),
      ],
    );
  }

  Widget _buildPasswordForm() {
    final strings = _strings;
    return Stack(
      key: const ValueKey('pwd'),
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (kIsWeb) const SizedBox(height: 8),
            AuthFieldLabel(strings.accountLabel),
            AuthTextField(
              controller: _accountCtrl,
              focusNode: _accountFocusNode,
              hint: strings.enterUsernameOrEmail,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => _focusField(_passwordFocusNode),
              onChanged: (_) => _handleInputChanged(),
            ),
            const SizedBox(height: 22),
            AuthFieldLabel(strings.passwordLabel),
            AuthTextField(
              controller: _passwordCtrl,
              focusNode: _passwordFocusNode,
              hint: strings.enterPassword,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _finishField(
                submit: _canSubmitPassword ? _passwordLogin : null,
              ),
              onChanged: (_) => _handleInputChanged(),
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
            const SizedBox(height: 14),
            _rememberPasswordRow(strings),
            const SizedBox(height: 18),
            _actionRow(
              leftIcon: Icons.arrow_back_rounded,
              leftLabel: strings.switchToSmsLogin,
              leftAction: () {
                setState(() {
                  _isSmsMode = true;
                  _isQrMode = false;
                });
                _stopQrLoginPolling();
                _requestPrimaryFieldFocus();
              },
              rightIcon: Icons.lock_outline_rounded,
              rightLabel: strings.forgotPasswordAction,
              rightAction: () => Navigator.push(
                context,
                AppMaterialPageRoute(
                  builder: (_) => const ForgotPasswordPage(),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              text: strings.loginButton,
              loadingText: strings.loggingIn,
              loading: _busy,
              pill: true,
              onPressed: _canSubmitPassword ? _passwordLogin : null,
            ),
          ],
        ),
        if (_supportsWebQrLogin) _buildWebQrCornerEntry(),
      ],
    );
  }

  Widget _buildRegisterForm() {
    final strings = _strings;
    return Column(
      key: const ValueKey('register'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthFieldLabel(strings.phoneLabel),
        AuthCompoundField(
          controller: _phoneCtrl,
          focusNode: _registerPhoneFocusNode,
          hint: strings.enterPhone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 15,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _focusField(_registerSmsFocusNode),
          onChanged: (_) => _handleInputChanged(),
          leading: _countryPicker(),
          leadingWidth: _countryLeadingWidth,
        ),
        SizedBox(height: _authFieldGap),
        AuthCompoundField(
          controller: _smsCtrl,
          focusNode: _registerSmsFocusNode,
          hint: strings.smsCodeHint,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _focusField(_nicknameFocusNode),
          onChanged: (_) => _handleInputChanged(),
          trailing: _sendCodeAction(_cooldown, _busy, _sendRegisterCode),
          trailingWidth: 122,
        ),
        SizedBox(height: _authFieldGap),
        AuthTextField(
          controller: _nicknameCtrl,
          focusNode: _nicknameFocusNode,
          hint: strings.enterNickname,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _focusField(_registerPasswordFocusNode),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 18),
          child: _registerNicknameInlineMessage(),
        ),
        AuthTextField(
          controller: _registerPasswordCtrl,
          focusNode: _registerPasswordFocusNode,
          hint: strings.enterPasswordRule,
          obscureText: _registerObscure,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _focusField(_confirmPasswordFocusNode),
          onChanged: (_) => _handleInputChanged(),
          suffix: GestureDetector(
            onTap: () => setState(() => _registerObscure = !_registerObscure),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                _registerObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppTokens.ink300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildRegisterPasswordRules(),
        const SizedBox(height: 14),
        AuthTextField(
          controller: _confirmPasswordCtrl,
          focusNode: _confirmPasswordFocusNode,
          hint: strings.enterPasswordAgain,
          obscureText: _confirmRegisterObscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _finishField(
            submit: _canSubmitRegister ? _register : null,
          ),
          onChanged: (_) => _handleInputChanged(),
          suffix: GestureDetector(
            onTap: () => setState(
                () => _confirmRegisterObscure = !_confirmRegisterObscure),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(
                _confirmRegisterObscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppTokens.ink300,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _buildConfirmPasswordMessage(),
        SizedBox(height: _authFieldGap),
        _buildRegisterAgreement(),
        const SizedBox(height: 12),
        AuthPrimaryButton(
          text: strings.registerButton,
          loadingText: strings.registering,
          loading: _busy,
          pill: true,
          onPressed: _canSubmitRegister ? _register : null,
        ),
        if (kIsWeb) const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRegisterPasswordRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '至少 8 位，须同时包含英文字母和数字',
          style: AppTokens.caption.copyWith(
            fontSize: 12,
            height: 1.25,
            color: AppTokens.ink400,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: [
            _passwordRuleItem('8 位以上', _registerPasswordHasMinLength),
            _passwordRuleItem('英文字母', _registerPasswordHasLetter),
            _passwordRuleItem('数字', _registerPasswordHasDigit),
          ],
        ),
      ],
    );
  }

  Widget _passwordRuleItem(String text, bool ok) {
    final color = ok ? AppTokens.success : AppTokens.ink300;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: AppTokens.caption.copyWith(
            fontSize: 12,
            height: 1.2,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordMessage() {
    if (!_confirmPasswordTouched || _confirmPasswordOk) {
      return const SizedBox(height: 18);
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '两次输入的密码不一致',
        style: AppTokens.caption.copyWith(
          fontSize: 12,
          height: 1.35,
          color: AppTokens.danger,
        ),
      ),
    );
  }

  Widget _registerNicknameInlineMessage() {
    final error = _registerNicknameError;
    final hint = _registerNicknameHint;
    final text = (error != null && error.isNotEmpty) ? error : hint;
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          height: 1.2,
          color: error != null && error.isNotEmpty
              ? const Color(0xFFFF3B30)
              : AppTokens.ink300,
        ),
      ),
    );
  }

  Widget _buildRegisterAgreement() {
    final textStyle = AppTokens.caption.copyWith(
      fontSize: 13,
      color: AppTokens.ink400,
      height: 1.5,
    );
    final linkStyle = textStyle.copyWith(
      color: AppTokens.brand500,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(_strings.agreeRegisterPrefix, style: textStyle),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                AppMaterialPageRoute(builder: (_) => const UserAgreementPage()),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 2),
                child:
                    Text('《${_strings.userAgreementTitle}》', style: linkStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendRegisterCode() async {
    final strings = _strings;
    if (_cooldown > 0 || _busy) return;
    if (_phoneCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterPhone);
    }
    if (!_isPhoneValid) {
      return ToastUtils.toast(_phoneInvalidText);
    }
    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AuthApi.instance.sendSms(
        phone: _e164Phone,
        scene: 'REGISTER',
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

  Widget _rememberPasswordRow(AuthLocalizations strings) {
    final labelStyle = AppTokens.caption.copyWith(
      color: AppTokens.ink400,
      fontSize: 14,
    );
    return GestureDetector(
      onTap: () => setState(() => _rememberPassword = !_rememberPassword),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: _rememberPassword,
              onChanged: (value) {
                setState(() => _rememberPassword = value ?? false);
              },
              activeColor: AppTokens.brand600,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
          Text(strings.rememberPassword, style: labelStyle),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData leftIcon,
    required String leftLabel,
    required VoidCallback leftAction,
    IconData? rightIcon,
    String? rightLabel,
    VoidCallback? rightAction,
  }) {
    final helperStyle = AppTokens.caption.copyWith(
      color: AppTokens.ink400,
      fontSize: 14,
    );
    return Row(
      children: [
        GestureDetector(
          onTap: leftAction,
          child: Row(
            children: [
              Icon(leftIcon, size: 18, color: AppTokens.ink400),
              const SizedBox(width: 6),
              Text(leftLabel, style: helperStyle),
            ],
          ),
        ),
        const Spacer(),
        if (rightIcon != null && rightLabel != null)
          GestureDetector(
            onTap: rightAction,
            child: Row(
              children: [
                Icon(rightIcon, size: 18, color: AppTokens.ink400),
                const SizedBox(width: 6),
                Text(rightLabel, style: helperStyle),
              ],
            ),
          ),
      ],
    );
  }

  Widget _countryPicker() {
    final dialCodeStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppTokens.brand500,
      fontFamily: AppTokens.fontFamily,
      height: 1.2,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
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
                      style: dialCodeStyle,
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppTokens.ink400,
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
      ),
    );
  }

  Widget _sendCodeAction(int cooldown, bool busy, VoidCallback onTap) {
    final strings = _strings;
    final enabled = cooldown == 0 && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        alignment: Alignment.center,
        child: Text(
          cooldown > 0 ? '${cooldown}s' : strings.getCode,
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

// ═══════════════════════════════════════════════════════════════════════════════
// DeviceChallengePage
// ═══════════════════════════════════════════════════════════════════════════════

class DeviceChallengePage extends StatefulWidget {
  final String challengeId;
  final String phone;
  final String phoneMasked;
  const DeviceChallengePage({
    Key? key,
    required this.challengeId,
    required this.phone,
    required this.phoneMasked,
  }) : super(key: key);

  @override
  State<DeviceChallengePage> createState() => _DeviceChallengePageState();
}

class _DeviceChallengePageState extends State<DeviceChallengePage> {
  final _smsCtrl = TextEditingController();
  final _smsFocusNode = FocusNode();
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;
  bool get _canVerify => !_busy && _smsCtrl.text.trim().length == 6;
  AuthLocalizations get _strings => AuthLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    LoginCoordinator.instance.markDeviceVerifying();
    _smsCtrl.addListener(_handleInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_smsFocusNode.canRequestFocus) return;
      FocusScope.of(context).requestFocus(_smsFocusNode);
    });
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _smsCtrl.removeListener(_handleInputChanged);
    _smsCtrl.dispose();
    _smsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_cooldown > 0) return;
    final phone = widget.phone.trim();
    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;
    setState(() => _busy = true);
    try {
      await AuthApi.instance.sendSms(
        phone: phone,
        scene: 'DEVICE',
        challengeId: widget.challengeId,
      );
      if (mounted) ToastUtils.toast(_strings.codeSentSuccess);
      setState(() => _cooldown = 60);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          if (_cooldown > 0) _cooldown--;
          if (_cooldown == 0) t.cancel();
        });
      });
    } on DioError catch (e) {
      ToastUtils.toast(_deviceDioMsg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _deviceDioMsg(DioError e) => DioErrorMessage.fromAuth(e, _strings);

  Future<void> _verify() async {
    final strings = _strings;
    if (_busy) return;
    if (_smsCtrl.text.trim().isEmpty) {
      return ToastUtils.toast(strings.enterSmsCode);
    }
    if (_smsCtrl.text.trim().length != 6) {
      return ToastUtils.toast(strings.smsCodeMust6);
    }
    setState(() => _busy = true);
    try {
      await LoginCoordinator.instance.verifyDeviceChallenge(
        context: context,
        challengeId: widget.challengeId,
        smsCode: _smsCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on LoginCoordinatorException catch (e) {
      ToastUtils.toast(
        DioErrorMessage.sanitizeUserText(
          e.message,
          fallback: _strings.requestFailed,
        ),
      );
    } catch (e) {
      ToastUtils.toast(DioErrorMessage.fromThrowable(e, _strings));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _sendCodeAction(int cooldown, bool busy, VoidCallback onTap) {
    final strings = _strings;
    final enabled = cooldown == 0 && !busy;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        alignment: Alignment.center,
        child: Text(
          cooldown > 0 ? '${cooldown}s' : strings.send,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTokens.brand500 : AppTokens.ink300,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AuthLocalizations.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: authFormImmersiveOverlayStyle(background: AppTokens.surface),
      child: AuthScaffold(
        title: strings.deviceVerifyTitle,
        subtitle: strings.deviceVerifySubtitle,
        showBack: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthInfoBanner(
              icon: Icons.shield_outlined,
              text: widget.phoneMasked.trim().isNotEmpty
                  ? strings.codeSentTo(widget.phoneMasked)
                  : strings.deviceVerifySmsHint,
            ),
            const SizedBox(height: 24),
            AuthFieldLabel(strings.smsCodeLabel),
            AuthCompoundField(
              controller: _smsCtrl,
              focusNode: _smsFocusNode,
              autofocus: true,
              hint: strings.sixDigitCodeHint,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                FocusScope.of(context).unfocus();
                if (_canVerify) _verify();
              },
              trailing: _sendCodeAction(_cooldown, _busy, _sendCode),
              trailingWidth: 100,
            ),
            const SizedBox(height: 28),
            AuthPrimaryButton(
              text: strings.confirmLogin,
              loading: _busy,
              pill: true,
              onPressed: _canVerify ? _verify : null,
            ),
          ],
        ),
      ),
    );
  }
}
