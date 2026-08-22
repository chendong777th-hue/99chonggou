import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';

const Color _pickerNameColor = AppTokens.ink600;

class MomentsFriendMultiPickerPage extends StatefulWidget {
  const MomentsFriendMultiPickerPage({
    super.key,
    required this.title,
    this.initialSelectedIds = const [],
  });

  final String title;
  final List<String> initialSelectedIds;

  @override
  State<MomentsFriendMultiPickerPage> createState() =>
      _MomentsFriendMultiPickerPageState();
}

class _MomentsFriendMultiPickerPageState
    extends State<MomentsFriendMultiPickerPage> {
  bool _loading = true;
  String _keyword = '';
  List<V2TimFriendInfo> _friends = const [];
  final Set<String> _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(
      widget.initialSelectedIds
          .map((id) => ChatIdFormat.rawUserUid(id))
          .where((id) => id.isNotEmpty),
    );
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final list = await MeFriendApi.instance.loadFriendsForPickers();
      if (!mounted) return;
      setState(() {
        _friends = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _friends = const [];
        _loading = false;
      });
    }
  }

  String _displayName(V2TimFriendInfo item) {
    return UserDisplayProfile.nameOfFriend(item);
  }

  List<V2TimFriendInfo> get _filtered {
    final keyword = _keyword.trim().toLowerCase();
    if (keyword.isEmpty) return _friends;
    return _friends.where((item) {
      final name = _displayName(item).toLowerCase();
      final id = item.userID.toLowerCase();
      return name.contains(keyword) || id.contains(keyword);
    }).toList();
  }

  List<ISuspensionBeanImpl> _buildIndexedItems(List<V2TimFriendInfo> friends) {
    final items = <ISuspensionBeanImpl>[];
    for (final friend in friends) {
      items.add(
        ISuspensionBeanImpl(
          memberInfo: friend,
          tagIndex: memberSuspensionIndexTag(_displayName(friend)),
        ),
      );
    }
    SuspensionUtil.sortListBySuspensionTag(items);
    return items;
  }

  void _toggle(V2TimFriendInfo item) {
    final id = ChatIdFormat.rawUserUid(item.userID);
    if (id.isEmpty) return;
    setState(() {
      if (!_selectedIds.add(id)) {
        _selectedIds.remove(id);
      }
    });
  }

  void _confirm() {
    final selected = <MomentUserSnapshot>[];
    for (final friend in _friends) {
      final id = ChatIdFormat.rawUserUid(friend.userID);
      if (!_selectedIds.contains(id)) continue;
      selected.add(
        MomentUserSnapshot(
          id: id,
          name: _displayName(friend),
          avatarUrl: UserDisplayProfile.avatarOfFriend(friend),
        ),
      );
    }
    Navigator.pop(context, selected);
  }

  Widget _buildFriendRow({
    required V2TimFriendInfo item,
    required bool dark,
    required bool showDivider,
  }) {
    final id = ChatIdFormat.rawUserUid(item.userID);
    final selected = _selectedIds.contains(id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(item),
        child: Container(
          decoration: showDivider
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.line(dark: dark),
                      width: 0.7,
                    ),
                  ),
                )
              : null,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              AppUserAvatar(
                faceUrl: UserDisplayProfile.avatarOfFriend(item),
                showName: _displayName(item),
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _displayName(item),
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected
                    ? _pickerNameColor
                    : AppColors.subText(dark: dark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = _filtered;
    final showIndexBar = _keyword.trim().isEmpty;
    final indexedItems = _buildIndexedItems(items);

    return Scaffold(
      backgroundColor: AppColors.card(dark: dark),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.card(dark: dark),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: _pickerNameColor,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _confirm,
            child: Text(
              TIM_t('完成'),
              style: TextStyle(
                color: _selectedIds.isEmpty
                    ? AppColors.subText(dark: dark)
                    : _pickerNameColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: TIM_t('搜索'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceAlt(dark: dark),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _keyword = value),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator())
                : items.isEmpty
                    ? Center(
                        child: Text(
                          _keyword.trim().isEmpty
                              ? TIM_t('暂无好友')
                              : TIM_t('未找到相关好友'),
                          style: TextStyle(
                            color: AppColors.subText(dark: dark),
                          ),
                        ),
                      )
                    : AZListViewContainer(
                        memberList: indexedItems,
                        isShowIndexBar: showIndexBar,
                        susItemBuilder: (context, index) {
                          final model = indexedItems[index];
                          return Container(
                            height: 32,
                            alignment: Alignment.centerLeft,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            color: AppColors.surfaceAlt(dark: dark),
                            child: Text(
                              model.getSuspensionTag(),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.subText(dark: dark),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                        itemBuilder: (context, index) {
                          final item =
                              indexedItems[index].memberInfo as V2TimFriendInfo;
                          final nextIndex = index + 1;
                          final showDivider = nextIndex < indexedItems.length &&
                              !indexedItems[nextIndex].isShowSuspension;
                          return _buildFriendRow(
                            item: item,
                            dark: dark,
                            showDivider: showDivider,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
