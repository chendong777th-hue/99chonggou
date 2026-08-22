import 'dart:async';

import 'package:azlistview_all_platforms/azlistview_all_platforms.dart';
import 'package:flutter/material.dart';
import 'package:lpinyin/lpinyin.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/common_group_chats_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/contact_style_search_bar.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/az_list_view.dart';

/// 共同群聊列表页：搜索 + A–Z 索引；后台分页拉全量。
class CommonGroupChatsPage extends StatefulWidget {
  const CommonGroupChatsPage({
    super.key,
    required this.peerUserId,
    this.initialGroups = const [],
    this.initialTotal = 0,
    this.peerDisplayName,
    this.embedded = false,
    this.onClose,
  });

  final String peerUserId;
  final List<MeGroupRecord> initialGroups;
  final int initialTotal;
  final String? peerDisplayName;

  /// 嵌入桌面右栏 / 弹窗时隐藏自带 AppBar。
  final bool embedded;
  final VoidCallback? onClose;

  @override
  State<CommonGroupChatsPage> createState() => _CommonGroupChatsPageState();
}

class _CommonGroupChatsPageState extends State<CommonGroupChatsPage> {
  static const int _pageSize = CommonGroupChatsService.defaultPageSize;

  final TextEditingController _searchController = TextEditingController();
  final List<MeGroupRecord> _groups = <MeGroupRecord>[];

