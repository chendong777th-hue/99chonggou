import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';

class AuthLocalizations {
  const AuthLocalizations._(this.locale);

  final Locale locale;

  static AuthLocalizations of(BuildContext context) {
    return AuthLocalizations._(Localizations.localeOf(context));
  }

  static AuthLocalizations fromAppLocale(AppLocale locale) {
    switch (locale) {
      case AppLocale.zhHant:
        return AuthLocalizations._(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );
      case AppLocale.en:
        return AuthLocalizations._(const Locale('en'));
      case AppLocale.ja:
        return AuthLocalizations._(const Locale('ja'));
      case AppLocale.ko:
        return AuthLocalizations._(const Locale('ko'));
      case AppLocale.zhHans:
        return AuthLocalizations._(const Locale('zh'));
    }
  }

  bool get _isZhHant {
    if (locale.languageCode != 'zh') {
      return false;
    }
    return locale.scriptCode == 'Hant' ||
        locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.countryCode == 'MO';
  }

  bool get _isEn => locale.languageCode == 'en';
  bool get _isJa => locale.languageCode == 'ja';
  bool get _isKo => locale.languageCode == 'ko';

  String get hello {
    if (_isZhHant) return '你好，';
    if (_isEn) return 'Hello,';
    if (_isJa) return 'こんにちは、';
    if (_isKo) return '안녕하세요,';
    return '你好，';
  }

  String welcomeUse(String appName) {
    if (_isZhHant) return '歡迎使用$appName';
    if (_isEn) return 'Welcome to $appName';
    if (_isJa) return '$appName へようこそ';
    if (_isKo) return '$appName에 오신 것을 환영합니다';
    return '欢迎使用$appName';
  }

  String get loginTab {
    if (_isZhHant) return '登入';
    if (_isEn) return 'Login';
    if (_isJa) return 'ログイン';
    if (_isKo) return '로그인';
    return '登录';
  }

  String get registerTab {
    if (_isZhHant) return '註冊';
    if (_isEn) return 'Register';
    if (_isJa) return '新規登録';
    if (_isKo) return '회원가입';
    return '注册';
  }

  String get findPassword {
    if (_isZhHant) return '找回密碼';
    if (_isEn) return 'Reset Password';
    if (_isJa) return 'パスワードをリセット';
    if (_isKo) return '비밀번호 찾기';
    return '找回密码';
  }

  String get phoneLabel {
    if (_isZhHant) return '手機號';
    if (_isEn) return 'Phone';
    if (_isJa) return '電話番号';
    if (_isKo) return '휴대폰 번호';
    return '手机号';
  }

  String get accountLabel {
    if (_isZhHant) return '帳號';
    if (_isEn) return 'Account';
    if (_isJa) return 'アカウント';
    if (_isKo) return '계정';
    return '账号';
  }

  String get passwordLabel {
    if (_isZhHant) return '密碼';
    if (_isEn) return 'Password';
    if (_isJa) return 'パスワード';
    if (_isKo) return '비밀번호';
    return '密码';
  }

  String get rememberPassword {
    if (_isZhHant) return '記住密碼';
    if (_isEn) return 'Remember password';
    if (_isJa) return 'パスワードを記憶';
    if (_isKo) return '비밀번호 기억';
    return '记住密码';
  }

  String get smsCodeLabel {
    if (_isZhHant) return '驗證碼';
    if (_isEn) return 'Verification Code';
    if (_isJa) return '確認コード';
    if (_isKo) return '인증 코드';
    return '验证码';
  }

  String get newPasswordLabel {
    if (_isZhHant) return '新密碼';
    if (_isEn) return 'New Password';
    if (_isJa) return '新しいパスワード';
    if (_isKo) return '새 비밀번호';
    return '新密码';
  }

  String get confirmPasswordLabel {
    if (_isZhHant) return '確認密碼';
    if (_isEn) return 'Confirm Password';
    if (_isJa) return 'パスワード確認';
    if (_isKo) return '비밀번호 확인';
    return '确认密码';
  }

  String get enterPhone {
    if (_isZhHant) return '請輸入手機號';
    if (_isEn) return 'Enter phone number';
    if (_isJa) return '電話番号を入力';
    if (_isKo) return '휴대폰 번호를 입력하세요';
    return '请输入手机号';
  }

