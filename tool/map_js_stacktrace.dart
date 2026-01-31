import 'dart:convert';
import 'dart:io';

import 'package:source_maps/parser.dart' as source_maps;
import 'package:source_maps/source_maps.dart';

void main(List<String> args) async {
  final mapPath = _readArg(args, '--map');
  final stackPath = _readArg(args, '--stack');

  if (mapPath == null || mapPath.trim().isEmpty) {
    stderr.writeln('Missing required --map <path to main.dart.js.map>.');
    exit(64);
  }

  final mapFile = File(mapPath);
  if (!mapFile.existsSync()) {
    stderr.writeln('Source map not found: $mapPath');
    exit(66);
  }

  final stack = await _readStack(stackPath);
  if (stack.trim().isEmpty) {
    stderr.writeln(
        'No stack trace provided. Use --stack <path> or pipe via stdin.');
    exit(64);
  }

  final mapJson = await mapFile.readAsString();
  final mapping = source_maps.parse(mapJson);

  final lines = LineSplitter.split(stack).toList();
  final frameRegex = RegExp(r'([\w.-]+\.js[^\s:]*):(\d+):(\d+)');

  for (final line in lines) {
    final match = frameRegex.firstMatch(line);
    if (match == null) {
      stdout.writeln(line);
      continue;
    }

    final rawLine = int.tryParse(match.group(2) ?? '');
    final rawColumn = int.tryParse(match.group(3) ?? '');
    if (rawLine == null || rawColumn == null) {
      stdout.writeln(line);
      continue;
    }

    final span = _lookup(mapping, rawLine - 1, rawColumn - 1);
    if (span == null) {
      stdout.writeln('$line -> (no mapping)');
      continue;
    }

    final sourceLine = span.start.line + 1;
    final sourceColumn = span.start.column + 1;
    final sourceUrl = span.sourceUrl?.toString() ?? '(unknown)';

    stdout.writeln('$line -> $sourceUrl:$sourceLine:$sourceColumn');
  }
}

Future<String> _readStack(String? stackPath) async {
  if (stackPath == null || stackPath.trim().isEmpty) {
    return stdin.transform(utf8.decoder).join();
  }
  final file = File(stackPath);
  if (!file.existsSync()) {
    stderr.writeln('Stack trace file not found: $stackPath');
    exit(66);
  }
  return file.readAsString();
}

SourceMapSpan? _lookup(Mapping mapping, int line, int column) {
  try {
    return mapping.spanFor(line, column);
  } catch (_) {
    return null;
  }
}

String? _readArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }
  return args[index + 1];
}
