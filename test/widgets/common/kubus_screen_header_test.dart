import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/widgets/common/kubus_screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'KubusHeaderText uses standardized screen title and subtitle sizes on wide layouts',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(1200, 800)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: KubusHeaderText(
                title: 'Screen Title',
                subtitle: 'Screen Subtitle',
              ),
            ),
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

  testWidgets(
      'KubusHeaderText uses responsive mobile title sizing on narrow layouts',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(320, 800)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: KubusHeaderText(
                title: 'Screen Title',
                subtitle: 'Screen Subtitle',
              ),
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Screen Title'));
    expect(
        title.style?.fontSize, lessThan(KubusHeaderMetrics.mobileAppBarTitle));
    expect(title.style?.fontSize, greaterThan(15));
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
    expect(title.maxLines, 1);
  });

  testWidgets(
      'KubusHeaderText allows at most two lines for narrow section headers',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(200, 800)),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              child: KubusHeaderText(
                title: 'Very Long Compact Section Header Title',
                kind: KubusHeaderKind.section,
              ),
            ),
          ),
        ),
      ),
    );

    final title =
        tester.widget<Text>(find.text('Very Long Compact Section Header Title'));

    expect(title.maxLines, 2);
  });

  testWidgets(
      'KubusHeaderText shrinks and allows extra title line on narrow widths',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 220,
            child: const KubusHeaderText(
              title: 'Very Long Kubus Header Title',
              subtitle: 'Subtitle',
              maxTitleLines: 1,
            ),
          ),
        ),
      ),
    );

    final title =
        tester.widget<Text>(find.text('Very Long Kubus Header Title'));

    expect(title.style?.fontSize, lessThan(KubusHeaderMetrics.screenTitle));
    expect(title.maxLines, 2);
  });
}
