import 'dart:convert';
import 'dart:io';
import 'package:custom_lint_builder/src/channel.dart';
import 'package:kubus_lints/kubus_lints.dart' as kubus_lints;


void main(List<String> args) async {
  final host = args[0];
  final port = int.parse(args[1]);

  runSocket(
    port: port,
    host: host,
    fix: false,
    includeBuiltInLints: true,
    {'kubus_lints': kubus_lints.createPlugin,
},
  );
}