  String get smsCodeHint {
    if (_isZhHant) return '6 位簡訊驗證碼';
    if (_isEn) return '6-digit SMS code';
    if (_isJa) return '6桁のSMS認証コード';
    if (_isKo) return '6자리 문자 인증 코드';
    return '6 位短信验证码';
  }

  String get enterAccount {
    if (_isZhHant) return '請輸入帳號';
    if (_isEn) return 'Enter account';
    if (_isJa) return 'アカウントを入力';
    if (_isKo) return '계정을 입력하세요';
    return '请输入账号';
  }

  String get enterUsernameOrEmail {
    if (_isZhHant) return '請輸入手機號或用戶ID';
    if (_isEn) return 'Enter phone number or user ID';
    if (_isJa) return '電話番号またはユーザーIDを入力';
    if (_isKo) return '휴대폰 번호 또는 사용자 ID를 입력하세요';
    return '请输入手机号或用户ID';
  }

  String get enterPassword {
    if (_isZhHant) return '請輸入密碼';
    if (_isEn) return 'Enter password';
    if (_isJa) return 'パスワードを入力';
    if (_isKo) return '비밀번호를 입력하세요';
    return '请输入密码';
  }

  String get enterNickname {
    if (_isZhHant) return '請輸入暱稱';
    if (_isEn) return 'Enter nickname';
    if (_isJa) return 'ニックネームを入力';
    if (_isKo) return '닉네임을 입력하세요';
    return '请输入昵称';
  }

  String get enterPasswordRule {
    if (_isZhHant) return '請輸入英文數字組合密碼';
    if (_isEn) return 'Enter letters and numbers password';
    if (_isJa) return '英字と数字を含むパスワードを入力';
    if (_isKo) return '영문과 숫자를 포함한 비밀번호를 입력하세요';
    return '请输入英文数字组合密码';
  }

  String get enterPasswordAgain {
    if (_isZhHant) return '請再次輸入密碼';
    if (_isEn) return 'Enter password again';
    if (_isJa) return 'もう一度パスワードを入力';
    if (_isKo) return '비밀번호를 다시 입력하세요';
    return '请再次输入密码';
  }

  String get switchToPasswordLogin {
    if (_isZhHant) return '切換帳號密碼登入';
    if (_isEn) return 'Use account password login';
    if (_isJa) return 'アカウントとパスワードでログイン';
    if (_isKo) return '계정 비밀번호 로그인으로 전환';
    return '切换账号密码登录';
  }

  String get switchToSmsLogin {
    if (_isZhHant) return '切換驗證碼登入';
    if (_isEn) return 'Use SMS login';
    if (_isJa) return '認証コードログインに切り替え';
    if (_isKo) return '문자 로그인으로 전환';
    return '切换验证码登录';
  }

  String get switchToQrLogin {
    if (_isZhHant) return '掃碼登入';
    if (_isEn) return 'Scan QR to login';
    if (_isJa) return 'QRコードでログイン';
    if (_isKo) return 'QR 로그인';
    return '扫码登录';
  }

  String get qrLoginTitle {
    if (_isZhHant) return '手機掃碼登入';
    if (_isEn) return 'Scan with mobile app';
    if (_isJa) return 'スマホでスキャンしてログイン';
    if (_isKo) return '모바일 앱으로 스캔하여 로그인';
    return '手机扫码登录';
  }

  String get qrLoginHint {
    if (_isZhHant) return '請使用已登入的手機 App 掃描二維碼';
    if (_isEn) return 'Scan this code with the logged-in mobile app';
    if (_isJa) return 'ログイン済みのスマホアプリでQRコードをスキャンしてください';
    if (_isKo) return '로그인된 모바일 앱으로 QR 코드를 스캔하세요';
    return '请使用已登录的手机 App 扫描二维码';
  }

  String get qrLoginWaitingScan {
    if (_isZhHant) return '等待掃碼…';
    if (_isEn) return 'Waiting for scan…';
    if (_isJa) return 'スキャン待ち…';
    if (_isKo) return '스캔 대기 중…';
    return '等待扫码…';
  }

  String get qrLoginScannedConfirmOnPhone {
    if (_isZhHant) return '已掃碼，請在手機上確認';
    if (_isEn) return 'Scanned. Confirm on your phone';
    if (_isJa) return 'スキャン済み。スマホで確認してください';
    if (_isKo) return '스캔됨. 휴대폰에서 확인해 주세요';
    return '已扫码，请在手机上确认';
  }

