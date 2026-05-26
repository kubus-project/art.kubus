import 'dart:async';

import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/profile_package.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/community/user_profile_screen.dart' as mobile;
import 'package:art_kubus/screens/desktop/community/desktop_user_profile_screen.dart'
    as desktop;
import 'package:art_kubus/widgets/app_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('mobile public profile shows skeleton until critical package',
      (tester) async {
    final pending = Completer<ProfileCriticalPackage?>();

    await tester.pumpWidget(
      _harness(
        mobile.UserProfileScreen(
          userId: 'ProfileLoadingWallet111111111111111111111',
          initialCriticalPackageFuture: pending.future,
        ),
      ),
    );

    expect(find.byType(AppLoading), findsOneWidget);
    expect(find.text('first_post'), findsNothing);
    expect(find.text('First Post'), findsNothing);

    pending.complete(null);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('desktop public profile shows skeleton until critical package',
      (tester) async {
    final pending = Completer<ProfileCriticalPackage?>();

    await tester.pumpWidget(
      _harness(
        desktop.UserProfileScreen(
          userId: 'ProfileLoadingWallet111111111111111111111',
          initialCriticalPackageFuture: pending.future,
        ),
      ),
    );

    expect(find.byType(AppLoading), findsOneWidget);
    expect(find.text('first_post'), findsNothing);
    expect(find.text('First Post'), findsNothing);

    pending.complete(null);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _harness(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ThemeProvider(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}
