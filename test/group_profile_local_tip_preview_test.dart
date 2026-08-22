import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_profile_local_tip_preview.dart';

void main() {
  group('groupProfileLocalTipPreview', () {
    test('maps profile change actions to frozen copy', () {
      expect(
        groupProfileLocalTipPreview('group_name_changed', '张三'),
        '张三修改了群名称',
      );
      expect(
        groupProfileLocalTipPreview('group_avatar_changed', '李四'),
        '李四修改了群头像',
      );
      expect(
        groupProfileLocalTipPreview('group_notice_changed', '王五'),
        '王五修改了群公告',
      );
    });

    test('returns empty for unknown action', () {
      expect(groupProfileLocalTipPreview('member_muted', '张三'), '');
    });
  });
}
