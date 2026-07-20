import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/widgets/profile/profile_account_health_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake notice that mimics the banner contract: resolves its visibility
/// asynchronously and renders nothing while hidden.
class _FakeNotice extends StatefulWidget {
  const _FakeNotice({
    required this.visible,
    required this.label,
    required this.onVisibilityResolved,
  });

  final bool visible;
  final String label;
  final ValueChanged<bool> onVisibilityResolved;

  @override
  State<_FakeNotice> createState() => _FakeNoticeState();
}

class _FakeNoticeState extends State<_FakeNotice> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onVisibilityResolved(widget.visible);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Text(widget.label);
  }
}

void main() {
  Widget harness({
    required bool criticalVisible,
    required bool advisoryVisible,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProfileAccountHealthSection(
          criticalBuilder: (resolve) => _FakeNotice(
            visible: criticalVisible,
            label: 'critical-notice',
            onVisibilityResolved: resolve,
          ),
          advisoryBuilder: (resolve) => _FakeNotice(
            visible: advisoryVisible,
            label: 'advisory-notice',
            onVisibilityResolved: resolve,
          ),
        ),
      ),
    );
  }

  testWidgets('renders nothing when no notice fires', (tester) async {
    await tester.pumpWidget(
      harness(criticalVisible: false, advisoryVisible: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account health'), findsNothing);
    expect(find.text('Account suggestions'), findsNothing);
    expect(find.text('critical-notice'), findsNothing);
    expect(find.text('advisory-notice'), findsNothing);
  });

  testWidgets('critical notice renders inline and expanded', (tester) async {
    await tester.pumpWidget(
      harness(criticalVisible: true, advisoryVisible: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account health'), findsOneWidget);
    expect(find.text('critical-notice'), findsOneWidget);
    expect(find.text('Account suggestions'), findsNothing);
  });

  testWidgets('advisory-only notice renders inline without a disclosure',
      (tester) async {
    await tester.pumpWidget(
      harness(criticalVisible: false, advisoryVisible: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account health'), findsOneWidget);
    expect(find.text('advisory-notice'), findsOneWidget);
    expect(find.text('Account suggestions'), findsNothing);
  });

  testWidgets(
      'advisory collapses behind the disclosure while critical is present',
      (tester) async {
    await tester.pumpWidget(
      harness(criticalVisible: true, advisoryVisible: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account health'), findsOneWidget);
    expect(find.text('critical-notice'), findsOneWidget);
    expect(find.text('Account suggestions'), findsOneWidget);

    // The advisory widget stays mounted (so its state persists) but is not
    // visible while collapsed.
    expect(find.text('advisory-notice'), findsNothing);
    final advisoryOffstage = tester.widget<Offstage>(
      find
          .ancestor(
            of: find.text('advisory-notice', skipOffstage: false),
            matching: find.byType(Offstage, skipOffstage: false),
          )
          .first,
    );
    expect(advisoryOffstage.offstage, isTrue);

    await tester.tap(find.text('Account suggestions'));
    await tester.pumpAndSettle();

    final expanded = tester.widget<Offstage>(
      find
          .ancestor(
            of: find.text('advisory-notice'),
            matching: find.byType(Offstage),
          )
          .first,
    );
    expect(expanded.offstage, isFalse);
  });
}