  String get qrLoginExpired {
    if (_isZhHant) return '二維碼已過期';
    if (_isEn) return 'QR code expired';
    if (_isJa) return 'QRコードの有効期限切れ';
    if (_isKo) return 'QR 코드가 만료되었습니다';
    return '二维码已过期';
  }

  String get qrLoginCancelled {
    if (_isZhHant) return '已在手機上取消登入';
    if (_isEn) return 'Login cancelled on phone';
    if (_isJa) return 'スマホでログインがキャンセルされました';
    if (_isKo) return '휴대폰에서 로그인이 취소되었습니다';
    return '已在手机上取消登录';
  }

  String get qrLoginRefresh {
    if (_isZhHant) return '刷新二維碼';
    if (_isEn) return 'Refresh QR code';
    if (_isJa) return 'QRコードを更新';
    if (_isKo) return 'QR 코드 새로고침';
    return '刷新二维码';
  }

  String get qrLoginUnavailable {
    if (_isZhHant) return '掃碼登入暫不可用';
    if (_isEn) return 'QR login is not available yet';
    if (_isJa) return 'QRログインは現在利用できません';
    if (_isKo) return 'QR 로그인을 아직 사용할 수 없습니다';
    return '扫码登录暂不可用';
  }

  String get qrWebLoginConfirmTitle {
    if (_isZhHant) return '確認登入網頁版';
    if (_isEn) return 'Confirm web login';
    if (_isJa) return 'ウェブ版ログインを確認';
    if (_isKo) return '웹 로그인 확인';
    return '确认登录网页版';
  }

  String get qrWebLoginConfirmMessage {
    if (_isZhHant) return '即將授權當前帳號登入網頁版，請確認是本人操作。';
    if (_isEn) {
      return 'Authorize this account to sign in on the web. Confirm it is you.';
    }
    if (_isJa) return 'このアカウントでウェブ版へのログインを許可します。本人操作か確認してください。';
    if (_isKo) return '이 계정으로 웹 로그인을 승인합니다. 본인 확인 후 진행하세요.';
    return '即将授权当前账号登录网页版，请确认是本人操作。';
  }

  String get qrWebLoginConfirmAction {
    if (_isZhHant) return '確認登入';
    if (_isEn) return 'Confirm login';
    if (_isJa) return 'ログインを確認';
    if (_isKo) return '로그인 확인';
    return '确认登录';
  }

  String get qrWebLoginCancelAction {
    if (_isZhHant) return '取消';
    if (_isEn) return 'Cancel';
    if (_isJa) return 'キャンセル';
    if (_isKo) return '취소';
    return '取消';
  }

  String get qrWebLoginConfirmedToast {
    if (_isZhHant) return '已確認，請回到網頁查看';
    if (_isEn) return 'Confirmed. Return to the web page';
    if (_isJa) return '確認しました。ウェブページに戻ってください';
    if (_isKo) return '확인됨. 웹 페이지로 돌아가세요';
    return '已确认，请回到网页查看';
  }

  String get qrWebLoginCancelledToast {
    if (_isZhHant) return '已取消網頁登入';
    if (_isEn) return 'Web login cancelled';
    if (_isJa) return 'ウェブログインをキャンセルしました';
    if (_isKo) return '웹 로그인이 취소되었습니다';
    return '已取消网页登录';
  }

  String get qrWebLoginNeedAppLogin {
    if (_isZhHant) return '請先登入 App 後再掃碼登入網頁版';
    if (_isEn) {
      return 'Please sign in to the app before scanning for web login';
    }
    if (_isJa) return 'ウェブログインをスキャンする前にアプリへログインしてください';
    if (_isKo) return '웹 로그인 스캔 전에 앱에 먼저 로그인하세요';
    return '请先登录 App 后再扫码登录网页版';
  }

  String get qrWebLoginSessionExpired {
    if (_isZhHant) return '二維碼已失效，請讓網頁刷新後再掃';
    if (_isEn) {
      return 'QR code expired. Refresh the web page and scan again';
    }
    if (_isJa) return 'QRコードの有効期限切れです。ウェブを更新して再度スキャンしてください';
    if (_isKo) return 'QR 코드가 만료되었습니다. 웹 페이지를 새로고침한 뒤 다시 스캔하세요';
    return '二维码已失效，请让网页刷新后再扫';
  }

