import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/add_friend_privacy_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';

class FriendPermissionPage extends StatefulWidget {
  const FriendPermissionPage({super.key});

  @override
  State<FriendPermissionPage> createState() => _FriendPermissionPageState();
}

class _FriendPermissionPageState extends State<FriendPermissionPage> {
  bool? _friendAddRequiresVerify;
  bool _loadingVerify = true;
  bool _savingVerify = false;
  String? _verifyLoadError;

  String? _lastActiveVisibility;
  bool _loadingVisibility = true;
  bool _savingVisibility = false;
  String? _visibilityLoadError;

  @override
  void initState() {
    super.initState();
    _loadFriendAddVerify();
    _loadLastActiveVisibility();
  }

  Future<void> _loadFriendAddVerify() async {
    setState(() {
      _loadingVerify = true;
      _verifyLoadError = null;
    });
    try {
      final settings = await UserApi.instance.fetchFriendAddVerify();
      if (!mounted) return;
      setState(() {
        _friendAddRequiresVerify = settings.friendAddRequiresVerify;
        _loadingVerify = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _verifyLoadError = UserApiErrorMessage.fromPrivacy(e);
        _loadingVerify = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyLoadError = AppI18n.current.t(
          zhHans: '加载失败',
          zhHant: '載入失敗',
          en: 'Failed to load.',
          ja: '読み込みに失敗しました。',
          ko: '불러오기에 실패했습니다.',
        );
        _loadingVerify = false;
      });
    }
  }

  String _verifyText(AppI18n i18n) {
    if (_loadingVerify) {
      return i18n.t(
        zhHans: '加载中',
        zhHant: '載入中',
        en: 'Loading...',
        ja: '読み込み中...',
        ko: '불러오는 중...',
      );
    }
    if (_verifyLoadError != null) {
      return i18n.t(
        zhHans: '加载失败',
        zhHant: '載入失敗',
        en: 'Failed to load',
        ja: '読み込み失敗',
        ko: '불러오기 실패',
      );
    }
    final requiresVerify = _friendAddRequiresVerify ?? true;
    if (requiresVerify) {
      return i18n.t(
        zhHans: '需要验证信息',
        zhHant: '需要驗證資訊',
        en: 'Require Verification',
        ja: '承認が必要',
        ko: '인증 필요',
      );
    }
    return i18n.t(
      zhHans: '允许任何人',
      zhHant: '允許任何人',
      en: 'Allow Anyone',
      ja: '誰でも追加可能',
      ko: '누구나 추가 가능',
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      NavigationRoutes.cupertino(builder: (_) => page),
    );
  }

  Future<void> _changeFriendAddVerify(bool friendAddRequiresVerify) async {
    if (_loadingVerify || _savingVerify || _verifyLoadError != null) {
      if (_verifyLoadError != null) {
        await _loadFriendAddVerify();
      }
      return;
    }

    final previous = _friendAddRequiresVerify;
    setState(() {
      _friendAddRequiresVerify = friendAddRequiresVerify;
      _savingVerify = true;
    });

    try {
      final saved = await UserApi.instance.updateFriendAddVerify(
        friendAddRequiresVerify: friendAddRequiresVerify,
      );
      if (!mounted) return;
      setState(() {
        _friendAddRequiresVerify = saved.friendAddRequiresVerify;
        _savingVerify = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _friendAddRequiresVerify = previous;
        _savingVerify = false;
      });
      ToastUtils.toast(UserApiErrorMessage.fromPrivacy(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friendAddRequiresVerify = previous;
        _savingVerify = false;
      });
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '设置失败，请稍后重试',
        zhHant: '設定失敗，請稍後再試',
        en: 'Failed to update settings. Please try again later.',
        ja: '設定の更新に失敗しました。しばらくしてからもう一度お試しください。',
        ko: '설정 변경에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      ));
    }
  }

  Future<void> _showAllowTypeSheet() async {
    if (_loadingVerify || _savingVerify) {
      return;
    }
    if (_verifyLoadError != null) {
      await _loadFriendAddVerify();
      if (!mounted || _verifyLoadError != null) {
        return;
      }
    }

    final i18n = AppI18n.of(context);
    final current = _friendAddRequiresVerify ?? true;

    final selected = await AppDialog.actionSheet<bool>(
      title: i18n.t(
        zhHans: '谁可以加我为好友',
        zhHant: '誰可以加我為好友',
        en: 'Who Can Add Me',
        ja: '友だち追加できる人',
        ko: '나를 친구로 추가할 수 있는 사람',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: [
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '允许任何人',
            zhHant: '允許任何人',
            en: 'Allow Anyone',
            ja: '誰でも追加可能',
            ko: '누구나 추가 가능',
          ),
          value: false,
          enabled: current,
        ),
        AppActionSheetItem(
          text: i18n.t(
            zhHans: '需要验证信息',
            zhHant: '需要驗證資訊',
            en: 'Require Verification',
            ja: '承認が必要',
            ko: '인증 필요',
          ),
          value: true,
          enabled: !current,
        ),
      ],
    );

