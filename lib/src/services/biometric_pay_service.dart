import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';
// ignore: unnecessary_import — explicit dep for openAppSettings (also re-exported by uikit)
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_config.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

enum BiometricAuthStatus {
  success,
  cancelled,
  unavailable,
  notEnrolled,
  failed,
}

class BiometricAuthResult {
  final BiometricAuthStatus status;

  const BiometricAuthResult(this.status);

  bool get success => status == BiometricAuthStatus.success;
  bool get cancelled => status == BiometricAuthStatus.cancelled;
  bool get notEnrolled => status == BiometricAuthStatus.notEnrolled;
}

/// 用于文案 / 图标：仅在系统明确报告 [BiometricType.face] 时视为面容。
enum BiometricPayModality {
  face,
  fingerprint,
  faceAndFingerprint,
  /// 无法区分模态时的中性文案（如「生物识别支付」）。
  biometric,
}

/// 面容 / 指纹快捷支付：本地生物识别解锁后读取已缓存 payPin。
class BiometricPayService {
  BiometricPayService._();

  static final BiometricPayService instance = BiometricPayService._();

  static const _enabledKey = 'biometric_pay_enabled';
  static const _promptNeverKey = 'biometric_pay_prompt_never';
  static const _promptLastAtKey = 'biometric_pay_prompt_last_at';
  static const _pinKey = 'biometric_pay_pin';
  static const _userIdKey = 'biometric_pay_user_id';

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  bool get isAvailableOnPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  static String? currentUserId() {
    final id = TIMUIKitCore.getInstance().loginUserInfo?.userID?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  Future<bool> isDeviceSupported() async {
    if (!isAvailableOnPlatform) return false;
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    if (!isAvailableOnPlatform) return false;
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableTypes() async {
    if (!isAvailableOnPlatform) return const [];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// 系统是否已录入可供 App 使用的生物识别（非锁屏专用人脸）。
  Future<bool> hasEnrolledBiometrics() async {
    final types = await getAvailableTypes();
    return types.isNotEmpty;
  }

  /// 打开系统设置，引导用户录入指纹 / 面容。
  Future<bool> openSystemSettings() => openAppSettings();

  /// 解析当前设备生物识别模态，供文案与图标使用。
  ///
  /// - 仅 [BiometricType.face] 才算「面容」
  /// - Android 上 `strong` / `weak` 视为指纹（非面容）
  /// - 未录入时：iOS 默认面容，Android 默认指纹
  BiometricPayModality resolveModality(List<BiometricType> types) {
    final hasFace = types.contains(BiometricType.face);
    final hasFinger = types.contains(BiometricType.fingerprint) ||
        types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak);

    if (hasFace && hasFinger) return BiometricPayModality.faceAndFingerprint;
    if (hasFace) return BiometricPayModality.face;
    if (hasFinger) return BiometricPayModality.fingerprint;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return BiometricPayModality.face;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return BiometricPayModality.fingerprint;
    }
    return BiometricPayModality.biometric;
  }

  Future<BiometricPayModality> currentModality() async {
    return resolveModality(await getAvailableTypes());
  }

  bool usesFaceUi(BiometricPayModality modality) =>
      modality == BiometricPayModality.face ||
      modality == BiometricPayModality.faceAndFingerprint;

  Future<bool> isEnabled() async {
    if (!isAvailableOnPlatform) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_enabledKey) != '1') return false;
    return _isStoredUserMatched();
  }

  Future<void> setEnabled(bool on) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_enabledKey, on ? '1' : '0');
  }

  Future<void> savePayPin({
    required String userId,
    required String pin,
  }) async {
    final trimmedUser = userId.trim();
    final trimmedPin = pin.trim();
    if (trimmedUser.isEmpty || trimmedPin.length != 6) return;
    await _secure.write(key: _userIdKey, value: trimmedUser);
    await _secure.write(key: _pinKey, value: trimmedPin);
    await setEnabled(true);
  }

  Future<String?> readPayPinForCurrentUser() async {
    if (!await _isStoredUserMatched()) {
      await disableAndClear();
      return null;
    }
    final pin = await _secure.read(key: _pinKey);
    final trimmed = pin?.trim() ?? '';
    if (trimmed.length != 6) {
      await disableAndClear();
      return null;
    }
    return trimmed;
  }

  Future<void> disableAndClear() async {
    await setEnabled(false);
    await _secure.delete(key: _pinKey);
    await _secure.delete(key: _userIdKey);
  }

  Future<BiometricAuthResult> authenticate({
    required AppI18n i18n,
    String? reason,
  }) async {
    if (!isAvailableOnPlatform) {
      return const BiometricAuthResult(BiometricAuthStatus.unavailable);
    }
    try {
      final supported = await isDeviceSupported();
      if (!supported) {
        return const BiometricAuthResult(BiometricAuthStatus.unavailable);
      }
      if (!await hasEnrolledBiometrics()) {
        return const BiometricAuthResult(BiometricAuthStatus.notEnrolled);
      }

      final ok = await _localAuth.authenticate(
        localizedReason: reason ?? authenticateReason(i18n),
        authMessages: _platformAuthMessages(i18n),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return BiometricAuthResult(
        ok ? BiometricAuthStatus.success : BiometricAuthStatus.failed,
      );
    } on PlatformException catch (e) {
      final code = e.code.toLowerCase();
      if (code.contains('not_enrolled') ||
          code.contains('notenrolled') ||
          code.contains('passcode_not_set') ||
          code == 'no_biometrics') {
        return const BiometricAuthResult(BiometricAuthStatus.notEnrolled);
      }
      if (code.contains('cancel') ||
          code.contains('abort') ||
          code.contains('user_fallback')) {
        return const BiometricAuthResult(BiometricAuthStatus.cancelled);
      }
      return const BiometricAuthResult(BiometricAuthStatus.failed);
    } catch (_) {
      return const BiometricAuthResult(BiometricAuthStatus.failed);
    }
  }

  /// local_auth 默认弹窗为英文，按应用语言覆盖 iOS / Android 系统提示文案。
  List<AuthMessages> _platformAuthMessages(AppI18n i18n) {
    final cancel = i18n.t(
      zhHans: '取消',
      zhHant: '取消',
      en: 'Cancel',
      ja: 'キャンセル',
      ko: '취소',
    );
    final goSettings = i18n.t(
      zhHans: '去设置',
      zhHant: '去設定',
      en: 'Go to Settings',
      ja: '設定を開く',
      ko: '설정으로',
    );
    final notSetUp = i18n.t(
      zhHans: '设备尚未设置生物识别。请在系统设置中录入指纹或面容后重试。',
      zhHant: '裝置尚未設定生物辨識。請在系統設定中錄入指紋或面容後重試。',
      en:
          'Biometric authentication is not set up. Add a fingerprint or face in Settings, then try again.',
      ja: '生体認証が未設定です。設定で指紋または顔を登録してから再試行してください。',
      ko: '생체 인증이 설정되지 않았습니다. 설정에서 지문 또는 얼굴을 등록한 뒤 다시 시도해 주세요.',
    );

    return <AuthMessages>[
      IOSAuthMessages(
        lockOut: i18n.t(
          zhHans: '生物识别已停用，请锁定并解锁屏幕后重试。',
          zhHant: '生物辨識已停用，請鎖定並解鎖螢幕後重試。',
          en:
              'Biometric authentication is disabled. Lock and unlock your screen to enable it.',
          ja: '生体認証が無効です。画面をロックして解除してから再試行してください。',
          ko: '생체 인증이 비활성화되었습니다. 화면을 잠근 뒤 잠금 해제하고 다시 시도해 주세요.',
        ),
        goToSettingsButton: goSettings,
        goToSettingsDescription: i18n.t(
          zhHans: '设备尚未设置面容 ID 或触控 ID。请在系统设置中开启后重试。',
          zhHant: '裝置尚未設定面容 ID 或觸控 ID。請在系統設定中開啟後重試。',
          en:
              'Face ID or Touch ID is not set up. Enable it in Settings, then try again.',
          ja: 'Face ID または Touch ID が未設定です。設定で有効にしてから再試行してください。',
          ko: 'Face ID 또는 Touch ID가 설정되지 않았습니다. 설정에서 켠 뒤 다시 시도해 주세요.',
        ),
        cancelButton: cancel,
      ),
      AndroidAuthMessages(
        biometricHint: i18n.t(
          zhHans: '验证身份',
          zhHant: '驗證身分',
          en: 'Verify identity',
          ja: '本人確認',
          ko: '본인 확인',
        ),
        biometricNotRecognized: i18n.t(
          zhHans: '未识别，请重试',
          zhHant: '未識別，請重試',
          en: 'Not recognized. Try again.',
          ja: '認識できません。もう一度お試しください。',
          ko: '인식되지 않았습니다. 다시 시도해 주세요.',
        ),
        biometricSuccess: i18n.t(
          zhHans: '验证成功',
          zhHant: '驗證成功',
          en: 'Success',
          ja: '成功',
          ko: '성공',
        ),
        biometricRequiredTitle: i18n.t(
          zhHans: '需要生物识别',
          zhHant: '需要生物辨識',
          en: 'Biometric required',
          ja: '生体認証が必要です',
          ko: '생체 인증 필요',
        ),
        cancelButton: cancel,
        deviceCredentialsRequiredTitle: i18n.t(
          zhHans: '需要设备解锁方式',
          zhHant: '需要裝置解鎖方式',
          en: 'Device credentials required',
          ja: 'デバイス認証が必要です',
          ko: '기기 인증 필요',
        ),
        deviceCredentialsSetupDescription: i18n.t(
          zhHans: '请先在系统设置中设置锁屏密码。',
          zhHant: '請先在系統設定中設定鎖屏密碼。',
          en: 'Set a screen lock in Settings first.',
          ja: '先に設定で画面ロックを設定してください。',
          ko: '먼저 설정에서 화면 잠금을 설정해 주세요.',
        ),
        goToSettingsButton: goSettings,
        goToSettingsDescription: notSetUp,
        signInTitle: i18n.t(
          zhHans: '需要验证身份',
          zhHant: '需要驗證身分',
          en: 'Authentication required',
          ja: '認証が必要です',
          ko: '인증 필요',
        ),
      ),
    ];
  }

  Future<bool> enableWithVerifiedPin({
    required String pin,
    required AppI18n i18n,
  }) async {
    final userId = currentUserId();
    if (userId == null) return false;

    final auth = await authenticate(
      i18n: i18n,
      reason: enableAuthReason(i18n),
    );
    if (!auth.success) return false;

    await savePayPin(userId: userId, pin: pin);
    return true;
  }

  Future<bool> isPromptNever() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_promptNeverKey) == '1';
  }

  Future<void> setPromptNever(bool never) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptNeverKey, never ? '1' : '0');
  }

  Future<DateTime?> getPromptLastAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_promptLastAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markPromptShownNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_promptLastAtKey, DateTime.now().toIso8601String());
  }

  Future<bool> shouldShowEnablePrompt({required PayAuthMethod authMethod}) async {
    if (!BiometricPayConfig.enablePostPayPrompt) return false;
    if (!isAvailableOnPlatform) return false;
    if (authMethod != PayAuthMethod.manual) return false;
    if (await isEnabled()) return false;
    if (!await isDeviceSupported()) return false;
    if (await isPromptNever()) return false;

    final lastAt = await getPromptLastAt();
    if (lastAt != null &&
        DateTime.now().difference(lastAt) < BiometricPayConfig.promptCooldown) {
      return false;
    }
    return true;
  }

  Future<String> paymentLabel(AppI18n i18n) async {
    return _labelForModality(await currentModality(), i18n);
  }

  Future<String> enableTitle(AppI18n i18n) async {
    switch (await currentModality()) {
      case BiometricPayModality.face:
        return i18n.t(
          zhHans: '开启面容支付',
          zhHant: '開啟面容支付',
          en: 'Enable Face ID Pay',
          ja: 'Face ID 支払いを有効にする',
          ko: 'Face ID 결제 사용',
        );
      case BiometricPayModality.fingerprint:
        return i18n.t(
          zhHans: '开启指纹支付',
          zhHant: '開啟指紋支付',
          en: 'Enable Fingerprint Pay',
          ja: '指紋支払いを有効にする',
          ko: '지문 결제 사용',
        );
      case BiometricPayModality.faceAndFingerprint:
        return i18n.t(
          zhHans: '开启面容/指纹支付',
          zhHant: '開啟面容/指紋支付',
          en: 'Enable Biometric Pay',
          ja: '生体認証支払いを有効にする',
          ko: '생체 인증 결제 사용',
        );
      case BiometricPayModality.biometric:
        return i18n.t(
          zhHans: '开启生物识别支付',
          zhHant: '開啟生物辨識支付',
          en: 'Enable Biometric Pay',
          ja: '生体認証支払いを有効にする',
          ko: '생체 인증 결제 사용',
        );
    }
  }

  String _labelForModality(BiometricPayModality modality, AppI18n i18n) {
    switch (modality) {
      case BiometricPayModality.face:
        return i18n.t(
          zhHans: '面容支付',
          zhHant: '面容支付',
          en: defaultTargetPlatform == TargetPlatform.iOS
              ? 'Face ID Pay'
              : 'Face Pay',
          ja: 'Face ID 支払い',
          ko: 'Face ID 결제',
        );
      case BiometricPayModality.fingerprint:
        return i18n.t(
          zhHans: '指纹支付',
          zhHant: '指紋支付',
          en: 'Fingerprint Pay',
          ja: '指紋支払い',
          ko: '지문 결제',
        );
      case BiometricPayModality.faceAndFingerprint:
        return i18n.t(
          zhHans: '面容/指纹支付',
          zhHant: '面容/指紋支付',
          en: 'Biometric Pay',
          ja: '生体認証支払い',
          ko: '생체 인증 결제',
        );
      case BiometricPayModality.biometric:
        return i18n.t(
          zhHans: '生物识别支付',
          zhHant: '生物辨識支付',
          en: 'Biometric Pay',
          ja: '生体認証支払い',
          ko: '생체 인증 결제',
        );
    }
  }

  String authenticateReason(AppI18n i18n) {
    return i18n.t(
      zhHans: '验证身份以完成支付',
      zhHant: '驗證身分以完成支付',
      en: 'Verify your identity to complete payment',
      ja: '本人確認のうえ支払いを完了します',
      ko: '본인 확인 후 결제를 완료합니다',
    );
  }

  String enableAuthReason(AppI18n i18n) {
    return i18n.t(
      zhHans: '验证身份以开启快捷支付',
      zhHant: '驗證身分以開啟快捷支付',
      en: 'Verify your identity to enable quick pay',
      ja: '本人確認のうえクイック支払いを有効にします',
      ko: '본인 확인 후 빠른 결제를 사용합니다',
    );
  }

  Future<String> enabledToast(AppI18n i18n) async {
    final label = await paymentLabel(i18n);
    return i18n.t(
      zhHans: '$label已开启',
      zhHant: '$label已開啟',
      en: '$label is enabled',
      ja: '$labelを有効にしました',
      ko: '$label가 사용 설정되었습니다',
    );
  }

  Future<String> disabledToast(AppI18n i18n) async {
    final label = await paymentLabel(i18n);
    return i18n.t(
      zhHans: '$label已关闭',
      zhHant: '$label已關閉',
      en: '$label is disabled',
      ja: '$labelを無効にしました',
      ko: '$label가 해제되었습니다',
    );
  }

  Future<bool> _isStoredUserMatched() async {
    final current = currentUserId();
    if (current == null) return false;
    final stored = (await _secure.read(key: _userIdKey))?.trim() ?? '';
    return stored.isNotEmpty && stored == current;
  }
}

enum PayAuthMethod {
  manual,
  biometric,
}
