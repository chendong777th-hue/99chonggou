import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/message_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';

enum ConnectStatus { success, failed, connecting }

class LocalSetting with ChangeNotifier {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  static const String _chatFontScaleKey = "chatFontScale";
  Timer? _connectStatusTimer;
  ConnectStatus? _pendingConnectStatus;

  /// Invoked when any notification preference changes (wired in main.dart).
  void Function()? onNotificationSettingsChanged;

  void _notifyNotificationSettingsChanged() {
    onNotificationSettingsChanged?.call();
  }

  /// Record is show reading status in historical message list
  bool? _isShowReadingStatus;

  /// Record is show online status of other users
  bool? _isShowOnlineStatus;

  /// The connection status to Tencent Server
  ConnectStatus? _connectStatus;

  /// Interface Language
  String? _language;

  /// Chat font scale in settings preview and future chat usage.
  double? _chatFontScale;

  bool? _notifySystemMessage;
  bool? _notifyVoiceVideoCall;
  bool? _notifyCallQuickAnswerPopup;
  NotificationDisplayMode? _notifyDisplayContent;
  bool? _notifyMessageBanner;
  NotificationDisplayMode? _notifyBannerDisplayContent;
  bool? _notifyMessageSound;
  String? _messageNotificationSoundId;
  bool? _notifyCallRingtone;
  bool? _notifyVibration;
  bool? _notificationPermissionPromptShown;
  bool? _batteryOptimizationGuideShown;

  ConnectStatus get connectStatus => _connectStatus ?? ConnectStatus.success;

  /// UI 用连接态：在 debounce 生效前也反映 pending，避免标题长期显示已连接。
  ConnectStatus get connectStatusForUi {
    final applied = connectStatus;
    final pending = _pendingConnectStatus;
    if (pending != null &&
        pending != ConnectStatus.success &&
        applied == ConnectStatus.success) {
      return pending;
    }
    return applied;
  }

  set connectStatus(ConnectStatus value) {
    _pendingConnectStatus = value;

    // IM SDK connection callbacks can oscillate quickly during iOS network
    // switching, flight-mode toggles, or UserSig refresh. Applying every
    // transient state immediately makes the home title/banner flicker. Keep
    // success immediate, but only show connecting/failed after the state has
    // stayed stable for a short period.
    if (value == ConnectStatus.success) {
      _connectStatusTimer?.cancel();
      _connectStatusTimer = null;
      _applyConnectStatus(value);
      return;
    }

    // 标题/横幅需要及时反映 connecting/failed；debounce 仅延迟写入 applied。
    notifyListeners();

    final current = _connectStatus ?? ConnectStatus.success;
    final delay = value == ConnectStatus.connecting
        ? (current == ConnectStatus.success
            ? const Duration(milliseconds: 1200)
            : const Duration(milliseconds: 500))
        : const Duration(milliseconds: 2500);

    _connectStatusTimer?.cancel();
    _connectStatusTimer = Timer(delay, () {
      if (_pendingConnectStatus != value) return;
      _applyConnectStatus(value);
    });
  }

  void _applyConnectStatus(ConnectStatus value) {
    if (_connectStatus == value) return;
    _connectStatus = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectStatusTimer?.cancel();
    super.dispose();
  }

  bool get isShowReadingStatus => _isShowReadingStatus ?? true;

  set isShowReadingStatus(bool value) {
    _isShowReadingStatus = value;
    notifyListeners();
    updateSettingsToLocal("isShowReadingStatus", value);
  }

  static const Set<String> supportedLanguages = <String>{
    'zh-Hans',
    'zh-Hant',
    'en',
    'ja',
    'ko',
  };

  static String normalizeLanguage(String? value) {
    final language = value?.trim();
    if (language == null || language.isEmpty) return 'zh-Hans';
    if (supportedLanguages.contains(language)) return language;
    return 'zh-Hans';
  }

  String? get language => _language ?? 'zh-Hans';

  set language(String? value) {
    final next = normalizeLanguage(value);
    if (_language == next) return;
    _language = next;
    notifyListeners();
    updateSettingsToLocalString("language", next);
  }

  updateLanguageWithoutWriteLocal(String? value) {
    final next = normalizeLanguage(value);
    if (_language == next) return;
    _language = next;
    notifyListeners();
  }

