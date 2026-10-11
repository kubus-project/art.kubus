import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/models/art_marker.dart';
import 'package:art_kubus/utils/keyboard_activation_tracker.dart';
import 'package:art_kubus/widgets/common/kubus_marker_overlay_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

const String _title = 'Vodnik mural';

ArtMarker _marker() => ArtMarker(
      id: 'marker-1',
      name: _title,
      description: 'A mural on a wall.',
      position: const LatLng(46.0569, 14.5058),
      type: ArtMarkerType.artwork,
      createdAt: DateTime(2024),
      createdBy: 'uploader-wallet',
    );

/// A quick card hosted the way the map screens host it: a row opens it, Escape
/// closes it and clears focus first (as the desktop map's back handler does).
class _QuickCardHarness extends StatefulWidget {
  const _QuickCardHarness({required this.log});

  final List<String> log;

  @override
  State<_QuickCardHarness> createState() => _QuickCardHarnessState();
}

class _QuickCardHarnessState extends State<_QuickCardHarness> {
  final FocusNode before = FocusNode(debugLabel: 'before');
  final FocusNode row = FocusNode(debugLabel: 'row');
  final FocusNode after = FocusNode(debugLabel: 'after');
  final FocusNode search = FocusNode(debugLabel: 'search');

  bool open = false;
  bool rowVisible = true;
  bool removeRowOnOpen = false;
  int cardEpoch = 0;

  void openCard() {
    setState(() {
      open = true;
      if (removeRowOnOpen) rowVisible = false;
    });
  }

  void closeCard() => setState(() => open = false);

  void recreateCard() => setState(() => cardEpoch++);

  void _escape() {
    FocusManager.instance.primaryFocus?.unfocus();
    closeCard();
  }

  @override
  void dispose() {
    before.dispose();
    row.dispose();
    after.dispose();
    search.dispose();
    super.dispose();
  }

  List<MarkerOverlayActionSpec> _actions() => <MarkerOverlayActionSpec>[
        for (final name in <String>['Navigate', 'Save', 'Share', 'Likes 3'])
          MarkerOverlayActionSpec(
            id: name,
            icon: Icons.navigation_outlined,
            label: name,
            tooltip: name,
            semanticsLabel: name,
            isActive: false,
            activeColor: Colors.teal,
            onTap: () => widget.log.add('action:$name'),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.escape): _escape,
          },
          child: Stack(
            children: [
              Positioned(
                left: 16,
                top: 16,
                child: _TestButton(label: 'Before', focusNode: before),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: _TestButton(label: 'Search', focusNode: search),
              ),
              if (rowVisible)
                Positioned(
                  left: 16,
                  top: 80,
                  child: _TestButton(
                    label: 'Row',
                    focusNode: row,
                    onTap: openCard,
                  ),
                ),
              if (open)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 160,
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      child: KubusMarkerOverlayCard(
                        key: ValueKey<int>(cardEpoch),
                        marker: _marker(),
                        artwork: null,
                        baseColor: Colors.teal,
                        displayTitle: _title,
                        canPresentExhibition: false,
                        onClose: closeCard,
                        onPrimaryAction: () => widget.log.add('details'),
                        primaryActionIcon: Icons.arrow_forward,
                        primaryActionLabel: 'View details',
                        actions: _actions(),
                        fallbackFocusNode: search,
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                bottom: 16,
                child: _TestButton(label: 'After', focusNode: after),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestButton extends StatelessWidget {
  const _TestButton({
    required this.label,
    required this.focusNode,
    this.onTap,
  });

  final String label;
  final FocusNode focusNode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        focusNode: focusNode,
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(label),
        ),
      ),
    );
  }
}

/// The spoken label of the focused element: the nearest semantics label above
/// its focus node.
String? _focusedLabel() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return null;
  // Tooltips add label-less Semantics wrappers, so take the nearest label.
  String? label;
  context.visitAncestorElements((element) {
    final widget = element.widget;
    if (widget is Semantics && (widget.properties.label ?? '').isNotEmpty) {
      label = widget.properties.label;
      return false;
    }
    return true;
  });
  return label;
}

Future<void> _pressTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.pump();
}

Future<void> _pressShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

Future<void> _pumpHarness(WidgetTester tester, List<String> log) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_QuickCardHarness(log: log));
  await tester.pump();
}

_QuickCardHarnessState _harnessState(WidgetTester tester) =>
    tester.state<_QuickCardHarnessState>(find.byType(_QuickCardHarness));

