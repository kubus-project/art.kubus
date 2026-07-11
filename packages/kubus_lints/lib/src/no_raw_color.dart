import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

/// Flags inline `Color(0x...)` / `Color.fromARGB` / `Color.fromRGBO`
/// literals outside the central token/role files.
class KubusNoRawColor extends DartLintRule {
  const KubusNoRawColor() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_color',
    problemMessage:
        'Raw Color literal. Define it centrally (KubusColors, '
        'KubusColorRoles, KubusAccentGradients) and reference the token.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, rawColorAllowedSuffixes)) return;

    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Color') return;
      // Only flag literal-constructed colors; `Color.lerp`, variables, and
      // scheme-derived colors are fine.
      reporter.atNode(node, _code);
    });
  }
}
