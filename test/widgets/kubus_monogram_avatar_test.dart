import 'package:art_kubus/widgets/avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('is a square with the avatar corner radius, never a circle',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: KubusMonogramAvatar(radius: 20, child: Text('MN'))),
    ));
    final box = tester.widget<Container>(find.byType(Container).first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.rectangle);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(AvatarWidget.shapeRadiusFor(radius: 20)),
    );
    expect(
        tester.getSize(find.byType(KubusMonogramAvatar)), const Size(40, 40));
    expect(find.text('MN'), findsOneWidget);
  });
}