void main() {
  setUp(() {
    KeyboardActivationTracker.install();
    KeyboardActivationTracker.resetForTests();
    resetMarkerOverlayFocusSessionForTests();
  });

  tearDown(() {
    resetMarkerOverlayFocusSessionForTests();
    KeyboardActivationTracker.resetForTests();
  });

  testWidgets('a keyboard open moves focus to the card title', (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);

    _harnessState(tester).row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(_focusedLabel(), _title);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'marker_overlay_entry',
    );
  });

  testWidgets('Tab visits the card in visual order and Directions is close',
      (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);

    _harnessState(tester).row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    final sequence = <String?>[_focusedLabel()];
    for (var press = 0; press < 8; press++) {
      await _pressTab(tester);
      sequence.add(_focusedLabel());
    }

    // The entry point, then seven presses: the card's controls in order, and
    // the first control after the card.
    expect(sequence.take(8).toList(), <String?>[
      _title,
      'Close',
      'Navigate',
      'Save',
      'Share',
      'Likes 3',
      'View details',
      'After',
    ]);
    // Title -> Close -> Navigate: Directions is the second Tab press.
    expect(sequence.indexOf('Navigate'), 2);
  });

  testWidgets('the card does not trap focus in either direction',
      (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);

    _harnessState(tester).row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    // Shift+Tab from the title leaves the card for the control before it.
    await _pressShiftTab(tester);
    expect(_focusedLabel(), 'Row');

    // Tab from there walks back into the card at its first control, close...
    await _pressTab(tester);
    expect(_focusedLabel(), 'Close');
    // ...and five presses later it is on the primary action, the last control.
    for (var press = 0; press < 5; press++) {
      await _pressTab(tester);
    }
    expect(_focusedLabel(), 'View details');
    // The next Tab leaves the card instead of wrapping inside it.
    await _pressTab(tester);
    expect(_focusedLabel(), 'After');
  });

  testWidgets('Enter on the title opens details like a tap', (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);

    _harnessState(tester).row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(_focusedLabel(), _title);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, <String>['details']);
  });

  testWidgets('a pointer open does not move focus', (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);

    await tester.tap(find.text('Row'));
    await tester.pump();
    await tester.pump();

    expect(find.text(_title), findsOneWidget);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      isNot('marker_overlay_entry'),
    );
    expect(_focusedLabel(), isNot(_title));
  });

  testWidgets('Escape closes the card and restores focus to the opener',
      (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);
    final state = _harnessState(tester);

    state.row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    expect(_focusedLabel(), _title);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();

    expect(find.text(_title), findsNothing);
    expect(state.row.hasPrimaryFocus, isTrue);
  });

  testWidgets(
      'closing restores focus to the search field when the opener is gone',
      (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);
    final state = _harnessState(tester);

    state.removeRowOnOpen = true;
    state.row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();

    expect(state.rowVisible, isFalse);
    expect(_focusedLabel(), _title);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    await tester.pump();

    expect(find.text(_title), findsNothing);
    expect(state.search.hasPrimaryFocus, isTrue);
  });

  testWidgets('a recreated card does not restore focus while it is open',
      (tester) async {
    final log = <String>[];
    await _pumpHarness(tester, log);
    final state = _harnessState(tester);

    state.row.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.pump();
    await _pressTab(tester);
    expect(_focusedLabel(), 'Close');

    // The overlay recreates the card when its placement changes. The control
    // that had focus is gone, so focus returns to the card's title rather than
    // to the opener or to nothing, and the card stays open.
    state.recreateCard();
    await tester.pump();
    await tester.pump();

    expect(find.text(_title), findsOneWidget);
    expect(_focusedLabel(), _title);
    expect(state.row.hasPrimaryFocus, isFalse);
  });

  testWidgets('Escape inside the card calls onEscape only when it is set',
      (tester) async {
    var escaped = 0;
    Widget card({VoidCallback? onEscape}) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: KubusMarkerOverlayCard(
                  marker: _marker(),
                  artwork: null,
                  baseColor: Colors.teal,
                  displayTitle: _title,
                  canPresentExhibition: false,
                  onClose: () {},
                  onPrimaryAction: () {},
                  primaryActionIcon: Icons.arrow_forward,
                  primaryActionLabel: 'View details',
                  onEscape: onEscape,
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(card(onEscape: () => escaped += 1));
    await tester.pump();
    // Tab into the card: its first stop is the close control.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusedLabel(), 'Close');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(escaped, 1);

    await tester.pumpWidget(card());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(escaped, 1);
  });

  testWidgets('the title is announced as a heading', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <String>[];
    await _pumpHarness(tester, log);

    await tester.tap(find.text('Row'));
    await tester.pump();
    await tester.pump();

    expect(
      tester.getSemantics(find.text(_title)),
      matchesSemantics(
        label: _title,
        isHeader: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
