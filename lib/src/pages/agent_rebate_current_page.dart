import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_error.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/agent_rebate_summary_card.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

class AgentRebateCurrentPage extends StatefulWidget {
  const AgentRebateCurrentPage({super.key, this.api});

  final AgentRebateApi? api;

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'agent_rebate_current'),
        builder: (_) => const AgentRebateCurrentPage(),
      ),
    );
  }

  @override
  State<AgentRebateCurrentPage> createState() => _AgentRebateCurrentPageState();
}

Future<void> openAgentRebateCurrentPage(BuildContext context) {
  return AgentRebateCurrentPage.open(context);
}

enum _RebateApplyKind { personal, agent }

class _AgentRebateCurrentPageState extends State<AgentRebateCurrentPage> {
  late final AgentRebateApi _api = widget.api ?? AgentRebateApi.instance;
  AgentRebateCurrentDto? _data;
  AgentRebateApplyDto? _personalApplyStatus;
  AgentRebateApplyDto? _agentApplyStatus;
  String? _error;
  bool _loading = true;
  bool _applyingPersonal = false;
  bool _applyingAgent = false;
  bool _waitingForSettlement = false;
  int _pollGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadApplyStatuses());
  }

  @override
  void dispose() {
    _pollGeneration++;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.fetchCurrent();
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
        _error = AgentRebateError.message(error);
        _loading = false;
      });
    }
  }

  Future<void> _loadApplyStatuses() async {
    try {
      final results = await Future.wait([
        _api.fetchPersonalRebateApplyStatus(),
        _api.fetchAgentRebateApplyStatus(),
      ]);
      if (!mounted) return;
      final personal = results[0];
      final agent = results[1];
      setState(() {
        _personalApplyStatus = personal;
        _agentApplyStatus = agent;
      });
      if (personal.isPending) {
        await _runPendingFlow(_RebateApplyKind.personal);
      } else if (agent.isPending) {
        await _runPendingFlow(_RebateApplyKind.agent);
      }
    } catch (_) {
      // 状态查询失败不阻断当前汇总页面。
    }
  }

  Future<void> _runPendingFlow(_RebateApplyKind kind) async {
    setState(() => _waitingForSettlement = true);
    try {
      await _pollApplyStatus(kind);
    } finally {
      if (mounted) {
        setState(() => _waitingForSettlement = false);
      }
    }
  }

  Future<void> _confirmAndApply(_RebateApplyKind kind) async {
    final applying =
        kind == _RebateApplyKind.personal ? _applyingPersonal : _applyingAgent;
    final status = kind == _RebateApplyKind.personal
        ? _personalApplyStatus
        : _agentApplyStatus;
    if (applying || status?.isPending == true) return;

    final i18n = AppI18n.of(context);
    final isPersonal = kind == _RebateApplyKind.personal;
    final confirmed = await AppDialog.confirm(
      title: i18n.t(
        zhHans: isPersonal ? '确认个人反水' : '确认级差反水',
        zhHant: isPersonal ? '確認個人反水' : '確認級差反水',
        en: isPersonal ? 'Personal Rebate' : 'Agent Rebate',
      ),
      message: i18n.t(
        zhHans: isPersonal
            ? '申请结算本人待反水。实际到账由机器人侧处理，确定继续吗？'
            : '申请结算本人级差待结算。金额由机器人侧核算，确定继续吗？',
        zhHant: isPersonal
            ? '申請結算本人待反水。實際到帳由機器人側處理，確定繼續嗎？'
            : '申請結算本人級差待結算。金額由機器人側核算，確定繼續嗎？',
        en: isPersonal
            ? 'Apply to settle personal pending rebate?'
            : 'Apply to settle agent differential rebate?',
      ),
      cancelText: i18n.t(zhHans: '取消', zhHant: '取消', en: 'Cancel'),
      confirmText: i18n.t(zhHans: '确认申请', zhHant: '確認申請', en: 'Apply'),
    );
    if (!mounted || !confirmed) return;

    setState(() {
      if (isPersonal) {
        _applyingPersonal = true;
      } else {
        _applyingAgent = true;
      }
      _waitingForSettlement = true;
    });
    try {
      final result = isPersonal
          ? await _api.submitPersonalRebateApply()
          : await _api.submitAgentRebateApply();
      if (!mounted) return;
      setState(() {
        if (isPersonal) {
          _personalApplyStatus = result;
        } else {
          _agentApplyStatus = result;
        }
      });
      if (result.isPending) {
        await _pollApplyStatus(kind);
      } else if (result.isSuccess) {
        _toastSuccess(i18n);
        await _load();
      } else if (result.isFailed) {
        _toastFailed(i18n);
      }
    } catch (error) {
      if (!mounted) return;
      if (AgentRebateError.revokesAccess(error)) {
        AgentIdentityService.instance.revokeGroupAgent(null);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AgentRebateError.message(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applyingPersonal = false;
          _applyingAgent = false;
          _waitingForSettlement = false;
        });
      }
    }
  }

  Future<void> _pollApplyStatus(_RebateApplyKind kind) async {
    final generation = ++_pollGeneration;
    final i18n = AppI18n.of(context);
    for (var attempt = 0; attempt < 30; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || generation != _pollGeneration) return;
      try {
        final status = kind == _RebateApplyKind.personal
            ? await _api.fetchPersonalRebateApplyStatus()
            : await _api.fetchAgentRebateApplyStatus();
        if (!mounted || generation != _pollGeneration) return;
        setState(() {
          if (kind == _RebateApplyKind.personal) {
            _personalApplyStatus = status;
          } else {
            _agentApplyStatus = status;
          }
        });
        if (status.isPending) continue;
        if (status.isSuccess) {
          _toastSuccess(i18n);
          await _load();
        } else if (status.isFailed) {
          _toastFailed(i18n);
        }
        return;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                i18n.t(
                  zhHans: '暂时无法查询反水状态，请稍后重试',
                  zhHant: '暫時無法查詢反水狀態，請稍後重試',
                  en: 'Unable to check rebate status.',
                ),
              ),
            ),
          );
        }
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.t(
              zhHans: '反水处理时间较长，请稍后重新查看状态',
              zhHant: '反水處理時間較長，請稍後重新查看狀態',
              en: 'Rebate processing is taking longer than expected.',
            ),
          ),
        ),
      );
    }
  }

  void _toastSuccess(AppI18n i18n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          i18n.t(
            zhHans: '反水结算成功',
            zhHant: '反水結算成功',
            en: 'Rebate settled successfully.',
          ),
        ),
      ),
    );
  }

  void _toastFailed(AppI18n i18n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          i18n.t(
            zhHans: '反水结算失败，请稍后重试',
            zhHant: '反水結算失敗，請稍後重試',
            en: 'Rebate settlement failed.',
          ),
        ),
      ),
    );
  }

  String _applyLabel(
    AppI18n i18n, {
    required bool applying,
    required AgentRebateApplyDto? status,
    required bool personal,
  }) {
    if (applying) {
      return i18n.t(zhHans: '提交中…', zhHant: '提交中…', en: 'Submitting…');
    }
    if (status?.isPending == true) {
      return i18n.t(zhHans: '处理中', zhHant: '處理中', en: 'Processing');
    }
    if (status?.isSuccess == true) {
      return personal
          ? i18n.t(zhHans: '再次个人反水', zhHant: '再次個人反水', en: 'Personal Again')
          : i18n.t(zhHans: '申请反水', zhHant: '申請反水', en: 'Apply Rebate');
    }
    return personal
        ? i18n.t(zhHans: '申请个人反水', zhHant: '申請個人反水', en: 'Personal Rebate')
        : i18n.t(zhHans: '申请反水', zhHant: '申請反水', en: 'Apply Rebate');
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final busy = _waitingForSettlement || _applyingPersonal || _applyingAgent;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: AppColors.background(dark: dark),
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.card(dark: dark),
          foregroundColor: AppColors.text(dark: dark),
          leading: IconButton(
            tooltip: i18n.t(zhHans: '返回', zhHant: '返回', en: 'Back'),
            onPressed: busy ? null : () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.primaryBlue,
          ),
          title: Text(
            i18n.t(
              zhHans: '当前反水汇总',
              zhHant: '當前反水匯總',
              en: 'Current Rebate Summary',
            ),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(child: _buildBody(i18n)),
                  Container(
                    width: double.infinity,
                    color: AppColors.card(dark: dark),
                    padding: const EdgeInsets.all(AppTokens.s5),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _applyingAgent ||
                                    _agentApplyStatus?.isPending == true ||
                                    _waitingForSettlement
                                ? null
                                : () => unawaited(
                                      _confirmAndApply(_RebateApplyKind.agent),
                                    ),
                            child: Text(
                              _applyLabel(
                                i18n,
                                applying: _applyingAgent,
                                status: _agentApplyStatus,
                                personal: false,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_waitingForSettlement) ...[
              const Positioned.fill(
                child: ModalBarrier(
                  dismissible: false,
                  color: Color(0x66000000),
                ),
              ),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s7,
                    vertical: AppTokens.s6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card(dark: dark),
                    borderRadius: BorderRadius.circular(AppTokens.rCard),
                    boxShadow: AppTokens.shadowSm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: AppTokens.s4),
                      Text(
                        i18n.t(
                          zhHans: '反水处理中，请稍候…',
                          zhHant: '反水處理中，請稍候…',
                          en: 'Processing rebate…',
                        ),
                        style: TextStyle(
                          color: AppColors.text(dark: dark),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppI18n i18n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return _ErrorState(message: error, onRetry: _load);
    }
    final current = _data;
    if (current == null) {
      return AppEmptyState(
        message: i18n.t(
          zhHans: '暂无当前汇总',
          zhHant: '暫無當前匯總',
          en: 'No current summary.',
        ),
      );
    }
    final summary = current.summary;
    final personal = current.personal ??
        const AgentRebatePersonalDto(
          balance: 0,
          totalFlow: 0,
          totalProfitLoss: 0,
          totalRebate: 0,
          pendingRebate: 0,
          agentPendingRebate: 0,
        );
    final agentName = summary.agentName?.trim() ?? '';
    final agentNo = summary.agentNo?.trim() ?? '';
    final dataTime = _formatDateTime(summary.dataTime);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.s5),
        children: [
          AgentRebatePersonalSummaryCard(
            personal: personal,
            highlight: true,
          ),
          const SizedBox(height: AppTokens.s4),
          AgentRebateSummaryCard(
            title: agentName.isNotEmpty
                ? agentName
                : i18n.t(zhHans: '当前汇总', zhHant: '當前匯總', en: 'Current Summary'),
            subtitle: [
              if (agentNo.isNotEmpty)
                i18n.format(
                  zhHans: '用户编号：{value}',
                  zhHant: '使用者編號：{value}',
                  en: 'User No.: {value}',
                  vars: {'value': agentNo},
                ),
              if (dataTime.isNotEmpty)
                i18n.format(
                  zhHans: '数据时间：{value}',
                  zhHant: '資料時間：{value}',
                  en: 'Data time: {value}',
                  vars: {'value': dataTime},
                ),
            ].join('  ·  '),
            summary: summary,
            highlight: true,
            showAgentCount: false,
            showPlatformProfitLoss: false,
            showTotalRebate: false,
            showAvailableRebate: false,
            playerCountLabel: i18n.t(
              zhHans: '用户人数',
              zhHant: '使用者人數',
              en: 'Users',
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    return formatAgentRebateChinaDateTime(value);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppEmptyState(message: message, padding: EdgeInsets.zero),
            const SizedBox(height: AppTokens.s5),
            FilledButton(
              onPressed: onRetry,
              child: Text(i18n.t(zhHans: '重试', zhHant: '重試', en: 'Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
