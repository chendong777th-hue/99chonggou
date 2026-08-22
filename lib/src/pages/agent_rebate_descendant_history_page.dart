import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_error.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/agent_rebate_date_range_picker.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

class AgentRebateDescendantHistoryPage extends StatefulWidget {
  const AgentRebateDescendantHistoryPage({
    super.key,
    required this.userId,
    this.displayName,
    this.initialRange,
    this.api,
  });

  final String userId;
  final String? displayName;
  final AgentRebateDateRange? initialRange;
  final AgentRebateApi? api;

  static Future<void> open(
    BuildContext context, {
    required String userId,
    String? displayName,
    AgentRebateDateRange? initialRange,
  }) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'agent_rebate_descendant_history'),
        builder: (_) => AgentRebateDescendantHistoryPage(
          userId: userId,
          displayName: displayName,
          initialRange: initialRange,
        ),
      ),
    );
  }

  @override
  State<AgentRebateDescendantHistoryPage> createState() =>
      _AgentRebateDescendantHistoryPageState();
}

class _AgentRebateDescendantHistoryPageState
    extends State<AgentRebateDescendantHistoryPage> {
  late final AgentRebateApi _api = widget.api ?? AgentRebateApi.instance;
  late AgentRebateDateRange _range =
      widget.initialRange ?? AgentRebateDateRange.recentDays(7);
  AgentDescendantsHistoryDto? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.fetchDescendantsHistory(
        _range,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      if (AgentRebateError.revokesAccess(error)) {
        AgentIdentityService.instance.revokeGroupAgent(null);
      }
      setState(() {
        _data = null;
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final selected = await showAgentRebateDateRangePicker(
      context,
      initialRange: _range,
    );
    if (!mounted || selected == null) return;
    setState(() => _range = selected);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.displayName?.trim() ?? '';
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
          name.isEmpty
              ? i18n.t(zhHans: '下级历史', zhHant: '下級歷史', en: 'History')
              : i18n.t(
                  zhHans: '$name的历史',
                  zhHant: '$name的歷史',
                  en: '$name History',
                ),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: i18n.t(zhHans: '选择日期', zhHant: '選擇日期', en: 'Dates'),
            onPressed: _loading ? null : _pickRange,
            icon: const Icon(Icons.date_range_rounded),
          ),
        ],
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
              child: Text(
                '${_range.startApiValue} — ${_range.endApiValue}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 13,
                ),
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
      return _HistoryErrorState(
        message: AgentRebateError.message(error),
        onRetry: _load,
      );
    }
    final items = sortAgentDescendantHistoryNewestFirst(
      _data?.items ?? const <AgentDescendantHistoryItemDto>[],
    );
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
            AppEmptyState(
              message: i18n.t(
                zhHans: '所选日期暂无下级记录',
                zhHant: '所選日期暫無下級記錄',
                en: 'No records for these dates.',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTokens.s5),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s4),
        itemBuilder: (_, index) => _HistoryCard(item: items[index], dark: dark),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.dark});

  final AgentDescendantHistoryItemDto item;
  final bool dark;

  Color _profitColor() {
    if (item.playerProfitLoss < 0) {
      return AppColors.primaryRed;
    }
    if (item.playerProfitLoss > 0) {
      return AppColors.success;
    }
    return AppColors.text(dark: dark);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final secondary = <(String, String)>[
      (
        i18n.t(zhHans: '余额', zhHant: '餘額', en: 'Balance'),
        formatAgentRebateAmount(item.balance),
      ),
      (
        i18n.t(zhHans: '待反水', zhHant: '待反水', en: 'Pending'),
        formatAgentRebateAmount(item.pendingRebate),
      ),
      (
        i18n.t(zhHans: '上分', zhHant: '上分', en: 'Credit'),
        formatAgentRebateAmount(item.totalUp),
      ),
      (
        i18n.t(zhHans: '下分', zhHant: '下分', en: 'Debit'),
        formatAgentRebateAmount(item.totalDown),
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(AppTokens.s5),
      decoration: BoxDecoration(
        color: AppColors.card(dark: dark),
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        border: Border.all(color: AppColors.line(dark: dark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.businessDate,
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - AppTokens.s3) / 2;
              return Wrap(
                spacing: AppTokens.s3,
                runSpacing: AppTokens.s3,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _HistoryHighlightMetric(
                      label: i18n.t(zhHans: '流水', zhHant: '流水', en: 'Turnover'),
                      value: formatAgentRebateAmount(item.totalFlow),
                      dark: dark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _HistoryHighlightMetric(
                      label: i18n.t(
                        zhHans: '玩家输赢',
                        zhHant: '玩家輸贏',
                        en: 'Player P/L',
                      ),
                      value: formatAgentRebateAmount(
                        item.playerProfitLoss,
                      ),
                      dark: dark,
                      valueColor: _profitColor(),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTokens.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - AppTokens.s4) / 2;
              return Wrap(
                spacing: AppTokens.s4,
                runSpacing: AppTokens.s4,
                children: [
                  for (final value in secondary)
                    SizedBox(
                      width: itemWidth,
                      child: _HistoryMetric(
                        label: value.$1,
                        value: value.$2,
                        dark: dark,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryHighlightMetric extends StatelessWidget {
  const _HistoryHighlightMetric({
    required this.label,
    required this.value,
    required this.dark,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool dark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s3,
        AppTokens.s4,
        AppTokens.s3,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt(dark: dark),
        borderRadius: BorderRadius.circular(AppTokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.subText(dark: dark),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppTokens.s2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? AppColors.text(dark: dark),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.label,
    required this.value,
    required this.dark,
  });

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
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

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
              AppI18n.of(
                context,
              ).t(zhHans: '重试', zhHant: '重試', en: 'Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
