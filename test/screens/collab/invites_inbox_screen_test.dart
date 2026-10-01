import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/collab_invite.dart';
import 'package:art_kubus/models/event.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/screens/collab/invites_inbox_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CollabInvite _invite({String entity = 'exhibition', String role = 'editor'}) {
  return CollabInvite(
    id: 'inv-1',
    entityType: entity,
    entityId: 'ex-1',
    invitedUserId: 'u-me',
    invitedByUserId: 'u-ana',
    invitedBy: UserSummaryDto.fromJson(const {
      'id': 'u-ana',
      'displayName': 'Ana Kovač',
      'username': 'ana_kovac',
    }),
    role: role,
    status: 'pending',
    createdAt: DateTime.utc(2026, 9, 20),
    expiresAt: DateTime.utc(2026, 10, 20),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  Size size = const Size(390, 700),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeProvider().lightTheme,
    home: MediaQuery(
      data:
          MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('invitation states kind, entity, sender, role and dates',
      (tester) async {
    await _pump(
      tester,
      InviteRow(
        invite: _invite(),
        onAccept: () {},
        onDecline: () {},
        onOpen: () {},
      ),
    );
    expect(find.text('INVITATION · EXHIBITION'), findsOneWidget);
    expect(find.text('From Ana Kovač'), findsOneWidget);
    expect(find.text('Your role: Editor'), findsOneWidget);
    expect(find.textContaining('Received'), findsOneWidget);
    expect(find.textContaining('Expires'), findsOneWidget);
  });

  testWidgets('Accept, Decline and View are distinct actions', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      InviteRow(
        invite: _invite(),
        onAccept: () => calls.add('accept'),
        onDecline: () => calls.add('decline'),
        onOpen: () => calls.add('view'),
      ),
    );
    await tester.tap(find.text('Accept'));
    await tester.tap(find.text('Decline'));
    await tester.tap(find.text('View'));
    expect(calls, ['accept', 'decline', 'view']);
    for (final label in const ['Accept', 'Decline', 'View']) {
      final box = tester.getSize(find
          .ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((w) => w is ConstrainedBox),
          )
          .first);
      expect(box.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('while busy, accept/decline are disabled; view stays available',
      (tester) async {
    var viewed = false;
    var accepted = false;
    await _pump(
      tester,
      InviteRow(
        invite: _invite(),
        isBusy: true,
        onAccept: () => accepted = true,
        onDecline: () {},
        onOpen: () => viewed = true,
      ),
    );
    await tester.tap(find.text('Decline'));
    await tester.tap(find.text('View'));
    expect(accepted, isFalse);
    expect(viewed, isTrue);
  });

  testWidgets('SL copy at 320 px with 2x text fits', (tester) async {
    await _pump(
      tester,
      InviteRow(
        invite: _invite(entity: 'collection', role: 'curator'),
        onAccept: () {},
        onDecline: () {},
        onOpen: () {},
      ),
      locale: const Locale('sl'),
      size: const Size(320, 900),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sprejmi'), findsOneWidget);
    expect(find.text('Vaša vloga: Kustos'), findsOneWidget);
  });
}