  double get chatFontScale => _chatFontScale ?? 1.0;

  set chatFontScale(double value) {
    final normalized = value.clamp(0.85, 1.3).toDouble();
    _chatFontScale = normalized;
    notifyListeners();
    updateSettingsToLocalDouble(_chatFontScaleKey, normalized);
  }

  bool get isShowOnlineStatus => _isShowOnlineStatus ?? true;

  set isShowOnlineStatus(bool value) {
    _isShowOnlineStatus = value;
    notifyListeners();
    updateSettingsToLocal("isShowOnlineStatus", value);
  }

  bool get notifySystemMessage => _notifySystemMessage ?? true;

  set notifySystemMessage(bool value) {
    _notifySystemMessage = value;
    notifyListeners();
    updateSettingsToLocal('notifySystemMessage', value);
    _notifyNotificationSettingsChanged();
  }

  bool get notifyVoiceVideoCall => _notifyVoiceVideoCall ?? true;

  set notifyVoiceVideoCall(bool value) {
    _notifyVoiceVideoCall = value;
    notifyListeners();
    updateSettingsToLocal('notifyVoiceVideoCall', value);
    _notifyNotificationSettingsChanged();
  }

  bool get notifyCallQuickAnswerPopup => _notifyCallQuickAnswerPopup ?? true;

  set notifyCallQuickAnswerPopup(bool value) {
    _notifyCallQuickAnswerPopup = value;
    notifyListeners();
    updateSettingsToLocal('notifyCallQuickAnswerPopup', value);
    _notifyNotificationSettingsChanged();
  }

  NotificationDisplayMode get notifyDisplayContent =>
      _notifyDisplayContent ?? NotificationDisplayMode.full;

  set notifyDisplayContent(NotificationDisplayMode value) {
    _notifyDisplayContent = value;
    notifyListeners();
    updateSettingsToLocalString('notifyDisplayContent', value.storageKey);
    _notifyNotificationSettingsChanged();
  }

  /// 从服务端 GET 结果写入本地（同时持久化并触发推送侧效）。
  void applyRemoteNotificationPreferences({
    required bool systemMessageNotificationEnabled,
    required bool callNotificationEnabled,
    required NotificationDisplayMode notificationDisplayContent,
  }) {
    _notifySystemMessage = systemMessageNotificationEnabled;
    _notifyVoiceVideoCall = callNotificationEnabled;
    _notifyDisplayContent = notificationDisplayContent;
    notifyListeners();
    updateSettingsToLocal(
      'notifySystemMessage',
      systemMessageNotificationEnabled,
    );
    updateSettingsToLocal('notifyVoiceVideoCall', callNotificationEnabled);
    updateSettingsToLocalString(
      'notifyDisplayContent',
      notificationDisplayContent.storageKey,
    );
    _notifyNotificationSettingsChanged();
  }

  bool get notifyMessageBanner => _notifyMessageBanner ?? true;

  set notifyMessageBanner(bool value) {
    _notifyMessageBanner = value;
    notifyListeners();
    updateSettingsToLocal('notifyMessageBanner', value);
    _notifyNotificationSettingsChanged();
  }

  NotificationDisplayMode get notifyBannerDisplayContent =>
      _notifyBannerDisplayContent ??
      _notifyDisplayContent ??
      NotificationDisplayMode.full;

  set notifyBannerDisplayContent(NotificationDisplayMode value) {
    _notifyBannerDisplayContent = value;
    notifyListeners();
    updateSettingsToLocalString('notifyBannerDisplayContent', value.storageKey);
    _notifyNotificationSettingsChanged();
  }

  bool get notifyMessageSound => _notifyMessageSound ?? true;

  set notifyMessageSound(bool value) {
    _notifyMessageSound = value;
    notifyListeners();
    updateSettingsToLocal('notifyMessageSound', value);
    _notifyNotificationSettingsChanged();
  }

  String get messageNotificationSoundId =>
      _messageNotificationSoundId ?? MessageNotificationSound.defaultId;

  set messageNotificationSoundId(String value) {
    final normalized = MessageNotificationSound.fromId(value).id;
    if (_messageNotificationSoundId == normalized) return;
    _messageNotificationSoundId = normalized;
    notifyListeners();
    updateSettingsToLocalString('messageNotificationSoundId', normalized);
  }

