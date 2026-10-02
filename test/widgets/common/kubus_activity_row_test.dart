import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/common/kubus_activity_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _row({required bool unread, Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(extensions: const [KubusColorRoles.light]),
    home: Scaffold(
      body: KubusActivityRow(
        icon: Icons.favorite,
        iconColor: Colors.pink,
        title: 'Ana liked your post',
        description: 'Riverside mural',
        timeLabel: '2 h',
        isUnread: unread,
        onTap: () {},
      ),
    ),
  );
}

void main() {
  testWidgets('unread state is announced in words, not only by colour',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_row(unread: true));
    expect(
      find.bySemanticsLabel(
          'Unread. Ana liked your post. Riverside mural. 2 h'),
      findsOneWidget,
    );
    await tester.pumpWidget(_row(unread: false));
    await tester.pump();
    expect(
      find.bySemanticsLabel('Ana liked your post. Riverside mural. 2 h'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Slovenian unread label is localized', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_row(unread: true, locale: const Locale('sl')));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^Neprebrano\\.')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('row is flat: no glass or gradient decoration', (tester) async {
    await tester.pumpWidget(_row(unread: true));
    expect(find.byType(BackdropFilter), findsNothing);
    final decorated = tester.widgetList<Container>(find.byType(Container));
    for (final c in decorated) {
      final d = c.decoration;
      if (d is BoxDecoration) {
        expect(d.gradient, isNull);
        expect(d.boxShadow, anyOf(isNull, isEmpty));
      }
    }
  });
}
