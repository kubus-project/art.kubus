import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/desktop/components/desktop_widgets.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('DesktopStatCard uses standardized stat sizing', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 180,
              child: DesktopStatCard(
                label: 'Followers',
                value: '128',
                icon: Icons.group_outlined,
              ),
            ),
          ),
        ),
      ),
    );

    final value = tester.widget<Text>(find.text('128'));
    final label = tester.widget<Text>(find.text('Followers'));

    expect(value.style?.fontSize, KubusChromeMetrics.statValue);
    expect(label.style?.fontSize, KubusChromeMetrics.statLabel);
  });
}