    if (selected == null) return;
    await _changeFriendAddVerify(selected);
  }

  Future<void> _loadLastActiveVisibility() async {
    setState(() {
      _loadingVisibility = true;
      _visibilityLoadError = null;
    });
    try {
      final settings = await UserApi.instance.fetchOnlinePrivacyProtection();
      if (!mounted) return;
      setState(() {
        _lastActiveVisibility = settings.lastActiveVisibility;
        _loadingVisibility = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _visibilityLoadError = UserApiErrorMessage.fromPrivacy(e);
        _loadingVisibility = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _visibilityLoadError = AppI18n.current.t(
          zhHans: '加载失败',
          zhHant: '載入失敗',
          en: 'Failed to load.',
          ja: '読み込みに失敗しました。',
          ko: '불러오기에 실패했습니다.',
        );
        _loadingVisibility = false;
      });
    }
  }

  String _lastActiveVisibilityLabel(AppI18n i18n, String? value) {
    switch (LastActiveVisibility.normalize(value)) {
      case LastActiveVisibility.friendsOnly:
        return i18n.t(
          zhHans: '仅好友可查看',
          zhHant: '僅好友可查看',
          en: 'Friends only',
          ja: '友達のみ',
          ko: '친구만',
        );
      case LastActiveVisibility.hidden:
        return i18n.t(
          zhHans: '不显示在线时间',
          zhHant: '不顯示在線時間',
          en: 'Hidden',
          ja: '非表示',
          ko: '표시 안 함',
        );
      default:
        return i18n.t(
          zhHans: '所有人可查看',
          zhHant: '所有人可查看',
          en: 'Everyone',
          ja: '全員に公開',
          ko: '모두에게 공개',
        );
    }
  }

  String _lastActiveVisibilityText(AppI18n i18n) {
    if (_loadingVisibility) {
      return i18n.t(
        zhHans: '加载中',
        zhHant: '載入中',
        en: 'Loading...',
        ja: '読み込み中...',
        ko: '불러오는 중...',
      );
    }
    if (_visibilityLoadError != null) {
      return i18n.t(
        zhHans: '加载失败',
        zhHant: '載入失敗',
        en: 'Failed to load',
        ja: '読み込み失敗',
        ko: '불러오기 실패',
      );
    }
    return _lastActiveVisibilityLabel(i18n, _lastActiveVisibility);
  }

  Future<void> _changeLastActiveVisibility(String next) async {
    if (_loadingVisibility || _savingVisibility || _visibilityLoadError != null) {
      if (_visibilityLoadError != null) {
        await _loadLastActiveVisibility();
      }
      return;
    }

    final normalized = LastActiveVisibility.normalize(next);
    final previous = _lastActiveVisibility;
    setState(() {
      _lastActiveVisibility = normalized;
      _savingVisibility = true;
    });

    try {
      final saved = await UserApi.instance.updateOnlinePrivacyProtection(
        lastActiveVisibility: normalized,
      );
      if (!mounted) return;
      setState(() {
        _lastActiveVisibility = saved.lastActiveVisibility;
        _savingVisibility = false;
      });
    } on DioError catch (e) {
      if (!mounted) return;
      setState(() {
        _lastActiveVisibility = previous;
        _savingVisibility = false;
      });
      ToastUtils.toast(UserApiErrorMessage.fromPrivacy(e));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastActiveVisibility = previous;
        _savingVisibility = false;
      });
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '设置失败，请稍后重试',
        zhHant: '設定失敗，請稍後再試',
        en: 'Failed to update settings. Please try again later.',
        ja: '設定の更新に失敗しました。しばらくしてからもう一度お試しください。',
        ko: '설정 변경에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      ));
    }
  }

  Future<void> _showLastActiveVisibilitySheet() async {
    if (_loadingVisibility || _savingVisibility) {
      return;
    }
    if (_visibilityLoadError != null) {
      await _loadLastActiveVisibility();
      if (!mounted || _visibilityLoadError != null) {
        return;
      }
    }

    final i18n = AppI18n.of(context);
    final current = LastActiveVisibility.normalize(_lastActiveVisibility);

    final selected = await AppDialog.actionSheet<String>(
      title: i18n.t(
        zhHans: '最后上线时间',
        zhHant: '最後上線時間',
        en: 'Last Online Time',
        ja: '最終オンライン時間',
        ko: '마지막 접속 시간',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: [
        AppActionSheetItem(
          text: _lastActiveVisibilityLabel(i18n, LastActiveVisibility.everyone),
          value: LastActiveVisibility.everyone,
          enabled: current != LastActiveVisibility.everyone,
        ),
        AppActionSheetItem(
          text: _lastActiveVisibilityLabel(i18n, LastActiveVisibility.friendsOnly),
          value: LastActiveVisibility.friendsOnly,
          enabled: current != LastActiveVisibility.friendsOnly,
        ),
        AppActionSheetItem(
          text: _lastActiveVisibilityLabel(i18n, LastActiveVisibility.hidden),
          value: LastActiveVisibility.hidden,
          enabled: current != LastActiveVisibility.hidden,
        ),
      ],
    );

    if (selected == null) return;
    await _changeLastActiveVisibility(selected);
  }

  @override
  Widget build(BuildContext context) {
    final localSetting = Provider.of<LocalSetting>(context);
    final dark = settingsIsDark(context);
    final helperColor = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '朋友权限',
        zhHant: '朋友權限',
        en: 'Friend Permissions',
        ja: '友だち権限',
        ko: '친구 권한',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text(
            i18n.t(
              zhHans: '管理谁可以加你为好友，以及他人通过哪些方式可以找到你。',
              zhHant: '管理誰可以加你為好友，以及他人可透過哪些方式找到你。',
              en: 'Manage who can add you as a friend and how others can find you.',
              ja: '誰があなたを友だち追加できるか、また相手がどの方法であなたを見つけられるかを管理します。',
              ko: '누가 나를 친구로 추가할 수 있는지, 그리고 다른 사용자가 어떤 방법으로 나를 찾을 수 있는지 관리합니다.',
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
            SettingsCell(
              title: i18n.t(
                zhHans: '加我为好友的方式',
                zhHant: '加我為好友的方式',
                en: 'How Others Can Add Me',
                ja: '友だち追加の許可方式',
                ko: '친구 추가 허용 방식',
              ),
              value: _savingVerify
                  ? i18n.t(
                      zhHans: '保存中',
                      zhHant: '儲存中',
                      en: 'Saving...',
                      ja: '保存中...',
                      ko: '저장 중...',
                    )
                  : _verifyText(i18n),
              onTap: _showAllowTypeSheet,
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '添加我的方式',
                zhHant: '添加我的方式',
                en: 'Ways to Find Me',
                ja: '相手が私を追加する方法',
                ko: '나를 추가하는 방법',
              ),
              showDivider: false,
              onTap: () => _open(context, const AddFriendPrivacyPage()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '最后上线时间',
                zhHant: '最後上線時間',
                en: 'Last Online Time',
                ja: '最終オンライン時間',
                ko: '마지막 접속 시간',
              ),
              value: _savingVisibility
                  ? i18n.t(
                      zhHans: '保存中',
                      zhHant: '儲存中',
                      en: 'Saving...',
                      ja: '保存中...',
                      ko: '저장 중...',
                    )
                  : _lastActiveVisibilityText(i18n),
              onTap: _showLastActiveVisibilitySheet,
            ),
            _ToggleCell(
              title: i18n.t(
                zhHans: '显示在线状态',
                zhHant: '顯示在線狀態',
                en: 'Show Online Status',
                ja: 'オンライン状態を表示',
                ko: '온라인 상태 표시',
              ),
              subtitle: i18n.t(
                zhHans: '关闭后，您将不可以在会话列表和通讯录中看到好友在线或离线的状态提示。',
                zhHant: '關閉後，您將不可以在會話列表和通訊錄中看到好友在線或離線的狀態提示。',
                en: 'When off, online/offline status will not appear in chats or contacts.',
                ja: 'オフにすると、オンライン/オフライン状態は表示されません。',
                ko: '끄면 채팅 목록과 연락처에서 온라인 상태가 표시되지 않습니다.',
              ),
              value: localSetting.isShowOnlineStatus,
              onChanged: (value) {
                localSetting.isShowOnlineStatus = value;
              },
            ),
            _ToggleCell(
              title: i18n.t(
                zhHans: '消息阅读状态',
                zhHant: '訊息已讀狀態',
                en: 'Read Receipts',
                ja: '既読ステータス',
                ko: '읽음 상태',
              ),
              subtitle: i18n.t(
                zhHans: '关闭后，你和对方都无法看到消息是否已读',
                zhHant: '關閉後，你與對方都無法查看訊息是否已讀',
                en: 'When disabled, neither side can see whether messages have been read.',
                ja: 'オフにすると、あなたも相手もメッセージの既読状態を確認できなくなります。',
                ko: '끄면 나와 상대방 모두 메시지의 읽음 여부를 확인할 수 없습니다.',
              ),
              value: localSetting.isShowReadingStatus,
              showDivider: false,
              onChanged: (value) {
                localSetting.isShowReadingStatus = value;
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ToggleCell extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  const _ToggleCell({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.subText(dark: dark),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SettingsPlatformSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