  String get qrWebLoginSessionBound {
    if (_isZhHant) return '該二維碼已被其他帳號掃描';
    if (_isEn) return 'This QR code was scanned by another account';
    if (_isJa) return 'このQRコードは他のアカウントがスキャン済みです';
    if (_isKo) return '이 QR 코드는 다른 계정이 이미 스캔했습니다';
    return '该二维码已被其他账号扫描';
  }

  String get qrWebLoginSessionInvalidStatus {
    if (_isZhHant) return '狀態異常，請刷新網頁二維碼後重試';
    if (_isEn) {
      return 'Invalid status. Refresh the web QR code and try again';
    }
    if (_isJa) return '状態が不正です。ウェブのQRを更新して再試行してください';
    if (_isKo) return '상태가 올바르지 않습니다. 웹 QR을 새로고침한 뒤 다시 시도하세요';
    return '状态异常，请刷新网页二维码后重试';
  }

  String get qrWebLoginScannerMismatch {
    if (_isZhHant) return '請使用掃碼的帳號進行確認';
    if (_isEn) return 'Please confirm with the account that scanned the code';
    if (_isJa) return 'スキャンしたアカウントで確認してください';
    if (_isKo) return '스캔한 계정으로 확인해 주세요';
    return '请使用扫码的账号进行确认';
  }

  String get qrWebLoginDeviceBanned {
    if (_isZhHant) return '該設備不可用，無法登入網頁版';
    if (_isEn) return 'This device cannot sign in to the web version';
    if (_isJa) return 'このデバイスではウェブ版にログインできません';
    if (_isKo) return '이 기기에서는 웹 버전에 로그인할 수 없습니다';
    return '该设备不可用，无法登录网页版';
  }

  String get forgotPasswordAction {
    if (_isZhHant) return '忘記密碼？';
    if (_isEn) return 'Forgot password?';
    if (_isJa) return 'パスワードをお忘れですか？';
    if (_isKo) return '비밀번호를 잊으셨나요?';
    return '忘记密码？';
  }

  String get loginButton {
    if (_isZhHant) return '登入';
    if (_isEn) return 'Login';
    if (_isJa) return 'ログイン';
    if (_isKo) return '로그인';
    return '登录';
  }

  String get loggingIn {
    if (_isZhHant) return '正在登入';
    if (_isEn) return 'Logging in';
    if (_isJa) return 'ログイン中';
    if (_isKo) return '로그인 중';
    return '正在登陆';
  }

  String get registerButton {
    if (_isZhHant) return '註冊';
    if (_isEn) return 'Register';
    if (_isJa) return '新規登録';
    if (_isKo) return '회원가입';
    return '注册';
  }

  String get registering {
    if (_isZhHant) return '正在註冊';
    if (_isEn) return 'Registering';
    if (_isJa) return '登録中';
    if (_isKo) return '가입 중';
    return '正在注册';
  }

  String get resetPasswordButton {
    if (_isZhHant) return '重設密碼';
    if (_isEn) return 'Reset Password';
    if (_isJa) return 'パスワードをリセット';
    if (_isKo) return '비밀번호 재설정';
    return '重置密码';
  }

  String get getCode {
    if (_isZhHant) return '獲取驗證碼';
    if (_isEn) return 'Get Code';
    if (_isJa) return 'コードを取得';
    if (_isKo) return '인증코드 받기';
    return '获取验证码';
  }

  String get send {
    if (_isZhHant) return '發送';
    if (_isEn) return 'Send';
    if (_isJa) return '送信';
    if (_isKo) return '전송';
    return '发送';
  }

  String get deviceVerifyTitle {
    if (_isZhHant) return '設備驗證';
    if (_isEn) return 'Device Verification';
    if (_isJa) return 'デバイス確認';
    if (_isKo) return '기기 인증';
    return '设备验证';
  }

  String get deviceVerifySubtitle {
    if (_isZhHant) return '檢測到新設備登入，需要驗證身份';
    if (_isEn) return 'New device login detected. Verification is required.';
    if (_isJa) return '新しい端末からのログインが検出されました。本人確認が必要です。';
    if (_isKo) return '새 기기 로그인 감지됨. 본인 확인이 필요합니다.';
    return '检测到新设备登录，需要验证身份';
  }

