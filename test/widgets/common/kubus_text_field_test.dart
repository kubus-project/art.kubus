import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/common/kubus_text_field.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );

void main() {
  testWidgets('renders above-label and forwards text input', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_wrap(KubusTextField(
      label: 'Email',
      controller: controller,
      hintText: 'you@kubus.site',
    )));
    expect(find.text('Email'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'rok@kubus.site');
    expect(controller.text, 'rok@kubus.site');
  });

  testWidgets('validator surfaces error text', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(_wrap(Form(
      key: key,
      child: KubusTextField(
        label: 'Name',
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    )));
    key.currentState!.validate();
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('label text is omitted when null', (tester) async {
    await tester.pumpWidget(_wrap(const KubusTextField(hintText: 'Search')));
    expect(find.text('Search'), findsOneWidget);
    expect(find.byKey(KubusTextField.labelKey), findsNothing);

    await tester.pumpWidget(_wrap(const KubusTextField(
      label: 'Query',
      hintText: 'Search',
    )));
    expect(find.byKey(KubusTextField.labelKey), findsOneWidget);
  });
}
