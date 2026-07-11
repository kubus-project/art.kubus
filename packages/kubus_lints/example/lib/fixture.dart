// Fixture file exercising every kubus lint rule. `dart run custom_lint`
// in this package fails if any expect_lint marker does not fire (or if an
// unexpected lint fires).
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// expect_lint: kubus_no_raw_color
const bad = Color(0xFF123456);

// expect_lint: kubus_no_raw_color
final badArgb = Color.fromARGB(255, 1, 2, 3);

final okNamed = Colors.transparent;

// expect_lint: kubus_no_raw_border
final badBorder = Border.all(color: Colors.red);

// Border.all with a variable color is allowed (only literals are flagged).
final okBorder = Border.all(color: okNamed);

// expect_lint: kubus_no_raw_border, kubus_no_raw_color
const badSide = BorderSide(color: Color(0xFF000000));

// expect_lint: kubus_no_raw_backdropfilter
final badBlur = BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
  child: const SizedBox.shrink(),
);

// expect_lint: kubus_no_inline_google_fonts
final badFont = GoogleFonts.inter(fontSize: 12);