  String get deviceVerifySmsHint {
    if (_isZhHant) return '驗證碼將發送到您帳號綁定的手機號，請點擊右側發送';
    if (_isEn) {
      return 'A code will be sent to your bound phone number. Tap Send on the right';
    }
    if (_isJa) return '登録電話番号に確認コードを送信します。右の「送信」をタップしてください';
    if (_isKo) return '등록된 휴대폰 번호로 인증 코드를 보냅니다. 오른쪽 전송을 누르세요';
    return '验证码将发送到您账号绑定的手机号，请点击右侧发送';
  }

  String codeSentTo(String phoneMasked) {
    if (_isZhHant) return '驗證碼將發送到 $phoneMasked';
    if (_isEn) return 'The verification code will be sent to $phoneMasked';
    if (_isJa) return '確認コードは $phoneMasked に送信されます';
    if (_isKo) return '인증 코드는 $phoneMasked 로 전송됩니다';
    return '验证码将发送到 $phoneMasked';
  }

  String get sixDigitCodeHint {
    if (_isZhHant) return '6 位驗證碼';
    if (_isEn) return '6-digit code';
    if (_isJa) return '6桁の認証コード';
    if (_isKo) return '6자리 인증 코드';
    return '6 位验证码';
  }

  String get confirmLogin {
    if (_isZhHant) return '確認登入';
    if (_isEn) return 'Confirm Login';
    if (_isJa) return 'ログインを確認';
    if (_isKo) return '로그인 확인';
    return '确认登录';
  }

  String get agreeRegisterPrefix {
    if (_isZhHant) return '註冊代表同意';
    if (_isEn) return 'By registering, you agree to';
    if (_isJa) return '登録は以下への同意を意味します';
    if (_isKo) return '회원가입은 다음에 동의함을 의미합니다';
    return '注册代表同意';
  }

  String get userAgreementTitle {
    if (_isZhHant) return '用戶協議';
    if (_isEn) return 'User Agreement';
    if (_isJa) return '利用規約';
    if (_isKo) return '이용약관';
    return '用户协议';
  }


  String get codeSentSuccess {
    if (_isZhHant) return '驗證碼已發送';
    if (_isEn) return 'Verification code sent';
    if (_isJa) return '確認コードを送信しました';
    if (_isKo) return '인증 코드가 전송되었습니다';
    return '验证码已发送';
  }

  String get phoneMust11 {
    if (_isZhHant) return '手機號需為 11 位數字';
    if (_isEn) return 'Phone number must be 11 digits';
    if (_isJa) return '電話番号は11桁の数字で入力してください';
    if (_isKo) return '휴대폰 번호는 11자리 숫자여야 합니다';
    return '手机号需为 11 位数字';
  }

  String get enterSmsCode {
    if (_isZhHant) return '請輸入驗證碼';
    if (_isEn) return 'Enter verification code';
    if (_isJa) return '認証コードを入力';
    if (_isKo) return '인증 코드를 입력하세요';
    return '请输入验证码';
  }

  String get smsCodeMust6 {
    if (_isZhHant) return '驗證碼需為 6 位數字';
    if (_isEn) return 'Verification code must be 6 digits';
    if (_isJa) return '認証コードは6桁で入力してください';
    if (_isKo) return '인증 코드는 6자리 숫자여야 합니다';
    return '验证码需为 6 位数字';
  }

  String get passwordMin8 {
    if (_isZhHant) return '密碼至少 8 位';
    if (_isEn) return 'Password must be at least 8 characters';
    if (_isJa) return 'パスワードは8文字以上で入力してください';
    if (_isKo) return '비밀번호는 8자 이상이어야 합니다';
    return '密码至少 8 位';
  }

  String imLoginFailed(String desc) {
    if (_isZhHant) return 'IM 登入失敗：$desc';
    if (_isEn) return 'IM login failed: $desc';
    if (_isJa) return 'IM ログインに失敗しました: $desc';
    if (_isKo) return 'IM 로그인 실패: $desc';
    return 'IM 登录失败：$desc';
  }

  String get nicknameMin2 {
    if (_isZhHant) return '暱稱至少 2 位';
    if (_isEn) return 'Nickname must be at least 2 characters';
    if (_isJa) return 'ニックネームは2文字以上で入力してください';
    if (_isKo) return '닉네임은 2자 이상이어야 합니다';
    return '昵称至少 2 位';
  }

