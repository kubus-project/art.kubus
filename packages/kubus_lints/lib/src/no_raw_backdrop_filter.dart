import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

/// Flags raw `BackdropFilter` construction outside the canonical glass stack
/// so blur fallback and glass tokens stay consistent everywhere.
class KubusNoRawBackdropFilter extends DartLintRule {
  const KubusNoRawBackdropFilter() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_raw_backdropfilter',
    problemMessage:
        'Raw BackdropFilter. Use GlassSurface / LiquidGlassPanel / '
        'showKubusDialog so blur fallback & tokens stay consistent.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, backdropFilterAllowedSuffixes)) return;

    context.registry.addInstanceCreationExpression((node) {
      if (node.constructorName.type.name.lexeme == 'BackdropFilter') {
        reporter.atNode(node, _code);
      }
    });
  }
}
