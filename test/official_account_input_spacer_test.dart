import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/official_account_input_spacer.dart';

void main() {
  testWidgets('keeps normal input height and bottom safe area', (tester) async {
    const bottomInset = 34.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: Scaffold(
            body: Column(
              children: [
                Spacer(),
                OfficialAccountInputSpacer(
                  backgroundColor: Color(0xFFF5F5F6),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final box = tester.renderObject<RenderBox>(
      find.byType(OfficialAccountInputSpacer),
    );
    expect(
      box.size.height,
      OfficialAccountInputSpacer.inputBarHeight + bottomInset,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(EditableText), findsNothing);
  });
}
