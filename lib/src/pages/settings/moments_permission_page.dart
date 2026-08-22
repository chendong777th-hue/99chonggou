import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/moments_privacy_friend_list_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_prefs.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

class MomentsPermissionPage extends StatefulWidget {
  const MomentsPermissionPage({super.key});

  @override
  State<MomentsPermissionPage> createState() => _MomentsPermissionPageState();
}

class _MomentsPermissionPageState extends State<MomentsPermissionPage> {
  bool _loading = true;
  int? _visibleRangeDays;
  List<String> _blockedViewerIds = const [];
  List<String> _hiddenAuthorIds = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings =
          await MomentsSettingsService.instance.loadSettings(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _visibleRangeDays = settings.visibleRangeDays;
        _blockedViewerIds = settings.blockedViewerIds;
        _hiddenAuthorIds = settings.hiddenAuthorIds;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _visibleRangeDays = null;
        _blockedViewerIds = const [];
        _hiddenAuthorIds = const [];
        _loading = false;
      });
    }
  }

  String _selectedCountLabel(AppI18n i18n, int count) {
    if (count <= 0) return '';
    return i18n.t(
      zhHans: '$count 人',
      zhHant: '$count 人',
      en: '$count',
      ja: '$count',
      ko: '$count',
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      NavigationRoutes.cupertino(builder: (_) => page),
    ).then((_) {
      if (mounted) _load();
    });
  }

  String _visibleRangeValue(AppI18n i18n) {
    if (_visibleRangeDays == null) {
      return i18n.t(
        zhHans: '未设置',
        zhHant: '未設定',
        en: 'Not set',
        ja: '未設定',
        ko: '설정 안 됨',
      );
    }
    switch (_visibleRangeDays) {
      case MomentsLocalPrefs.visibleRangeAll:
        return i18n.t(
          zhHans: '全部',
          zhHant: '全部',
          en: 'All',
          ja: 'すべて',
          ko: '전체',
        );
      case 3:
        return i18n.t(
          zhHans: '最近三天',
          zhHant: '最近三天',
          en: 'Last 3 days',
          ja: 'Last 3 days',
          ko: 'Last 3 days',
        );
      case 90:
        return i18n.t(
          zhHans: '最近三个月',
          zhHant: '最近三個月',
          en: 'Last 3 months',
          ja: 'Last 3 months',
          ko: 'Last 3 months',
        );
      case 180:
        return i18n.t(
          zhHans: '最近半年',
          zhHant: '最近半年',
          en: 'Last 6 months',
          ja: 'Last 6 months',
          ko: 'Last 6 months',
        );
      case 365:
        return i18n.t(
          zhHans: '最近一年',
          zhHant: '最近一年',
          en: 'Last year',
          ja: 'Last year',
          ko: 'Last year',
        );
      default:
        return MomentsLocalPrefs.visibleRangeLabel(_visibleRangeDays);
    }
  }

  Future<void> _pickVisibleRange() async {
    final i18n = AppI18n.of(context);
    final options = <int>[
      MomentsLocalPrefs.visibleRangeAll,
      3,
      90,
      180,
      365,
    ];

    String labelFor(int days) {
      switch (days) {
        case MomentsLocalPrefs.visibleRangeAll:
          return i18n.t(
            zhHans: '全部',
            zhHant: '全部',
            en: 'All',
            ja: 'すべて',
            ko: '전체',
          );
        case 3:
          return i18n.t(
            zhHans: '最近三天',
            zhHant: '最近三天',
            en: 'Last 3 days',
            ja: 'Last 3 days',
            ko: 'Last 3 days',
          );
        case 90:
          return i18n.t(
            zhHans: '最近三个月',
            zhHant: '最近三個月',
            en: 'Last 3 months',
            ja: 'Last 3 months',
            ko: 'Last 3 months',
          );
        case 180:
          return i18n.t(
            zhHans: '最近半年',
            zhHant: '最近半年',
            en: 'Last 6 months',
            ja: 'Last 6 months',
            ko: 'Last 6 months',
          );
        case 365:
          return i18n.t(
            zhHans: '最近一年',
            zhHant: '最近一年',
            en: 'Last year',
            ja: 'Last year',
            ko: 'Last year',
          );
        default:
          return MomentsLocalPrefs.visibleRangeLabel(days);
      }
    }

    final selected = await AppDialog.actionSheet<int>(
      title: i18n.t(
        zhHans: '允许朋友查看朋友圈的范围',
        zhHant: '允許朋友查看朋友圈的範圍',
        en: 'Visible Range for Friends',
        ja: 'Visible Range for Friends',
        ko: 'Visible Range for Friends',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      actions: options
          .map(
            (days) => AppActionSheetItem(
              text: labelFor(days),
              value: days,
              enabled: _visibleRangeDays != days,
            ),
          )
          .toList(),
    );
    if (selected == null || selected == _visibleRangeDays) return;
    await MomentsSettingsService.instance.saveVisibleRangeDays(selected);
    if (!mounted) return;
    setState(() => _visibleRangeDays = selected);
    ToastUtils.toast(i18n.t(
      zhHans: '已保存',
      zhHant: '已儲存',
      en: 'Saved',
      ja: '保存しました',
      ko: '저장됨',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);

    if (_loading) {
      return SettingsScaffold(
        title: i18n.t(
          zhHans: '朋友圈权限',
          zhHant: '朋友圈權限',
          en: 'Moments Privacy',
          ja: 'Moments Privacy',
          ko: 'Moments Privacy',
        ),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return SettingsScaffold(
      title: i18n.t(
        zhHans: '朋友圈权限',
        zhHant: '朋友圈權限',
        en: 'Moments Privacy',
        ja: 'Moments Privacy',
        ko: 'Moments Privacy',
      ),
      children: [
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '不让他(她)看',
                zhHant: '不讓他(她)看',
                en: 'Hide My Posts From',
                ja: 'Hide My Posts From',
                ko: 'Hide My Posts From',
              ),
              value: _selectedCountLabel(i18n, _blockedViewerIds.length),
              onTap: () => _open(
                context,
                const MomentsPrivacyFriendListPage(
                  kind: MomentsPrivacyListKind.blockedViewer,
                ),
              ),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '不看他（她）',
                zhHant: '不看他（她）',
                en: 'Hide Their Posts',
                ja: 'Hide Their Posts',
                ko: 'Hide Their Posts',
              ),
              value: _selectedCountLabel(i18n, _hiddenAuthorIds.length),
              onTap: () => _open(
                context,
                const MomentsPrivacyFriendListPage(
                  kind: MomentsPrivacyListKind.hiddenAuthor,
                ),
              ),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '允许朋友查看朋友圈的范围',
                zhHant: '允許朋友查看朋友圈的範圍',
                en: 'Visible Range for Friends',
                ja: 'Visible Range for Friends',
                ko: 'Visible Range for Friends',
              ),
              value: _visibleRangeValue(i18n),
              showDivider: false,
              onTap: _pickVisibleRange,
            ),
          ],
        ),
      ],
    );
  }
}
