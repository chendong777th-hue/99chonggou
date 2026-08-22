import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/utils/adaptive_modal.dart';

DateTime _clampCupertinoSheetDate(
  DateTime value, {
  required DateTime minimumDate,
  required DateTime maximumDate,
}) {
  if (value.isBefore(minimumDate)) return minimumDate;
  if (value.isAfter(maximumDate)) return maximumDate;
  return value;
}

DateTime _alignMinute(DateTime value, {int interval = 1}) {
  final safeInterval = interval <= 0 ? 1 : interval;
  final minute = (value.minute ~/ safeInterval) * safeInterval;
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    minute,
  );
}

/// Same Cupertino sheet chrome as group-live schedule / profile birthday pickers.
Future<DateTime?> showAppCupertinoDateTimeSheet(
  BuildContext context, {
  required String title,
  required DateTime initialDateTime,
  DateTime? minimumDate,
  DateTime? maximumDate,
  CupertinoDatePickerMode mode = CupertinoDatePickerMode.dateAndTime,
  bool use24hFormat = true,
  int minuteInterval = 1,
}) async {
  final i18n = AppI18n.of(context);
  final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
  final sheetBackground = theme.conversationItemBgColor ??
      theme.weakBackgroundColor ??
      Colors.white;
  final titleColor = theme.darkTextColor ?? Colors.black;
  final actionColor = theme.primaryColor ?? const Color(0xFF1E90FF);
  final dividerColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);

  final now = DateTime.now();
  final minDate = minimumDate ?? DateTime(now.year - 100);
  final maxDate = maximumDate ?? DateTime(now.year + 100);
  var tempDate = _clampCupertinoSheetDate(
    mode == CupertinoDatePickerMode.dateAndTime ||
            mode == CupertinoDatePickerMode.time
        ? _alignMinute(initialDateTime, interval: minuteInterval)
        : DateTime(
            initialDateTime.year,
            initialDateTime.month,
            initialDateTime.day,
          ),
    minimumDate: minDate,
    maximumDate: maxDate,
  );

  return showAdaptiveModalSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    desktopMaxWidth: 420,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: sheetBackground,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            i18n.t(
                              zhHans: '取消',
                              zhHant: '取消',
                              en: 'Cancel',
                              ja: 'キャンセル',
                              ko: '취소',
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              color: titleColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.pop(sheetContext, tempDate),
                          child: Text(
                            i18n.t(
                              zhHans: '确定',
                              zhHant: '確定',
                              en: 'OK',
                              ja: 'OK',
                              ko: '확인',
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: actionColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 0.5, color: dividerColor),
                  SizedBox(
                    height: 220,
                    child: CupertinoDatePicker(
                      mode: mode,
                      initialDateTime: tempDate,
                      minimumDate: minDate,
                      maximumDate: maxDate,
                      use24hFormat: use24hFormat,
                      minuteInterval: minuteInterval,
                      onDateTimeChanged: (date) {
                        setModalState(() {
                          tempDate = _clampCupertinoSheetDate(
                            date,
                            minimumDate: minDate,
                            maximumDate: maxDate,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Chat-history "find by date" — same sheet as live schedule, date-only.
Future<DateTime?> showChatHistoryDatePicker(BuildContext context) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return showAppCupertinoDateTimeSheet(
    context,
    title: AppI18n.of(context).t(
      zhHans: '选择日期',
      zhHant: '選擇日期',
      en: 'Select date',
      ja: '日付を選択',
      ko: '날짜 선택',
    ),
    initialDateTime: today,
    minimumDate: DateTime(now.year - 5, now.month, now.day),
    maximumDate: today,
    mode: CupertinoDatePickerMode.date,
  );
}
