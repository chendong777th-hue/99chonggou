import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_descendant_history_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_error.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

class AgentRebateDescendantDetailPage extends StatefulWidget {
  const AgentRebateDescendantDetailPage({
    super.key,
    required this.userId,
    this.initialItem,
    this.initialChildren = const [],
    this.initialDescendants = const [],
    this.initialDescendantCount = 0,
    this.api,
  });

  final String userId;
  final AgentDescendantItemDto? initialItem;
  final List<AgentDescendantTreeNodeDto> initialChildren;
  final List<AgentDescendantItemDto> initialDescendants;
  final int initialDescendantCount;
  final AgentRebateApi? api;

  static Future<void> open(
    BuildContext context, {
    required String userId,
    AgentDescendantItemDto? initialItem,
    List<AgentDescendantTreeNodeDto> initialChildren = const [],
    List<AgentDescendantItemDto> initialDescendants = const [],
    int initialDescendantCount = 0,
    AgentRebateApi? api,
  }) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'agent_rebate_descendant_detail'),
        builder: (_) => AgentRebateDescendantDetailPage(
          userId: userId,
          initialItem: initialItem,
          initialChildren: initialChildren,
          initialDescendants: initialDescendants,
          initialDescendantCount: initialDescendantCount,
          api: api,
        ),
      ),
    );
  }

  @override
  State<AgentRebateDescendantDetailPage> createState() =>
      _AgentRebateDescendantDetailPageState();
}

