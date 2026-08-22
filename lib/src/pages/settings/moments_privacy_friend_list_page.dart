import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/moments/moments_friend_multi_picker_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';

enum MomentsPrivacyListKind {
  blockedViewer,
  hiddenAuthor,
}

class MomentsPrivacyFriendListPage extends StatefulWidget {
  const MomentsPrivacyFriendListPage({
    super.key,
    required this.kind,
  });

  final MomentsPrivacyListKind kind;

  @override
  State<MomentsPrivacyFriendListPage> createState() =>
      _MomentsPrivacyFriendListPageState();
}

class _MomentsPrivacyFriendListPageState
    extends State<MomentsPrivacyFriendListPage> {
  bool _loading = true;
  List<MomentUserSnapshot> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<String>> _loadIds() async {
    switch (widget.kind) {
      case MomentsPrivacyListKind.blockedViewer:
        return MomentsSettingsService.instance.loadBlockedViewerIds();
      case MomentsPrivacyListKind.hiddenAuthor:
        return MomentsSettingsService.instance.loadHiddenAuthorIds();
    }
  }

  Future<void> _saveIds(List<String> ids) async {
    switch (widget.kind) {
      case MomentsPrivacyListKind.blockedViewer:
        await MomentsSettingsService.instance.saveBlockedViewerIds(ids);
        return;
      case MomentsPrivacyListKind.hiddenAuthor:
        await MomentsSettingsService.instance.saveHiddenAuthorIds(ids);
        return;
    }
  }

  String _friendDisplayName(V2TimFriendInfo item) {
    final remark = item.friendRemark?.trim() ?? '';
    if (remark.isNotEmpty) return remark;
    final nick = item.userProfile?.nickName?.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    return item.userID;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ids = await _loadIds();
      final friends = await MeFriendApi.instance.loadFriendsForPickers();
      if (!mounted) return;
      final friendById = <String, V2TimFriendInfo>{};
      for (final friend in friends) {
        final id = ChatIdFormat.rawUserUid(friend.userID);
        if (id.isNotEmpty) {
          friendById[id] = friend;
        }
      }
      final entries = <MomentUserSnapshot>[];
      for (final rawId in ids) {
        final id = ChatIdFormat.rawUserUid(rawId);
        if (id.isEmpty) continue;
        final friend = friendById[id];
        if (friend != null) {
          entries.add(
            MomentUserSnapshot(
              id: id,
              name: _friendDisplayName(friend),
              avatarUrl: friend.userProfile?.faceUrl?.trim() ?? '',
            ),
          );
        } else {
          entries.add(
            MomentUserSnapshot(
              id: id,
              name: id,
              avatarUrl: '',
            ),
          );
        }
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = const [];
        _loading = false;
      });
    }
  }

  String _pageTitle(AppI18n i18n) {
    final count = _entries.length;
    switch (widget.kind) {
      case MomentsPrivacyListKind.blockedViewer:
        return i18n.t(
          zhHans: '不让他(她)看我的朋友圈 ($count)',
          zhHant: '不讓他(她)看我的朋友圈 ($count)',
          en: 'Hide My Posts From Others ($count)',
          ja: 'Hide My Posts From Others ($count)',
          ko: 'Hide My Posts From Others ($count)',
        );
      case MomentsPrivacyListKind.hiddenAuthor:
        return i18n.t(
          zhHans: '不看他(她)的朋友圈 ($count)',
          zhHant: '不看他(她)的朋友圈 ($count)',
          en: 'Hide Their Posts ($count)',
          ja: 'Hide Their Posts ($count)',
          ko: 'Hide Their Posts ($count)',
        );
    }
  }

  String _emptyHint(AppI18n i18n) {
    switch (widget.kind) {
      case MomentsPrivacyListKind.blockedViewer:
        return i18n.t(
          zhHans: '把通讯录的某个朋友放到这里，选择「公开」这个可见范围发照片他（她）将无法看到。',
          zhHant: '把通訊錄的某個朋友放到這裡，選擇「公開」這個可見範圍發照片他（她）將無法看到。',
          en: 'Add a contact here. When you post with Public visibility, they will not see your moments.',
          ja: 'Add a contact here. When you post with Public visibility, they will not see your moments.',
          ko: 'Add a contact here. When you post with Public visibility, they will not see your moments.',
        );
      case MomentsPrivacyListKind.hiddenAuthor:
        return i18n.t(
          zhHans: '把通讯录的某个朋友放到这里，你将看不到他（她）发布的朋友圈动态。',
          zhHant: '把通訊錄的某個朋友放到這裡，你將看不到他（她）發佈的朋友圈動態。',
          en: 'Add a contact here. You will not see their moments in your feed.',
          ja: 'Add a contact here. You will not see their moments in your feed.',
          ko: 'Add a contact here. You will not see their moments in your feed.',
        );
    }
  }

  String _pickerTitle(AppI18n i18n) {
    switch (widget.kind) {
      case MomentsPrivacyListKind.blockedViewer:
        return i18n.t(
          zhHans: '选择朋友',
          zhHant: '選擇朋友',
          en: 'Select Friends',
          ja: 'Select Friends',
          ko: 'Select Friends',
        );
      case MomentsPrivacyListKind.hiddenAuthor:
        return i18n.t(
          zhHans: '选择朋友',
          zhHant: '選擇朋友',
          en: 'Select Friends',
          ja: 'Select Friends',
          ko: 'Select Friends',
        );
    }
  }

  Future<void> _addFriends() async {
    final picked = await Navigator.push<List<MomentUserSnapshot>>(
      context,
      NavigationRoutes.cupertino(
        builder: (_) => MomentsFriendMultiPickerPage(
          title: _pickerTitle(AppI18n.of(context)),
          initialSelectedIds: _entries.map((e) => e.id).toList(),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    final ids = picked.map((e) => e.id).toList();
    await _saveIds(ids);
    if (!mounted) return;
    await _load();
  }

  Future<void> _removeFriend(String userId) async {
    final id = ChatIdFormat.rawUserUid(userId);
    final ids = _entries
        .map((e) => e.id)
        .where((item) => ChatIdFormat.rawUserUid(item) != id)
        .toList();
    await _saveIds(ids);
    if (!mounted) return;
    await _load();
  }

  Widget _buildAddButton(AppI18n i18n, {bool compact = false}) {
    final dark = settingsIsDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _addFriends,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: compact ? null : 220,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 48,
            vertical: compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt(dark: dark),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.line(dark: dark)),
          ),
          child: Text(
            i18n.t(
              zhHans: '添加',
              zhHant: '添加',
              en: 'Add',
              ja: '追加',
              ko: '추가',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = settingsIsDark(context);

    if (_loading) {
      return SettingsScaffold(
        title: _pageTitle(i18n),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    return SettingsScaffold(
      title: _pageTitle(i18n),
      children: [
        if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
            child: Column(
              children: [
                Text(
                  _emptyHint(i18n),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subText(dark: dark),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 28),
                _buildAddButton(i18n),
              ],
            ),
          )
        else ...[
          SettingsGroup(
            margin: EdgeInsets.zero,
            children: [
              for (var i = 0; i < _entries.length; i++)
                _FriendRow(
                  entry: _entries[i],
                  dark: dark,
                  showDivider: i < _entries.length - 1,
                  onRemove: () => _removeFriend(_entries[i].id),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Align(
              alignment: Alignment.center,
              child: _buildAddButton(i18n, compact: true),
            ),
          ),
        ],
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.entry,
    required this.dark,
    required this.showDivider,
    required this.onRemove,
  });

  final MomentUserSnapshot entry;
  final bool dark;
  final bool showDivider;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          AppUserAvatar(
            faceUrl: entry.avatarUrl,
            showName: entry.name,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.name,
              style: TextStyle(
                color: AppColors.text(dark: dark),
                fontSize: 16,
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              color: AppColors.subText(dark: dark),
            ),
            tooltip: AppI18n.of(context).t(
              zhHans: '移除',
              zhHant: '移除',
              en: 'Remove',
              ja: '削除',
              ko: '제거',
            ),
          ),
        ],
      ),
    );
  }
}
