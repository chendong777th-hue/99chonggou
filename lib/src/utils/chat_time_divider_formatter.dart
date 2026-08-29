import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// Formats the date label used by chat history time-divider rows.
///
/// Message timestamps from the IM SDK are seconds, while a few local
/// integrations provide milliseconds. Accept both so a malformed unit does
/// not turn a valid history row into a date near the Unix epoch.
String formatChatTimeDivider(int timestamp, {DateTime? now}) {
  if (timestamp <= 0) {
    return '';
  }
  final milliseconds =
      timestamp >= 1000000000000 ? timestamp : timestamp * 1000;
  final messageDate = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final currentDate = now ?? DateTime.now();
  final today = DateTime(currentDate.year, currentDate.month, currentDate.day);
  final messageDay =
      DateTime(messageDate.year, messageDate.month, messageDate.day);
  final timeText = _formatTime(messageDate);
  final i18n = AppI18n.current;

  if (messageDay == today) {
    return '${i18n.t(zhHans: '今天', zhHant: '今天', en: 'Today', ja: '今日', ko: '오늘')} $timeText';
  }
  if (messageDay == today.subtract(const Duration(days: 1))) {
    return '${i18n.t(zhHans: '昨天', zhHant: '昨天', en: 'Yesterday', ja: '昨日', ko: '어제')} $timeText';
  }

  switch (i18n.locale) {
    case AppLocale.en:
      const months = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final dateText = '${months[messageDate.month - 1]} ${messageDate.day}';
      return messageDate.year == currentDate.year
          ? '$dateText $timeText'
          : '$dateText, ${messageDate.year} $timeText';
    case AppLocale.ja:
      final pattern = messageDate.year == currentDate.year
          ? 'M月d日 HH:mm'
          : 'yyyy年M月d日 HH:mm';
      return _formatDate(messageDate, pattern);
    case AppLocale.ko:
      final pattern = messageDate.year == currentDate.year
          ? 'M월 d일 HH:mm'
          : 'yyyy년 M월 d일 HH:mm';
      return _formatDate(messageDate, pattern);
    case AppLocale.zhHans:
    case AppLocale.zhHant:
      final pattern = messageDate.year == currentDate.year
          ? 'M月d日 HH:mm'
          : 'yyyy年M月d日 HH:mm';
      return _formatDate(messageDate, pattern);
  }
}

String _formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _formatDate(DateTime date, String pattern) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString();
  final day = date.day.toString();
  final time = _formatTime(date);
  switch (pattern) {
    case 'M月d日 HH:mm':
      return '$month月$day日 $time';
    case 'yyyy年M月d日 HH:mm':
      return '$year年$month月$day日 $time';
    case 'M월 d일 HH:mm':
      return '$month월 $day일 $time';
    case 'yyyy년 M월 d일 HH:mm':
      return '$year년 $month월 $day일 $time';
    default:
      return '$year-$month-$day $time';
  }
}
