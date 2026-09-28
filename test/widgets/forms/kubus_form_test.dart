import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/providers/themeprovider.dart';
import 'package:art_kubus/utils/design_tokens.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/forms/kubus_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
}) {
  final theme = ThemeProvider();
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: brightness == Brightness.dark ? theme.darkTheme : theme.lightTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  group('KubusFormTextField', () {
    testWidgets('keeps a persistent label that is the spoken field name',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const KubusFormTextField(
        label: 'Username',
        hintText: 'artist_name',
        required: true,
      )));

      // Label stays visible with and without a value (placeholder is not
      // the only label).
      expect(find.text('Username'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'ana');
      await tester.pump();
      expect(find.text('Username'), findsOneWidget);

      final node = tester.getSemantics(find.byType(TextField));
      expect(node.label, contains('Username'));
      expect(node.label.toLowerCase(), contains('required'));
      expect(node.label, isNot(contains('*')));
      handle.dispose();
    });

    testWidgets('no error before the first submit; errors track input after',
        (tester) async {
      final formKey = GlobalKey<FormState>();
      final submit = KubusFormSubmitState();
      late StateSetter rebuild;
      await tester.pumpWidget(_app(StatefulBuilder(builder: (context, set) {
        rebuild = set;
        return Form(
          key: formKey,
          autovalidateMode: submit.autovalidateMode,
          child: KubusFormTextField(
            label: 'Display name',
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Enter a display name.' : null,
          ),
        );
      })));

      // Typing then clearing before any submit must not show red.
      await tester.enterText(find.byType(TextFormField), 'a');
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(find.text('Enter a display name.'), findsNothing);

      expect(submit.validate(formKey), isFalse);
      rebuild(() {});
      await tester.pump();
      expect(find.text('Enter a display name.'), findsOneWidget);
      expect(submit.autovalidateMode, AutovalidateMode.onUserInteraction);

      await tester.enterText(find.byType(TextFormField), 'Ana');
      await tester.pump();
      expect(find.text('Enter a display name.'), findsNothing);
    });

    testWidgets('password toggles visibility with a labelled button',
        (tester) async {
      await tester.pumpWidget(_app(const KubusFormTextField(
        label: 'Password',
        kind: KubusFieldKind.password,
      )));
      EditableText editable() =>
          tester.widget<EditableText>(find.byType(EditableText));
      expect(editable().obscureText, isTrue);
      expect(find.byTooltip('Show password'), findsOneWidget);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(editable().obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('number accepts digits only; currency shows a machine unit',
        (tester) async {
      await tester.pumpWidget(_app(const Column(
        children: [
          KubusFormTextField(label: 'Years', kind: KubusFieldKind.number),
          KubusFormTextField(
            label: 'Price',
            kind: KubusFieldKind.currency,
            unitLabel: 'KUB8',
          ),
        ],
      )));
      await tester.enterText(find.byType(TextFormField).first, '12ab3');
      expect(find.text('123'), findsOneWidget);

      final unit = tester.widget<Text>(find.text('KUB8'));
      expect(unit.style?.fontFamily, KubusTypography.structuralFamily);
      await tester.enterText(find.byType(TextFormField).last, '2.5x');
      expect(find.text('2.5'), findsOneWidget);
    });

    testWidgets('field decoration is flat and uses semantic roles',
        (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(_app(
          const KubusFormTextField(label: 'Name'),
          brightness: brightness,
        ));
        final roles =
            KubusColorRoles.of(tester.element(find.byType(KubusFormTextField)));
        final decorator =
            tester.widget<InputDecorator>(find.byType(InputDecorator));
        final decoration = decorator.decoration;
        expect(decoration.filled, isTrue);
        expect(decoration.fillColor, roles.surface);
        final enabled = decoration.enabledBorder! as OutlineInputBorder;
        final focused = decoration.focusedBorder! as OutlineInputBorder;
        expect(enabled.borderSide.color, roles.rule);
        expect(focused.borderSide.color, roles.focus);
        expect(
            enabled.borderRadius, BorderRadius.circular(KubusRadius.control));
        final field = tester.getSize(find.byType(TextField));
        expect(field.height, lessThanOrEqualTo(56),
            reason: 'no giant field heights');
      }
    });
  });

  group('choice rows', () {
    testWidgets('switch row: whole row toggles, 48 px, toggle semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      var value = false;
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, set) => KubusFormSwitchRow(
          title: 'Private profile',
          description: 'Only followers see your activity.',
          value: value,
          onChanged: (v) => set(() => value = v),
        ),
      )));
      expect(tester.getSize(find.byType(KubusFormSwitchRow)).height,
          greaterThanOrEqualTo(48));

      await tester.tap(find.text('Private profile'));
      await tester.pump();
      expect(value, isTrue);
      expect(
        tester.getSemantics(find.byType(Switch)),
        isSemantics(
          label: 'Private profile\nOnly followers see your activity.',
          hasToggledState: true,
          isToggled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('disabled switch row ignores taps', (tester) async {
      await tester.pumpWidget(_app(const KubusFormSwitchRow(
        title: 'Share last visited place',
        value: false,
        onChanged: null,
      )));
      await tester.tap(find.text('Share last visited place'));
      await tester.pump();
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    testWidgets('checkbox and radio rows select by row', (tester) async {
      var checked = false;
      String? choice = 'a';
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, set) => Column(
          children: [
            KubusFormCheckboxRow(
              title: 'I agree',
              value: checked,
              onChanged: (v) => set(() => checked = v),
            ),
            KubusFormRadioGroup<String>(
              label: 'Visibility',
              value: choice,
              onChanged: (v) => set(() => choice = v),
              options: const [
                KubusRadioOption(value: 'a', title: 'Public'),
                KubusRadioOption(value: 'b', title: 'Followers'),
              ],
            ),
          ],
        ),
      )));
      await tester.tap(find.text('I agree'));
      await tester.tap(find.text('Followers'));
      await tester.pump();
      expect(checked, isTrue);
      expect(choice, 'b');
    });
  });

  testWidgets('select and date fields keep persistent labels (SL)',
      (tester) async {
    await tester.pumpWidget(_app(
      Column(
        children: [
          KubusFormSelect<String>(
            label: 'Vrsta',
            value: 'x',
            onChanged: (_) {},
            items: const [
              DropdownMenuItem(value: 'x', child: Text('Galerija')),
            ],
          ),
          KubusFormDateField(
            label: 'Začetek',
            value: null,
            onChanged: (_) {},
          ),
        ],
      ),
      locale: const Locale('sl'),
    ));
    expect(find.text('Vrsta'), findsOneWidget);
    expect(find.text('Začetek'), findsOneWidget);
    expect(find.text('Izberite datum'), findsOneWidget);
  });

  testWidgets('input formatter keeps Space Mono out of content values',
      (tester) async {
    await tester.pumpWidget(_app(const KubusFormTextField(label: 'Bio')));
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.style.fontFamily, KubusTypography.contentFamily);
    expect(
      tester
          .widget<TextField>(find.byType(TextField))
          .inputFormatters
          ?.whereType<FilteringTextInputFormatter>(),
      anyOf(isNull, isEmpty),
    );
  });

  testWidgets('sections announce a structural heading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const KubusFormSection(
      title: 'Links',
      children: [KubusFormTextField(label: 'Website')],
    )));
    expect(find.text('LINKS'), findsOneWidget);
    final heading = tester.widget<Text>(find.text('LINKS'));
    expect(heading.style?.fontFamily, KubusTypography.structuralFamily);
    handle.dispose();
  });
}
