import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'KubusHeaderText uses standardized screen title and subtitle sizes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KubusHeaderText(
            title: 'Screen Title',
            subtitle: 'Screen Subtitle',
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Screen Title'));
    final subtitle = tester.widget<Text>(find.text('Screen Subtitle'));

    expect(title.style?.fontSize, KubusHeaderMetrics.screenTitle);
    expect(subtitle.style?.fontSize, KubusHeaderMetrics.screenSubtitle);

    final size = tester.getSize(find.byType(KubusHeaderText));
    expect(
        size.height, greaterThanOrEqualTo(KubusHeaderMetrics.headerMinHeight));
  });

  testWidgets('KubusHeaderText uses section sizing for compact section headers',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: KubusHeaderText(
            title: 'Section Title',
            subtitle: 'Section Subtitle',
            kind: KubusHeaderKind.section,
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Section Title'));
    final subtitle = tester.widget<Text>(find.text('Section Subtitle'));

    expect(title.style?.fontSize, KubusHeaderMetrics.sectionTitle);
    expect(subtitle.style?.fontSize, KubusHeaderMetrics.sectionSubtitle);
  });
}
