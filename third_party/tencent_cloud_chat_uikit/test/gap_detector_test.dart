import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html)
      'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/gap_detector.dart';

V2TimMessage _message(
  int seq, {
  String? msgID,
  int? timestamp,
}) {
  return V2TimMessage(
    msgID: msgID ?? 'm$seq',
    seq: '$seq',
    timestamp: timestamp ?? seq,
    elemType: 1,
    isSelf: false,
  );
}

void main() {
  test('group server Seq reports the exact missing range', () {
    final gaps = GapDetector.detectGaps(
      newestFirst: <V2TimMessage>[_message(103), _message(100)],
      isGroup: true,
      fullScan: true,
    );

    expect(gaps, hasLength(1));
    expect(gaps.single.upperSeq, 103);
    expect(gaps.single.lowerSeq, 100);
  });

  test('local rows are ignored instead of hiding adjacent server gaps', () {
    final gaps = GapDetector.detectGaps(
      newestFirst: <V2TimMessage>[
        _message(103),
        _message(0, msgID: 'local_tip'),
        _message(100),
      ],
      isGroup: true,
      fullScan: true,
    );

    expect(gaps, hasLength(1));
    expect(gaps.single.gapId, 'gap_m103_m100');
  });

  test('C2C timestamp spacing is never treated as continuity proof', () {
    final gaps = GapDetector.detectGaps(
      newestFirst: <V2TimMessage>[
        _message(9, timestamp: 200000),
        _message(1, timestamp: 1),
      ],
      isGroup: false,
      fullScan: true,
    );

    expect(gaps, isEmpty);
  });

  test('seam scan ignores gaps outside the bounded radius', () {
    final messages = <V2TimMessage>[
      for (var seq = 130; seq >= 101; seq--)
        if (seq != 112) _message(seq),
    ];

    expect(
      GapDetector.detectGaps(
        newestFirst: messages,
        isGroup: true,
        seamIndex: 1,
      ),
      isEmpty,
    );
    expect(
      GapDetector.detectGaps(
        newestFirst: messages,
        isGroup: true,
        seamIndex: 18,
      ),
      hasLength(1),
    );
  });
}
