import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/recent_activity.dart';
import 'package:art_kubus/widgets/recent_activity_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(body: child),
  );
}

RecentActivity _sampleActivity() {
  return RecentActivity(
    id: 'activity-1',
    category: ActivityCategory.comment,
    title: 'New Comment',
    description: 'Alice: Nice artwork',
    timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    isRead: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recent activity tile keeps bounded height inside ListView',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        SizedBox(
          width: 420,
          height: 760,
          child: ListView(
            children: [
              RecentActivityTile(
                activity: _sampleActivity(),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tileFinder = find.byType(RecentActivityTile);
    expect(tileFinder, findsOneWidget);

    final tileSize = tester.getSize(tileFinder);
    // Guard against viewport-filling invisible overlay regressions.
    expect(tileSize.height, lessThan(260));
    expect(tileSize.height, greaterThan(60));
  });

  testWidgets('recent activity tile tap callback fires', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _buildApp(
        Center(
          child: SizedBox(
            width: 420,
            child: RecentActivityTile(
              activity: _sampleActivity(),
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(RecentActivityTile));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
