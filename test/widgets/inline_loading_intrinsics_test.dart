import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:art_kubus/widgets/inline_loading.dart';

void main() {
  testWidgets(
      'explicitly sized InlineLoading survives intrinsic measurement '
      '(SliverFillRemaining hasScrollBody: false)', (tester) async {
    // Regression: the nearby-art panel renders its loading state under
    // SliverFillRemaining(hasScrollBody: false), which measures the child's
    // max intrinsic height. A LayoutBuilder cannot answer intrinsics, so an
    // InlineLoading built on one throws on every guest map boot.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: InlineLoading(width: 40, height: 40)),
            ),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
