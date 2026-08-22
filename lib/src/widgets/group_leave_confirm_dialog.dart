import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_leave_diag_log.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

class GroupLeaveConfirmDialog {
  GroupLeaveConfirmDialog._();

  static Future<bool> show({required bool dismiss}) {
    GroupLeaveDiagLog.log(
      'confirm_shown',
      extras: <String, Object?>{'action': dismiss ? 'dismiss' : 'leave'},
    );
    final i18n = AppI18n.current;
    return AppDialog.confirm(
      title: i18n.t(
        zhHans: dismiss ? '解散群聊' : '退出群聊',
        zhHant: dismiss ? '解散群聊' : '退出群聊',
        en: dismiss ? 'Dismiss Group' : 'Leave Group',
        ja: dismiss ? 'グループを解散' : 'グループを退会',
        ko: dismiss ? '그룹 해산' : '그룹 나가기',
      ),
      message: i18n.t(
        zhHans: dismiss ? '解散后不会接收到此群聊消息' : '退出后不会接收到此群聊消息',
        zhHant: dismiss ? '解散後不會接收到此群聊消息' : '退出後不會接收到此群聊消息',
        en: dismiss
            ? 'You will no longer receive messages from this group after dismissing it.'
            : 'You will no longer receive messages from this group after leaving.',
        ja: dismiss
            ? '解散後はこのグループのメッセージを受信しなくなります。'
            : '退会後はこのグループのメッセージを受信しなくなります。',
        ko: dismiss
            ? '해산 후에는 이 그룹의 메시지를 받지 않습니다.'
            : '나간 후에는 이 그룹의 메시지를 받지 않습니다.',
      ),
      confirmText: i18n.t(
        zhHans: dismiss ? '解散' : '退出',
        zhHant: dismiss ? '解散' : '退出',
        en: dismiss ? 'Dismiss' : 'Leave',
        ja: dismiss ? '解散' : '退会',
        ko: dismiss ? '해산' : '나가기',
      ),
      cancelText: i18n.t(
        zhHans: '取消',
        zhHant: '取消',
        en: 'Cancel',
        ja: 'キャンセル',
        ko: '취소',
      ),
      destructive: true,
    ).then((accepted) {
      GroupLeaveDiagLog.log(
        accepted ? 'confirm_accepted' : 'confirm_cancelled',
        extras: <String, Object?>{'action': dismiss ? 'dismiss' : 'leave'},
      );
      return accepted;
    });
  }
}
