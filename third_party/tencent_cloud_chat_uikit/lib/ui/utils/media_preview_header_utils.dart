import 'package:intl/intl.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

class MediaPreviewHeaderUtils {
  MediaPreviewHeaderUtils._();

  static String titleForMessage(V2TimMessage message) {
    if (message.isSelf == true) {
      return TIM_t('您');
    }
    final nick = message.nickName?.trim() ?? '';
    if (nick.isNotEmpty) {
      return nick;
    }
    final sender = message.sender?.trim() ?? '';
    if (sender.isNotEmpty) {
      return sender;
    }
    return TIM_t('成员');
  }

  static String subtitleForMessage(int? timestampSeconds) {
    if (timestampSeconds == null || timestampSeconds <= 0) {
      return '';
    }
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay =
        DateTime(dateTime.year, dateTime.month, dateTime.day);
    final timeText = DateFormat('HH:mm').format(dateTime);

    if (messageDay == today) {
      return '${TIM_t('今天')} $timeText';
    }
    if (messageDay == today.subtract(const Duration(days: 1))) {
      return '${TIM_t('昨天')} $timeText';
    }
    if (dateTime.year == now.year) {
      return '${DateFormat('M月d日').format(dateTime)} $timeText';
    }
    return DateFormat('yyyy年M月d日 HH:mm').format(dateTime);
  }
}
