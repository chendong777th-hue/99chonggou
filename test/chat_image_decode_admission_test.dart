import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_image_decode_admission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ChatImageDecodeAdmission.instance.resetForTesting();
  });

  testWidgets('admits one outgoing image decode per frame in FIFO order',
      (tester) async {
    final admitted = <String>[];
    ChatImageDecodeAdmission.instance.request(
      key: 'conv|one',
      visible: true,
      onAdmit: () => admitted.add('one'),
    );
    ChatImageDecodeAdmission.instance.request(
      key: 'conv|two',
      visible: true,
      onAdmit: () => admitted.add('two'),
    );

    expect(admitted, isEmpty);
    await tester.pump();
    expect(admitted, <String>['one']);
    await tester.pump();
    expect(admitted, <String>['one', 'two']);
  });

  testWidgets('visible row is admitted before queued offscreen row',
      (tester) async {
    final admitted = <String>[];
    ChatImageDecodeAdmission.instance.request(
      key: 'conv|offscreen',
      visible: false,
      onAdmit: () => admitted.add('offscreen'),
    );
    ChatImageDecodeAdmission.instance.request(
      key: 'conv|visible',
      visible: true,
      onAdmit: () => admitted.add('visible'),
    );

    await tester.pump();
    expect(admitted, <String>['visible']);
    await tester.pump();
    expect(admitted, <String>['visible', 'offscreen']);
  });

  testWidgets('disposed row can cancel pending decode admission',
      (tester) async {
    var admitted = false;
    ChatImageDecodeAdmission.instance.request(
      key: 'conv|disposed',
      visible: true,
      onAdmit: () => admitted = true,
    );
    ChatImageDecodeAdmission.instance.cancel('conv|disposed');

    await tester.pump();
    expect(admitted, isFalse);
  });
}
