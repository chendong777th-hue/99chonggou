import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_settings_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_game_settings.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/dio_error_message.dart';

/// 用户资料页：自下而上展示三公流水（下注 / 庄 / 上下分）。
class UserProfileGameLedgerSheet extends StatefulWidget {
  const UserProfileGameLedgerSheet({
    super.key,
    required this.imUserId,
    this.displayName = '',
  });

  final String imUserId;
  final String displayName;

  static Future<void> show(
    BuildContext context, {
    required String imUserId,
    String displayName = '',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: UserProfileGameLedgerSheet(
            imUserId: imUserId,
            displayName: displayName,
          ),
        ),
      ),
    );
  }

  @override
  State<UserProfileGameLedgerSheet> createState() =>
      _UserProfileGameLedgerSheetState();
}

class _UserProfileGameLedgerSheetState extends State<UserProfileGameLedgerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loading = true;
  String? _error;
  SangongUserFlowReport _flow = const SangongUserFlowReport();
  int? _currentBalance;
  SangongUserGroupInfo _userGroup = const SangongUserGroupInfo();
  SangongGameSettings _gameSettings = SangongGameSettings.defaults();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    unawaited(_load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _titleName {
    final fromApi = _flow.nickname.trim();
    if (fromApi.isNotEmpty) {
      return fromApi;
    }
    final fallback = widget.displayName.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }
    return widget.imUserId.trim();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tenantReady = await SangongAdminApi.instance.ensureTenantSelected();
      if (!tenantReady) {
        if (!mounted) return;
        setState(() {
          _error = AppI18n.of(context).t(
            zhHans: '请先进入游戏群以确定租户',
            zhHant: '請先進入遊戲群以確定租戶',
            en: 'Open a game group to select tenant',
          );
          _loading = false;
        });
        return;
      }
      final imUserId = widget.imUserId.trim();
      final results = await Future.wait([
        SangongAdminApi.instance.fetchUserFlow(
          imUserId: imUserId,
        ),
        SangongAdminApi.instance.findUserReport(imUserId),
        SangongSettingsApi.instance.fetch(),
      ]);
      if (!mounted) {
        return;
      }
      final flow = results[0] as SangongUserFlowReport;
      final report = results[1] as SangongAdminUserReport?;
      final settings = results[2] as SangongGameSettings;
      setState(() {
        _flow = flow;
        _currentBalance = report?.balance;
        _userGroup = report?.group ?? const SangongUserGroupInfo();
        _gameSettings = settings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = DioErrorMessage.forApp(error);
        _loading = false;
      });
    }
  }

  String _formatTime(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      return trimmed;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _signedAmount(int value) {
    if (value > 0) {
      return '+$value';
    }
    return '$value';
  }

  Color _amountColor(int value, {required bool dark}) {
    if (value > 0) {
      return const Color(0xFF2E7D32);
    }
    if (value < 0) {
      return const Color(0xFFC62828);
    }
    return AppColors.subText(dark: dark);
  }

  DateTime? _parseTime(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }

  List<T> _newestFirst<T>(List<T> items, String Function(T item) timeOf) {
    final sorted = List<T>.from(items);
    sorted.sort((a, b) {
      final ta = _parseTime(timeOf(a));
      final tb = _parseTime(timeOf(b));
      if (ta == null && tb == null) {
        return 0;
      }
      if (ta == null) {
        return 1;
      }
      if (tb == null) {
        return -1;
      }
      return tb.compareTo(ta);
    });
    return sorted;
  }

  String _groupLabel(AppI18n i18n) {
    final label = _userGroup.displayLabel;
    if (label.isNotEmpty) {
      return label;
    }
    return i18n.t(
      zhHans: '未分组',
      zhHant: '未分組',
      en: 'Ungrouped',
    );
  }

  String? _sessionSubtitle(AppI18n i18n) {
    final parts = <String>[];
    if (_flow.isAllHistory) {
      parts.add(
        i18n.t(
          zhHans: '全部历史',
          zhHant: '全部歷史',
          en: 'All history',
        ),
      );
    } else if (_flow.sessionId != null && _flow.sessionId! > 0) {
      parts.add(
        i18n.t(
          zhHans: '会话 ${_flow.sessionId}',
          zhHant: '會話 ${_flow.sessionId}',
          en: 'Session ${_flow.sessionId}',
        ),
      );
    }
    parts.add(
      i18n.t(
        zhHans: '分组：${_groupLabel(i18n)}',
        zhHant: '分組：${_groupLabel(i18n)}',
        en: 'Group: ${_groupLabel(i18n)}',
      ),
    );
    if (_currentBalance != null) {
      parts.add(
        i18n.t(
          zhHans: '当前积分：$_currentBalance',
          zhHant: '當前積分：$_currentBalance',
          en: 'Balance: $_currentBalance',
        ),
      );
    }
    return parts.join(' · ');
  }

  bool get _hasMultipleSessions {
    final ids = <int>{};
    for (final entry in _flow.betFlow) {
      if (entry.sessionId > 0) {
        ids.add(entry.sessionId);
      }
    }
    for (final entry in _flow.bankerFlow) {
      if (entry.sessionId > 0) {
        ids.add(entry.sessionId);
      }
    }
    return ids.length > 1;
  }

  bool _shouldShowEntrySession(int sessionId) {
    return sessionId > 0 && (_flow.isAllHistory || _hasMultipleSessions);
  }

  String? _sessionLabel(int sessionId, AppI18n i18n) {
    if (!_shouldShowEntrySession(sessionId)) {
      return null;
    }
    return i18n.t(
      zhHans: '会话$sessionId',
      zhHant: '會話$sessionId',
      en: 'S$sessionId',
    );
  }

  String _tabCountSuffix(int count, int loaded) {
    final total = count > 0 ? count : loaded;
    if (total <= 0) {
      return '';
    }
    return ' ($total)';
  }

  int _compareDesc(int a, int b) => b.compareTo(a);

  List<SangongUserBetFlowEntry> get _betItemsNewestFirst {
    final sorted = List<SangongUserBetFlowEntry>.from(_flow.betFlow);
    sorted.sort((a, b) {
      final ta = _parseTime(a.settledAt);
      final tb = _parseTime(b.settledAt);
      if (ta != null && tb != null) {
        return tb.compareTo(ta);
      }
      if (ta != null) {
        return -1;
      }
      if (tb != null) {
        return 1;
      }
      final sessionCmp = _compareDesc(a.sessionId, b.sessionId);
      if (sessionCmp != 0) {
        return sessionCmp;
      }
      final periodCmp = _compareDesc(a.periodNo, b.periodNo);
      if (periodCmp != 0) {
        return periodCmp;
      }
      return _compareDesc(a.door, b.door);
    });
    return sorted;
  }

  List<SangongUserBankerFlowEntry> get _bankerItemsNewestFirst {
    final sorted = List<SangongUserBankerFlowEntry>.from(_flow.bankerFlow);
    sorted.sort((a, b) {
      final ta = _parseTime(a.settledAt);
      final tb = _parseTime(b.settledAt);
      if (ta != null && tb != null) {
        return tb.compareTo(ta);
      }
      if (ta != null) {
        return -1;
      }
      if (tb != null) {
        return 1;
      }
      final sessionCmp = _compareDesc(a.sessionId, b.sessionId);
      if (sessionCmp != 0) {
        return sessionCmp;
      }
      return _compareDesc(a.periodNo, b.periodNo);
    });
    return sorted;
  }

  List<SangongUserLedgerFlowEntry> get _ledgerItemsNewestFirst =>
      _newestFirst(_flow.ledgerFlow, (e) => e.createdAt);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = AppColors.text(dark: dark);
    final subColor = AppColors.subText(dark: dark);
    final surface = AppColors.card(dark: dark);
    final divider = subColor.withValues(alpha: 0.2);
    final primary = Theme.of(context).colorScheme.primary;
    final i18n = AppI18n.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;
    final sessionSubtitle = _sessionSubtitle(i18n);

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: subColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.t(
                            zhHans: '【$_titleName】流水',
                            zhHant: '【$_titleName】流水',
                            en: 'Ledger · $_titleName',
                          ),
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!_loading && sessionSubtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              sessionSubtitle,
                              style: TextStyle(color: subColor, fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : () => unawaited(_load()),
                    icon: Icon(Icons.refresh_rounded, color: subColor),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: primary,
              unselectedLabelColor: subColor,
              indicatorColor: primary,
              dividerColor: divider,
              tabs: [
                Tab(
                  text: i18n.t(
                    zhHans: '下注流水${_tabCountSuffix(_flow.counts.bet, _flow.betFlow.length)}',
                    zhHant: '下注流水${_tabCountSuffix(_flow.counts.bet, _flow.betFlow.length)}',
                    en: 'Bets${_tabCountSuffix(_flow.counts.bet, _flow.betFlow.length)}',
                  ),
                ),
                Tab(
                  text: i18n.t(
                    zhHans: '庄流水${_tabCountSuffix(_flow.counts.banker, _flow.bankerFlow.length)}',
                    zhHant: '莊流水${_tabCountSuffix(_flow.counts.banker, _flow.bankerFlow.length)}',
                    en: 'Banker${_tabCountSuffix(_flow.counts.banker, _flow.bankerFlow.length)}',
                  ),
                ),
                Tab(
                  text: i18n.t(
                    zhHans: '上下分${_tabCountSuffix(_flow.counts.ledger, _flow.ledgerFlow.length)}',
                    zhHant: '上下分${_tabCountSuffix(_flow.counts.ledger, _flow.ledgerFlow.length)}',
                    en: 'Balance${_tabCountSuffix(_flow.counts.ledger, _flow.ledgerFlow.length)}',
                  ),
                ),
              ],
            ),
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(titleColor, subColor)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildBetList(titleColor, subColor, divider),
                            _buildBankerList(titleColor, subColor, divider),
                            _buildBalanceList(titleColor, subColor),
                          ],
                        ),
            ),
            SizedBox(height: bottomInset > 0 ? bottomInset : 12),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Color titleColor, Color subColor) {
    final i18n = AppI18n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: subColor, size: 40),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(color: subColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => unawaited(_load()),
              child: Text(
                i18n.t(zhHans: '重试', zhHant: '重試', en: 'Retry'),
                style: TextStyle(color: titleColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(Color subColor) {
    return Center(
      child: Text(
        AppI18n.of(context).t(
          zhHans: '暂无记录',
          zhHant: '暫無記錄',
          en: 'No records',
        ),
        style: TextStyle(color: subColor, fontSize: 14),
      ),
    );
  }

  Widget _buildTotalBar({
    required Color titleColor,
    required Color subColor,
    required Color divider,
    required String label,
    required String trailing,
    int? trailingValue,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: subColor.withValues(alpha: dark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: trailingValue != null
                    ? _amountColor(trailingValue, dark: dark)
                    : titleColor,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBetList(Color titleColor, Color subColor, Color divider) {
    final allItems = _flow.betFlow;
    if (allItems.isEmpty) {
      return _buildEmpty(subColor);
    }
    final items = _betItemsNewestFirst;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final betTotal = allItems.fold<int>(0, (sum, e) => sum + e.betAmount);
    final netTotal = allItems
        .where((e) => e.net != null)
        .fold<int>(0, (sum, e) => sum + e.net!);
    final count = _flow.counts.bet > 0 ? _flow.counts.bet : allItems.length;
    final i18n = AppI18n.of(context);
    return Column(
      children: [
        _buildTotalBar(
          titleColor: titleColor,
          subColor: subColor,
          divider: divider,
          label: i18n.t(
            zhHans: '合计（$count笔）',
            zhHant: '合計（$count筆）',
            en: 'Total ($count)',
          ),
          trailing: i18n.t(
            zhHans: '下注 $betTotal · 输赢 ${_signedAmount(netTotal)}',
            zhHant: '下注 $betTotal · 輸贏 ${_signedAmount(netTotal)}',
            en: 'Bet $betTotal · Net ${_signedAmount(netTotal)}',
          ),
          trailingValue: netTotal,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: divider),
            itemBuilder: (context, index) {
              final item = items[index];
              final time = _formatTime(item.settledAt);
              final sessionLabel = _sessionLabel(item.sessionId, i18n);
              final subtitle = [
                if (sessionLabel != null) sessionLabel,
                if (item.periodNo > 0) '第${item.periodNo}局',
                if (item.doorLabel.isNotEmpty) item.doorLabel,
                if (!item.settled)
                  i18n.t(zhHans: '未结算', zhHant: '未結算', en: 'Pending'),
                if (item.compare.trim().isNotEmpty) item.compare.trim(),
              ].join(' · ');
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '下注 ${item.betAmount}',
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: subtitle.isNotEmpty
                    ? Text(
                        subtitle,
                        style: TextStyle(color: subColor, fontSize: 12),
                      )
                    : null,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.net != null)
                      Text(
                        _signedAmount(item.net!),
                        style: TextStyle(
                          color: _amountColor(item.net!, dark: dark),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Text(
                        i18n.t(
                          zhHans: '待结算',
                          zhHant: '待結算',
                          en: 'Pending',
                        ),
                        style: TextStyle(color: subColor, fontSize: 13),
                      ),
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: TextStyle(color: subColor, fontSize: 11),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatBankerBracketTime(String raw) {
    final parsed = _parseTime(raw);
    if (parsed == null) {
      return '';
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '【$month-$day $hour:$minute】';
  }

  static const Color _bankerGreen = Color(0xFF1B9E3E);
  static const Color _bankerBlue = Color(0xFF1976D2);
  /// 上下分参考样式：标签/时间浅绿、上分金额褐红、剩余/下分金额深灰。
  static const Color _ledgerLabelGreen = Color(0xFF88B04B);
  static const Color _ledgerCreditValue = Color(0xFFC0504D);

  /// 上下分专用：【MM-DD HH:MM:SS】
  String _formatLedgerBracketTime(String raw) {
    final parsed = _parseTime(raw);
    if (parsed == null) {
      return '';
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '【$month-$day $hour:$minute:$second】';
  }

  int _bankerWater(SangongUserBankerFlowEntry item) {
    return _gameSettings.computeBankerWater(
      item.totalBetAmount,
      bankerRakePoints: item.bankerRakePoints,
    );
  }

  Widget _buildBankerFlowRow(
    SangongUserBankerFlowEntry item, {
    required Color titleColor,
  }) {
    final time = _formatBankerBracketTime(item.settledAt);
    final sessionLabel = _sessionLabel(item.sessionId, AppI18n.of(context));
    final period = item.periodNo > 0 ? '${item.periodNo}' : '-';
    final grab = item.totalBetAmount;
    final water = _bankerWater(item);
    final net = item.net;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 15, height: 1.35),
              children: [
                if (time.isNotEmpty)
                  TextSpan(
                    text: time,
                    style: const TextStyle(color: _bankerGreen),
                  ),
                if (sessionLabel != null)
                  TextSpan(
                    text: '$sessionLabel ',
                    style: TextStyle(color: titleColor.withValues(alpha: 0.72)),
                  ),
                TextSpan(
                  text: '岛数:$period',
                  style: const TextStyle(color: _bankerGreen),
                ),
                TextSpan(
                  text: '抢注:$grab',
                  style: TextStyle(color: titleColor),
                ),
                TextSpan(
                  text: '水:$water',
                  style: const TextStyle(color: _bankerBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 15, height: 1.35),
              children: [
                const TextSpan(
                  text: '出入:',
                  style: TextStyle(color: _bankerGreen),
                ),
                TextSpan(
                  text: '$net',
                  style: const TextStyle(color: _bankerGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankerList(Color titleColor, Color subColor, Color divider) {
    final allItems = _flow.bankerFlow;
    if (allItems.isEmpty) {
      return _buildEmpty(subColor);
    }
    final items = _bankerItemsNewestFirst;
    final totalBetAmount =
        allItems.fold<int>(0, (sum, e) => sum + e.totalBetAmount);
    final waterTotal =
        allItems.fold<int>(0, (sum, e) => sum + _bankerWater(e));
    final netTotal = allItems.fold<int>(0, (sum, e) => sum + e.net);
    final count = _flow.counts.banker > 0 ? _flow.counts.banker : allItems.length;
    final i18n = AppI18n.of(context);
    return Column(
      children: [
        _buildTotalBar(
          titleColor: titleColor,
          subColor: subColor,
          divider: divider,
          label: i18n.t(
            zhHans: '合计（$count笔）',
            zhHant: '合計（$count筆）',
            en: 'Total ($count)',
          ),
          trailing: i18n.t(
            zhHans: '抢注 $totalBetAmount · 水 $waterTotal · 出入 ${_signedAmount(netTotal)}',
            zhHant: '搶注 $totalBetAmount · 水 $waterTotal · 出入 ${_signedAmount(netTotal)}',
            en: 'Grab $totalBetAmount · Water $waterTotal · Net ${_signedAmount(netTotal)}',
          ),
          trailingValue: netTotal,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: divider),
            itemBuilder: (context, index) {
              return _buildBankerFlowRow(
                items[index],
                titleColor: titleColor,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerFlowRow(
    SangongUserLedgerFlowEntry item, {
    required Color titleColor,
  }) {
    final time = _formatLedgerBracketTime(item.createdAt);
    final change = item.balanceChange.abs();
    final actionLabel = item.isDebit ? '下分' : '上分';
    final operator = item.operator.trim();
    // 参考：【06-17 06:06:25】 上分:188 剩余:-13879
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 15, height: 1.25, color: titleColor),
          children: [
            if (time.isNotEmpty)
              TextSpan(
                text: '$time ',
                style: const TextStyle(color: _ledgerLabelGreen),
              ),
            TextSpan(
              text: '$actionLabel:',
              style: const TextStyle(color: _ledgerLabelGreen),
            ),
            TextSpan(
              text: '$change',
              style: const TextStyle(color: _ledgerCreditValue),
            ),
            const TextSpan(
              text: ' 剩余:',
              style: TextStyle(color: _ledgerLabelGreen),
            ),
            TextSpan(
              text: '${item.balanceAfter}',
              style: TextStyle(color: titleColor),
            ),
            if (operator.isNotEmpty) ...[
              const TextSpan(
                text: ' 操作:',
                style: TextStyle(color: _ledgerLabelGreen),
              ),
              TextSpan(
                text: operator,
                style: TextStyle(color: titleColor.withValues(alpha: 0.82)),
              ),
            ],
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLedgerSummaryRow({
    required Color titleColor,
    required int creditTotal,
    required int debitTotal,
  }) {
    final name = _titleName;
    // 参考：【昵称】总上分:42000 总下分:0（可换行）
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 15, height: 1.3, color: titleColor),
          children: [
            TextSpan(
              text: '【$name】',
              style: const TextStyle(color: _ledgerLabelGreen),
            ),
            const TextSpan(
              text: '总上分:',
              style: TextStyle(color: _ledgerLabelGreen),
            ),
            TextSpan(
              text: '$creditTotal',
              style: const TextStyle(color: _ledgerCreditValue),
            ),
            const TextSpan(
              text: ' 总下分:',
              style: TextStyle(color: _ledgerLabelGreen),
            ),
            TextSpan(
              text: '$debitTotal',
              style: TextStyle(color: titleColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceList(Color titleColor, Color subColor) {
    final allItems = _flow.ledgerFlow;
    if (allItems.isEmpty) {
      return _buildEmpty(subColor);
    }
    // 与参考图一致：时间正序（旧→新），汇总行贴在列表底部。
    final items = _ledgerItemsNewestFirst.reversed.toList(growable: false);
    final creditTotal = allItems
        .where((e) => e.balanceChange > 0)
        .fold<int>(0, (sum, e) => sum + e.balanceChange);
    final debitTotal = allItems
        .where((e) => e.balanceChange < 0)
        .fold<int>(0, (sum, e) => sum + e.balanceChange.abs());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _buildLedgerFlowRow(
                items[index],
                titleColor: titleColor,
              );
            },
          ),
        ),
        _buildLedgerSummaryRow(
          titleColor: titleColor,
          creditTotal: creditTotal,
          debitTotal: debitTotal,
        ),
      ],
    );
  }
}