class _AgentRebateDescendantDetailPageState
    extends State<AgentRebateDescendantDetailPage> {
  late final AgentRebateApi _api = widget.api ?? AgentRebateApi.instance;
  AgentDescendantDetailDto? _data;
  List<AgentDescendantTreeNodeDto> _childNodes = const [];
  List<AgentDescendantItemDto> _children = const [];
  List<AgentDescendantItemDto> _allDescendants = const [];
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _allDescendants = widget.initialDescendants;
    _childNodes = widget.initialChildren;
    _children = _resolveChildren();
    final initialItem = widget.initialItem;
    if (initialItem != null && initialItem.userId.trim().isNotEmpty) {
      _data = _initialData(initialItem);
      _loading = false;
    }
    unawaited(_load());
  }

  AgentDescendantDetailDto _initialData(AgentDescendantItemDto item) {
    return AgentDescendantDetailDto(
      userId: widget.userId,
      item: item,
      directChildCount: _children.length,
      descendantCount: widget.initialDescendantCount,
      teamTotalUp: item.totalUp,
      teamTotalDown: item.totalDown,
    );
  }

  List<AgentDescendantItemDto> _resolveChildren() {
    if (_childNodes.isNotEmpty) {
      return _childNodes.map((node) => node.item).toList(growable: false);
    }
    return _directChildrenOf(widget.userId);
  }

  AgentDescendantTreeNodeDto? _nodeFor(String userId) {
    final target = userId.trim();
    for (final node in _childNodes) {
      if (node.item.userId.trim() == target) return node;
    }
    return null;
  }

  List<AgentDescendantItemDto> _directChildrenOf(String parentUserId) {
    final parent = parentUserId.trim();
    if (parent.isEmpty) return const [];
    return _allDescendants
        .where((item) => item.directParentUserId.trim() == parent)
        .toList(growable: false);
  }

  Future<void> _load() async {
    final hasCached = _data != null;
    if (!hasCached) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await _api.fetchDescendantDetail(widget.userId);
      if (!mounted) return;
      setState(() {
        _data = result;
        _children = _resolveChildren();
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (AgentRebateError.revokesAccess(error)) {
        AgentIdentityService.instance.revokeGroupAgent(null);
      }
      setState(() {
        if (!hasCached) {
          _data = null;
          _children = const [];
          _error = error;
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initialName = widget.initialItem?.displayName.trim() ?? '';
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
          initialName.isEmpty
              ? i18n.t(zhHans: '下级详情', zhHant: '下級詳情', en: 'Details')
              : initialName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(top: false, child: _buildBody(i18n, dark)),
    );
  }

  Widget _buildBody(AppI18n i18n, bool dark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return _DetailErrorState(
        message: AgentRebateError.message(error),
        onRetry: _load,
      );
    }
    final data = _data;
    if (data == null || data.item.userId.isEmpty) {
      return AppEmptyState(
        message: i18n.t(
          zhHans: '未找到下级资料',
          zhHant: '找不到下級資料',
          en: 'Player details were not found.',
        ),
      );
    }
    final item = data.item;
    final name = item.displayName.trim().isNotEmpty
        ? item.displayName.trim()
        : item.userId;
    final metrics = <(String, String)>[
      (i18n.t(zhHans: '用户编号', zhHant: '使用者編號', en: 'User No.'), item.playerNo),
      (
        i18n.t(zhHans: '下级数量', zhHant: '下級數量', en: 'Downline'),
        '${data.directChildCount > 0 ? data.directChildCount : _children.length}',
      ),
      (
        i18n.t(zhHans: '余额', zhHant: '餘額', en: 'Balance'),
        formatAgentRebateAmount(item.balance),
      ),
      (
        i18n.t(zhHans: '总流水', zhHant: '總流水', en: 'Turnover'),
        formatAgentRebateAmount(item.totalFlow),
      ),
      (
        i18n.t(zhHans: '团队总上分', zhHant: '團隊總上分', en: 'Team Credit'),
        formatAgentRebateAmount(data.teamTotalUp),
      ),
      (
        i18n.t(zhHans: '团队总下分', zhHant: '團隊總下分', en: 'Team Debit'),
        formatAgentRebateAmount(data.teamTotalDown),
      ),
      (
        i18n.t(zhHans: '已用流水', zhHant: '已用流水', en: 'Used'),
        formatAgentRebateAmount(item.usedFlow),
      ),
      (
        i18n.t(zhHans: '剩余流水', zhHant: '剩餘流水', en: 'Remaining'),
        formatAgentRebateAmount(item.remainingFlow),
      ),
      (
        i18n.t(zhHans: '玩家输赢', zhHant: '玩家輸贏', en: 'Player P/L'),
        formatAgentRebateAmount(item.playerProfitLoss),
      ),
      (
        i18n.t(zhHans: '已反水', zhHant: '已反水', en: 'Rebated'),
        formatAgentRebateAmount(item.totalRebated),
      ),
      (
        i18n.t(zhHans: '待反水', zhHant: '待反水', en: 'Pending'),
        formatAgentRebateAmount(item.pendingRebate),
      ),
      (
        i18n.t(zhHans: '反水比例', zhHant: '反水比例', en: 'Rate'),
        formatAgentRebateRate(item.rebateRate),
      ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.s5),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTokens.s5),
            decoration: BoxDecoration(
              color: AppColors.card(dark: dark),
              borderRadius: BorderRadius.circular(AppTokens.rCard),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: AppColors.text(dark: dark),
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (item.isAgent)
                      Text(
                        i18n.t(zhHans: '下级代理', zhHant: '下級代理', en: 'Agent'),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppTokens.s2),
                Text(
                  item.userId,
                  style: TextStyle(
                    color: AppColors.subText(dark: dark),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: AppTokens.s5),
                LayoutBuilder(
                  builder: (_, constraints) {
                    final width = (constraints.maxWidth - AppTokens.s4) / 2;
                    return Wrap(
                      spacing: AppTokens.s4,
                      runSpacing: AppTokens.s5,
                      children: [
                        for (final metric in metrics)
                          SizedBox(
                            width: width,
                            child: _Metric(
                              label: metric.$1,
                              value: metric.$2,
                              dark: dark,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.s5),
          Text(
            i18n.t(zhHans: '直属下级', zhHant: '直屬下級', en: 'Direct Downline'),
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.s3),
          if (_children.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTokens.s4),
              child: Text(
                i18n.t(
                  zhHans: '暂无直属下级',
                  zhHant: '暫無直屬下級',
                  en: 'No direct downline.',
                ),
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 13,
                ),
              ),
            )
          else
            for (final child in _children) ...[
              _ChildTile(
                item: child,
                dark: dark,
                onTap: () {
                  final childNode = _nodeFor(child.userId);
                  unawaited(
                    AgentRebateDescendantDetailPage.open(
                      context,
                      userId: child.userId,
                      initialItem: child,
                      initialChildren: childNode?.children ?? const [],
                      initialDescendants: _allDescendants,
                      initialDescendantCount: childNode?.descendantCount ?? 0,
                      api: _api,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTokens.s3),
            ],
          const SizedBox(height: AppTokens.s2),
          FilledButton.icon(
            onPressed: () {
              unawaited(
                AgentRebateDescendantHistoryPage.open(
                  context,
                  userId: item.userId,
                  displayName: name,
                ),
              );
            },
            icon: const Icon(Icons.history_rounded),
            label: Text(
              i18n.t(zhHans: '查看历史', zhHant: '查看歷史', en: 'View History'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildTile extends StatelessWidget {
  const _ChildTile({
    required this.item,
    required this.dark,
    required this.onTap,
  });

  final AgentDescendantItemDto item;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final name = item.displayName.trim().isNotEmpty
        ? item.displayName.trim()
        : item.userId;
    return Material(
      color: AppColors.card(dark: dark),
      borderRadius: BorderRadius.circular(AppTokens.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text(dark: dark),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (item.isAgent) ...[
                          const SizedBox(width: AppTokens.s2),
                          Text(
                            i18n.t(zhHans: '代理', zhHant: '代理', en: 'Agent'),
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTokens.s2),
                    Text(
                      i18n.t(
                        zhHans:
                            '编号 ${item.playerNo}  ·  积分 ${formatAgentRebateAmount(item.balance)}',
                        zhHant:
                            '編號 ${item.playerNo}  ·  積分 ${formatAgentRebateAmount(item.balance)}',
                        en: 'No. ${item.playerNo}  ·  Points ${formatAgentRebateAmount(item.balance)}',
                      ),
                      style: TextStyle(
                        color: AppColors.subText(dark: dark),
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
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.dark});

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.subText(dark: dark), fontSize: 12),
        ),
        const SizedBox(height: AppTokens.s2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.text(dark: dark),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

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
