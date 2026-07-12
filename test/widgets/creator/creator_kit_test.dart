import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:art_kubus/widgets/creator/creator_kit.dart';
import 'package:art_kubus/widgets/inline_loading.dart';

Widget _wrap(Widget child, {double width = 800}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );
}

// A 1x1 transparent PNG so the cover picker preview can decode real bytes.
final Uint8List _kTransparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group('CreatorDescriptionTextField', () {
    testWidgets('uses multiline keyboard, min lines and default max length',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CreatorDescriptionTextField(label: 'Description')),
      );

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field, isNotNull);

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.keyboardType, TextInputType.multiline);
      expect(editable.minLines, 4);
      expect(editable.maxLines, greaterThanOrEqualTo(10));

      // Large paste stays within the max length counter limit.
      await tester.enterText(
        find.byType(TextFormField),
        'a' * (CreatorDescriptionTextField.maxDescriptionLength + 500),
      );
      await tester.pump();
      expect(
        editable.controller.text.length,
        lessThanOrEqualTo(CreatorDescriptionTextField.maxDescriptionLength),
      );
    });
  });

  group('CreatorFooterActions', () {
    testWidgets('renders side by side on wide layouts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CreatorFooterActions(
            primaryLabel: 'Save',
            onPrimary: () {},
            secondaryLabel: 'Cancel',
            onSecondary: () {},
          ),
          width: 700,
        ),
      );

      final primary = tester.getCenter(find.text('Save'));
      final secondary = tester.getCenter(find.text('Cancel'));
      expect(primary.dy, moreOrLessEquals(secondary.dy, epsilon: 1));
    });

    testWidgets('stacks actions vertically on narrow layouts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CreatorFooterActions(
            primaryLabel: 'Save',
            onPrimary: () {},
            secondaryLabel: 'Cancel',
            onSecondary: () {},
          ),
          width: 320,
        ),
      );

      final primary = tester.getCenter(find.text('Save'));
      final secondary = tester.getCenter(find.text('Cancel'));
      expect(primary.dy, lessThan(secondary.dy));
    });

    testWidgets('shows spinner and disables button while loading',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          CreatorFooterActions(
            primaryLabel: 'Save',
            onPrimary: () => tapped = true,
            primaryLoading: true,
          ),
        ),
      );

      expect(find.byType(InlineLoading), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(tapped, isFalse);
    });
  });

  group('CreatorSearchField', () {
    testWidgets('reports changes and clears through the clear button',
        (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? lastChange;
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => CreatorSearchField(
              controller: controller,
              hint: 'Search',
              onChanged: (value) => setState(() => lastChange = value),
              onClear: () => setState(controller.clear),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'mural');
      await tester.pump();
      expect(lastChange, 'mural');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(controller.text, isEmpty);
    });
  });

  group('CreatorCoverImagePicker', () {
    testWidgets('renders preview with BoxFit.cover when bytes are present',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          CreatorCoverImagePicker(
            imageBytes: _kTransparentPng,
            uploadLabel: 'Upload',
            changeLabel: 'Change',
            removeTooltip: 'Remove',
            onPick: () {},
            onRemove: () {},
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      // With an image present the action label switches to "change".
      expect(find.text('Change'), findsOneWidget);
    });
  });

  group('CreatorDropdown', () {
    testWidgets('long labels stay constrained without horizontal overflow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          CreatorDropdown<String>(
            label: 'Type',
            value: 'a',
            items: [
              DropdownMenuItem(
                value: 'a',
                child: Text(
                  'An exceptionally long dropdown option label that would '
                  'overflow a narrow layout if not constrained properly',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (_) {},
          ),
          width: 280,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
