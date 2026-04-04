import 'package:art_kubus/screens/desktop/components/desktop_notifications_panel.dart';
import 'package:art_kubus/screens/desktop/desktop_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fallback helper returns unavailable only when fallback and empty', () {
    expect(
      DesktopNotificationsPanel.shouldShowUnavailableInFallback(
        isIpfsFallbackMode: true,
        activityCount: 0,
      ),
      isTrue,
    );

    expect(
      DesktopNotificationsPanel.shouldShowUnavailableInFallback(
        isIpfsFallbackMode: true,
        activityCount: 2,
      ),
      isFalse,
    );

    expect(
      DesktopNotificationsPanel.shouldShowUnavailableInFallback(
        isIpfsFallbackMode: false,
        activityCount: 0,
      ),
      isFalse,
    );
  });

  testWidgets('desktop breakpoints classify compact/medium widths correctly',
      (tester) async {
    bool compactAt500 = false;
    bool compactAt700 = true;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(500, 900)),
          child: Builder(
            builder: (context) {
              compactAt500 = DesktopBreakpoints.isCompact(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(700, 900)),
          child: Builder(
            builder: (context) {
              compactAt700 = DesktopBreakpoints.isCompact(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(compactAt500, isTrue);
    expect(compactAt700, isFalse);
  });
}
