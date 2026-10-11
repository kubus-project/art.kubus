import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_send_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('send button uses the control corner, not a circle',
      (tester) async {
    var sent = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KubusSendButton(tooltip: 'Send', onPressed: () => sent++),
        ),
      ),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    final shape = button.style!.shape!.resolve(<WidgetState>{})
        as RoundedRectangleBorder;
    expect(
      shape.borderRadius,
      BorderRadius.circular(KubusRadius.control + 2),
    );
    expect(KubusSendButton.radius, KubusRadius.control + 2);
    expect(tester.getSize(find.byType(IconButton)), const Size(48, 48));

    await tester.tap(find.byType(IconButton));
    expect(sent, 1);
  });
}
