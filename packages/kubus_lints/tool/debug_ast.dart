// Resolved-AST shape probe for rule debugging. Run from packages/kubus_lints:
//   puro dart run tool/debug_ast.dart
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

Future<void> main() async {
  final path =
      '${Directory.current.path}\\example\\lib\\fixture.dart'.replaceAll('/', '\\');
  final collection = AnalysisContextCollection(includedPaths: [path]);
  final context = collection.contextFor(path);
  final result = await context.currentSession.getResolvedUnit(path);
  if (result is! ResolvedUnitResult) {
    print('resolution failed: $result');
    return;
  }
  result.unit.accept(_Dump());
}

class _Dump extends RecursiveAstVisitor<void> {
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.toSource().contains('GoogleFonts')) {
      print('MethodInvocation: ${node.toSource()}');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.toSource().contains('GoogleFonts')) {
      print('InstanceCreation: ${node.toSource()}');
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (node.toSource().contains('GoogleFonts')) {
      print('FunctionExpressionInvocation: ${node.toSource()}');
    }
    super.visitFunctionExpressionInvocation(node);
  }
}
