import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kubus light map style starts from a non-white background', () {
    final style = jsonDecode(
      File('assets/map_styles/kubus_light.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final layers = style['layers'] as List<dynamic>;
    final background = layers.cast<Map<String, dynamic>>().firstWhere(
          (layer) => layer['id'] == 'background',
        );
    final paint = background['paint'] as Map<String, dynamic>;

    expect(paint['background-color'], isNot('#FFFFFF'));
    expect(paint['background-color'], '#F1F7FF');
  });
}
