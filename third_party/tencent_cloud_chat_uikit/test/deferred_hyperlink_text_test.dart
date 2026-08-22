import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/deferred_hyperlink_text.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/hyperlink_enrich_scheduler.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/link_text_parse_cache.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/widgets/link_text.dart';

void main() {
  setUp(() {
    LinkTextParseCache.instance.clear();
    HyperlinkEnrichScheduler.instance.debugReset();
  });
  tearDown(() {
    LinkTextParseCache.instance.clear();
    HyperlinkEnrichScheduler.instance.debugReset();
  });

  testWidgets('plain on first build; enriches after post-frame', (tester) async {
    var ready = false;
    const text = 'hello https://example.com/defer';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeferredHyperlinkText(
            identity: 'msg-1\u0000$text',
            displayText: text,
            textStyle: const TextStyle(fontSize: 16),
            onReadyChanged: (value) => ready = value,
            buildEnriched: () {
              return ({TextStyle? style}) => LinkText(
                    messageText: text,
                    style: style,
                  );
            },
          ),
        ),
      ),
    );

    // pumpWidget runs the post-frame scheduler job (marks ready). One more
    // pump builds the enriched LinkText path.
    final state = tester.state<DeferredHyperlinkTextState>(
      find.byType(DeferredHyperlinkText),
    );
    expect(state.isHyperlinkReady, isTrue);
    expect(ready, isTrue);

    await tester.pump();
    expect(LinkTextParseCache.instance.flaggedMisses, greaterThan(0));
  });

  testWidgets('enrich budget spreads across frames', (tester) async {
    HyperlinkEnrichScheduler.instance.maxPerFrame = 2;
    final readyFlags = List<bool>.filled(4, false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              for (var i = 0; i < 4; i++)
                DeferredHyperlinkText(
                  identity: 'msg-$i\u0000https://example.com/$i',
                  displayText: 'https://example.com/$i',
                  textStyle: const TextStyle(fontSize: 14),
                  onReadyChanged: (_) => readyFlags[i] = true,
                  buildEnriched: () {
                    final text = 'https://example.com/$i';
                    return ({TextStyle? style}) => LinkText(
                          messageText: text,
                          style: style,
                        );
                  },
                ),
            ],
          ),
        ),
      ),
    );

    // First post-frame (inside pumpWidget): at most 2 enrichments.
    expect(readyFlags.where((v) => v).length, 2);
    expect(HyperlinkEnrichScheduler.instance.pendingCount, greaterThan(0));

    await tester.pump();
    expect(readyFlags.where((v) => v).length, 4);
    expect(HyperlinkEnrichScheduler.instance.pendingCount, 0);
  });
}
