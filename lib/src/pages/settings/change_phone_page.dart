import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/security/slider_captcha.dart';
import 'package:tencent_cloud_chat_demo/src/utils/phone_binding_guard.dart';

class ChangePhonePage extends StatefulWidget {
  /// 桌面/Web 弹窗内嵌时隐藏自身 AppBar，由宿主弹窗标题栏承接。
  final bool embedded;

  const ChangePhonePage({super.key, this.embedded = false});

  @override
  State<ChangePhonePage> createState() => _ChangePhonePageState();
}

class _ChangePhonePageState extends State<ChangePhonePage> {
  final oldCodeController = TextEditingController();
  final newPhoneController = TextEditingController();
  final newCodeController = TextEditingController();

  String changeId = '';
  String currentPhone = '';
  String newPhoneMasked = '';
  int step = 0;
  bool busy = false;
  bool loadingCurrentPhone = true;
  bool _isBindMode = false;
  int oldCodeCooldown = 0;
  int newCodeCooldown = 0;
  Timer? oldCodeCooldownTimer;
  Timer? newCodeCooldownTimer;

  bool get _canVerifyOld =>
      !busy && changeId.isNotEmpty && oldCodeController.text.trim().length == 6;

  bool get _canSendNewCode =>
      !busy &&
      newCodeCooldown == 0 &&
      step >= 2 &&
      newPhoneController.text.trim().isNotEmpty;

  bool get _canConfirm =>
      !busy &&
      changeId.isNotEmpty &&
      step >= 3 &&
      newCodeController.text.trim().length == 6;

  bool get _canBindSendCode =>
      !busy &&
      newCodeCooldown == 0 &&
      newPhoneController.text.trim().isNotEmpty;

  bool get _canBindConfirm =>
      !busy &&
      changeId.isNotEmpty &&
      newCodeController.text.trim().length == 6;

  int get _uiStep => step >= 2 ? 2 : 1;

  @override
  void initState() {
    super.initState();
    oldCodeController.addListener(_refresh);
    newPhoneController.addListener(_refresh);
    newCodeController.addListener(_refresh);
    _loadCurrentPhone();
  }

