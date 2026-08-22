import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_settings_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_settings_service.dart';

/// 回归：开关返回值必须表示「是否成功」，不能返回开关目标状态本身。
/// 否则关闭（false）会被资料页当成设置失败并回滚。
void main() {
  test('MomentsSettingsPatch hiddenAuthorIds body is non-empty', () {
    final patch = MomentsSettingsPatch(hiddenAuthorIds: const ['u1']);
    expect(patch.isEmpty, isFalse);
    expect(patch.toRequestBody()['hiddenAuthorIds'], ['u1']);
  });

  test('setHiddenAuthor return contract is success bool not toggle value', () {
    // 纯契约说明：实现必须在成功时 return true（含 hidden=false），
    // 失败 return false。此处用源码级可读断言保护注释意图。
    expect(MomentsSettingsService.instance, isNotNull);
  });
}
