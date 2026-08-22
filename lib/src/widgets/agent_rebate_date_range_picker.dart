import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

Future<AgentRebateDateRange?> showAgentRebateDateRangePicker(
  BuildContext context, {
  required AgentRebateDateRange initialRange,
  DateTime? now,
}) async {
  final i18n = AppI18n.of(context);
  // 预设按中国时间 07:00→次日 07:00 业务日计算，与反水历史聚合口径一致。
  final clock = now ?? DateTime.now();
  final choices = <(String, AgentRebateDateRange)>[
    (
      i18n.t(zhHans: '昨天', zhHant: '昨天', en: 'Yesterday'),
      AgentRebateDateRange.yesterday(clock),
    ),
    (
      i18n.t(zhHans: '今天', zhHant: '今天', en: 'Today'),
      AgentRebateDateRange.today(clock),
    ),
    (
      i18n.t(zhHans: '一周', zhHant: '一週', en: '7 days'),
      AgentRebateDateRange.recentDays(7, clock),
    ),
    (
      i18n.t(zhHans: '30天', zhHant: '30天', en: '30 days'),
      AgentRebateDateRange.recentDays(30, clock),
    ),
    (
      i18n.t(zhHans: '90天', zhHant: '90天', en: '90 days'),
      AgentRebateDateRange.recentDays(90, clock),
    ),
  ];
  final selected = await AppDialog.actionSheet<AgentRebateDateRange>(
    title: i18n.t(
      zhHans: '选择查询时间',
      zhHant: '選擇查詢時間',
      en: 'Select period',
    ),
    cancelText: i18n.t(zhHans: '取消', zhHant: '取消', en: 'Cancel'),
    actions: choices.map((choice) {
      final range = choice.$2;
      final isCurrent = range.start == initialRange.start &&
          range.end == initialRange.end;
      return AppActionSheetItem<AgentRebateDateRange>(
        text: choice.$1,
        subtitle: isCurrent
            ? i18n.t(zhHans: '当前选择', zhHant: '目前選擇', en: 'Selected')
            : '${range.startApiValue} — ${range.endApiValue}',
        value: range,
      );
    }).toList(growable: false),
  );
  if (!context.mounted) {
    return null;
  }
  return selected;
}
