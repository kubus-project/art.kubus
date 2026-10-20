import 'package:art_kubus/widgets/messaging/messaging_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpComposer(
    WidgetTester tester, {
    required TextEditingController controller,
    required VoidCallback onSend,
    VoidCallback? onAttach,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagingComposer(
            controller: controller,
            onSend: onSend,
            onAttach: onAttach ?? () {},
            hintText: 'Type a message',
            sendTooltip: 'Send',
            attachTooltip: 'Attach a file',
          ),
        ),
      ),
    );
  }

  testWidgets('composer exposes labelled field, send and attach actions',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await pumpComposer(
      tester,
      controller: controller,
      onSend: () {},
    );

    expect(find.bySemanticsLabel('Type a message'), findsWidgets);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(find.byTooltip('Attach a file'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('send action and submit both invoke onSend', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;

    await pumpComposer(
      tester,
      controller: controller,
      onSend: () => sends++,
    );

    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sends, 1);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(sends, 2);
  });
}
