import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'allowlists.dart';

/// Flags inline `GoogleFonts.*` calls outside the typography token file.
class KubusNoInlineGoogleFonts extends DartLintRule {
  const KubusNoInlineGoogleFonts() : super(code: _code);

  static const _code = LintCode(
    name: 'kubus_no_inline_google_fonts',
    problemMessage:
        'Inline GoogleFonts call. Use KubusTextStyles / the theme textTheme '
        '(lib/utils/design_tokens.dart).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.fullName;
    if (isAllowed(path, googleFontsAllowedSuffixes)) return;

    // google_fonts exposes fonts as static getters returning functions, so
    // `GoogleFonts.inter(...)` resolves as a FunctionExpressionInvocation.
    // Cover the plain static-method shape too for robustness.
    context.registry.addFunctionExpressionInvocation((node) {
      if (node.function.toSource().startsWith('GoogleFonts.')) {
        reporter.atNode(node, _code);
      }
    });
    context.registry.addMethodInvocation((node) {
      if (node.target?.toSource() == 'GoogleFonts') {
        reporter.atNode(node, _code);
      }
    });
  }
}