  String get passwordRule {
    if (_isZhHant) return '密碼需為 8 位以上英文和數字組合';
    if (_isEn) return 'Password must contain letters and numbers with at least 8 characters';
    if (_isJa) return 'パスワードは8文字以上で、英字と数字を含めてください';
    if (_isKo) return '비밀번호는 8자 이상이며 영문과 숫자를 포함해야 합니다';
    return '密码需为 8 位以上英文和数字组合';
  }

  String get enterConfirmPassword {
    if (_isZhHant) return '請輸入確認密碼';
    if (_isEn) return 'Enter confirm password';
    if (_isJa) return '確認用パスワードを入力';
    if (_isKo) return '확인 비밀번호를 입력하세요';
    return '请输入确认密码';
  }

  String get passwordMismatch {
    if (_isZhHant) return '兩次輸入的密碼不一致';
    if (_isEn) return 'Passwords do not match';
    if (_isJa) return '入力したパスワードが一致しません';
    if (_isKo) return '비밀번호가 일치하지 않습니다';
    return '两次输入的密码不一致';
  }

  String get accountOrPasswordWrong {
    if (_isZhHant) return '帳號或密碼錯誤';
    if (_isEn) return 'Incorrect account or password';
    if (_isJa) return 'アカウントまたはパスワードが正しくありません';
    if (_isKo) return '계정 또는 비밀번호가 올바르지 않습니다';
    return '账号或密码错误';
  }

  String get accountNotFound {
    if (_isZhHant) return '帳號不存在';
    if (_isEn) return 'Account not found';
    if (_isJa) return 'アカウントが存在しません';
    if (_isKo) return '계정을 찾을 수 없습니다';
    return '账号不存在';
  }

  String get accountDisabled {
    if (_isZhHant) return '帳號已被禁用';
    if (_isEn) return 'Account has been disabled';
    if (_isJa) return 'アカウントは無効になっています';
    if (_isKo) return '계정이 비활성화되었습니다';
    return '账号已被禁用';
  }

  String get invalidPhone {
    if (_isZhHant) return '請輸入正確的手機號';
    if (_isEn) return 'Enter a valid phone number';
    if (_isJa) return '正しい電話番号を入力してください';
    if (_isKo) return '올바른 휴대폰 번호를 입력해 주세요';
    return '请输入正确的手机号';
  }

  String get invalidInput {
    if (_isZhHant) return '請求參數無效，請重新登入後再試';
    if (_isEn) return 'Invalid request. Please log in again and retry';
    if (_isJa) return 'リクエストが無効です。再度ログインしてお試しください';
    if (_isKo) return '요청이 올바르지 않습니다. 다시 로그인 후 시도하세요';
    return '请求参数无效，请重新登录后再试';
  }

  String get deviceVerifyPhoneUnavailable {
    if (_isZhHant) return '無法取得綁定手機號，請使用手機號登入';
    if (_isEn) return 'Bound phone unavailable. Sign in with your mobile number.';
    if (_isJa) return '登録電話番号を取得できません。携帯番号でログインしてください';
    if (_isKo) return '등록된 번호를 확인할 수 없습니다. 휴대폰 번호로 로그인하세요';
    return '无法获取绑定手机号，请使用手机号登录';
  }

  String get httpForbidden {
    if (_isZhHant) return '服務拒絕訪問，請稍後重試';
    if (_isEn) return 'Access denied. Please try again later';
    if (_isJa) return 'アクセスが拒否されました。しばらくしてからお試しください';
    if (_isKo) return '접근이 거부되었습니다. 잠시 후 다시 시도해 주세요';
    return '服务拒绝访问，请稍后重试';
  }

  String get requestFailed {
    if (_isZhHant) return '請求失敗，請稍後再試';
    if (_isEn) return 'Request failed, please try again later';
    if (_isJa) return 'リクエストに失敗しました。しばらくしてからお試しください';
    if (_isKo) return '요청에 실패했습니다. 잠시 후 다시 시도하세요';
    return '请求失败，请稍后再试';
  }

  String get networkUnavailable {
    if (_isZhHant) return '無法連接伺服器，請檢查網路後重試';
    if (_isEn) {
      return 'Unable to connect to the server. Check your network and try again';
    }
    if (_isJa) return 'サーバーに接続できません。ネットワークを確認して再試行してください';
    if (_isKo) return '서버에 연결할 수 없습니다. 네트워크를 확인한 후 다시 시도하세요';
    return '无法连接服务器，请检查网络后重试';
  }

