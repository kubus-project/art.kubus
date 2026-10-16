import 'package:art_kubus/utils/kubus_color_roles.dart';
import 'package:art_kubus/widgets/community/community_post_token_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final values = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (values.last + 0.05) / (values.first + 0.05);
}

void main() {
  for (final roles in [KubusColorRoles.light, KubusColorRoles.dark]) {
    testWidgets('hashtag remains readable and navigable on ${roles.surface}',
        (tester) async {
      var tapped = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(extensions: [roles]),
        home: Scaffold(
          body: CommunityPostTokenChip(
            label: '#Art',
            onTap: () => tapped++,
          ),
        ),
      ));
      final text = tester.widget<Text>(find.text('#Art'));
      final ink = tester.widget<Ink>(find.byType(Ink));
      final fill = (ink.decoration! as BoxDecoration).color!;
      final control = tester.widget<InkWell>(find.byType(InkWell));
      for (final background in [
        fill,
        Color.alphaBlend(control.hoverColor!, fill),
        Color.alphaBlend(control.focusColor!, fill),
      ]) {
        expect(contrast(text.style!.color!, background),
            greaterThanOrEqualTo(4.5));
      }
      await tester.tap(find.text('#Art'));
      expect(tapped, 1);
    });
  }
}
