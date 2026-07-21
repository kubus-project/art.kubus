import 'package:art_kubus/widgets/detail/profile_relationship_actions.dart';
import 'package:art_kubus/widgets/inline_loading.dart';
import 'package:art_kubus/widgets/kubus_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness(Widget child, {double width = 400}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

ProfileRelationshipActions _actions({
  bool isFollowing = false,
  bool isFollowLoading = false,
  VoidCallback? onFollow,
  VoidCallback? onMessage,
}) {
  return ProfileRelationshipActions(
    isFollowing: isFollowing,
    isFollowLoading: isFollowLoading,
    onFollow: onFollow ?? () {},
    onMessage: onMessage ?? () {},
    followLabel: 'Follow',
    followingLabel: 'Following',
    messageLabel: 'Message',
  );
}

void main() {
  testWidgets('renders Follow and Message with canonical KubusButtons',
      (tester) async {
    await tester.pumpWidget(_harness(_actions()));

    expect(find.text('Follow'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.byType(KubusButton), findsNWidgets(2));
    // No ad-hoc Material relationship buttons.
    expect(find.byType(ElevatedButton),
        findsNWidgets(2)); // internal to KubusButton
  });

  testWidgets('both actions meet the 44x44 minimum target', (tester) async {
    await tester.pumpWidget(_harness(_actions()));

    final followSize =
        tester.getSize(find.widgetWithText(KubusButton, 'Follow'));
    final messageSize =
        tester.getSize(find.widgetWithText(KubusButton, 'Message'));

    expect(followSize.height, greaterThanOrEqualTo(44));
    expect(followSize.width, greaterThanOrEqualTo(44));
    expect(messageSize.height, greaterThanOrEqualTo(44));
    expect(messageSize.width, greaterThanOrEqualTo(44));
  });

  testWidgets('Follow precedes Message in reading order at wide widths',
      (tester) async {
    await tester.pumpWidget(_harness(_actions(), width: 420));

    final followCenter =
        tester.getCenter(find.widgetWithText(KubusButton, 'Follow'));
    final messageCenter =
        tester.getCenter(find.widgetWithText(KubusButton, 'Message'));
    expect(followCenter.dx, lessThan(messageCenter.dx));
  });

  testWidgets('following state swaps to the Following label', (tester) async {
    await tester.pumpWidget(_harness(_actions(isFollowing: true)));
    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('loading shows a spinner, blocks taps, and keeps 44px height',
      (tester) async {
    var follows = 0;
    await tester.pumpWidget(
      _harness(_actions(isFollowLoading: true, onFollow: () => follows++)),
    );

    expect(find.byType(InlineLoading), findsOneWidget);
    await tester.tap(find.byType(KubusButton).first, warnIfMissed: false);
    expect(follows, 0);

    final followSize = tester.getSize(find.byType(KubusButton).first);
    expect(followSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('taps invoke the follow and message callbacks', (tester) async {
    var follows = 0;
    var messages = 0;
    await tester.pumpWidget(
      _harness(_actions(
        onFollow: () => follows++,
        onMessage: () => messages++,
      )),
    );

    await tester.tap(find.widgetWithText(KubusButton, 'Follow'));
    await tester.tap(find.widgetWithText(KubusButton, 'Message'));
    expect(follows, 1);
    expect(messages, 1);
  });

  testWidgets('stacks vertically on very narrow widths without overflow',
      (tester) async {
    await tester.pumpWidget(_harness(_actions(), width: 200));
    await tester.pumpAndSettle();

    // Both still present and tappable, stacked (Message below Follow).
    final followCenter =
        tester.getCenter(find.widgetWithText(KubusButton, 'Follow'));
    final messageCenter =
        tester.getCenter(find.widgetWithText(KubusButton, 'Message'));
    expect(messageCenter.dy, greaterThan(followCenter.dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Follow and Message are discoverable through semantics',
      (tester) async {
    await tester.pumpWidget(_harness(_actions()));
    expect(find.bySemanticsLabel('Follow'), findsOneWidget);
    expect(find.bySemanticsLabel('Message'), findsOneWidget);
  });
}
