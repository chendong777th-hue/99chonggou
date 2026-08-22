import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

class AgentRebateSummaryCard extends StatelessWidget {
  const AgentRebateSummaryCard({
    super.key,
    required this.title,
    required this.summary,
    this.subtitle,
    this.highlight = false,
    this.showAgentCount = true,
    this.showPlatformProfitLoss = true,
    this.showTotalRebate = false,
    this.showAvailableRebate = true,
    this.availableRebateLabel,
    this.useAgentPendingRebate = false,
    this.playerCountLabel,
  });

  final String title;
  final String? subtitle;
  final AgentRebateSummaryDto summary;
  final bool highlight;
  final bool showAgentCount;
  final bool showPlatformProfitLoss;
  final bool showTotalRebate;
  final bool showAvailableRebate;
  final String? availableRebateLabel;
  final bool useAgentPendingRebate;
  final String? playerCountLabel;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = <(String, String)>[
      if (showAgentCount)
        (
          i18n.t(zhHans: '代理人数', zhHant: '代理人數', en: 'Agents'),
          '${summary.agentCount}',
        ),
      (
        playerCountLabel ??
            i18n.t(zhHans: '玩家人数', zhHant: '玩家人數', en: 'Players'),
        '${summary.playerCount}',
      ),
      (
        i18n.t(zhHans: '总余额', zhHant: '總餘額', en: 'Total Balance'),
        formatAgentRebateAmount(summary.totalBalance),
      ),
      (
        i18n.t(zhHans: '总流水', zhHant: '總流水', en: 'Total Turnover'),
        formatAgentRebateAmount(summary.totalFlow),
      ),
      (
        i18n.t(zhHans: '玩家输赢', zhHant: '玩家輸贏', en: 'Player P/L'),
        formatAgentRebateAmount(summary.playerProfitLoss),
      ),
      if (showPlatformProfitLoss)
        (
          i18n.t(zhHans: '平台输赢', zhHant: '平台輸贏', en: 'Platform P/L'),
          formatAgentRebateAmount(summary.platformProfitLoss),
        ),
      (
        i18n.t(zhHans: '总上分', zhHant: '總上分', en: 'Total Credit'),
        formatAgentRebateAmount(summary.totalUp),
      ),
      (
        i18n.t(zhHans: '总下分', zhHant: '總下分', en: 'Total Debit'),
        formatAgentRebateAmount(summary.totalDown),
      ),
      if (showTotalRebate)
        (
          i18n.t(
            zhHans: '总反水',
            zhHant: '總反水',
            en: 'Total Rebate',
          ),
          formatAgentRebateAmount(summary.totalRebated),
        ),
      if (showAvailableRebate)
        (
          availableRebateLabel ??
              i18n.t(zhHans: '可反水', zhHant: '可反水', en: 'Available Rebate'),
          formatAgentRebateAmount(
            useAgentPendingRebate
                ? summary.agentPendingRebate
                : summary.totalRebated,
          ),
        ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card(dark: dark),
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        border: Border.all(
          color: highlight
              ? AppColors.primaryBlue.withValues(alpha: 0.45)
              : AppColors.line(dark: dark),
        ),
        boxShadow: AppTokens.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: highlight
                    ? AppColors.primaryBlue
                    : AppColors.text(dark: dark),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: AppTokens.s2),
              Text(
                subtitle!,
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: AppTokens.s5),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - AppTokens.s4) / 2;
                return Wrap(
                  spacing: AppTokens.s4,
                  runSpacing: AppTokens.s5,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: itemWidth,
                        child: _SummaryValue(
                          label: item.$1,
                          value: item.$2,
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
    );
  }
}

class AgentRebatePersonalSummaryCard extends StatelessWidget {
  const AgentRebatePersonalSummaryCard({
    super.key,
    required this.personal,
    this.highlight = false,
  });

  final AgentRebatePersonalDto personal;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = <(String, String)>[
      (
        i18n.t(zhHans: '玩家余额', zhHant: '玩家餘額', en: 'Player Balance'),
        formatAgentRebateAmount(personal.balance),
      ),
      (
        i18n.t(zhHans: '个人总流水', zhHant: '個人總流水', en: 'Personal Turnover'),
        formatAgentRebateAmount(personal.totalFlow),
      ),
      (
        i18n.t(zhHans: '个人总输赢', zhHant: '個人總輸贏', en: 'Personal P/L'),
        formatAgentRebateAmount(personal.totalProfitLoss),
      ),
      (
        i18n.t(zhHans: '已反水', zhHant: '已反水', en: 'Rebated'),
        formatAgentRebateAmount(personal.totalRebate),
      ),
      (
        i18n.t(zhHans: '个人待反水', zhHant: '個人待反水', en: 'Personal Pending'),
        formatAgentRebateAmount(personal.pendingRebate),
      ),
      (
        // 级差用接口 agentPending*，不要用下级 remainingFlow 重算。
        i18n.t(zhHans: '级差待结算', zhHant: '級差待結算', en: 'Agent Pending'),
        formatAgentRebateAmount(personal.agentPendingRebate),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card(dark: dark),
        borderRadius: BorderRadius.circular(AppTokens.rCard),
        border: Border.all(
          color: highlight
              ? AppColors.primaryBlue.withValues(alpha: 0.45)
              : AppColors.line(dark: dark),
        ),
        boxShadow: AppTokens.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.t(
                zhHans: '个人反水汇总',
                zhHant: '個人反水匯總',
                en: 'Personal Rebate Summary',
              ),
              style: TextStyle(
                color: highlight
                    ? AppColors.primaryBlue
                    : AppColors.text(dark: dark),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTokens.s5),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - AppTokens.s4) / 2;
                return Wrap(
                  spacing: AppTokens.s4,
                  runSpacing: AppTokens.s5,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: itemWidth,
                        child: _SummaryValue(
                          label: item.$1,
                          value: item.$2,
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
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
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
          ),
        ),
      ],
    );
  }
}