  bool get notifyCallRingtone => _notifyCallRingtone ?? true;

  set notifyCallRingtone(bool value) {
    _notifyCallRingtone = value;
    notifyListeners();
    updateSettingsToLocal('notifyCallRingtone', value);
    _notifyNotificationSettingsChanged();
  }

  bool get notifyVibration => _notifyVibration ?? true;

  set notifyVibration(bool value) {
    _notifyVibration = value;
    notifyListeners();
    updateSettingsToLocal('notifyVibration', value);
    _notifyNotificationSettingsChanged();
  }

  bool get notificationPermissionPromptShown =>
      _notificationPermissionPromptShown ?? false;

  set notificationPermissionPromptShown(bool value) {
    _notificationPermissionPromptShown = value;
    notifyListeners();
    updateSettingsToLocal('notificationPermissionPromptShown', value);
  }

  bool get batteryOptimizationGuideShown =>
      _batteryOptimizationGuideShown ?? false;

  set batteryOptimizationGuideShown(bool value) {
    _batteryOptimizationGuideShown = value;
    notifyListeners();
    updateSettingsToLocal('batteryOptimizationGuideShown', value);
  }

  loadSettingsFromLocal() async {
    SharedPreferences prefs = await _prefs;
    _isShowOnlineStatus = prefs.getBool("isShowOnlineStatus") ?? true;
    final storedLanguage = normalizeLanguage(prefs.getString("language"));
    _language = storedLanguage;
    if (prefs.getString("language") != storedLanguage) {
      await prefs.setString("language", storedLanguage);
    }
    final storedChatFontScale = prefs.getDouble(_chatFontScaleKey);
    if (storedChatFontScale == null) {
      _chatFontScale = 1.0;
      await prefs.setDouble(_chatFontScaleKey, 1.0);
    } else {
      _chatFontScale = storedChatFontScale;
    }
    final storedReadingStatus = prefs.getBool("isShowReadingStatus");
    if (storedReadingStatus == null) {
      _isShowReadingStatus = true;
      await prefs.setBool("isShowReadingStatus", true);
    } else {
      _isShowReadingStatus = storedReadingStatus;
    }
    _notifySystemMessage = prefs.getBool('notifySystemMessage') ?? true;
    _notifyVoiceVideoCall = prefs.getBool('notifyVoiceVideoCall') ?? true;
    _notifyCallQuickAnswerPopup =
        prefs.getBool('notifyCallQuickAnswerPopup') ?? true;
    _notifyDisplayContent = NotificationDisplayMode.fromStorage(
      prefs.getString('notifyDisplayContent'),
    );
    _notifyMessageBanner = prefs.getBool('notifyMessageBanner') ?? true;
    final bannerContentRaw = prefs.getString('notifyBannerDisplayContent');
    _notifyBannerDisplayContent = bannerContentRaw == null
        ? null
        : NotificationDisplayMode.fromStorage(bannerContentRaw);
    _notifyMessageSound = prefs.getBool('notifyMessageSound') ?? true;
    _messageNotificationSoundId = MessageNotificationSound.fromId(
      prefs.getString('messageNotificationSoundId'),
    ).id;
    _notifyCallRingtone = prefs.getBool('notifyCallRingtone') ?? true;
    _notifyVibration = prefs.getBool('notifyVibration') ?? true;
    _notificationPermissionPromptShown =
        prefs.getBool('notificationPermissionPromptShown') ?? false;
    _batteryOptimizationGuideShown =
        prefs.getBool('batteryOptimizationGuideShown') ?? false;
    notifyListeners();
    _notifyNotificationSettingsChanged();
  }

  updateSettingsToLocal(String setting, bool value) async {
    SharedPreferences prefs = await _prefs;
    prefs.setBool(setting, value);
  }

  updateSettingsToLocalString(String setting, String value) async {
    SharedPreferences prefs = await _prefs;
    prefs.setString(setting, value);
  }

  updateSettingsToLocalDouble(String setting, double value) async {
    SharedPreferences prefs = await _prefs;
    prefs.setDouble(setting, value);
  }

  LocalSetting({bool autoLoad = true}) {
    if (autoLoad) {
      loadSettingsFromLocal();
    }
  }
}
