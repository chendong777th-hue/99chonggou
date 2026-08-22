import 'dart:async' show TimeoutException, unawaited;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
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
import 'package:tencent_cloud_chat_demo/src/widgets/agent_rebate_summary_card.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_empty_state.dart';

class AgentRebateHistoryPage extends StatefulWidget {
  const AgentRebateHistoryPage({super.key, this.api, this.initialRange});

  final AgentRebateApi? api;
  final AgentRebateDateRange? initialRange;

  static Future<void> open(
    BuildContext context, {
    AgentRebateDateRange? initialRange,
  }) {
    return Navigator.of(context).push<void>(
      AppMaterialPageRoute(
        settings: const RouteSettings(name: 'agent_rebate_history'),
        builder: (_) => AgentRebateHistoryPage(initialRange: initialRange),
      ),
    );
  }

  @override
  State<AgentRebateHistoryPage> createState() => _AgentRebateHistoryPageState();
}

Future<void> openAgentRebateHistoryPage(
  BuildContext context, {
  AgentRebateDateRange? initialRange,
}) {
  return AgentRebateHistoryPage.open(context, initialRange: initialRange);
}

class _AgentRebateHistoryPageState extends State<AgentRebateHistoryPage> {
  late final AgentRebateApi _api = widget.api ?? AgentRebateApi.instance;
  late AgentRebateDateRange _range =
      widget.initialRange ?? AgentRebateDateRange.today();
  AgentRebateHistoryDto? _data;
  String? _error;
  bool _loading = true;
  bool _exporting = false;

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
      final result = await _api.fetchHistory(_range);
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

  Future<void> _pickRange() async {
    final picked = await showAgentRebateDateRangePicker(
      context,
      initialRange: _range,
    );
    if (!mounted || picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  Future<void> _downloadHistory() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      var task = await _api.submitHistoryExport(_range);
      if (task.taskNo.trim().isEmpty) {
        throw const FormatException('Export task number is missing');
      }
      for (var attempt = 0; task.isPending && attempt < 40; attempt++) {
        if (!mounted) return;
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        task = await _api.fetchHistoryExportTask(task.taskNo);
      }
      if (task.isFailed) {
        throw StateError(
          task.errorMessage?.trim().isNotEmpty == true
              ? task.errorMessage!
              : 'EXPORT_FAILED',
        );
      }
      if (!task.isCompleted) {
        throw TimeoutException('EXPORT_NOT_READY');
      }
      final fallbackName =
          '代理反水历史_${_range.startApiValue}_${_range.endApiValue}.xlsx';
      final download = await _api.downloadHistoryExport(
        task.taskNo,
        fallbackFileName: task.fileName?.trim().isNotEmpty == true
            ? task.fileName!
            : fallbackName,
      );
      if (download.bytes.isEmpty) {
        throw const FormatException('Export file is empty');
      }
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存反水历史',
        fileName: download.fileName,
        type: FileType.custom,
        allowedExtensions: <String>[
          _agentRebateExportExtension(download.fileName),
        ],
        bytes: Uint8List.fromList(download.bytes),
      );
      if (!mounted) return;
      if (kIsWeb || savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppI18n.of(context).t(
                zhHans: '历史记录已下载',
                zhHant: '歷史記錄已下載',
                en: 'History downloaded.',
              ),
            ),
          ),
        );
        if (!kIsWeb && savedPath != null) {
          await OpenFile.open(savedPath);
        }
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
        setState(() => _exporting = false);
      }
    }
  }

  String _agentRebateExportExtension(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    for (final extension in const <String>['xlsx', 'zip', 'txt']) {
      if (normalized.endsWith('.$extension')) {
        return extension;
      }
    }
    return 'xlsx';
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
          i18n.t(zhHans: '反水历史', zhHant: '反水歷史', en: 'Rebate History'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              onPressed: _loading ? null : _downloadHistory,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(
                i18n.t(zhHans: '下载', zhHant: '下載', en: 'Download'),
              ),
            ),
          const SizedBox(width: AppTokens.s2),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _DateRangeBar(
              range: _range,
              loading: _loading,
              onPressed: _pickRange,
            ),
            Expanded(child: _buildBody(i18n)),
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
      return _HistoryErrorState(message: error, onRetry: _load);
    }
    final history = _data;
    if (history == null || history.days.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AppEmptyState(
              message: i18n.t(
                zhHans: '所选日期暂无反水记录',
                zhHant: '所選日期暫無反水記錄',
                en: 'No rebate records for the selected dates.',
              ),
            ),
          ],
        ),
      );
    }
    final days = sortAgentRebateHistoryDaysNewestFirst(history.days);
    final teamTotalRebateLabel = i18n.t(
      zhHans: '团队总反水',
      zhHant: '團隊總反水',
      en: 'Team Total Rebate',
    );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTokens.s5),
        itemCount: days.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppTokens.s4),
        itemBuilder: (context, index) {
          if (index == 0) {
            return AgentRebateSummaryCard(
              title: i18n.t(zhHans: '合计', zhHant: '合計', en: 'Total'),
              subtitle: '${history.startDate} — ${history.endDate}',
              summary: history.total,
              highlight: true,
              availableRebateLabel: teamTotalRebateLabel,
            );
          }
          final day = days[index - 1];
          return AgentRebateSummaryCard(
            title: day.businessDate,
            summary: day.summary,
            availableRebateLabel: teamTotalRebateLabel,
          );
        },
      ),
    );
  }
}

class _DateRangeBar extends StatelessWidget {
  const _DateRangeBar({
    required this.range,
    required this.loading,
    required this.onPressed,
  });

  final AgentRebateDateRange range;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: AppColors.card(dark: dark),
      child: InkWell(
        onTap: loading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s5,
            vertical: AppTokens.s4,
          ),
          child: Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                color: AppColors.primaryBlue,
                size: 21,
              ),
              const SizedBox(width: AppTokens.s3),
              Expanded(
                child: Text(
                  '${range.startApiValue} — ${range.endApiValue}',
                  style: TextStyle(
                    color: AppColors.text(dark: dark),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                i18n.format(
                  zhHans: '共 {days} 天',
                  zhHant: '共 {days} 天',
                  en: '{days} days',
                  vars: {'days': '${range.inclusiveDays}'},
                ),
                style: TextStyle(
                  color: AppColors.subText(dark: dark),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: AppTokens.s2),
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

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

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
