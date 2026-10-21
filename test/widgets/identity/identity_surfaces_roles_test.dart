import 'package:art_kubus/community/community_interactions.dart';
import 'package:art_kubus/l10n/app_localizations.dart';
import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/community/community_comment_row.dart';
import 'package:art_kubus/widgets/profile_identity_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const _badgeKey = ValueKey<String>('profile-avatar-role-badge');
const _wallet = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

ProfileIdentityData _identity({
  String name = 'Ana Kovač',
  String? username = 'ana_kovac',
  bool artist = false,
  bool institution = false,
  bool verified = false,
}) =>
    ProfileIdentityData.fromIdentityPayload(
      {
        'author': {
          'id': 'ana-1',
          'walletAddress': _wallet,
          'displayName': name,
          if (username != null) 'username': username,
          'roles': {'artist': artist, 'institution': institution},
          'isVerified': verified,
        },
      },
      fallbackLabel: 'Unknown',
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        brightness: brightness,
        extensions: [
          brightness == Brightness.dark
              ? KubusColorRoles.dark
              : KubusColorRoles.light,
        ],
      ),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
}

Widget _summary(
  ProfileIdentityData identity, {
  double radius = 20,
  ProfileIdentityLayout layout = ProfileIdentityLayout.row,
}) =>
    ProfileIdentitySummary(
      identity: identity,
      layout: layout,
      avatarRadius: radius,
      fetchMissingAvatar: false,
      allowFabricatedFallback: false,
      onTap: () {},
    );

int _semanticNodesWith(WidgetTester tester, Pattern pattern) {
  var count = 0;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (data.label.contains(pattern)) count++;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // The finders read this owner; the rootPipelineOwner is a different tree here.
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
  return count;
}

/// The merged label of the semantics node that speaks [name], or '' if none.
String _identityLabel(WidgetTester tester, String name) {
  var label = '';
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    if (label.isEmpty && data.label.contains(name)) label = data.label;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  // The finders read this owner; the rootPipelineOwner is a different tree here.
  // ignore: deprecated_member_use
  final root = tester.binding.pipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) visit(root);
  return label;
}

void main() {
  group('ProfileIdentitySummary', () {
    testWidgets('speaks name, handle, role and verification as one label',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        _summary(_identity(artist: true, verified: true)),
      );
      final label = _identityLabel(tester, 'Ana Kovač');
      expect(label, contains('Ana Kovač'));
      expect(label, contains('ana_kovac'));
      expect(label, contains('Artist'));
      expect(label, contains('Verified'));
      // No second node repeats the role for the same person.
      expect(_semanticNodesWith(tester, 'Artist'), 1);
      handle.dispose();
    });

    testWidgets('a person with no stated role carries no role text',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _summary(_identity()));
      expect(find.byKey(_badgeKey), findsNothing);
      expect(_semanticNodesWith(tester, 'Artist'), 0);
      expect(_semanticNodesWith(tester, 'Institution'), 0);
      handle.dispose();
    });

    for (final layout in ProfileIdentityLayout.values) {
      testWidgets('${layout.name}: dual role with a long name at 200% text',
          (tester) async {
        await _pump(
          tester,
          _summary(
            _identity(
              name: 'Muzej in galerija sodobne umetnosti Ljubljana in okolica',
              username: 'muzej_galerija_sodobne_umetnosti_ljubljana',
              artist: true,
              institution: true,
              verified: true,
            ),
            layout: layout,
          ),
          width: 320,
          textScale: 2,
        );
        expect(find.byKey(_badgeKey), findsOneWidget);
        expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
        expect(find.byIcon(Icons.account_balance_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('missing avatar still shows initials with the badge',
        (tester) async {
      await _pump(tester, _summary(_identity(institution: true)));
      expect(find.text('AK'), findsOneWidget);
      expect(find.byKey(_badgeKey), findsOneWidget);
    });

    testWidgets('the whole identity stays one tap target', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        ProfileIdentitySummary(
          identity: _identity(artist: true),
          fetchMissingAvatar: false,
          allowFabricatedFallback: false,
          onTap: () => taps++,
        ),
      );
      final badge = tester.getRect(find.byKey(_badgeKey));
      await tester.tapAt(badge.center);
      expect(taps, 1);
    });
  });

  group('CommunityCommentRow', () {
    Comment comment({bool artist = false, bool institution = false}) => Comment(
          id: 'c1',
          authorIdentityData: _identity(
            artist: artist,
            institution: institution,
            verified: artist,
          ),
          content: 'Thank you!',
          timestamp: DateTime(2026, 9, 20, 16),
        );

    for (final reply in [false, true]) {
      testWidgets(
          '${reply ? 'reply' : 'comment'}: author badge on the avatar, none '
          'beside the name', (tester) async {
        await _pump(
          tester,
          CommunityCommentRow(
            comment: comment(artist: true),
            isReply: reply,
            timeLabel: '2h ago',
          ),
        );
        expect(find.byKey(_badgeKey), findsOneWidget);
        expect(find.byIcon(Icons.brush_rounded), findsOneWidget);
        final avatar = tester.getRect(find.byType(ProfileIdentitySummary));
        final badge = tester.getRect(find.byKey(_badgeKey));
        expect(badge.left, greaterThanOrEqualTo(avatar.left));
        // The compact reply avatar (24 px) stays tappable and uncluttered.
        expect(badge.height, lessThanOrEqualTo(reply ? 14 : 16));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a comment whose author states no role has no badge',
        (tester) async {
      await _pump(
        tester,
        CommunityCommentRow(
          comment: comment(),
          isReply: false,
          timeLabel: '2h ago',
        ),
      );
      expect(find.byKey(_badgeKey), findsNothing);
    });
  });
}