  @override
  void dispose() {
    oldCodeController.removeListener(_refresh);
    newPhoneController.removeListener(_refresh);
    newCodeController.removeListener(_refresh);
    oldCodeCooldownTimer?.cancel();
    newCodeCooldownTimer?.cancel();
    oldCodeController.dispose();
    newPhoneController.dispose();
    newCodeController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _startOldCodeCooldown() {
    oldCodeCooldownTimer?.cancel();
    setState(() => oldCodeCooldown = 60);
    oldCodeCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (oldCodeCooldown > 0) {
          oldCodeCooldown--;
        }
        if (oldCodeCooldown == 0) {
          timer.cancel();
        }
      });
    });
  }

  void _startNewCodeCooldown() {
    newCodeCooldownTimer?.cancel();
    setState(() => newCodeCooldown = 60);
    newCodeCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (newCodeCooldown > 0) {
          newCodeCooldown--;
        }
        if (newCodeCooldown == 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _loadCurrentPhone() async {
    try {
      final me = await AuthApi.instance.fetchMe();
      if (!mounted) return;
      setState(() {
        currentPhone = me.phoneMasked.trim().isEmpty
            ? me.phone.trim()
            : me.phoneMasked.trim();
        _isBindMode = !PhoneBindingGuard.isBound(me);
        loadingCurrentPhone = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        currentPhone = AppI18n.current.t(
          zhHans: '未获取',
          zhHant: '未取得',
          en: 'Unavailable',
          ja: '取得できません',
          ko: '가져올 수 없음',
        );
        loadingCurrentPhone = false;
      });
    }
  }

  Future<void> _start() async {
    if (busy || oldCodeCooldown > 0) return;
    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;

    setState(() => busy = true);
    try {
      final ret = await SettingsApi.instance.startPhoneChange();
      if (!mounted) return;
      setState(() {
        changeId = ret.changeId;
        currentPhone = ret.phoneMasked.isEmpty ? currentPhone : ret.phoneMasked;
        step = 1;
      });
      _startOldCodeCooldown();
      _toast(AppI18n.current.t(
        zhHans: '验证码已发送至当前手机号',
        zhHant: '驗證碼已發送至目前手機號',
        en: 'A verification code has been sent to your current phone number.',
        ja: '現在の電話番号に認証コードを送信しました。',
        ko: '현재 휴대전화 번호로 인증 코드가 전송되었습니다.',
      ));
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verifyOld() async {
    if (busy) return;
    final code = oldCodeController.text.trim();
    if (changeId.isEmpty) {
      _toast(AppI18n.current.t(
        zhHans: '请先获取旧手机号验证码',
        zhHant: '請先取得舊手機號驗證碼',
        en: 'Please request the code for your current phone number first.',
        ja: '先に現在の電話番号の認証コードを取得してください。',
        ko: '먼저 현재 휴대전화 번호의 인증 코드를 받아 주세요.',
      ));
      return;
    }
    if (code.length != 6) {
      _toast(AppI18n.current.t(
        zhHans: '请输入 6 位旧号验证码',
        zhHant: '請輸入 6 位舊號驗證碼',
        en: 'Enter the 6-digit code sent to your current phone number.',
        ja: '現在の電話番号に届いた6桁の認証コードを入力してください。',
        ko: '현재 번호로 받은 6자리 인증 코드를 입력해 주세요.',
      ));
      return;
    }

    setState(() => busy = true);
    try {
      final ret = await SettingsApi.instance.verifyOldPhone(
        changeId: changeId,
        smsCode: code,
      );
      if (!mounted) return;
      setState(() {
        changeId = ret.changeId.isEmpty ? changeId : ret.changeId;
        step = 2;
      });
      _toast(AppI18n.current.t(
        zhHans: '旧手机号验证通过',
        zhHant: '舊手機號驗證通過',
        en: 'Your current phone number has been verified.',
        ja: '現在の電話番号の確認が完了しました。',
        ko: '현재 휴대전화 번호 인증이 완료되었습니다.',
      ));
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendNew() async {
    if (busy || newCodeCooldown > 0) return;
    final phone = newPhoneController.text.trim();
    if (changeId.isEmpty || step < 2) {
      _toast(AppI18n.current.t(
        zhHans: '请先验证旧手机号',
        zhHant: '請先驗證舊手機號',
        en: 'Please verify your current phone number first.',
        ja: '先に現在の電話番号を認証してください。',
        ko: '먼저 현재 휴대전화 번호를 인증해 주세요.',
      ));
      return;
    }
    if (phone.isEmpty) {
      _toast(AppI18n.current.t(
        zhHans: '请输入新手机号',
        zhHant: '請輸入新手機號',
        en: 'Enter your new phone number.',
        ja: '新しい電話番号を入力してください。',
        ko: '새 휴대전화 번호를 입력해 주세요.',
      ));
      return;
    }

    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;

    setState(() => busy = true);
    try {
      final ret = await SettingsApi.instance.sendNewPhoneCode(
        changeId: changeId,
        newPhone: phone,
      );
      if (!mounted) return;
      setState(() {
        newPhoneMasked = ret.phoneMasked;
        step = 3;
      });
      _startNewCodeCooldown();
      _toast(AppI18n.current.t(
        zhHans: '验证码已发送至新手机号',
        zhHant: '驗證碼已發送至新手機號',
        en: 'A verification code has been sent to your new phone number.',
        ja: '新しい電話番号に認証コードを送信しました。',
        ko: '새 휴대전화 번호로 인증 코드가 전송되었습니다.',
      ));
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _confirm() async {
    if (busy) return;
    final code = newCodeController.text.trim();
    if (changeId.isEmpty || step < 3) {
      _toast(AppI18n.current.t(
        zhHans: '请先获取新手机号验证码',
        zhHant: '請先取得新手機號驗證碼',
        en: 'Please request the code for your new phone number first.',
        ja: '先に新しい電話番号の認証コードを取得してください。',
        ko: '먼저 새 휴대전화 번호의 인증 코드를 받아 주세요.',
      ));
      return;
    }
    if (code.length != 6) {
      _toast(AppI18n.current.t(
        zhHans: '请输入 6 位新号验证码',
        zhHant: '請輸入 6 位新號驗證碼',
        en: 'Enter the 6-digit code sent to your new phone number.',
        ja: '新しい電話番号に届いた6桁の認証コードを入力してください。',
        ko: '새 번호로 받은 6자리 인증 코드를 입력해 주세요.',
      ));
      return;
    }

    setState(() => busy = true);
    try {
      final ret = await SettingsApi.instance.confirmPhoneChange(
        changeId: changeId,
        smsCode: code,
      );
      if (!mounted) return;
      final showPhone =
          ret.phoneMasked.isNotEmpty ? ret.phoneMasked : ret.phone;
      _toast(showPhone.isEmpty
          ? AppI18n.current.t(
              zhHans: '修改成功',
              zhHant: '修改成功',
              en: 'Phone number updated successfully.',
              ja: '電話番号を変更しました。',
              ko: '휴대전화 번호가 변경되었습니다.',
            )
          : AppI18n.current.format(
              zhHans: '已更换为 {phone}',
              zhHant: '已更換為 {phone}',
              en: 'Changed to {phone}',
              ja: '{phone} に変更しました',
              ko: '{phone}(으)로 변경되었습니다',
              vars: {'phone': showPhone},
            ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _bindSendCode() async {
    if (busy || newCodeCooldown > 0) return;
    final phone = newPhoneController.text.trim();
    if (phone.isEmpty) {
      _toast(AppI18n.current.t(
        zhHans: '请输入手机号',
        zhHant: '請輸入手機號',
        en: 'Enter your phone number.',
        ja: '電話番号を入力してください。',
        ko: '휴대전화 번호를 입력해 주세요.',
      ));
      return;
    }

    final passed = await showSliderCaptcha(context);
    if (!passed || !mounted) return;

    setState(() => busy = true);
    try {
      final ret = await SettingsApi.instance.startPhoneBind(phone: phone);
      if (!mounted) return;
      setState(() {
        changeId = ret.bindId;
        newPhoneMasked =
            ret.phoneMasked.isEmpty ? phone : ret.phoneMasked;
        step = 1;
      });
      _startNewCodeCooldown();
      _toast(AppI18n.current.t(
        zhHans: '验证码已发送至手机号',
        zhHant: '驗證碼已發送至手機號',
        en: 'A verification code has been sent to your phone number.',
        ja: '電話番号に認証コードを送信しました。',
        ko: '휴대전화 번호로 인증 코드가 전송되었습니다.',
      ));
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _bindConfirm() async {
    if (busy) return;
    final code = newCodeController.text.trim();
    if (changeId.isEmpty) {
      _toast(AppI18n.current.t(
        zhHans: '请先获取验证码',
        zhHant: '請先取得驗證碼',
        en: 'Please request a verification code first.',
        ja: '先に認証コードを取得してください。',
        ko: '먼저 인증 코드를 받아 주세요.',
      ));
      return;
    }
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

    setState(() => busy = true);
    try {
      final ret = await SettingsApi.instance.confirmPhoneBind(
        bindId: changeId,
        smsCode: code,
      );
      if (!mounted) return;
      final showPhone =
          ret.phoneMasked.isNotEmpty ? ret.phoneMasked : ret.phone;
      _toast(showPhone.isEmpty
          ? AppI18n.current.t(
              zhHans: '绑定成功',
              zhHant: '綁定成功',
              en: 'Phone number linked successfully.',
              ja: '電話番号を登録しました。',
              ko: '휴대전화 번호가 등록되었습니다.',
            )
          : AppI18n.current.format(
              zhHans: '已绑定 {phone}',
              zhHant: '已綁定 {phone}',
              en: 'Linked to {phone}',
              ja: '{phone} を登録しました',
              ko: '{phone}(으)로 등록되었습니다',
              vars: {'phone': showPhone},
            ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _toast(_errorText(e));
    } finally {
      if (mounted) setState(() => busy = false);
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
          case 'CHANGE_SESSION_EXPIRED':
            return AppI18n.current.t(
              zhHans: '操作超时，请重新开始',
              zhHant: '操作逾時，請重新開始',
              en: 'This operation has timed out. Please start again.',
              ja: '操作がタイムアウトしました。最初からやり直してください。',
              ko: '작업 시간이 초과되었습니다. 처음부터 다시 진행해 주세요.',
            );
          case 'CHANGE_SESSION_FORBIDDEN':
            return AppI18n.current.t(
              zhHans: '本次操作无效，请重新开始',
              zhHant: '本次操作無效，請重新開始',
              en: 'This action is no longer valid. Please start again.',
              ja: 'この操作は無効です。最初からやり直してください。',
              ko: '이번 작업은 유효하지 않습니다. 처음부터 다시 진행해 주세요.',
            );
          case 'INVALID_PHONE':
            return AppI18n.current.t(
              zhHans: '手机号格式不正确',
              zhHant: '手機號格式不正確',
              en: 'The phone number format is invalid.',
              ja: '電話番号の形式が正しくありません。',
              ko: '휴대전화 번호 형식이 올바르지 않습니다.',
            );
          case 'SAME_PHONE':
            return AppI18n.current.t(
              zhHans: '新手机号不能与当前号码相同',
              zhHant: '新手機號不能與目前號碼相同',
              en: 'Your new phone number must be different from the current one.',
              ja: '新しい電話番号は現在の番号と同じにできません。',
              ko: '새 휴대전화 번호는 현재 번호와 같을 수 없습니다.',
            );
          case 'PHONE_EXISTS':
            return AppI18n.current.t(
              zhHans: '该手机号已被注册',
              zhHant: '該手機號已被註冊',
              en: 'This phone number is already registered.',
              ja: 'この電話番号はすでに登録されています。',
              ko: '이미 등록된 휴대전화 번호입니다.',
            );
          case 'RATE_LIMITED':
            return AppI18n.current.t(
              zhHans: '发送过于频繁，请稍后再试',
              zhHant: '發送過於頻繁，請稍後再試',
              en: 'Too many requests. Please try again later.',
              ja: '送信回数が多すぎます。しばらくしてからもう一度お試しください。',
              ko: '요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.',
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

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      embedded: widget.embedded,
      title: _isBindMode
          ? i18n.t(
              zhHans: '绑定手机号',
              zhHant: '綁定手機號',
              en: 'Link Phone Number',
              ja: '電話番号を登録',
              ko: '휴대전화 번호 등록',
            )
          : i18n.t(
              zhHans: '修改手机号',
              zhHant: '修改手機號',
              en: 'Change Phone Number',
              ja: '電話番号を変更',
              ko: '휴대전화 번호 변경',
            ),
      children: [
        if (loadingCurrentPhone)
          const Padding(
            padding: EdgeInsets.only(top: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_isBindMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              i18n.t(
                zhHans: '绑定手机号后，可使用修改密码、支付密码等功能。',
                zhHant: '綁定手機號後，可使用修改密碼、支付密碼等功能。',
                en: 'After linking a phone number, you can change your password and set a payment password.',
                ja: '電話番号を登録すると、パスワード変更や支払いパスワード設定が利用できます。',
                ko: '휴대전화 번호를 등록하면 비밀번호 변경, 결제 비밀번호 설정 등을 사용할 수 있습니다.',
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
                  zhHans: '手机号',
                  zhHant: '手機號',
                  en: 'Phone Number',
                  ja: '電話番号',
                  ko: '휴대전화 번호',
                ),
                hint: i18n.t(
                  zhHans: '请输入手机号',
                  zhHant: '請輸入手機號',
                  en: 'Enter phone number',
                  ja: '電話番号を入力',
                  ko: '휴대전화 번호를 입력해 주세요',
                ),
                keyboardType: TextInputType.phone,
                controller: newPhoneController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              _CodeCell(
                label: i18n.t(
                  zhHans: '验证码',
                  zhHant: '驗證碼',
                  en: 'Verification Code',
                  ja: '認証コード',
                  ko: '인증 코드',
                ),
                hint: newPhoneMasked.isEmpty
                    ? i18n.t(
                        zhHans: '请输入验证码',
                        zhHant: '請輸入驗證碼',
                        en: 'Enter verification code',
                        ja: '認証コードを入力',
                        ko: '인증 코드를 입력해 주세요',
                      )
                    : i18n.format(
                        zhHans: '已发送至 {phone}',
                        zhHant: '已發送至 {phone}',
                        en: 'Sent to {phone}',
                        ja: '{phone} に送信済み',
                        ko: '{phone}(으)로 전송됨',
                        vars: {'phone': newPhoneMasked},
                      ),
                buttonText: newCodeCooldown > 0
                    ? '${newCodeCooldown}s'
                    : busy && step == 0
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
                controller: newCodeController,
                onPressed: _canBindSendCode ? _bindSendCode : null,
                dark: dark,
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
                  backgroundColor: _canBindConfirm
                      ? AppColors.primaryBlue
                      : AppColors.line(dark: dark),
                  foregroundColor: _canBindConfirm
                      ? Colors.white
                      : AppColors.subText(dark: dark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _canBindConfirm ? _bindConfirm : null,
                child: Text(
                  busy
                      ? i18n.t(
                          zhHans: '处理中...',
                          zhHant: '處理中...',
                          en: 'Processing...',
                          ja: '処理中...',
                          ko: '처리 중...',
                        )
                      : i18n.t(
                          zhHans: '完成绑定',
                          zhHant: '完成綁定',
                          en: 'Link Phone',
                          ja: '登録を完了',
                          ko: '등록 완료',
                        ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            _uiStep == 1
                ? i18n.t(
                    zhHans: '先验证当前绑定手机号，再进入下一步绑定新手机号。',
                    zhHant: '請先驗證目前綁定的手機號，再進行下一步綁定新手機號。',
                    en: 'Verify your current phone number first, then proceed to bind a new one.',
                    ja: 'まず現在の電話番号を確認し、その後で新しい電話番号を登録してください。',
                    ko: '먼저 현재 휴대전화 번호를 인증한 뒤 새 번호를 등록해 주세요.',
                  )
                : i18n.t(
                    zhHans: '当前手机号已验证，请绑定新的手机号并完成验证。',
                    zhHant: '目前手機號已驗證，請綁定新的手機號並完成驗證。',
                    en: 'Your current phone number has been verified. Please bind and verify a new number.',
                    ja: '現在の電話番号の確認が完了しました。新しい電話番号を登録して認証してください。',
                    ko: '현재 휴대전화 번호 인증이 완료되었습니다. 새 번호를 등록하고 인증해 주세요.',
                  ),
            style: TextStyle(
              color: helperColor,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
        _StepIndicator(currentStep: _uiStep),
        if (_uiStep == 1) ...[
          _StepLabel(
            text: i18n.t(
              zhHans: '第 1 步  验证当前手机号',
              zhHant: '第 1 步  驗證目前手機號',
              en: 'Step 1  Verify Current Phone Number',
              ja: 'ステップ1  現在の電話番号を確認',
              ko: '1단계  현재 휴대전화 번호 인증',
            ),
          ),
          SettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              SettingsCell(
                title: i18n.t(
                  zhHans: '当前手机号',
                  zhHant: '目前手機號',
                  en: 'Current Phone Number',
                  ja: '現在の電話番号',
                  ko: '현재 휴대전화 번호',
                ),
                value: currentPhone,
                showArrow: false,
              ),
              _CodeCell(
                label: i18n.t(
                  zhHans: '旧号验证码',
                  zhHant: '舊號驗證碼',
                  en: 'Current Code',
                  ja: '現在の番号の認証コード',
                  ko: '현재 번호 인증 코드',
                ),
                hint: i18n.t(
                  zhHans: '请输入验证码',
                  zhHant: '請輸入驗證碼',
                  en: 'Enter verification code',
                  ja: '認証コードを入力',
                  ko: '인증 코드를 입력해 주세요',
                ),
                buttonText: oldCodeCooldown > 0
                    ? '${oldCodeCooldown}s'
                    : busy && step == 0
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
                controller: oldCodeController,
                onPressed: busy || loadingCurrentPhone || oldCodeCooldown > 0
                    ? null
                    : _start,
                dark: dark,
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
                  backgroundColor: _canVerifyOld
                      ? AppColors.primaryBlue
                      : AppColors.line(dark: dark),
                  foregroundColor: _canVerifyOld
                      ? Colors.white
                      : AppColors.subText(dark: dark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _canVerifyOld ? _verifyOld : null,
                child: Text(
                  i18n.t(
                    zhHans: '下一步',
                    zhHant: '下一步',
                    en: 'Next',
                    ja: '次へ',
                    ko: '다음',
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ] else ...[
          _StepLabel(
            text: i18n.t(
              zhHans: '第 2 步  绑定新手机号',
              zhHant: '第 2 步  綁定新手機號',
              en: 'Step 2  Bind New Phone Number',
              ja: 'ステップ2  新しい電話番号を登録',
              ko: '2단계  새 휴대전화 번호 등록',
            ),
          ),
          SettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              SettingsCell(
                title: i18n.t(
                  zhHans: '当前手机号',
                  zhHant: '目前手機號',
                  en: 'Current Phone Number',
                  ja: '現在の電話番号',
                  ko: '현재 휴대전화 번호',
                ),
                value: currentPhone,
                showArrow: false,
              ),
              SettingsInputCell(
                label: i18n.t(
                  zhHans: '新手机号',
                  zhHant: '新手機號',
                  en: 'New Phone Number',
                  ja: '新しい電話番号',
                  ko: '새 휴대전화 번호',
                ),
                hint: i18n.t(
                  zhHans: '请输入新手机号',
                  zhHant: '請輸入新手機號',
                  en: 'Enter new phone number',
                  ja: '新しい電話番号を入力',
                  ko: '새 휴대전화 번호를 입력해 주세요',
                ),
                keyboardType: TextInputType.phone,
                controller: newPhoneController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(20),
                ],
              ),
              _CodeCell(
                label: i18n.t(
                  zhHans: '新号验证码',
                  zhHant: '新號驗證碼',
                  en: 'New Number Code',
                  ja: '新しい番号の認証コード',
                  ko: '새 번호 인증 코드',
                ),
                hint: newPhoneMasked.isEmpty
                    ? i18n.t(
                        zhHans: '请输入验证码',
                        zhHant: '請輸入驗證碼',
                        en: 'Enter verification code',
                        ja: '認証コードを入力',
                        ko: '인증 코드를 입력해 주세요',
                      )
                    : i18n.format(
                        zhHans: '已发送至 {phone}',
                        zhHant: '已發送至 {phone}',
                        en: 'Sent to {phone}',
                        ja: '{phone} に送信済み',
                        ko: '{phone}(으)로 전송됨',
                        vars: {'phone': newPhoneMasked},
                      ),
                buttonText: newCodeCooldown > 0
                    ? '${newCodeCooldown}s'
                    : busy && step == 2
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
                controller: newCodeController,
                onPressed: _canSendNewCode ? _sendNew : null,
                dark: dark,
                showDivider: false,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(() {
                          step = 1;
                          newPhoneMasked = '';
                          newCodeController.clear();
                        });
                      },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  i18n.t(
                    zhHans: '返回上一步',
                    zhHant: '返回上一步',
                    en: 'Back',
                    ja: '前のステップへ戻る',
                    ko: '이전 단계로 돌아가기',
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _canConfirm
                      ? AppColors.primaryBlue
                      : AppColors.line(dark: dark),
                  foregroundColor: _canConfirm
                      ? Colors.white
                      : AppColors.subText(dark: dark),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _canConfirm ? _confirm : null,
                child: Text(
                  busy
                      ? i18n.t(
                          zhHans: '处理中...',
                          zhHant: '處理中...',
                          en: 'Processing...',
                          ja: '処理中...',
                          ko: '처리 중...',
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
      ],
    );
  }
}

class _CodeCell extends StatelessWidget {
  final String label;
  final String hint;
  final String buttonText;
  final TextEditingController controller;
  final VoidCallback? onPressed;
  final bool dark;
  final bool showDivider;

  const _CodeCell({
    required this.label,
    required this.hint,
    required this.buttonText,
    required this.controller,
    required this.onPressed,
    required this.dark,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
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

class _StepLabel extends StatelessWidget {
  final String text;

  const _StepLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.subText(dark: dark),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;

  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card(dark: dark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.line(dark: dark),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StepIndicatorItem(
              index: 1,
              title: i18n.t(
                zhHans: '验证当前手机号',
                zhHant: '驗證目前手機號',
                en: 'Verify Current Phone',
                ja: '現在の電話番号を確認',
                ko: '현재 번호 인증',
              ),
              active: currentStep == 1,
              done: currentStep > 1,
            ),
          ),
          Container(
            width: 26,
            height: 1,
            color: currentStep > 1
                ? AppColors.primaryBlue.withValues(alpha: 0.35)
                : AppColors.line(dark: dark),
          ),
          Expanded(
            child: _StepIndicatorItem(
              index: 2,
              title: i18n.t(
                zhHans: '绑定新手机号',
                zhHant: '綁定新手機號',
                en: 'Bind New Phone',
                ja: '新しい電話番号を登録',
                ko: '새 번호 등록',
              ),
              active: currentStep == 2,
              done: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicatorItem extends StatelessWidget {
  final int index;
  final String title;
  final bool active;
  final bool done;

  const _StepIndicatorItem({
    required this.index,
    required this.title,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final bool highlighted = active || done;

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: highlighted ? AppColors.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted
                  ? AppColors.primaryBlue
                  : AppColors.line(dark: dark),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: highlighted ? Colors.white : AppColors.subText(dark: dark),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: highlighted
                  ? AppColors.text(dark: dark)
                  : AppColors.subText(dark: dark),
              fontSize: 14,
              fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