  String get loadFailed {
    if (_isZhHant) return '載入失敗，請檢查網路後重試';
    if (_isEn) {
      return 'Failed to load. Please check your connection and try again.';
    }
    if (_isJa) return '読み込みに失敗しました。通信状況を確認してからもう一度お試しください。';
    if (_isKo) return '불러오기에 실패했습니다. 네트워크를 확인한 뒤 다시 시도해 주세요.';
    return '加载失败，请检查网络后重试';
  }

  String get smsCodeInvalid {
    if (_isZhHant) return '驗證碼錯誤';
    if (_isEn) return 'Verification code is incorrect';
    if (_isJa) return '認証コードが正しくありません';
    if (_isKo) return '인증 코드가 올바르지 않습니다';
    return '验证码错误';
  }

  String get smsCodeExpired {
    if (_isZhHant) return '驗證碼已過期，請重新獲取';
    if (_isEn) return 'Verification code expired. Please request a new one';
    if (_isJa) return '認証コードの有効期限が切れました。再取得してください';
    if (_isKo) return '인증 코드가 만료되었습니다. 다시 받아 주세요';
    return '验证码已过期，请重新获取';
  }

  String get challengeExpired {
    if (_isZhHant) return '驗證已過期，請重新登入';
    if (_isEn) return 'Verification expired, please log in again';
    if (_isJa) return '認証の有効期限が切れました。再度ログインしてください';
    if (_isKo) return '인증이 만료되었습니다. 다시 로그인하세요';
    return '验证已过期，请重新登录';
  }


  String get rateLimited {
    if (_isZhHant) return '請求太頻繁，請稍後再試';
    if (_isEn) return 'Too many requests, please try again later';
    if (_isJa) return 'リクエストが多すぎます。しばらくしてからお試しください';
    if (_isKo) return '요청이 너무 잦습니다. 잠시 후 다시 시도하세요';
    return '请求太频繁，请稍后再试';
  }


  String get smsCountryNotSupported {
    if (_isZhHant) return '該地區暫不支援註冊';
    if (_isEn) return 'Registration is not supported in this region';
    if (_isJa) return 'この地域では登録に対応していません';
    if (_isKo) return '이 지역은 회원가입을 지원하지 않습니다';
    return '该地区暂不支持注册';
  }

  String get smsProviderUnavailable {
    if (_isZhHant) return '驗證碼發送失敗，請稍後再試';
    if (_isEn) return 'Failed to send verification code. Please try again later';
    if (_isJa) return '認証コードの送信に失敗しました。しばらくしてからお試しください';
    if (_isKo) return '인증 코드 전송에 실패했습니다. 잠시 후 다시 시도해 주세요';
    return '验证码发送失败，请稍后重试';
  }

  String get smsSendRateLimited {
    if (_isZhHant) return '發送過於頻繁，請稍後再試';
    if (_isEn) return 'Too many requests. Please try again later';
    if (_isJa) return '送信が多すぎます。しばらくしてからお試しください';
    if (_isKo) return '전송이 너무 잦습니다. 잠시 후 다시 시도해 주세요';
    return '发送过于频繁，请稍后再试';
  }

  String get phoneRegistered {
    if (_isZhHant) return '該手機號已註冊';
    if (_isEn) return 'This phone number is already registered';
    if (_isJa) return 'この電話番号は既に登録されています';
    if (_isKo) return '이미 등록된 휴대폰 번호입니다';
    return '该手机号已注册';
  }

  String get resetPasswordButImFailed {
    if (_isZhHant) return '密碼重設成功但 IM 登入失敗';
    if (_isEn) return 'Password reset succeeded, but IM login failed';
    if (_isJa) return 'パスワードの再設定は成功しましたが、IM ログインに失敗しました';
    if (_isKo) return '비밀번호 재설정은 성공했지만 IM 로그인에 실패했습니다';
    return '密码重置成功但 IM 登录失败';
  }

  String get unregisteredPhone {
    if (_isZhHant) return '該手機號未註冊';
    if (_isEn) return 'This phone number is not registered';
    if (_isJa) return 'この電話番号は未登録です';
    if (_isKo) return '등록되지 않은 휴대폰 번호입니다';
    return '该手机号未注册';
  }
}
