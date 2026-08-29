import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';

/// T1 契约测试：ChatUiStateStore 的 markMessageChanged 合并同一帧内多次调用
/// 为单次 notifyListeners（通过 post-frame coalesce），避免群消息风暴时逐条 notify。
///
/// 测试策略：不依赖 Flutter frame 调度（纯 Dart 测试无法驱动
/// SchedulerBinding.addPostFrameCallback）。改为：
/// - 验证 rowRevision 同步更新（读取不受 coalesce 影响）
/// - 验证 flushCoalescedNotify 只 emit 一次（多次 mark 后一次 flush）
/// - 验证用户交互方法仍立即 notify
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChatUiStateStore store;

  setUp(() {
    store = ChatUiStateStore();
  });

  tearDown(() {
    store.dispose();
  });

  test('markMessageChanged does not notify synchronously', () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.markMessageChanged('group_test', 'msg_1');
    expect(notifyCount, 0);
  });

  test('flushCoalescedNotify emits single notify after multiple marks', () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.markMessageChanged('group_test', 'msg_1');
    store.markMessageChanged('group_test', 'msg_2');
    store.markMessageChanged('group_test', 'msg_3');
    store.markMessageChanged('group_test', 'msg_4');
    store.markMessageChanged('group_test', 'msg_5');

    expect(notifyCount, 0);

    store.flushCoalescedNotify();
    expect(notifyCount, 1);
  });

  test('second flush after no pending marks does not notify', () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.markMessageChanged('group_test', 'msg_1');
    store.flushCoalescedNotify();
    expect(notifyCount, 1);

    store.flushCoalescedNotify();
    expect(notifyCount, 1);
  });

  test('rowRevision updates synchronously before notify fires', () {
    store.markMessageChanged('group_test', 'msg_1');
    expect(store.rowRevision('group_test', 'msg_1'), 1);

    store.markMessageChanged('group_test', 'msg_1');
    expect(store.rowRevision('group_test', 'msg_1'), 2);
  });

  test('markMessagesChanged batch coalesces into single flush', () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.markMessagesChanged('group_test', ['msg_a', 'msg_b', 'msg_c']);
    expect(notifyCount, 0);

    store.flushCoalescedNotify();
    expect(notifyCount, 1);
  });

  test('user interaction methods notify immediately', () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.setMultiSelect('group_test', true);
    expect(notifyCount, 1);

    store.setMessageSelected('group_test', 'msg_1', true);
    expect(notifyCount, 2);
  });

  test('no notify when markMessageChanged called with empty key', () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.markMessageChanged('group_test', '');
    store.flushCoalescedNotify();
    expect(notifyCount, 0);
  });

  test('clearConversationState notifies immediately even with pending coalesce',
      () {
    var notifyCount = 0;
    store.addListener(() {
      notifyCount++;
    });

    store.markMessageChanged('group_test', 'msg_1');
    expect(notifyCount, 0);

    store.clearConversationState('group_test');
    expect(notifyCount, 1);

    // flush 后不应再 emit（clear 已 notify）。
    store.flushCoalescedNotify();
    expect(notifyCount, 1);
  });
}
