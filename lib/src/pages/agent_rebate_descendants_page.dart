import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_descendant_detail_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_error.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

enum _DescendantSort { balance, totalFlow, profitLoss }

class _VisibleRow {
  const _VisibleRow({
    required this.item,
    required this.depth,
    required this.name,
    required this.playerNoText,
    required this.balanceText,
    required this.profitFlowText,
    required this.isAgent,
    required this.profitNegative,
  });

  final AgentDescendantItemDto item;
  final int depth;
  final String name;
  final String playerNoText;
  final String balanceText;
  final String profitFlowText;
  final bool isAgent;
  final bool profitNegative;
}

class AgentRebateDescendantsPage extends StatefulWidget {
  const AgentRebateDescendantsPage({
    super.key,
    this.api,
    this.profileLoader,
    this.avatarBuilder,
  });

  final AgentRebateApi? api;
  final Future<UserSearchResult?> Function(String userId)? profileLoader;
  final Widget Function(BuildContext context, String faceUrl, String showName)?
      avatarBuilder;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'agent_rebate_descendants'),
        builder: (_) => const AgentRebateDescendantsPage(),
      ),
    );
  }

  @override
  State<AgentRebateDescendantsPage> createState() =>
      _AgentRebateDescendantsPageState();
}

class _AgentRebateDescendantsPageState
    extends State<AgentRebateDescendantsPage> {
  late final AgentRebateApi _api = widget.api ?? AgentRebateApi.instance;
  late final Future<UserSearchResult?> Function(String userId) _profileLoader =
      widget.profileLoader ?? UserApi.instance.tryFetchUserById;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, UserSearchResult> _profiles = <String, UserSearchResult>{};
  AgentFirstLevelAgentsDto? _data;
  Object? _error;
  bool _loading = true;
  String _keyword = '';
  _DescendantSort _sort = _DescendantSort.balance;
  bool _descending = true;
  int _profileGeneration = 0;
  List<_VisibleRow>? _rowCache;
  final Map<String, List<AgentDescendantTreeNodeDto>> _childrenCache =
      <String, List<AgentDescendantTreeNodeDto>>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _profileGeneration++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = AgentFirstLevelAgentsDto.fromDescendants(
        await _api.fetchDescendants(),
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
        _rowCache = null;
        _childrenCache.clear();
      });
      unawaited(_loadProfiles(_collectProfileItems(result)));
    } catch (error) {
      if (!mounted) return;
      if (AgentRebateError.revokesAccess(error)) {
        AgentIdentityService.instance.revokeGroupAgent(null);
      }
      setState(() {
        _data = null;
        _error = error;
        _loading = false;
        _rowCache = null;
        _childrenCache.clear();
      });
    }
  }

  Future<void> _loadProfiles(List<AgentDescendantItemDto> items) async {
    final generation = ++_profileGeneration;
    final ids = items
        .map((item) => item.userId.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    const batchSize = 8;
    for (var start = 0; start < ids.length; start += batchSize) {
      final end =
          start + batchSize < ids.length ? start + batchSize : ids.length;
      final batch = ids.sublist(start, end);
      final profiles = await Future.wait(
        batch.map((id) async {
          try {
            return await _profileLoader(id);
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted || generation != _profileGeneration) return;
      for (final profile in profiles) {
        if (profile != null && profile.userId.trim().isNotEmpty) {
          _profiles[profile.userId.trim()] = profile;
        }
      }
    }
    if (!mounted || generation != _profileGeneration) return;
    setState(() {
      if (_keyword.trim().isNotEmpty) {
        _rowCache = null;
      }
    });
  }

  void _selectSort(_DescendantSort sort) {
    setState(() {
      if (_sort == sort) {
        _descending = !_descending;
      } else {
        _sort = sort;
        _descending = true;
      }
      _rowCache = null;
    });
  }

  List<AgentDescendantItemDto> _collectProfileItems(
    AgentFirstLevelAgentsDto data,
  ) {
    final items = <AgentDescendantItemDto>[];
    for (final group in data.agents) {
      items.add(group.agent);
      items.addAll(group.descendants);
      _collectTreeItems(group.children, items);
    }
    return items;
  }

  void _collectTreeItems(
    List<AgentDescendantTreeNodeDto> nodes,
    List<AgentDescendantItemDto> items,
  ) {
    for (final node in nodes) {
      items.add(node.item);
      _collectTreeItems(node.children, items);
    }
  }

  List<AgentDescendantTreeNodeDto> _resolveGroupChildren(
    AgentFirstLevelAgentGroupDto group,
  ) {
    final cacheKey = group.agent.userId.trim();
    final cached = _childrenCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    final resolved = group.children.isNotEmpty
        ? group.children
        : group.descendants.isEmpty
            ? const <AgentDescendantTreeNodeDto>[]
            : _treeFromDescendants(group.agent.userId, group.descendants);
    if (cacheKey.isNotEmpty) {
      _childrenCache[cacheKey] = resolved;
    }
    return resolved;
  }

  List<AgentDescendantTreeNodeDto> _treeFromDescendants(
    String parentUserId,
    List<AgentDescendantItemDto> descendants, [
    Set<String>? visiting,
  ]) {
    final parent = parentUserId.trim();
    if (parent.isEmpty) return const [];
    final stack = visiting ?? <String>{};
    if (!stack.add(parent)) return const [];
    try {
      return descendants
          .where((item) {
            final id = item.userId.trim();
            return id.isNotEmpty &&
                id != parent &&
                item.directParentUserId.trim() == parent;
          })
          .map((item) {
            final nested = _treeFromDescendants(
              item.userId,
              descendants,
              stack,
            );
            return AgentDescendantTreeNodeDto(
              item: item,
              childCount: nested.length,
              descendantCount: nested.fold<int>(
                0,
                (total, child) => total + 1 + child.descendantCount,
              ),
              children: nested,
            );
          })
          .toList(growable: false);
    } finally {
      stack.remove(parent);
    }
  }

  List<_VisibleRow> _visibleRows(AppI18n i18n) {
    return _rowCache ??= _buildVisibleRows(i18n);
  }

  _VisibleRow _toRow({
    required AgentDescendantItemDto item,
    required int depth,
    required AppI18n i18n,
  }) {
    final name = item.displayName.trim().isNotEmpty
        ? item.displayName.trim()
        : item.userId;
    final balance = formatAgentRebateAmount(item.balance);
    final profit = formatAgentRebateAmount(item.playerProfitLoss);
    final flow = formatAgentRebateAmount(item.totalFlow);
    return _VisibleRow(
      item: item,
      depth: depth,
      name: name,
      playerNoText: i18n.t(
        zhHans: '编号 ${item.playerNo}',
        zhHant: '編號 ${item.playerNo}',
        en: 'No. ${item.playerNo}',
      ),
      balanceText: i18n.t(
        zhHans: '总积分 $balance',
        zhHant: '總積分 $balance',
        en: 'Points $balance',
      ),
      profitFlowText: i18n.t(
        zhHans: '用户输赢 $profit  今日流水 $flow',
        zhHant: '使用者輸贏 $profit  今日流水 $flow',
        en: 'User P/L $profit  Today $flow',
      ),
      isAgent: item.isAgent,
      profitNegative: item.playerProfitLoss < 0,
    );
  }

  List<_VisibleRow> _buildVisibleRows(AppI18n i18n) {
    final keyword = _keyword.trim().toLowerCase();
    final groups = (_data?.agents ?? const <AgentFirstLevelAgentGroupDto>[])
        .toList(growable: true);
    double valueOf(AgentDescendantItemDto item) {
      return switch (_sort) {
        _DescendantSort.balance => item.balance,
        _DescendantSort.totalFlow => item.totalFlow,
        _DescendantSort.profitLoss => item.playerProfitLoss,
      };
    }

    groups.sort((left, right) {
      final result = valueOf(left.agent).compareTo(valueOf(right.agent));
      if (result == 0) {
        return left.agent.displayName.compareTo(right.agent.displayName);
      }
      return _descending ? -result : result;
    });

    final rows = <_VisibleRow>[];
    final visibleIds = <String>{};
    for (final group in groups) {
      final children = _resolveGroupChildren(group);
      if (keyword.isEmpty) {
        _appendItemIfMissing(
          rows,
          visibleIds,
          group.agent,
          0,
          i18n,
        );
        _appendTree(rows, children, 1, i18n, visibleIds: visibleIds);
        // children 与 descendants 是接口的两种表达。即使 children 不完整，
        // descendants 中无法挂树的记录也必须展示，不能静默过滤。
        for (final item in group.descendants) {
          _appendItemIfMissing(rows, visibleIds, item, 1, i18n);
        }
        continue;
      }
      final supplementalMatches = group.descendants
          .where((item) => _matchesKeyword(item, keyword))
          .toList(growable: false);
      if (!_groupMatches(group.agent, children, keyword) &&
          supplementalMatches.isEmpty) {
        continue;
      }
      _appendSearchRows(
        rows: rows,
        item: group.agent,
        children: children,
        depth: 0,
        keyword: keyword,
        ancestorMatched: false,
        i18n: i18n,
        visibleIds: visibleIds,
      );
      for (final item in supplementalMatches) {
        _appendItemIfMissing(rows, visibleIds, item, 1, i18n);
      }
    }
    return rows;
  }

  void _appendItemIfMissing(
    List<_VisibleRow> rows,
    Set<String> visibleIds,
    AgentDescendantItemDto item,
    int depth,
    AppI18n i18n,
  ) {
    final id = item.userId.trim();
    if (id.isEmpty || !visibleIds.add(id)) return;
    rows.add(_toRow(item: item, depth: depth, i18n: i18n));
  }

  void _appendTree(
    List<_VisibleRow> rows,
    List<AgentDescendantTreeNodeDto> nodes,
    int depth,
    AppI18n i18n, {
    Set<String>? visibleIds,
  }) {
    for (final node in nodes) {
      if (visibleIds == null) {
        rows.add(_toRow(item: node.item, depth: depth, i18n: i18n));
      } else {
        _appendItemIfMissing(rows, visibleIds, node.item, depth, i18n);
      }
      _appendTree(
        rows,
        node.children,
        depth + 1,
        i18n,
        visibleIds: visibleIds,
      );
    }
  }

  bool _groupMatches(
    AgentDescendantItemDto agent,
    List<AgentDescendantTreeNodeDto> children,
    String keyword,
  ) {
    return _matchesKeyword(agent, keyword) || _treeHasMatch(children, keyword);
  }

  bool _treeHasMatch(
    List<AgentDescendantTreeNodeDto> nodes,
    String keyword,
  ) {
    for (final node in nodes) {
      if (_matchesKeyword(node.item, keyword)) {
        return true;
      }
      if (_treeHasMatch(node.children, keyword)) {
        return true;
      }
    }
    return false;
  }

  void _appendSearchRows({
    required List<_VisibleRow> rows,
    required AgentDescendantItemDto item,
    required List<AgentDescendantTreeNodeDto> children,
    required int depth,
    required String keyword,
    required bool ancestorMatched,
    required AppI18n i18n,
    required Set<String> visibleIds,
  }) {
    final selfMatch = _matchesKeyword(item, keyword);
    final descendantMatch = _treeHasMatch(children, keyword);
    if (!ancestorMatched && !selfMatch && !descendantMatch) {
      return;
    }
    _appendItemIfMissing(rows, visibleIds, item, depth, i18n);
    if (ancestorMatched || selfMatch) {
      _appendTree(
        rows,
        children,
        depth + 1,
        i18n,
        visibleIds: visibleIds,
      );
      return;
    }
    for (final child in children) {
      _appendSearchRows(
        rows: rows,
        item: child.item,
        children: child.children,
        depth: depth + 1,
        keyword: keyword,
        ancestorMatched: false,
        i18n: i18n,
        visibleIds: visibleIds,
      );
    }
  }

  bool _matchesKeyword(AgentDescendantItemDto item, String keyword) {
    if (keyword.isEmpty) return true;
    if (item.displayName.trim().toLowerCase().contains(keyword)) return true;
    if (item.playerNo.trim().toLowerCase().contains(keyword)) return true;
    if (item.userId.trim().toLowerCase().contains(keyword)) return true;
    final profile = _profiles[item.userId.trim()];
    final nick = profile?.nickname.trim().toLowerCase() ?? '';
    return nick.isNotEmpty && nick.contains(keyword);
  }

  AgentFirstLevelAgentGroupDto? _groupContaining(String userId) {
    final target = userId.trim();
    if (target.isEmpty) return null;
    for (final group
        in _data?.agents ?? const <AgentFirstLevelAgentGroupDto>[]) {
      if (group.agent.userId.trim() == target) {
        return group;
      }
      final children = _resolveGroupChildren(group);
      if (_findNode(children, target) != null) {
        return group;
      }
      if (group.descendants.any((item) => item.userId.trim() == target)) {
        return group;
      }
    }
    return null;
  }

  AgentDescendantTreeNodeDto? _findNode(
    List<AgentDescendantTreeNodeDto> nodes,
    String userId,
  ) {
    final target = userId.trim();
    for (final node in nodes) {
      if (node.item.userId.trim() == target) {
        return node;
      }
      final nested = _findNode(node.children, target);
      if (nested != null) {
        return nested;
      }
    }
    return null;
  }

  List<AgentDescendantItemDto> _descendantsFor(String agentUserId) {
    return _groupContaining(agentUserId)?.descendants ?? const [];
  }

  List<AgentDescendantTreeNodeDto> _childrenFor(String agentUserId) {
    final target = agentUserId.trim();
    if (target.isEmpty) return const [];
    final group = _groupContaining(target);
    if (group == null) return const [];
    final children = _resolveGroupChildren(group);
    if (group.agent.userId.trim() == target) {
      return children;
    }
    return _findNode(children, target)?.children ?? const [];
  }

  int _descendantCountFor(String agentUserId) {
    final target = agentUserId.trim();
    if (target.isEmpty) return 0;
    final group = _groupContaining(target);
    if (group == null) return 0;
    if (group.agent.userId.trim() == target) {
      return group.descendantCount;
    }
    return _findNode(_resolveGroupChildren(group), target)?.descendantCount ??
        0;
  }

  String _sortLabel(AppI18n i18n, _DescendantSort sort) {
    final label = switch (sort) {
      _DescendantSort.balance => i18n.t(
          zhHans: '总积分',
          zhHant: '總積分',
          en: 'Points',
        ),
      _DescendantSort.totalFlow => i18n.t(
          zhHans: '总流水',
          zhHant: '總流水',
          en: 'Turnover',
        ),
      _DescendantSort.profitLoss => i18n.t(
          zhHans: '输赢',
          zhHant: '輸贏',
          en: 'P/L',
        ),
    };
    if (_sort != sort) return label;
    return '$label ${_descending ? '↓' : '↑'}';
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.background(dark: dark),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.card(dark: dark),
        foregroundColor: AppColors.text(dark: dark),
        leading: IconButton(
          tooltip: i18n.t(zhHans: '返回', zhHant: '返回', en: 'Back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryBlue,
        ),
        title: Text(
          i18n.t(zhHans: '我的下级', zhHant: '我的下級', en: 'My Downline'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.card(dark: dark),
              padding: const EdgeInsets.fromLTRB(
                AppTokens.s5,
                AppTokens.s3,
                AppTokens.s5,
                AppTokens.s4,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _keyword = value;
                        _rowCache = null;
                      });
                    },
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: i18n.t(
                        zhHans: '搜索昵称或编号',
                        zhHant: '搜尋暱稱或編號',
                        en: 'Search nickname or No.',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _keyword.isEmpty
                          ? null
                          : IconButton(
                              tooltip: i18n.t(
                                zhHans: '清空',
                                zhHant: '清空',
                                en: 'Clear',
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _keyword = '';
                                  _rowCache = null;
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: AppColors.background(dark: dark),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTokens.s4,
                        vertical: AppTokens.s3,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.rCard),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s3),
                  Row(
                    children: [
                      Text(
                        i18n.t(zhHans: '排序', zhHant: '排序', en: 'Sort'),
                        style: TextStyle(
                          color: AppColors.subText(dark: dark),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: AppTokens.s3),
                      for (final sort in _DescendantSort.values) ...[
                        Expanded(
                          child: ChoiceChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _sortLabel(i18n, sort),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            selected: _sort == sort,
                            onSelected: (_) => _selectSort(sort),
                          ),
                        ),
                        if (sort != _DescendantSort.values.last)
                          const SizedBox(width: AppTokens.s2),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(i18n, dark)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppI18n i18n, bool dark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return _ErrorState(
        message: AgentRebateError.message(error),
        onRetry: _load,
      );
    }
    final data = _data;
    final rows = _visibleRows(i18n);
    if (data == null || rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
            AppEmptyState(
              message: _keyword.trim().isEmpty
                  ? i18n.t(
                      zhHans: '当前暂无直属下级',
                      zhHant: '目前暫無直屬下級',
                      en: 'No direct downline players.',
                    )
                  : i18n.t(
                      zhHans: '未找到匹配昵称或编号的下级',
                      zhHant: '找不到符合暱稱或編號的下級',
                      en: 'No matching nickname or number.',
                    ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.s5),
        addAutomaticKeepAlives: false,
        cacheExtent: 200,
        itemCount: rows.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.s3),
              child: Text(
                i18n.t(
                  zhHans: '共 ${rows.length} 人',
                  zhHant: '共 ${rows.length} 人',
                  en: '${rows.length} players',
                ),
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 13,
                ),
              ),
            );
          }
          final row = rows[index - 1];
          final item = row.item;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTokens.s3),
            child: _DescendantTile(
              key: ValueKey<String>(item.userId),
              row: row,
              avatarUrl: _profiles[item.userId.trim()]?.avatarUrl ?? '',
              avatarBuilder: widget.avatarBuilder,
              dark: dark,
              onTap: () {
                unawaited(
                  AgentRebateDescendantDetailPage.open(
                    context,
                    userId: item.userId,
                    initialItem: item,
                    initialChildren: _childrenFor(item.userId),
                    initialDescendants: _descendantsFor(item.userId),
                    initialDescendantCount: _descendantCountFor(item.userId),
                    api: _api,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _DescendantTile extends StatelessWidget {
  const _DescendantTile({
    super.key,
    required this.row,
    required this.avatarUrl,
    required this.avatarBuilder,
    required this.dark,
    required this.onTap,
  });

  final _VisibleRow row;
  final String avatarUrl;
  final Widget Function(BuildContext context, String faceUrl, String showName)?
      avatarBuilder;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: AppTokens.s5 * row.depth),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.card(dark: dark),
            borderRadius: BorderRadius.circular(AppTokens.rCard),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s4),
            child: Row(
              children: [
                avatarBuilder?.call(context, avatarUrl, row.name) ??
                    AppUserAvatar(
                      faceUrl: avatarUrl,
                      showName: row.name,
                      size: 48,
                    ),
                const SizedBox(width: AppTokens.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              row.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.text(dark: dark),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (row.isAgent) ...[
                            const SizedBox(width: AppTokens.s2),
                            const _AgentBadge(),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTokens.s2),
                      Text(
                        row.playerNoText,
                        style: TextStyle(
                          color: AppColors.subText(dark: dark),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s2),
                      Text(
                        row.balanceText,
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppTokens.s2),
                      Text(
                        row.profitFlowText,
                        style: TextStyle(
                          color: row.profitNegative
                              ? Colors.redAccent
                              : AppColors.primaryBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.subText(dark: dark),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentBadge extends StatelessWidget {
  const _AgentBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppI18n.of(context).t(zhHans: '代理', zhHant: '代理', en: 'Agent'),
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppEmptyState(message: message, padding: EdgeInsets.zero),
          const SizedBox(height: AppTokens.s4),
          FilledButton(
            onPressed: () => unawaited(onRetry()),
            child: Text(
              AppI18n.of(context).t(zhHans: '重试', zhHant: '重試', en: 'Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
