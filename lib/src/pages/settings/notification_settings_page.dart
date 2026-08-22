import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/message_notification_sound.dart';
import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/message_notification_sound_picker_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/me_notification_settings_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_permission_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/notification_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loadingRemote = true;
  bool _savingRemote = false;
  String? _remoteLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRemoteSettings();
    });
  }

  Future<void> _loadRemoteSettings() async {
    if (!mounted) return;
    setState(() {
      _loadingRemote = true;
      _remoteLoadError = null;
    });
    final localSetting = Provider.of<LocalSetting>(context, listen: false);
    try {
      await MeNotificationSettingsSyncService.instance.fetchAndApply(
        localSetting,
      );
      if (!mounted) return;
      setState(() => _loadingRemote = false);
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _remoteLoadError = UserApiErrorMessage.fromNotificationSettings(e);
        _loadingRemote = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _remoteLoadError = AppI18n.current.t(
          zhHans: '加载失败',
          zhHant: '載入失敗',
          en: 'Failed to load.',
          ja: '読み込みに失敗しました。',
          ko: '불러오기에 실패했습니다.',
        );
        _loadingRemote = false;
      });
    }
  }

  Future<void> _runRemoteUpdate(
    Future<void> Function() action, {
    VoidCallback? onFailure,
  }) async {
    if (_loadingRemote || _savingRemote) return;
    // 不 setState busy：整页重建会让 ListView / 开关动画抖动。
    _savingRemote = true;
    try {
      await action();
    } on DioError catch (e) {
      onFailure?.call();
      ToastUtils.toast(UserApiErrorMessage.fromNotificationSettings(e));
    } catch (_) {
      onFailure?.call();
      ToastUtils.toast(AppI18n.current.t(
        zhHans: '保存失败',
        zhHant: '儲存失敗',
        en: 'Failed to save.',
        ja: '保存に失敗しました。',
        ko: '저장에 실패했습니다.',
      ));
    } finally {
      _savingRemote = false;
    }
  }

  Future<void> _pickDisplayMode(
    BuildContext context, {
    required NotificationDisplayMode current,
    required ValueChanged<NotificationDisplayMode> onSelected,
  }) async {
    final i18n = AppI18n.of(context);
    final selected = await AppDialog.actionSheet<NotificationDisplayMode>(
      title: i18n.t(
        zhHans: '通知显示内容',
        zhHant: '通知顯示內容',
        en: 'Notification Content',
        ja: '通知の表示内容',
        ko: '알림 표시 내용',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: NotificationDisplayMode.values
          .map(
            (mode) => AppActionSheetItem<NotificationDisplayMode>(
              text: mode.localizedLabel(i18n),
              value: mode,
              enabled: mode != current,
            ),
          )
          .toList(),
    );

    if (selected == null) return;
    onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final localSetting = Provider.of<LocalSetting>(context, listen: false);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '通知',
        zhHant: '通知',
        en: 'Notifications',
        ja: '通知',
        ko: '알림',
      ),
      children: [
        if (PlatformUtils().isMobile)
          const _SystemNotificationPermissionBanner(),
        if (_remoteLoadError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppColors.subText(dark: settingsIsDark(context))
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                title: Text(
                  _remoteLoadError!,
                  style: TextStyle(
                    color: AppColors.text(dark: settingsIsDark(context)),
                    fontSize: 14,
                  ),
                ),
                trailing: TextButton(
                  onPressed: _loadRemoteSettings,
                  child: Text(
                    i18n.t(
                      zhHans: '重试',
                      zhHant: '重試',
                      en: 'Retry',
                      ja: '再試行',
                      ko: '다시 시도',
                    ),
                  ),
                ),
              ),
            ),
          ),
        _SettingsSectionHeader(
          title: i18n.t(
            zhHans: '未打开时',
            zhHant: '未開啟時',
            en: 'When the app is closed',
            ja: 'アプリ未起動時',
            ko: '앱이 닫혀 있을 때',
          ),
        ),
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            Selector<LocalSetting, bool>(
              selector: (_, s) => s.notifySystemMessage,
              builder: (_, value, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '系统消息通知',
                  zhHant: '系統訊息通知',
                  en: 'System Message Notifications',
                  ja: 'システムメッセージ通知',
                  ko: '시스템 메시지 알림',
                ),
                value: value,
                onChanged: (v) => _runRemoteUpdate(
                  () => MeNotificationSettingsSyncService.instance
                      .updateSystemMessageEnabled(localSetting, v),
                ),
              ),
            ),
            Selector<LocalSetting, bool>(
              selector: (_, s) => s.notifyVoiceVideoCall,
              builder: (_, value, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '语音和视频通话通知',
                  zhHant: '語音與視訊通話通知',
                  en: 'Voice and Video Call Notifications',
                  ja: '音声・ビデオ通話通知',
                  ko: '음성 및 영상 통화 알림',
                ),
                value: value,
                onChanged: (v) => _runRemoteUpdate(
                  () => MeNotificationSettingsSyncService.instance
                      .updateCallNotificationEnabled(localSetting, v),
                ),
              ),
            ),
            Selector<LocalSetting, (bool, bool)>(
              selector: (_, s) =>
                  (s.notifyVoiceVideoCall, s.notifyCallQuickAnswerPopup),
              builder: (_, state, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '语音和视频通话用弹窗快捷接听',
                  zhHant: '語音與視訊通話彈窗快捷接聽',
                  en: 'Quick Answer Popup for Voice and Video Calls',
                  ja: '音声・ビデオ通話のクイック応答ポップアップ',
                  ko: '음성 및 영상 통화 팝업 빠른 응답',
                ),
                isSubItem: true,
                value: state.$2,
                enabled: state.$1,
                onChanged: (v) {
                  if (!localSetting.notifyVoiceVideoCall) return;
                  localSetting.notifyCallQuickAnswerPopup = v;
                },
              ),
            ),
            Selector<LocalSetting, NotificationDisplayMode>(
              selector: (_, s) => s.notifyDisplayContent,
              builder: (_, mode, __) => _NotificationValueCell(
                title: i18n.t(
                  zhHans: '通知显示内容',
                  zhHant: '通知顯示內容',
                  en: 'Notification Content',
                  ja: '通知の表示内容',
                  ko: '알림 표시 내용',
                ),
                value: _loadingRemote
                    ? i18n.t(
                        zhHans: '加载中',
                        zhHant: '載入中',
                        en: 'Loading...',
                        ja: '読み込み中...',
                        ko: '불러오는 중...',
                      )
                    : mode.localizedLabel(i18n),
                showDivider: false,
                onTap: () {
                  if (_loadingRemote || _savingRemote) return;
                  _pickDisplayMode(
                    context,
                    current: localSetting.notifyDisplayContent,
                    onSelected: (next) => _runRemoteUpdate(
                      () => MeNotificationSettingsSyncService.instance
                          .updateDisplayContent(localSetting, next),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsSectionHeader(
          title: i18n.t(
            zhHans: '打开时',
            zhHant: '開啟時',
            en: 'When the app is open',
            ja: 'アプリ起動中',
            ko: '앱이 열려 있을 때',
          ),
        ),
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            Selector<LocalSetting, bool>(
              selector: (_, s) => s.notifyMessageBanner,
              builder: (_, value, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '打开时通知',
                  zhHant: '開啟時通知',
                  en: 'Notify When Open',
                  ja: '起動中の通知',
                  ko: '앱 실행 중 알림',
                ),
                value: value,
                onChanged: (v) => localSetting.notifyMessageBanner = v,
              ),
            ),
            Selector<LocalSetting, (bool, NotificationDisplayMode)>(
              selector: (_, s) =>
                  (s.notifyMessageBanner, s.notifyBannerDisplayContent),
              builder: (_, state, __) => _NotificationValueCell(
                title: i18n.t(
                  zhHans: '通知显示内容',
                  zhHant: '通知顯示內容',
                  en: 'Notification Content',
                  ja: '通知の表示内容',
                  ko: '알림 표시 내용',
                ),
                isSubItem: true,
                value: state.$2.localizedLabel(i18n),
                enabled: state.$1,
                onTap: () {
                  if (!localSetting.notifyMessageBanner) return;
                  _pickDisplayMode(
                    context,
                    current: localSetting.notifyBannerDisplayContent,
                    onSelected: (mode) =>
                        localSetting.notifyBannerDisplayContent = mode,
                  );
                },
              ),
            ),
            Selector<LocalSetting, bool>(
              selector: (_, s) => s.notifyMessageSound,
              builder: (_, value, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '消息提示音',
                  zhHant: '訊息提示音',
                  en: 'Message Sound',
                  ja: 'メッセージ通知音',
                  ko: '메시지 알림음',
                ),
                value: value,
                onChanged: (v) => localSetting.notifyMessageSound = v,
              ),
            ),
            Selector<LocalSetting, (bool, String)>(
              selector: (_, s) =>
                  (s.notifyMessageSound, s.messageNotificationSoundId),
              builder: (_, state, __) => _NotificationValueCell(
                title: i18n.t(
                  zhHans: '默认提示音',
                  zhHant: '預設提示音',
                  en: 'Default Sound',
                  ja: 'デフォルト通知音',
                  ko: '기본 알림음',
                ),
                isSubItem: true,
                value: MessageNotificationSound.fromId(state.$2)
                    .localizedLabel(i18n),
                enabled: state.$1,
                onTap: () {
                  if (!localSetting.notifyMessageSound) return;
                  Navigator.push(
                    context,
                    NavigationRoutes.cupertino(
                      builder: (_) =>
                          const MessageNotificationSoundPickerPage(),
                    ),
                  );
                },
              ),
            ),
            Selector<LocalSetting, bool>(
              selector: (_, s) => s.notifyCallRingtone,
              builder: (_, value, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '语音和视频通话来电铃声',
                  zhHant: '語音與視訊通話來電鈴聲',
                  en: 'Call Ringtone for Voice and Video Calls',
                  ja: '音声・ビデオ通話の着信音',
                  ko: '음성 및 영상 통화 벨소리',
                ),
                value: value,
                onChanged: (v) => localSetting.notifyCallRingtone = v,
              ),
            ),
            Selector<LocalSetting, bool>(
              selector: (_, s) => s.notifyVibration,
              builder: (_, value, __) => _NotificationSwitchCell(
                title: i18n.t(
                  zhHans: '振动',
                  zhHant: '震動',
                  en: 'Vibration',
                  ja: 'バイブレーション',
                  ko: '진동',
                ),
                value: value,
                showDivider: false,
                onChanged: (v) => localSetting.notifyVibration = v,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;

  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppColors.subText(dark: dark),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _NotificationSwitchCell extends StatelessWidget {
  final String title;
  final bool value;
  final bool isSubItem;
  final bool showDivider;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitchCell({
    required this.title,
    required this.value,
    required this.onChanged,
    this.isSubItem = false,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final displayTitle = isSubItem ? '- $title' : title;

    return SizedBox(
      height: 56,
      child: Container(
        padding: EdgeInsets.fromLTRB(isSubItem ? 24 : 16, 0, 16, 0),
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
            Expanded(
              child: Text(
                displayTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.text(dark: dark)
                      .withValues(alpha: enabled ? 1 : 0.45),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: SettingsPlatformSwitch(
                value: value,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationValueCell extends StatelessWidget {
  final String title;
  final String value;
  final bool isSubItem;
  final bool showDivider;
  final bool enabled;
  final VoidCallback? onTap;

  const _NotificationValueCell({
    required this.title,
    required this.value,
    this.isSubItem = false,
    this.showDivider = true,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final displayTitle = isSubItem ? '- $title' : title;
    final interactive = enabled && onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: interactive ? onTap : null,
        child: SizedBox(
          height: 56,
          child: Container(
            padding: EdgeInsets.fromLTRB(isSubItem ? 24 : 16, 0, 16, 0),
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
                Expanded(
                  flex: 2,
                  child: Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text(dark: dark)
                          .withValues(alpha: enabled ? 1 : 0.45),
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.subText(dark: dark)
                                .withValues(alpha: enabled ? 1 : 0.45),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Opacity(
                        opacity: enabled ? 1 : 0,
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.subText(dark: dark),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemNotificationPermissionBanner extends StatefulWidget {
  const _SystemNotificationPermissionBanner();

  @override
  State<_SystemNotificationPermissionBanner> createState() =>
      _SystemNotificationPermissionBannerState();
}

class _SystemNotificationPermissionBannerState
    extends State<_SystemNotificationPermissionBanner>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final granted = await NotificationPermissionService.instance.isGranted();
    if (!mounted) return;
    final wasGranted = _granted;
    setState(() {
      _granted = granted;
      _loading = false;
    });
    if (!wasGranted && granted) {
      await NotificationSettingsService.instance.applyFromSettings();
    }
  }

  Future<void> _openSettings() async {
    await NotificationPermissionService.instance.openSystemSettings();
    await _refresh();
    if (_granted) {
      await NotificationSettingsService.instance.applyFromSettings();
    }
  }

  Future<void> _requestPermission() async {
    final granted =
        await NotificationPermissionService.instance.requestSystemPermission();
    if (!mounted) return;
    setState(() => _granted = granted);
    if (granted) {
      await NotificationSettingsService.instance.applyFromSettings();
      return;
    }
    if (await NotificationPermissionService.instance.isPermanentlyDenied()) {
      await _openSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _granted) {
      return const SizedBox.shrink();
    }

    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: (dark ? const Color(0xFF3A2E14) : const Color(0xFFFFF4E5)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                i18n.t(
                  zhHans: '系统通知权限未开启，离线消息与通话提醒将无法送达。',
                  zhHant: '系統通知權限未開啟，離線訊息與通話提醒將無法送達。',
                  en: 'System notifications are off. Offline messages and call alerts will not be delivered.',
                  ja: 'システム通知がオフのため、オフラインのメッセージと通話通知は届きません。',
                  ko: '시스템 알림이 꺼져 있어 오프라인 메시지와 통화 알림을 받을 수 없습니다.',
                ),
                style: TextStyle(
                  color: dark ? const Color(0xFFFFD591) : const Color(0xFFB45309),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: _requestPermission,
                    child: Text(
                      i18n.t(
                        zhHans: '立即开启',
                        zhHant: '立即開啟',
                        en: 'Enable now',
                        ja: '今すぐ有効にする',
                        ko: '지금 켜기',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _openSettings,
                    child: Text(
                      i18n.t(
                        zhHans: '前往系统设置',
                        zhHant: '前往系統設定',
                        en: 'Open system settings',
                        ja: 'システム設定を開く',
                        ko: '시스템 설정',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