  int _total = 0;
  bool _initialLoading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    if (widget.initialGroups.isNotEmpty) {
      _groups.addAll(widget.initialGroups);
      _total = widget.initialTotal > 0
          ? widget.initialTotal
          : widget.initialGroups.length;
      _hasMore = _groups.length < _total;
      // 有首页数据时，后台继续拉完，保证索引/搜索覆盖全量。
      if (_hasMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_loadRemainingPages());
        });
      }
    } else {
      _initialLoading = true;
      _total = widget.initialTotal;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_loadNextPage(reset: true).then((_) {
          if (mounted && _hasMore) {
            unawaited(_loadRemainingPages());
          }
        }));
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _displayName(MeGroupRecord group) {
    final name = group.groupName.trim();
    return name.isNotEmpty ? name : group.groupId.trim();
  }

  bool _matches(MeGroupRecord group, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }
    final name = _displayName(group);
    final pinyin = PinyinHelper.getPinyinE(name).toLowerCase();
    final short = PinyinHelper.getShortPinyin(name).toLowerCase();
    final haystack =
        '${group.groupId} $name $pinyin $short'.toLowerCase();
    return haystack.contains(keyword);
  }

  List<ISuspensionBeanImpl<MeGroupRecord>> _buildIndexedItems(
    List<MeGroupRecord> groups,
  ) {
    final items = <ISuspensionBeanImpl<MeGroupRecord>>[];
    for (final group in groups) {
      items.add(
        ISuspensionBeanImpl<MeGroupRecord>(
          memberInfo: group,
          tagIndex: memberSuspensionIndexTag(_displayName(group)),
        ),
      );
    }
    SuspensionUtil.sortListBySuspensionTag(items);
    return items;
  }

  /// 链式拉完剩余页（索引/搜索需要完整列表）。
  Future<void> _loadRemainingPages() async {
    while (mounted && _hasMore) {
      final before = _groups.length;
      await _loadNextPage();
      if (!mounted) {
        return;
      }
      // 失败或本页无新增时停止，避免死循环重试。
      if (_loadError != null || _groups.length <= before) {
        break;
      }
    }
  }

  Future<void> _loadNextPage({bool reset = false}) async {
    final peer = ChatIdFormat.rawUserUid(widget.peerUserId);
    if (peer.isEmpty) {
      if (mounted) {
        setState(() {
          _initialLoading = false;
          _loadingMore = false;
          _hasMore = false;
        });
      }
      return;
    }
    if (_loadingMore || (!_hasMore && !reset)) {
      return;
    }

    setState(() {
      _loadError = null;
      if (reset || _groups.isEmpty) {
        _initialLoading = true;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final offset = reset ? 0 : _groups.length;
      final page = await CommonGroupChatsService.instance.loadCommonGroupsPage(
        peer,
        limit: _pageSize,
        offset: offset,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        if (reset) {
          _groups
            ..clear()
            ..addAll(page.items);
        } else {
          final existing = _groups.map((e) => e.groupId).toSet();
          for (final item in page.items) {
            if (!existing.contains(item.groupId)) {
              _groups.add(item);
            }
          }
        }
        _total = page.total > 0 ? page.total : _groups.length;
        _hasMore = page.items.isNotEmpty && _groups.length < _total;
        _initialLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = e;
        _initialLoading = false;
        _loadingMore = false;
      });
      if (_groups.isNotEmpty) {
        ToastUtils.toast(AppI18n.of(context).t(
          zhHans: '加载失败，请稍后重试',
          zhHant: '載入失敗，請稍後再試',
          en: 'Failed to load. Please try again.',
          ja: '読み込みに失敗しました。しばらくしてからもう一度お試しください。',
          ko: '불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        ));
      }
    }
  }

  Future<void> _openGroupChat(MeGroupRecord group) async {
    final groupId = group.groupId.trim();
    if (groupId.isEmpty) {
      return;
    }
    final res = await TIMUIKitCore.getSDKInstance()
        .getConversationManager()
        .getConversation(conversationID: 'group_$groupId');
    if (!mounted) {
      return;
    }
    final conversation = res.data;
    if (res.code != 0 || conversation == null) {
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '打开群聊失败',
        zhHant: '打開群聊失敗',
        en: 'Failed to open group chat.',
        ja: 'グループチャットを開けませんでした。',
        ko: '그룹 채팅을 열지 못했습니다.',
      ));
      return;
    }
    await Navigator.of(context).push(appChatRoute(conversation));
  }

  Widget _buildRow({
    required Color card,
    required Color textColor,
    required Color weakColor,
    required Color line,
    required MeGroupRecord group,
    required bool showDivider,
  }) {
    final name = _displayName(group);
    return Material(
      color: card,
      child: InkWell(
        onTap: () => _openGroupChat(group),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Avatar(
                      faceUrl: group.avatarUrl,
                      showName: name,
                      type: 2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: textColor),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: weakColor,
                    size: 22,
                  ),
                ],
              ),
            ),
            if (showDivider)
              Divider(
                height: 0.6,
                thickness: 0.6,
                indent: 72,
                color: line,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final isDark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final i18n = AppI18n.of(context);
    final bg = theme.weakBackgroundColor ?? AppColors.background(dark: isDark);
    final card = theme.conversationItemBgColor ??
        theme.wideBackgroundColor ??
        AppColors.card(dark: isDark);
    final textColor = theme.darkTextColor ?? AppColors.text(dark: isDark);
    final weakColor = theme.weakTextColor ?? AppColors.subText(dark: isDark);
    final line = theme.weakDividerColor ?? AppColors.line(dark: isDark);
    final primary = theme.primaryColor ?? AppColors.primaryBlue;
    final keyword = _searchController.text.trim().toLowerCase();
    final filtered = _groups.where((g) => _matches(g, keyword)).toList();
    final indexed = _buildIndexedItems(filtered);
    final showIndexBar = keyword.isEmpty && indexed.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      appBar: widget.embedded
          ? null
          : AppBar(
              elevation: 0,
              centerTitle: true,
              backgroundColor: theme.appbarBgColor ?? card,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: primary,
                onPressed: widget.onClose ?? () => Navigator.of(context).pop(),
              ),
              title: Text(
                i18n.t(
                  zhHans: '共同的群聊',
                  zhHant: '共同的群聊',
                  en: 'Common Groups',
                  ja: '共通のグループ',
                  ko: '공통 그룹',
                ),
                style: TextStyle(
                  color: theme.appbarTextColor ?? textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
      body: Column(
        children: [
          ContactStyleSearchBar(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            showCancel: false,
            hint: i18n.t(
              zhHans: '搜索群聊',
              zhHant: '搜尋群聊',
              en: 'Search groups',
              ja: 'グループを検索',
              ko: '그룹 검색',
            ),
          ),
          if (_loadingMore)
            LinearProgressIndicator(
              minHeight: 1.5,
              color: primary,
              backgroundColor: line,
            ),
          Expanded(
            child: _buildListBody(
              i18n: i18n,
              card: card,
              textColor: textColor,
              weakColor: weakColor,
              line: line,
              primary: primary,
              indexed: indexed,
              showIndexBar: showIndexBar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody({
    required AppI18n i18n,
    required Color card,
    required Color textColor,
    required Color weakColor,
    required Color line,
    required Color primary,
    required List<ISuspensionBeanImpl<MeGroupRecord>> indexed,
    required bool showIndexBar,
  }) {
    if (_initialLoading && _groups.isEmpty) {
      return Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: primary),
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError != null
                  ? i18n.t(
                      zhHans: '加载失败',
                      zhHant: '載入失敗',
                      en: 'Failed to load',
                      ja: '読み込みに失敗しました',
                      ko: '불러오지 못했습니다',
                    )
                  : i18n.t(
                      zhHans: '暂无共同群聊',
                      zhHant: '暫無共同群聊',
                      en: 'No common groups',
                      ja: '共通のグループはありません',
                      ko: '공통 그룹이 없습니다',
                    ),
              style: TextStyle(color: weakColor, fontSize: 15),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => unawaited(_loadNextPage(reset: true).then((_) {
                  if (mounted && _hasMore) {
                    unawaited(_loadRemainingPages());
                  }
                })),
                child: Text(i18n.t(
                  zhHans: '重试',
                  zhHant: '重試',
                  en: 'Retry',
                  ja: '再試行',
                  ko: '다시 시도',
                )),
              ),
            ],
          ],
        ),
      );
    }

    if (indexed.isEmpty) {
      return Center(
        child: Text(
          i18n.t(
            zhHans: '未找到相关群聊',
            zhHant: '未找到相關群聊',
            en: 'No matching groups',
            ja: '該当するグループが見つかりません',
            ko: '관련 그룹을 찾을 수 없습니다',
          ),
          style: TextStyle(color: weakColor, fontSize: 15),
        ),
      );
    }

    return AZListViewContainer(
      memberList: indexed,
      isShowIndexBar: showIndexBar,
      susItemBuilder: (context, index) {
        final model = indexed[index];
        return Container(
          height: 32,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: themeWeakBg(context),
          child: Text(
            model.getSuspensionTag(),
            style: TextStyle(
              fontSize: 13,
              color: weakColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      },
      itemBuilder: (context, index) {
        final group = indexed[index].memberInfo;
        final next = index + 1;
        final showDivider =
            next < indexed.length && !indexed[next].isShowSuspension;
        return _buildRow(
          card: card,
          textColor: textColor,
          weakColor: weakColor,
          line: line,
          group: group,
          showDivider: showDivider,
        );
      },
    );
  }

  Color themeWeakBg(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final isDark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    return theme.weakBackgroundColor ?? AppColors.background(dark: isDark);
  }
}
